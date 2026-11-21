//
//  TripEditView.swift
//  SimRa
//
//  Created by Emil Pauls on 25.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import MapKit
import UIKit

// MARK: - Notifications

private enum TripEditNotifications {
    static let tripEdited = Notification.Name("tripEdited")
    static let annotationChanged = Notification.Name("annotationChanged")
}

// MARK: - Trip Point

@objc(TripPoint)
public final class TripPoint: NSObject, MKAnnotation, Identifiable {

    public var title: String?

    public var tripLocation: TripLocation

    /// True while a manually created annotation is being edited
    /// and has not yet been persisted.
    public var isPending = false

    /// Stable SwiftUI identity.
    public let id = UUID().uuidString

    public var subtitle: String? { nil }

    public var displayTitle: String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty
            ? NSLocalizedString("Danger", comment: "Fallback incident title")
            : trimmed
    }

    public var coordinate: CLLocationCoordinate2D {
        tripLocation.location.coordinate
    }

    public init(tripLocation: TripLocation) {
        self.tripLocation = tripLocation
        super.init()
    }
}

// MARK: - Host Delegate

@objc
public protocol TripEditViewHostDelegate: AnyObject {

    /// Only called when `usesDelegateForPresentation` is true.
    func tripEditViewHostDidRequestDetails(_ host: TripEditViewHostController)

    /// Only called when `usesDelegateForPresentation` is true.
    /// Call `annotationEditingDidFinish(_:saved:)` on the host afterwards.
    func tripEditViewHost(
        _ host: TripEditViewHostController,
        didRequestAnnotationEdit point: TripPoint
    )

    /// Called whenever start or end of the selection changes
    /// (e.g. to update the enabled state of an external trim button).
    @objc optional func tripEditViewHostSelectionDidChange(_ host: TripEditViewHostController)

    /// Called after the trip has been trimmed and saved.
    @objc optional func tripEditViewHostDidTrim(_ host: TripEditViewHostController)
}

// MARK: - View Model

@MainActor
final class TripEditViewModel: ObservableObject {

    private enum Limits {
        static let maximumRoutePoints = 1800
        static let maximumSelectedRoutePoints = 900
    }

    // MARK: Model

    let trip: Trip

    // MARK: Published State

    @Published private(set) var locations: [TripLocation] = []
    @Published private(set) var startIndex = 0
    @Published private(set) var endIndex = 0
    @Published private(set) var tripPoints: [TripPoint] = []
    @Published var cameraPosition: MapCameraPosition = .automatic
    @Published private(set) var changed = false
    @Published private(set) var routeCoordinates: [CLLocationCoordinate2D] = []
    @Published private(set) var selectedRouteCoordinates: [CLLocationCoordinate2D] = []

    // MARK: Callbacks

    var onSelectionChanged: (() -> Void)?
    var onTrimmed: (() -> Void)?

    // MARK: Caches

    private var coordinates: [CLLocationCoordinate2D] = []
    private var indexByLocation: [ObjectIdentifier: Int] = [:]

    private var incidentTypes: [String] {
        AppDelegate.shared().constants["incidents"] as? [String] ?? []
    }

    // MARK: Init

    init(trip: Trip) {
        self.trip = trip
        reload()
    }

    // MARK: Computed State

    var editingDisabled: Bool {
        trip.uploaded || trip.statisticsAdded
    }

    var hasLocations: Bool {
        !locations.isEmpty
    }

    /// A range can only be edited if there are at least two points.
    var canEditRange: Bool {
        !editingDisabled && locations.count >= 2
    }

    var hasChangedRange: Bool {
        guard !locations.isEmpty else { return false }
        return startIndex != 0 || endIndex != locations.count - 1
    }

    var canTrim: Bool {
        canEditRange && hasChangedRange && startIndex < endIndex
    }

    var selectedPointCount: Int {
        guard !locations.isEmpty else { return 0 }
        return max(endIndex - startIndex + 1, 0)
    }

    /// Number of saved incidents that would be deleted by trimming.
    var incidentsOutsideSelectionCount: Int {
        tripPoints.filter { !$0.isPending && !isInsideSelection($0) }.count
    }

    func coordinate(at index: Int) -> CLLocationCoordinate2D? {
        guard coordinates.indices.contains(index) else { return nil }
        return coordinates[index]
    }

    func isInsideSelection(_ point: TripPoint) -> Bool {
        guard let index = indexByLocation[ObjectIdentifier(point.tripLocation)] else {
            return true
        }
        return index >= startIndex && index <= endIndex
    }

    // MARK: Reload

    func reload() {
        var collected: [TripLocation] = []
        collected.reserveCapacity(trip.tripLocations.count)

        for case let location as TripLocation in trip.tripLocations {
            collected.append(location)
        }

        apply(locations: collected)
    }

    private func apply(locations newLocations: [TripLocation]) {
        locations = newLocations

        coordinates = newLocations.map { location in
            let clLocation: CLLocation = location.location
            return clLocation.coordinate
        }

        var lookup: [ObjectIdentifier: Int] = [:]
        lookup.reserveCapacity(newLocations.count)
        for (index, location) in newLocations.enumerated() {
            lookup[ObjectIdentifier(location)] = index
        }
        indexByLocation = lookup

        startIndex = 0
        endIndex = max(newLocations.count - 1, 0)
        changed = false

        routeCoordinates = Self.downsample(
            coordinates[...],
            maximumCount: Limits.maximumRoutePoints
        )

        updateSelectedRoute()
        rebuildTripPoints()
        updateCamera()
    }

    // MARK: Route Helpers

    /// Evenly thins out a coordinate slice. First and last point are always kept.
    private static func downsample(
        _ source: ArraySlice<CLLocationCoordinate2D>,
        maximumCount: Int
    ) -> [CLLocationCoordinate2D] {
        guard source.count > maximumCount, maximumCount >= 2 else {
            return Array(source)
        }

        let first = source.startIndex
        let step = Double(source.count - 1) / Double(maximumCount - 1)

        var result: [CLLocationCoordinate2D] = []
        result.reserveCapacity(maximumCount)

        for index in 0..<maximumCount {
            let offset = min(source.count - 1, Int((Double(index) * step).rounded()))
            result.append(source[first + offset])
        }

        return result
    }

    private func updateSelectedRoute() {
        guard !coordinates.isEmpty,
              startIndex >= 0,
              startIndex <= endIndex,
              endIndex < coordinates.count
        else {
            selectedRouteCoordinates = []
            return
        }

        selectedRouteCoordinates = Self.downsample(
            coordinates[startIndex...endIndex],
            maximumCount: Limits.maximumSelectedRoutePoints
        )
    }

    // MARK: Selection

    func updateStartIndex(_ value: Int) {
        guard canEditRange else { return }

        let newValue = min(max(value, 0), endIndex - 1)
        guard newValue != startIndex else { return }

        startIndex = newValue
        selectionDidChange()
    }

    func updateEndIndex(_ value: Int) {
        guard canEditRange else { return }

        let newValue = max(min(value, locations.count - 1), startIndex + 1)
        guard newValue != endIndex else { return }

        endIndex = newValue
        selectionDidChange()
    }

    private func selectionDidChange() {
        changed = hasChangedRange
        updateSelectedRoute()
        onSelectionChanged?()
    }

    // MARK: Save / Trim

    @discardableResult
    func applySelection() -> Bool {
        guard canTrim, endIndex < locations.count else { return false }

        let lower = startIndex
        let upper = endIndex
        let selectedLocations = Array(locations[lower...upper])

        guard !selectedLocations.isEmpty else { return false }

        updateCSVFiles(for: selectedLocations)

        for (index, location) in locations.enumerated() where index < lower || index > upper {
            location.tripMotions.removeAllObjects()
            location.tripAnnotation = nil
        }

        trip.tripLocations.removeAllObjects()
        trip.tripLocations.addObjects(from: selectedLocations)
        trip.edited = true
        trip.save()

        apply(locations: selectedLocations)

        NotificationCenter.default.post(name: TripEditNotifications.tripEdited, object: trip)

        onTrimmed?()
        onSelectionChanged?()

        return true
    }

    func persistAnnotations() {
        trip.save()
        changed = hasChangedRange
    }

    // MARK: CSV

    private func updateCSVFiles(for locations: [TripLocation]) {
        let documents = Self.documentsDirectoryURL()
        let locationsURL = documents.appendingPathComponent("TripLocations-\(trip.identifier).csv")
        let motionsURL = documents.appendingPathComponent("TripMotions-\(trip.identifier).csv")

        // Helpers are only used for formatting, so one instance each is enough.
        let gyroHelper = TripGyro()
        let motionHelper = TripMotion()

        var locationLines: [String] = []
        var motionLines: [String] = []
        locationLines.reserveCapacity(locations.count)

        for location in locations {
            let gyro = location.gyro ?? TripGyro()

            locationLines.append(
                gyroHelper.locationString(
                    from: location,
                    gyro: gyro,
                    closePassInfo: location.closePassInfo
                )
            )

            for case let motion as TripMotion in location.tripMotions {
                motionLines.append(motionHelper.motionString(from: motion))
            }
        }

        try? locationLines
            .joined(separator: "\n")
            .data(using: .utf8)?
            .write(to: locationsURL, options: .atomic)

        try? motionLines
            .joined(separator: "\n")
            .data(using: .utf8)?
            .write(to: motionsURL, options: .atomic)
    }

    private static func documentsDirectoryURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // MARK: Incident Points

    private static func incidentTitle(for incidentID: Int, types: [String]) -> String {
        types.indices.contains(incidentID)
            ? types[incidentID]
            : NSLocalizedString("Danger", comment: "Fallback incident title")
    }

    /// Synchronous on purpose: an asynchronous rebuild could overwrite
    /// a pending annotation that was added while the task was running.
    private func rebuildTripPoints() {
        let types = incidentTypes
        var points: [TripPoint] = []

        for location in locations {
            guard let annotation = location.tripAnnotation,
                  annotation.incidentId >= 0
            else { continue }

            let point = TripPoint(tripLocation: location)
            point.title = Self.incidentTitle(for: Int(annotation.incidentId), types: types)
            point.isPending = false
            points.append(point)
        }

        tripPoints = points
    }

    /// Updates one marker after its annotation was saved.
    func refreshSavedAnnotation(_ point: TripPoint) {
        point.isPending = false

        guard let annotation = point.tripLocation.tripAnnotation else {
            tripPoints.removeAll { $0 === point }
            return
        }

        point.title = Self.incidentTitle(for: Int(annotation.incidentId), types: incidentTypes)

        if !tripPoints.contains(where: { $0 === point }) {
            tripPoints.append(point)
        }

        // TripPoint is a class: notify SwiftUI explicitly that its values changed.
        objectWillChange.send()
    }

    // MARK: Pending Annotation

    func discardPendingAnnotation(_ point: TripPoint) {
        guard point.isPending else { return }

        point.tripLocation.tripAnnotation = nil
        tripPoints.removeAll { $0 === point }
    }

    // MARK: Add Annotation

    /// Returns a new pending annotation at the nearest track point,
    /// or the existing annotation if that point already has one.
    /// Returns nil if the press was too far away from the track.
    func annotationPoint(
        near coordinate: CLLocationCoordinate2D,
        tolerance: CLLocationDistance
    ) -> TripPoint? {
        guard !editingDisabled,
              !locations.isEmpty,
              CLLocationCoordinate2DIsValid(coordinate)
        else { return nil }

        let target = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        var closest: TripLocation?
        var closestDistance = CLLocationDistance.greatestFiniteMagnitude

        for location in locations {
            let clLocation: CLLocation = location.location
            let distance = clLocation.distance(from: target)

            if distance < closestDistance {
                closestDistance = distance
                closest = location
            }
        }

        guard let closest, closestDistance <= tolerance else { return nil }

        if let existing = tripPoints.first(where: { $0.tripLocation === closest }) {
            return existing
        }

        guard closest.tripAnnotation == nil else { return nil }

        let annotation = TripAnnotation()

        // Manual is assigned exactly once: when the annotation is actually created.
        annotation.source = TripAnnotationSource.manual.rawValue

        // Keep in memory only. Do NOT save here.
        closest.tripAnnotation = annotation

        let point = TripPoint(tripLocation: closest)
        point.title = NSLocalizedString("Danger", comment: "New incident")
        point.isPending = true

        tripPoints.append(point)

        return point
    }

    // MARK: Delete Annotation

    func deleteAnnotation(_ point: TripPoint) {
        guard !editingDisabled else { return }

        point.tripLocation.tripAnnotation = nil
        tripPoints.removeAll { $0 === point }

        trip.edited = true
        trip.save()

        NotificationCenter.default.post(name: TripEditNotifications.tripEdited, object: trip)
        NotificationCenter.default.post(name: TripEditNotifications.annotationChanged, object: trip)
    }

    // MARK: Camera

    private func updateCamera() {
        guard !routeCoordinates.isEmpty else {
            cameraPosition = .automatic
            return
        }

        var rect = MKMapRect.null

        for coordinate in routeCoordinates {
            let point = MKMapPoint(coordinate)
            let pointRect = MKMapRect(x: point.x, y: point.y, width: 0, height: 0)
            rect = rect.isNull ? pointRect : rect.union(pointRect)
        }

        guard !rect.isNull else { return }

        let horizontalPadding = max(rect.size.width * 0.12, 100)
        let verticalPadding = max(rect.size.height * 0.22, 150)

        cameraPosition = .rect(
            rect.insetBy(dx: -horizontalPadding, dy: -verticalPadding)
        )
    }
}

// MARK: - Host Controller

@available(iOS 17.0, *)
@objcMembers
public final class TripEditViewHostController: UIViewController {

    private let trip: Trip
    private weak var delegate: TripEditViewHostDelegate?
    private var viewModel: TripEditViewModel
    private var hostingController: UIHostingController<TripEditView>!

    /// false (default): details and annotation editor are shown as SwiftUI sheets.
    /// true: both are forwarded to the delegate instead.
    public var usesDelegateForPresentation = false {
        didSet { updateRootView() }
    }

    @objc
    public init(trip: Trip, delegate: TripEditViewHostDelegate) {
        self.trip = trip
        self.delegate = delegate
        self.viewModel = TripEditViewModel(trip: trip)

        super.init(nibName: nil, bundle: nil)

        bindViewModel()
        hostingController = UIHostingController(rootView: makeRootView())
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        embedHostingController()
    }

    // MARK: Public API

    @objc
    public func reload() {
        viewModel = TripEditViewModel(trip: trip)
        bindViewModel()
        updateRootView()
        notifySelectionChanged()
    }

    @objc
    public func performTrim() {
        viewModel.applySelection()
    }

    @objc
    public var canTrim: Bool {
        viewModel.canTrim
    }

    /// Call this after an externally presented annotation editor was closed.
    @objc
    public func annotationEditingDidFinish(_ point: TripPoint, saved: Bool) {
        if saved {
            viewModel.refreshSavedAnnotation(point)
        } else {
            viewModel.discardPendingAnnotation(point)
        }
    }

    // MARK: Private

    private func bindViewModel() {
        viewModel.onSelectionChanged = { [weak self] in
            self?.notifySelectionChanged()
        }

        viewModel.onTrimmed = { [weak self] in
            guard let self else { return }
            self.delegate?.tripEditViewHostDidTrim?(self)
        }
    }

    private func notifySelectionChanged() {
        delegate?.tripEditViewHostSelectionDidChange?(self)
    }

    private func makeRootView() -> TripEditView {
        var showDetails: (() -> Void)?
        var editAnnotation: ((TripPoint) -> Void)?

        if usesDelegateForPresentation {
            showDetails = { [weak self] in
                guard let self else { return }
                self.delegate?.tripEditViewHostDidRequestDetails(self)
            }

            editAnnotation = { [weak self] point in
                guard let self else { return }
                self.delegate?.tripEditViewHost(self, didRequestAnnotationEdit: point)
            }
        }

        return TripEditView(
            viewModel: viewModel,
            onShowDetails: showDetails,
            onEditAnnotation: editAnnotation
        )
    }

    private func updateRootView() {
        guard hostingController != nil else { return }
        hostingController.rootView = makeRootView()
    }

    private func embedHostingController() {
        view.backgroundColor = .clear

        addChild(hostingController)

        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        hostingController.view.backgroundColor = .clear

        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}

// MARK: - Main View

struct TripEditView: View {

    @ObservedObject var viewModel: TripEditViewModel

    /// If set, details are handled externally instead of the internal sheet.
    var onShowDetails: (() -> Void)?

    /// If set, annotation editing is handled externally instead of the internal sheet.
    var onEditAnnotation: ((TripPoint) -> Void)?

    private let showDetailsOnAppear: Bool

    @State private var editingTripPoint: TripPoint?
    @State private var presentedTripPoint: TripPoint?
    @State private var showTripDetails = false
    @State private var showTrimConfirmation = false
    @State private var didAppear = false

    init(
        viewModel: TripEditViewModel,
        onShowDetails: (() -> Void)? = nil,
        onEditAnnotation: ((TripPoint) -> Void)? = nil,
        showDetailsOnAppear: Bool = false
    ) {
        self.viewModel = viewModel
        self.onShowDetails = onShowDetails
        self.onEditAnnotation = onEditAnnotation
        self.showDetailsOnAppear = showDetailsOnAppear
    }

    var body: some View {
        TripMap(viewModel: viewModel, onEditAnnotation: editAnnotation)
            .ignoresSafeArea()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                BottomEditor(viewModel: viewModel)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            .onAppear {
                guard !didAppear else { return }
                didAppear = true

                if showDetailsOnAppear {
                    showDetails()
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(NSLocalizedString("Edit trip", comment: ""))
                        .font(.headline)
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button(action: showDetails) {
                        Image(systemName: "info.circle")
                    }
                    .accessibilityLabel(NSLocalizedString("Details", comment: ""))
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showTrimConfirmation = true
                    } label: {
                        Text(NSLocalizedString("Schneiden", comment: ""))
                            .fontWeight(.semibold)
                    }
                    .disabled(!viewModel.canTrim)
                }
            }
            .confirmationDialog(
                NSLocalizedString("Trim trip?", comment: ""),
                isPresented: $showTrimConfirmation,
                titleVisibility: .visible
            ) {
                Button(NSLocalizedString("Schneiden", comment: ""), role: .destructive) {
                    viewModel.applySelection()
                }

                Button(NSLocalizedString("Cancel", comment: ""), role: .cancel) {}
            } message: {
                Text(trimConfirmationMessage)
            }
            .sheet(isPresented: $showTripDetails) {
                NavigationStack {
                    TripDetailView(trip: viewModel.trip)
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingTripPoint, onDismiss: annotationSheetDismissed) { point in
                NavigationStack {
                    if let annotation = point.tripLocation.tripAnnotation {
                        AnnotationView(
                            tripAnnotation: annotation,
                            trip: viewModel.trip,
                            isNew: point.isPending,
                            onSaved: {
                                viewModel.refreshSavedAnnotation(point)
                            },
                            onDiscard: {
                                viewModel.discardPendingAnnotation(point)
                            }
                        )
                    }
                }
            }
    }

    // MARK: Actions

    private func showDetails() {
        if let onShowDetails {
            onShowDetails()
        } else {
            showTripDetails = true
        }
    }

    private func editAnnotation(_ point: TripPoint) {
        if let onEditAnnotation {
            onEditAnnotation(point)
        } else {
            presentedTripPoint = point
            editingTripPoint = point
        }
    }

    /// A new annotation that was dismissed by swiping down without saving
    /// must not stay in memory, otherwise it would be persisted by the next save.
    private func annotationSheetDismissed() {
        if let point = presentedTripPoint, point.isPending {
            viewModel.discardPendingAnnotation(point)
        }

        presentedTripPoint = nil
    }

    private var trimConfirmationMessage: String {
        let base = NSLocalizedString(
            "The parts of the route outside the selection will be deleted permanently, including their sensor data.",
            comment: ""
        )

        let incidents = viewModel.incidentsOutsideSelectionCount
        guard incidents > 0 else { return base }

        let format = NSLocalizedString(
            "%d incident(s) outside the selection will also be deleted.",
            comment: ""
        )

        return base + " " + String(format: format, incidents)
    }
}

// MARK: - Map

private struct TripMap: View {

    @ObservedObject var viewModel: TripEditViewModel

    let onEditAnnotation: (TripPoint) -> Void

    var body: some View {
        MapLongPressContainer(
            isEnabled: !viewModel.editingDisabled,
            onLongPress: handleLongPress
        ) {
            Map(position: $viewModel.cameraPosition) {
                completeTrack
                selectedTrack
                startAnnotation
                endAnnotation
                incidentAnnotations
            }
            .safeAreaPadding(.top, 116)
            .mapStyle(.standard(elevation: .flat))
            .mapControls {
                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            .mapControlVisibility(.visible)
        }
    }

    private func handleLongPress(_ coordinate: CLLocationCoordinate2D, tolerance: CLLocationDistance) {
        guard let point = viewModel.annotationPoint(near: coordinate, tolerance: tolerance) else {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
            return
        }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onEditAnnotation(point)
    }

    // MARK: Complete Track

    @MapContentBuilder
    private var completeTrack: some MapContent {
        if viewModel.routeCoordinates.count > 1 {
            MapPolyline(coordinates: viewModel.routeCoordinates)
                .stroke(Color.primary.opacity(0.28), lineWidth: 3)
        }
    }

    // MARK: Selected Track

    @MapContentBuilder
    private var selectedTrack: some MapContent {
        if viewModel.selectedRouteCoordinates.count > 1 {
            MapPolyline(coordinates: viewModel.selectedRouteCoordinates)
                .stroke(.tint, lineWidth: 5)
        }
    }

    // MARK: Start

    @MapContentBuilder
    private var startAnnotation: some MapContent {
        if let coordinate = viewModel.coordinate(at: viewModel.startIndex) {
            Annotation("", coordinate: coordinate) {
                TripEndpointMarker(
                    title: NSLocalizedString("Start", comment: ""),
                    systemImage: "play.fill",
                    tint: .green
                )
            }
        }
    }

    // MARK: End

    @MapContentBuilder
    private var endAnnotation: some MapContent {
        if let coordinate = viewModel.coordinate(at: viewModel.endIndex) {
            Annotation("", coordinate: coordinate) {
                TripEndpointMarker(
                    title: NSLocalizedString("Destination", comment: ""),
                    systemImage: "flag.checkered",
                    tint: .red
                )
            }
        }
    }

    // MARK: Incidents

    @MapContentBuilder
    private var incidentAnnotations: some MapContent {
        ForEach(viewModel.tripPoints) { point in
            Annotation("", coordinate: point.coordinate) {
                Button {
                    onEditAnnotation(point)
                } label: {
                    // Pass values, not the class instance, so SwiftUI detects changes.
                    IncidentMapMarker(
                        title: point.displayTitle,
                        color: markerColor(for: point)
                    )
                    .opacity(viewModel.isInsideSelection(point) ? 1 : 0.4)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(point.displayTitle)
            }
        }
    }

    private func markerColor(for point: TripPoint) -> Color {
        if point.isPending {
            return .blue
        }

        return point.tripLocation.tripAnnotation?.frightening == true ? .red : .orange
    }
}

// MARK: - Long Press Container

private struct MapLongPressContainer<Content: View>: View {

    let isEnabled: Bool

    let onLongPress: (CLLocationCoordinate2D, CLLocationDistance) -> Void

    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            content()

            MapLongPressBridge(isEnabled: isEnabled, onLongPress: onLongPress)
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Long Press Bridge

private struct MapLongPressBridge: UIViewRepresentable {

    let isEnabled: Bool

    let onLongPress: (CLLocationCoordinate2D, CLLocationDistance) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(isEnabled: isEnabled, onLongPress: onLongPress)
    }

    func makeUIView(context: Context) -> BridgeView {
        let view = BridgeView(frame: .zero)
        let coordinator = context.coordinator

        view.onWindowAvailable = { [weak coordinator] bridge in
            coordinator?.attachIfNeeded(from: bridge)
        }

        return view
    }

    func updateUIView(_ uiView: BridgeView, context: Context) {
        let coordinator = context.coordinator

        coordinator.isEnabled = isEnabled
        coordinator.onLongPress = onLongPress

        // Fast path: nothing to do while already attached.
        guard !coordinator.isAttached else { return }

        DispatchQueue.main.async { [weak uiView, weak coordinator] in
            guard let uiView, let coordinator else { return }
            coordinator.attachIfNeeded(from: uiView)
        }
    }

    static func dismantleUIView(_ uiView: BridgeView, coordinator: Coordinator) {
        coordinator.detach()
    }

    // MARK: Bridge View

    final class BridgeView: UIView {

        var onWindowAvailable: ((BridgeView) -> Void)?

        override init(frame: CGRect) {
            super.init(frame: frame)
            backgroundColor = .clear
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()

            guard window != nil else { return }

            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                self.onWindowAvailable?(self)
            }
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {

        /// Finger tolerance in screen points used to find the nearest track point.
        private static let touchTolerance: CGFloat = 44

        /// Lower bound for the tolerance when zoomed in very far.
        private static let minimumToleranceMeters: CLLocationDistance = 15

        var isEnabled: Bool {
            didSet { recognizer?.isEnabled = isEnabled }
        }

        var onLongPress: (CLLocationCoordinate2D, CLLocationDistance) -> Void

        private weak var mapView: MKMapView?
        private var recognizer: UILongPressGestureRecognizer?

        var isAttached: Bool {
            recognizer != nil && mapView?.window != nil
        }

        init(
            isEnabled: Bool,
            onLongPress: @escaping (CLLocationCoordinate2D, CLLocationDistance) -> Void
        ) {
            self.isEnabled = isEnabled
            self.onLongPress = onLongPress
            super.init()
        }

        // MARK: Attach

        func attachIfNeeded(from anchor: UIView) {
            guard !isAttached else {
                recognizer?.isEnabled = isEnabled
                return
            }

            guard anchor.window != nil,
                  let foundMapView = Self.nearestMapView(from: anchor)
            else { return }

            detach()

            let gesture = UILongPressGestureRecognizer(
                target: self,
                action: #selector(handleLongPress(_:))
            )
            gesture.minimumPressDuration = 0.55
            gesture.allowableMovement = 14
            gesture.numberOfTouchesRequired = 1
            gesture.cancelsTouchesInView = false
            gesture.delaysTouchesBegan = false
            gesture.delegate = self
            gesture.isEnabled = isEnabled

            foundMapView.addGestureRecognizer(gesture)

            mapView = foundMapView
            recognizer = gesture
        }

        // MARK: Detach

        func detach() {
            if let recognizer {
                recognizer.view?.removeGestureRecognizer(recognizer)
            }

            recognizer = nil
            mapView = nil
        }

        // MARK: Gesture

        @objc
        private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard isEnabled,
                  gesture.state == .began,
                  let mapView
            else { return }

            let point = gesture.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)

            guard CLLocationCoordinate2DIsValid(coordinate) else { return }

            // Convert the finger tolerance from screen points into meters
            // so the tolerance fits every zoom level.
            let edgePoint = CGPoint(x: point.x + Self.touchTolerance, y: point.y)
            let edgeCoordinate = mapView.convert(edgePoint, toCoordinateFrom: mapView)

            let tolerance = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
                .distance(from: CLLocation(latitude: edgeCoordinate.latitude, longitude: edgeCoordinate.longitude))

            onLongPress(coordinate, max(tolerance, Self.minimumToleranceMeters))
        }

        // MARK: Gesture Coordination

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
        ) -> Bool {
            true
        }

        // MARK: Map Lookup

        /// Searches upwards from the bridge view, so only the map of this
        /// screen is found and not a map of an underlying screen in the window.
        private static func nearestMapView(from anchor: UIView) -> MKMapView? {
            var current = anchor.superview

            while let container = current {
                if let mapView = findMapView(in: container) {
                    return mapView
                }
                current = container.superview
            }

            return nil
        }

        private static func findMapView(in view: UIView) -> MKMapView? {
            if let mapView = view as? MKMapView {
                return mapView
            }

            for subview in view.subviews {
                if let mapView = findMapView(in: subview) {
                    return mapView
                }
            }

            return nil
        }
    }
}

// MARK: - Incident Marker

private struct IncidentMapMarker: View {

    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color, in: Circle())
                .overlay {
                    Circle().stroke(.white, lineWidth: 2)
                }

            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.regularMaterial, in: Capsule())
        }
    }
}

// MARK: - Endpoint Marker

private struct TripEndpointMarker: View {

    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(tint, in: Circle())

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
        }
        .padding(.leading, 3)
        .padding(.trailing, 10)
        .padding(.vertical, 3)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().stroke(tint.opacity(0.35), lineWidth: 1)
        }
    }
}

// MARK: - Bottom Editor

private struct BottomEditor: View {

    @ObservedObject var viewModel: TripEditViewModel

    var body: some View {
        RangeSlider(
            startIndex: viewModel.startIndex,
            endIndex: viewModel.endIndex,
            count: viewModel.locations.count,
            disabled: !viewModel.canEditRange,
            onStartChanged: { viewModel.updateStartIndex($0) },
            onEndChanged: { viewModel.updateEndIndex($0) }
        )
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .modifier(PanelBackground())
    }
}

// MARK: - Panel Background

private struct PanelBackground: ViewModifier {

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)

        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(.ultraThinMaterial, in: shape)
        }
    }
}

// MARK: - Range Slider

/// Range slider with speed-dependent precision ("scrubbing"):
/// fast movements move the handle 1:1 with the finger,
/// slow movements move it in single track points.
private struct RangeSlider: View {

    let startIndex: Int
    let endIndex: Int
    let count: Int
    let disabled: Bool
    let onStartChanged: (Int) -> Void
    let onEndChanged: (Int) -> Void

    @State private var drag: DragState?
    @State private var feedback = UISelectionFeedbackGenerator()

    private enum Handle {
        case start
        case end
    }

    private struct DragState {
        let handle: Handle
        var lastX: CGFloat
        /// Fractional index, so tiny finger movements accumulate.
        var value: Double
        var wasAtBound: Bool
        var isFine: Bool
    }

    private enum Metrics {
        static let inset: CGFloat = 18
        static let height: CGFloat = 44
        static let trackHeight: CGFloat = 6
        static let handleSize: CGFloat = 32

        /// Below this speed (points per second) maximum precision applies.
        static let slowSpeed: CGFloat = 60

        /// Above this speed the handle follows the finger 1:1.
        static let fastSpeed: CGFloat = 700

        /// At maximum precision the finger has to move this many points
        /// to move the handle by one track point.
        static let finePointsPerIndex: Double = 6

        /// Handles closer than this are treated as overlapping.
        static let overlapDistance: CGFloat = 8
    }

    var body: some View {
        GeometryReader { geometry in
            let width = max(geometry.size.width - Metrics.inset * 2, 1)
            let maximum = max(count - 1, 1)
            let centerY = geometry.size.height / 2
            let startX = position(for: startIndex, maximum: maximum, width: width)
            let endX = position(for: endIndex, maximum: maximum, width: width)

            ZStack {
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: width, height: Metrics.trackHeight)
                    .position(x: geometry.size.width / 2, y: centerY)

                Capsule()
                    .fill(.tint)
                    .frame(width: max(endX - startX, Metrics.trackHeight), height: Metrics.trackHeight)
                    .position(x: (startX + endX) / 2, y: centerY)

                handleView(.start)
                    .position(x: startX, y: centerY)

                handleView(.end)
                    .position(x: endX, y: centerY)
            }
            .contentShape(Rectangle())
            .gesture(
                dragGesture(width: width, maximum: maximum, startX: startX, endX: endX)
            )
        }
        .frame(height: Metrics.height)
        .opacity(disabled ? 0.45 : 1)
        .allowsHitTesting(!disabled)
    }

    // MARK: Handle

    private func handleView(_ type: Handle) -> some View {
        let isActive = drag?.handle == type
        let isFine = isActive && drag?.isFine == true
        let color: Color = type == .start ? .green : .red
        let iconName = type == .start ? "play.fill" : "flag.checkered"
        let index = type == .start ? startIndex : endIndex

        return ZStack {
            Circle()
                .fill(.background)

            Circle()
                .fill(color.opacity(isFine ? 0.18 : 0))

            Circle()
                .stroke(color, lineWidth: isActive ? 2.5 : 1.5)

            Image(systemName: iconName)
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
        }
        .frame(width: Metrics.handleSize, height: Metrics.handleSize)
        .shadow(color: .black.opacity(isActive ? 0.18 : 0.08), radius: isActive ? 6 : 3, y: 1)
        .scaleEffect(isActive ? 1.12 : 1)
        .animation(.spring(duration: 0.2), value: isActive)
        .animation(.easeOut(duration: 0.15), value: isFine)
        .accessibilityElement()
        .accessibilityLabel(
            type == .start
                ? NSLocalizedString("Start", comment: "")
                : NSLocalizedString("Destination", comment: "")
        )
        .accessibilityValue("\(index + 1) / \(max(count, 1))")
        .accessibilityAdjustableAction { direction in
            let step = max(count / 100, 1)
            let delta = direction == .increment ? step : -step

            switch type {
            case .start: onStartChanged(startIndex + delta)
            case .end: onEndChanged(endIndex + delta)
            }
        }
    }

    // MARK: Drag

    private func dragGesture(
        width: CGFloat,
        maximum: Int,
        startX: CGFloat,
        endX: CGFloat
    ) -> some Gesture {
        DragGesture(minimumDistance: 2, coordinateSpace: .local)
            .onChanged { value in
                guard !disabled, count > 1 else { return }

                // Choose the handle once at the beginning of the drag.
                if drag == nil {
                    guard let handle = handleForDrag(
                        startLocationX: value.startLocation.x,
                        translationX: value.translation.width,
                        startX: startX,
                        endX: endX
                    ) else { return }

                    feedback.prepare()

                    drag = DragState(
                        handle: handle,
                        lastX: value.startLocation.x,
                        value: Double(handle == .start ? startIndex : endIndex),
                        wasAtBound: false,
                        isFine: false
                    )
                }

                guard var state = drag else { return }

                // Relative movement since the last event.
                let deltaX = value.location.x - state.lastX
                state.lastX = value.location.x

                let indicesPerPoint = Double(maximum) / Double(width)
                let factor = precisionFactor(
                    speed: abs(value.velocity.width),
                    indicesPerPoint: indicesPerPoint
                )

                state.value += Double(deltaX) * indicesPerPoint * factor

                let bounds: ClosedRange<Int>
                switch state.handle {
                case .start: bounds = 0...max(endIndex - 1, 0)
                case .end: bounds = min(startIndex + 1, maximum)...maximum
                }

                // Clamp the fractional value too, so no hidden overshoot accumulates.
                state.value = min(max(state.value, Double(bounds.lowerBound)), Double(bounds.upperBound))

                let newIndex = Int(state.value.rounded())

                // "Fine" = finger has to move at least 2 pt per track point.
                state.isFine = indicesPerPoint * factor <= 0.5

                let isAtBound = newIndex == bounds.lowerBound || newIndex == bounds.upperBound
                let currentIndex = state.handle == .start ? startIndex : endIndex
                let indexChanged = newIndex != currentIndex

                if indexChanged && ((isAtBound && !state.wasAtBound) || state.isFine) {
                    feedback.selectionChanged()
                    feedback.prepare()
                }

                state.wasAtBound = isAtBound
                drag = state

                guard indexChanged else { return }

                switch state.handle {
                case .start: onStartChanged(newIndex)
                case .end: onEndChanged(newIndex)
                }
            }
            .onEnded { _ in
                drag = nil
            }
    }

    /// Nearest handle wins. If both handles overlap,
    /// the drag direction decides (left = start, right = end).
    private func handleForDrag(
        startLocationX: CGFloat,
        translationX: CGFloat,
        startX: CGFloat,
        endX: CGFloat
    ) -> Handle? {
        let distanceToStart = abs(startLocationX - startX)
        let distanceToEnd = abs(startLocationX - endX)

        if abs(distanceToStart - distanceToEnd) < Metrics.overlapDistance {
            if translationX < 0 { return .start }
            if translationX > 0 { return .end }
            return nil
        }

        return distanceToStart < distanceToEnd ? .start : .end
    }

    /// 1.0 = handle follows the finger, smaller = finer.
    /// Uses a smoothstep curve between slow and fast speed.
    private func precisionFactor(speed: CGFloat, indicesPerPoint: Double) -> Double {
        guard indicesPerPoint > 0 else { return 1 }

        let minimumFactor = min(1, 1 / (Metrics.finePointsPerIndex * indicesPerPoint))

        let progress = Double(
            min(max((speed - Metrics.slowSpeed) / (Metrics.fastSpeed - Metrics.slowSpeed), 0), 1)
        )

        let eased = progress * progress * (3 - 2 * progress)

        return minimumFactor + (1 - minimumFactor) * eased
    }

    // MARK: Position

    private func position(for index: Int, maximum: Int, width: CGFloat) -> CGFloat {
        guard maximum > 0 else { return Metrics.inset }

        let clamped = min(max(index, 0), maximum)
        return Metrics.inset + CGFloat(clamped) / CGFloat(maximum) * width
    }
}
