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

// MARK: - Trip Point

@objc(TripPoint)
public final class TripPoint:
    NSObject,
    MKAnnotation,
    Identifiable
{
    public var title:
        String?

    public var tripLocation:
        TripLocation

    /// True while a manually created annotation
    /// is being edited and has not yet been persisted.
    public var isPending =
        false

    /// Stable SwiftUI identity.
    public let id =
        UUID().uuidString

    public var subtitle:
        String?
    {
        nil
    }

    public var displayTitle:
        String
    {
        let trimmed =
            title?
                .trimmingCharacters(
                    in:
                        .whitespacesAndNewlines
                )
            ?? ""

        return trimmed.isEmpty
            ? NSLocalizedString(
                "Gefahr",
                comment:
                    "Fallback incident title"
            )
            : trimmed
    }

    public var coordinate:
        CLLocationCoordinate2D
    {
        tripLocation
            .location
            .coordinate
    }

    public init(
        tripLocation:
            TripLocation
    ) {
        self.tripLocation =
            tripLocation

        super.init()
    }
}

// MARK: - Host Delegate

@objc
public protocol TripEditViewHostDelegate:
    AnyObject
{
    func tripEditViewHostDidRequestDetails(
        _ host:
            TripEditViewHostController
    )

    func tripEditViewHost(
        _ host:
            TripEditViewHostController,
        didRequestAnnotationEdit:
            TripPoint
    )
}

// MARK: - View Model

final class TripEditViewModel:
    ObservableObject
{
    // MARK: Model

    let trip:
        Trip

    // MARK: Published State

    @Published
    private(set) var locations:
        [TripLocation] = []

    @Published
    var startIndex:
        Int = 0

    @Published
    var endIndex:
        Int = 0

    @Published
    private(set) var tripPoints:
        [TripPoint] = []

    @Published
    var cameraPosition:
        MapCameraPosition = .automatic

    @Published
    private(set) var changed:
        Bool = false

    @Published
    private(set) var routeCoordinates:
        [CLLocationCoordinate2D] = []

    @Published
    private(set) var selectedRouteCoordinates:
        [CLLocationCoordinate2D] = []

    // MARK: Runtime

    private var rebuildTask:
        Task<Void, Never>?

    private var incidentTypes:
        [String]
    {
        AppDelegate.shared()
            .constants["incidents"]
            as? [String]
            ?? []
    }

    // MARK: Init

    init(
        trip:
            Trip
    ) {
        self.trip =
            trip

        reload()
    }

    deinit {
        rebuildTask?.cancel()
    }

    // MARK: Computed State

    var editingDisabled:
        Bool
    {
        trip.uploaded ||
        trip.statisticsAdded
    }

    var hasLocations:
        Bool
    {
        !locations.isEmpty
    }

    var hasChangedRange:
        Bool
    {
        guard
            !locations.isEmpty
        else {
            return false
        }

        return startIndex != 0 ||
            endIndex !=
                locations.count - 1
    }

    var selectedPointCount:
        Int
    {
        guard
            !locations.isEmpty
        else {
            return 0
        }

        return max(
            endIndex -
                startIndex +
                1,
            0
        )
    }

    // MARK: Reload

    func reload() {

        rebuildTask?.cancel()

        var collected:
            [TripLocation] = []

        collected.reserveCapacity(
            trip.tripLocations.count
        )

        for case
            let location as TripLocation
            in trip.tripLocations
        {
            collected.append(
                location
            )
        }

        locations =
            collected

        guard
            !locations.isEmpty
        else {

            startIndex =
                0

            endIndex =
                0

            routeCoordinates =
                []

            selectedRouteCoordinates =
                []

            tripPoints =
                []

            cameraPosition =
                .automatic

            return
        }

        startIndex =
            0

        endIndex =
            locations.count - 1

        routeCoordinates =
            makeRouteCoordinates(
                from:
                    locations,
                maximumCount:
                    1800
            )

        updateSelectedRoute()
        rebuildTripPoints()
        updateCamera()
    }

    // MARK: Route Cache

    private func makeRouteCoordinates(
        from locations:
            [TripLocation],
        maximumCount:
            Int
    ) -> [CLLocationCoordinate2D]
    {
        guard
            !locations.isEmpty
        else {
            return []
        }

        let coordinates =
            locations.map {
                $0.location.coordinate
            }

        guard
            coordinates.count >
                maximumCount,
            maximumCount >= 2
        else {
            return coordinates
        }

        var result:
            [CLLocationCoordinate2D] = []

        result.reserveCapacity(
            maximumCount
        )

        let step =
            Double(
                coordinates.count - 1
            )
            /
            Double(
                maximumCount - 1
            )

        for index
            in 0..<maximumCount
        {
            let sourceIndex =
                min(
                    coordinates.count - 1,
                    Int(
                        (
                            Double(index) *
                            step
                        )
                        .rounded()
                    )
                )

            result.append(
                coordinates[sourceIndex]
            )
        }

        return result
    }

    private func updateSelectedRoute() {

        guard
            !locations.isEmpty,
            startIndex >= 0,
            endIndex >= 0,
            startIndex <
                locations.count,
            endIndex <
                locations.count
        else {

            selectedRouteCoordinates =
                []

            return
        }

        let lower =
            min(
                startIndex,
                endIndex
            )

        let upper =
            max(
                startIndex,
                endIndex
            )

        guard
            lower <= upper
        else {

            selectedRouteCoordinates =
                []

            return
        }

        let selected =
            Array(
                locations[
                    lower...upper
                ]
            )

        selectedRouteCoordinates =
            makeRouteCoordinates(
                from:
                    selected,
                maximumCount:
                    900
            )
    }

    // MARK: Selection

    func updateStartIndex(
        _ value:
            Int
    ) {

        guard
            !locations.isEmpty
        else {
            return
        }

        let maximum =
            max(
                endIndex - 1,
                0
            )

        let newValue =
            min(
                max(
                    value,
                    0
                ),
                maximum
            )

        guard
            newValue != startIndex
        else {
            return
        }

        startIndex =
            newValue

        changed =
            true

        updateSelectedRoute()
    }

    func updateEndIndex(
        _ value:
            Int
    ) {

        guard
            !locations.isEmpty
        else {
            return
        }

        let minimum =
            min(
                startIndex + 1,
                locations.count - 1
            )

        let newValue =
            max(
                min(
                    value,
                    locations.count - 1
                ),
                minimum
            )

        guard
            newValue != endIndex
        else {
            return
        }

        endIndex =
            newValue

        changed =
            true

        updateSelectedRoute()
    }

    func resetSelection() {

        guard
            !locations.isEmpty
        else {
            return
        }

        startIndex =
            0

        endIndex =
            locations.count - 1

        changed =
            true

        updateSelectedRoute()
    }

    // MARK: Save / Trim

    func applySelection() {

        guard
            !locations.isEmpty,
            !editingDisabled
        else {
            return
        }

        let lower =
            min(
                startIndex,
                endIndex
            )

        let upper =
            max(
                startIndex,
                endIndex
            )

        guard
            lower >= 0,
            upper <
                locations.count
        else {
            return
        }

        guard
            lower > 0 ||
            upper <
                locations.count - 1
        else {
            return
        }

        let selectedLocations =
            Array(
                locations[
                    lower...upper
                ]
            )

        guard
            !selectedLocations.isEmpty
        else {
            return
        }

        updateCSVFiles(
            for:
                selectedLocations
        )

        let removedLocations =
            locations
                .enumerated()
                .filter {
                    index,
                    _
                    in
                    index < lower ||
                    index > upper
                }
                .map {
                    $0.element
                }

        for location
            in removedLocations
        {
            location.tripMotions
                .removeAllObjects()

            location.tripAnnotation =
                nil
        }

        trip.tripLocations
            .removeAllObjects()

        trip.tripLocations
            .addObjects(
                from:
                    selectedLocations
            )

        trip.edited =
            true

        trip.save()

        locations =
            selectedLocations

        startIndex =
            0

        endIndex =
            max(
                selectedLocations.count - 1,
                0
            )

        changed =
            false

        routeCoordinates =
            makeRouteCoordinates(
                from:
                    selectedLocations,
                maximumCount:
                    1800
            )

        updateSelectedRoute()
        rebuildTripPoints()
        updateCamera()

        NotificationCenter.default.post(
            name:
                NSNotification.Name(
                    "tripEdited"
                ),
            object:
                trip
        )
    }

    func persistAnnotations() {

        trip.save()

        changed =
            false
    }

    // MARK: CSV

    private func updateCSVFiles(
        for locations:
            [TripLocation]
    ) {

        let documents =
            Self.documentsDirectoryURL()

        let locationsURL =
            documents
                .appendingPathComponent(
                    "TripLocations-\(trip.identifier).csv"
                )

        let motionsURL =
            documents
                .appendingPathComponent(
                    "TripMotions-\(trip.identifier).csv"
                )

        var locationLines:
            [String] = []

        var motionLines:
            [String] = []

        locationLines.reserveCapacity(
            locations.count
        )

        for location
            in locations
        {
            let gyro =
                location.gyro ??
                TripGyro()

            let helper =
                TripGyro()

            locationLines.append(
                helper.locationString(
                    from:
                        location,
                    gyro:
                        gyro,
                    closePassInfo:
                        location.closePassInfo
                )
            )

            for case
                let motion as TripMotion
                in location.tripMotions
            {
                let motionHelper =
                    TripMotion()

                motionLines.append(
                    motionHelper.motionString(
                        from:
                            motion
                    )
                )
            }
        }

        try?
            locationLines
                .joined(
                    separator:
                        "\n"
                )
                .data(
                    using:
                        .utf8
                )?
                .write(
                    to:
                        locationsURL,
                    options:
                        .atomic
                )

        try?
            motionLines
                .joined(
                    separator:
                        "\n"
                )
                .data(
                    using:
                        .utf8
                )?
                .write(
                    to:
                        motionsURL,
                    options:
                        .atomic
                )
    }

    private static func documentsDirectoryURL()
        -> URL
    {
        FileManager.default.urls(
            for:
                .documentDirectory,
            in:
                .userDomainMask
        )[0]
    }

    // MARK: Incident Points

    private func rebuildTripPoints() {

        rebuildTask?.cancel()

        let snapshot =
            locations

        let incidentTypes =
            incidentTypes

        rebuildTask =
            Task { @MainActor [weak self] in

                guard
                    let self
                else {
                    return
                }

                var points:
                    [TripPoint] = []

                points.reserveCapacity(
                    min(
                        snapshot.count,
                        64
                    )
                )

                for (
                    index,
                    location
                ) in snapshot.enumerated()
                {
                    guard
                        !Task.isCancelled
                    else {
                        return
                    }

                    guard
                        let annotation =
                            location.tripAnnotation,
                        annotation.incidentId >= 0
                    else {
                        continue
                    }

                    let incidentID =
                        Int(
                            annotation.incidentId
                        )

                    let title =
                        incidentID >= 0 &&
                        incidentID <
                            incidentTypes.count
                        ? incidentTypes[
                            incidentID
                        ]
                        : NSLocalizedString(
                            "Gefahr",
                            comment:
                                "Fallback incident title"
                        )

                    let point =
                        TripPoint(
                            tripLocation:
                                location
                        )

                    point.title =
                        title

                    point.isPending =
                        false

                    points.append(
                        point
                    )

                    if index.isMultiple(
                        of:
                            150
                    ) {
                        await Task.yield()
                    }
                }

                guard
                    !Task.isCancelled
                else {
                    return
                }

                self.tripPoints =
                    points

                self.rebuildTask =
                    nil
            }
    }

    /// Updates one already-visible marker instead of
    /// rebuilding all annotations.
    func refreshSavedAnnotation(
        _ point:
            TripPoint
    ) {

        point.isPending =
            false

        guard
            let annotation =
                point
                    .tripLocation
                    .tripAnnotation
        else {

            tripPoints.removeAll {
                $0 === point
            }

            return
        }

        let incidentID =
            Int(
                annotation.incidentId
            )

        point.title =
            incidentID >= 0 &&
            incidentID <
                incidentTypes.count
            ? incidentTypes[
                incidentID
            ]
            : NSLocalizedString(
                "Gefahr",
                comment:
                    "Fallback incident title"
            )

        tripPoints =
            tripPoints
    }

    // MARK: Pending Annotation

    func discardPendingAnnotation(
        _ point:
            TripPoint
    ) {

        guard
            point.isPending
        else {
            return
        }

        point
            .tripLocation
            .tripAnnotation =
            nil

        tripPoints.removeAll {
            $0 === point
        }
    }

    // MARK: Add Annotation

    @discardableResult
    func addAnnotation(
        at coordinate:
            CLLocationCoordinate2D
    ) -> TripPoint? {

        guard
            !editingDisabled,
            !locations.isEmpty,
            CLLocationCoordinate2DIsValid(
                coordinate
            )
        else {
            return nil
        }

        let target =
            CLLocation(
                latitude:
                    coordinate.latitude,
                longitude:
                    coordinate.longitude
            )

        var closest:
            TripLocation?

        var closestDistance =
            CLLocationDistance
                .greatestFiniteMagnitude

        for location
            in locations
        {
            let distance =
                location.location
                    .distance(
                        from:
                            target
                    )

            if distance <
                closestDistance
            {
                closestDistance =
                    distance

                closest =
                    location
            }
        }

        guard
            let closest,
            closest.tripAnnotation == nil
        else {
            return nil
        }

        let annotation =
            TripAnnotation()

        // Manual is assigned exactly once:
        // when the annotation is actually created.
        annotation.source =
            TripAnnotationSource
                .manual
                .rawValue

        // Keep in memory only.
        // Do NOT save here.
        closest.tripAnnotation =
            annotation

        let point =
            TripPoint(
                tripLocation:
                    closest
            )

        // No incident type selected yet.
        point.title =
            NSLocalizedString(
                "Gefahr",
                comment:
                    "New incident"
            )

        point.isPending =
            true

        tripPoints.append(
            point
        )

        return point
    }

    // MARK: Delete Annotation

    func deleteAnnotation(
        _ point:
            TripPoint
    ) {

        guard
            !editingDisabled
        else {
            return
        }

        point
            .tripLocation
            .tripAnnotation =
            nil

        tripPoints.removeAll {
            $0 === point
        }

        trip.edited =
            true

        trip.save()

        NotificationCenter.default.post(
            name:
                NSNotification.Name(
                    "tripEdited"
                ),
            object:
                trip
        )

        NotificationCenter.default.post(
            name:
                NSNotification.Name(
                    "annotationChanged"
                ),
            object:
                trip
        )
    }

    // MARK: Camera

    private func updateCamera() {

        guard
            !routeCoordinates.isEmpty
        else {
            cameraPosition =
                .automatic

            return
        }

        var rect =
            MKMapRect.null

        for coordinate
            in routeCoordinates
        {
            let point =
                MKMapPoint(
                    coordinate
                )

            let pointRect =
                MKMapRect(
                    x:
                        point.x,
                    y:
                        point.y,
                    width:
                        0,
                    height:
                        0
                )

            rect =
                rect.isNull
                ? pointRect
                : rect.union(
                    pointRect
                )
        }

        guard
            !rect.isNull
        else {
            return
        }

        let horizontalPadding =
            max(
                rect.size.width *
                    0.12,
                100
            )

        let verticalPadding =
            max(
                rect.size.height *
                    0.22,
                150
            )

        cameraPosition =
            .rect(
                rect.insetBy(
                    dx:
                        -horizontalPadding,
                    dy:
                        -verticalPadding
                )
            )
    }
}

// MARK: - Host Controller

@available(iOS 17.0, *)
@objcMembers
public final class TripEditViewHostController:
    UIViewController
{
    private let trip:
        Trip

    private weak var delegate:
        TripEditViewHostDelegate?

    private var viewModel:
        TripEditViewModel

    private var hostingController:
        UIHostingController<TripEditView>!

    @objc
    public init(
        trip:
            Trip,
        delegate:
            TripEditViewHostDelegate
    ) {
        self.trip =
            trip

        self.delegate =
            delegate

        self.viewModel =
            TripEditViewModel(
                trip:
                    trip
            )

        super.init(
            nibName:
                nil,
            bundle:
                nil
        )

        hostingController =
            UIHostingController(
                rootView:
                    TripEditView(
                        viewModel:
                            viewModel,
                        onShowDetails:
                            { [weak self] in

                                guard
                                    let self
                                else {
                                    return
                                }

                                self.delegate?
                                    .tripEditViewHostDidRequestDetails(
                                        self
                                    )
                            },
                        onEditAnnotation:
                            { [weak self] point in

                                guard
                                    let self
                                else {
                                    return
                                }

                                self.delegate?
                                    .tripEditViewHost(
                                        self,
                                        didRequestAnnotationEdit:
                                            point
                                    )
                            }
                    )
            )

        embedHostingController()
    }

    @available(
        *,
        unavailable
    )
    required init?(
        coder:
            NSCoder
    ) {
        fatalError(
            "init(coder:) has not been implemented"
        )
    }

    @objc
    public func reload() {

        viewModel =
            TripEditViewModel(
                trip:
                    trip
            )

        updateRootView()
    }

    @objc
    public func performTrim() {
        viewModel.applySelection()
    }

    @objc
    public var canTrim:
        Bool
    {
        viewModel.hasChangedRange &&
        !viewModel.editingDisabled
    }

    private func updateRootView() {

        hostingController.rootView =
            TripEditView(
                viewModel:
                    viewModel,
                onShowDetails:
                    { [weak self] in

                        guard
                            let self
                        else {
                            return
                        }

                        self.delegate?
                            .tripEditViewHostDidRequestDetails(
                                self
                            )
                    },
                onEditAnnotation:
                    { [weak self] point in

                        guard
                            let self
                        else {
                            return
                        }

                        self.delegate?
                            .tripEditViewHost(
                                self,
                                didRequestAnnotationEdit:
                                    point
                            )
                    }
            )
    }

    private func embedHostingController() {

        view.backgroundColor =
            .clear

        addChild(
            hostingController
        )

        hostingController.view
            .translatesAutoresizingMaskIntoConstraints =
            false

        hostingController.view
            .backgroundColor =
            .clear

        view.addSubview(
            hostingController.view
        )

        NSLayoutConstraint.activate(
            [
                hostingController.view
                    .leadingAnchor
                    .constraint(
                        equalTo:
                            view.leadingAnchor
                    ),

                hostingController.view
                    .trailingAnchor
                    .constraint(
                        equalTo:
                            view.trailingAnchor
                    ),

                hostingController.view
                    .topAnchor
                    .constraint(
                        equalTo:
                            view.topAnchor
                    ),

                hostingController.view
                    .bottomAnchor
                    .constraint(
                        equalTo:
                            view.bottomAnchor
                    )
            ]
        )

        hostingController
            .didMove(
                toParent:
                    self
            )
    }
}

// MARK: - Main View

struct TripEditView:
    View
{
    @ObservedObject
    var viewModel:
        TripEditViewModel

    var onShowDetails:
        (() -> Void)? =
            nil

    var onEditAnnotation:
        ((TripPoint) -> Void)? =
            nil

    @State
    private var editingTripPoint:
        TripPoint?

    @State
    private var showTripDetails =
        false

    private let showDetailsOnAppear: Bool

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

    var body:
        some View
    {
        TripMap(
            viewModel:
                viewModel,
            onEditAnnotation:
                { point in

                    editingTripPoint =
                        point

                    onEditAnnotation?(
                        point
                    )
                }
        )
        .ignoresSafeArea()

        .safeAreaInset(
            edge:
                .bottom,
            spacing:
                0
        ) {

            BottomEditor(
                viewModel:
                    viewModel
            )
            .padding(
                .horizontal,
                16
            )
            .padding(
                .bottom,
                8
            )
        }

        .onAppear {
            if showDetailsOnAppear {
                showTripDetails = true
            }
        }

        .toolbar {

            ToolbarItem(
                placement:
                    .principal
            ) {

                Text(
                    NSLocalizedString(
                        "Edit trip",
                        comment:
                            ""
                    )
                )
                .font(
                    .headline
                )
            }

            ToolbarItem(
                placement:
                    .topBarLeading
            ) {

                Button {

                    showTripDetails =
                        true

                } label: {

                    Image(
                        systemName:
                            "info.circle"
                    )
                }
                .accessibilityLabel(
                    NSLocalizedString(
                        "Details",
                        comment:
                            ""
                    )
                )
            }

            ToolbarItem(
                placement:
                    .topBarTrailing
            ) {

                Button {

                    viewModel
                        .applySelection()

                } label: {

                    Text(
                        NSLocalizedString(
                            "Schneiden",
                            comment:
                                ""
                        )
                    )
                    .fontWeight(
                        .semibold
                    )
                }
                .disabled(
                    viewModel.editingDisabled ||
                    !viewModel.hasChangedRange
                )
            }
        }

        .sheet(
            isPresented:
                $showTripDetails
        ) {

            NavigationStack {

                TripDetailView(
                    trip:
                        viewModel.trip
                )
            }
            .presentationDetents(
                [
                    .medium,
                    .large
                ]
            )
            .presentationDragIndicator(
                .visible
            )
        }

        .sheet(
            item:
                $editingTripPoint
        ) { point in

            NavigationStack {

                if let annotation =
                    point.tripLocation
                        .tripAnnotation
                {

                    AnnotationView(
                        tripAnnotation:
                            annotation,
                        trip:
                            viewModel.trip,
                        isNew:
                            point.isPending,
                        onSaved:
                            {

                                // Update only this marker.
                                viewModel
                                    .refreshSavedAnnotation(
                                        point
                                    )
                            },
                        onDiscard:
                            {

                                viewModel
                                    .discardPendingAnnotation(
                                        point
                                    )
                            }
                    )
                }
            }
        }
    }
}

// MARK: - Map

private struct TripMap:
    View
{
    @ObservedObject
    var viewModel:
        TripEditViewModel

    let onEditAnnotation:
        (TripPoint) -> Void

    var body:
        some View
    {
        MapLongPressContainer(
            isEnabled:
                !viewModel.editingDisabled,
            onLongPress:
                { coordinate in

                    guard
                        !viewModel.editingDisabled,
                        let point =
                            viewModel.addAnnotation(
                                at:
                                    coordinate
                            )
                    else {
                        return
                    }

                    onEditAnnotation(
                        point
                    )
                }
        ) {

            Map(
                position:
                    $viewModel.cameraPosition
            ) {

                completeTrack
                selectedTrack
                startAnnotation
                endAnnotation
                incidentAnnotations
            }
            .safeAreaPadding(
                .top,
                116
            )
            .mapStyle(
                .standard(
                    elevation:
                        .flat
                )
            )
            .mapControls {

                MapCompass()
                MapScaleView()
                MapPitchToggle()
            }
            .mapControlVisibility(
                .visible
            )
        }
    }

    // MARK: - Complete Track

    @MapContentBuilder
    private var completeTrack:
        some MapContent
    {
        if
            viewModel
                .routeCoordinates
                .count > 1
        {
            MapPolyline(
                coordinates:
                    viewModel.routeCoordinates
            )
            .stroke(
                Color.primary.opacity(
                    0.28
                ),
                lineWidth:
                    3
            )
        }
    }

    // MARK: - Selected Track

    @MapContentBuilder
    private var selectedTrack:
        some MapContent
    {
        if
            viewModel
                .selectedRouteCoordinates
                .count > 1
        {
            MapPolyline(
                coordinates:
                    viewModel
                        .selectedRouteCoordinates
            )
            .stroke(
                .tint,
                lineWidth:
                    5
            )
        }
    }

    // MARK: - Start

    @MapContentBuilder
    private var startAnnotation:
        some MapContent
    {
        if let coordinate =
            coordinate(
                at:
                    viewModel.startIndex
            )
        {
            Annotation(
                "",
                coordinate:
                    coordinate
            ) {

                TripEndpointMarker(
                    title:
                        NSLocalizedString(
                            "Start",
                            comment:
                                ""
                        ),
                    systemImage:
                        "play.fill",
                    tint:
                        .green
                )
            }
        }
    }

    // MARK: - End

    @MapContentBuilder
    private var endAnnotation:
        some MapContent
    {
        if let coordinate =
            coordinate(
                at:
                    viewModel.endIndex
            )
        {
            Annotation(
                "",
                coordinate:
                    coordinate
            ) {

                TripEndpointMarker(
                    title:
                        NSLocalizedString(
                            "Ziel",
                            comment:
                                ""
                        ),
                    systemImage:
                        "flag.checkered",
                    tint:
                        .red
                )
            }
        }
    }

    // MARK: - Incidents

    @MapContentBuilder
    private var incidentAnnotations:
        some MapContent
    {
        ForEach(
            viewModel.tripPoints
        ) { point in

            Annotation(
                "",
                coordinate:
                    point.coordinate
            ) {

                Button {

                    onEditAnnotation(
                        point
                    )

                } label: {

                    IncidentMapMarker(
                        point:
                            point
                    )
                }
                .buttonStyle(
                    .plain
                )
                .accessibilityLabel(
                    point.displayTitle
                )
            }
        }
    }

    // MARK: - Coordinate

    private func coordinate(
        at index:
            Int
    ) -> CLLocationCoordinate2D? {

        guard
            index >= 0,
            index <
                viewModel.locations.count
        else {
            return nil
        }

        return viewModel
            .locations[index]
            .location
            .coordinate
    }
}

// MARK: - Long Press Container

private struct MapLongPressContainer<Content: View>:
    View
{
    let isEnabled:
        Bool

    let onLongPress:
        (CLLocationCoordinate2D) -> Void

    @ViewBuilder
    let content:
        () -> Content

    var body:
        some View
    {
        ZStack {

            content()

            MapLongPressBridge(
                isEnabled:
                    isEnabled,
                onLongPress:
                    onLongPress
            )
            .frame(
                width:
                    0,
                height:
                    0
            )
            .allowsHitTesting(
                false
            )
        }
    }
}

// MARK: - Long Press Bridge

private struct MapLongPressBridge:
    UIViewRepresentable
{
    let isEnabled:
        Bool

    let onLongPress:
        (CLLocationCoordinate2D) -> Void

    func makeCoordinator()
        -> Coordinator
    {
        Coordinator(
            isEnabled:
                isEnabled,
            onLongPress:
                onLongPress
        )
    }

    func makeUIView(
        context:
            Context
    ) -> BridgeView {

        BridgeView { window in

            context.coordinator
                .attachIfNeeded(
                    to:
                        window
                )
        }
    }

    func updateUIView(
        _ uiView:
            BridgeView,
        context:
            Context
    ) {

        context.coordinator
            .isEnabled =
            isEnabled

        context.coordinator
            .onLongPress =
            onLongPress

        if let window =
            uiView.window
        {

            context.coordinator
                .attachIfNeeded(
                    to:
                        window
                )

        } else {

            DispatchQueue.main.async {

                guard
                    let window =
                        uiView.window
                else {
                    return
                }

                context.coordinator
                    .attachIfNeeded(
                        to:
                            window
                    )
            }
        }
    }

    static func dismantleUIView(
        _ uiView:
            BridgeView,
        coordinator:
            Coordinator
    ) {
        coordinator.detach()
    }

    // MARK: Bridge View

    final class BridgeView:
        UIView
    {
        private let onWindowAvailable:
            (UIWindow) -> Void

        init(
            onWindowAvailable:
                @escaping
                (UIWindow) -> Void
        ) {
            self.onWindowAvailable =
                onWindowAvailable

            super.init(
                frame:
                    .zero
            )

            backgroundColor =
                .clear

            isUserInteractionEnabled =
                false
        }

        @available(
            *,
            unavailable
        )
        required init?(
            coder:
                NSCoder
        ) {
            fatalError(
                "init(coder:) has not been implemented"
            )
        }

        override func didMoveToWindow() {

            super.didMoveToWindow()

            guard
                window != nil
            else {
                return
            }

            DispatchQueue.main.async { [weak self] in

                guard
                    let self,
                    let window =
                        self.window
                else {
                    return
                }

                self.onWindowAvailable(
                    window
                )
            }
        }
    }

    // MARK: Coordinator

    final class Coordinator:
        NSObject,
        UIGestureRecognizerDelegate
    {
        var isEnabled:
            Bool

        var onLongPress:
            (CLLocationCoordinate2D) -> Void

        private weak var mapView:
            MKMapView?

        private weak var attachedView:
            UIView?

        private var recognizer:
            UILongPressGestureRecognizer?

        init(
            isEnabled:
                Bool,
            onLongPress:
                @escaping
                (CLLocationCoordinate2D) -> Void
        ) {
            self.isEnabled =
                isEnabled

            self.onLongPress =
                onLongPress

            super.init()
        }

        // MARK: Attach

        func attachIfNeeded(
            to window:
                UIWindow
        ) {

            guard
                let mapView =
                    findMapView(
                        in:
                            window
                    )
            else {
                return
            }

            guard
                self.mapView !== mapView
            else {

                recognizer?
                    .isEnabled =
                    isEnabled

                return
            }

            detach()

            self.mapView =
                mapView

            let gesture =
                UILongPressGestureRecognizer(
                    target:
                        self,
                    action:
                        #selector(
                            handleLongPress(_:)
                        )
                )

            gesture.minimumPressDuration =
                0.55

            gesture.allowableMovement =
                14

            gesture.numberOfTouchesRequired =
                1

            gesture.cancelsTouchesInView =
                false

            gesture.delaysTouchesBegan =
                false

            gesture.delegate =
                self

            gesture.isEnabled =
                isEnabled

            mapView.addGestureRecognizer(
                gesture
            )

            recognizer =
                gesture

            attachedView =
                mapView
        }

        // MARK: Detach

        func detach() {

            if let recognizer {

                attachedView?
                    .removeGestureRecognizer(
                        recognizer
                    )
            }

            recognizer =
                nil

            attachedView =
                nil

            mapView =
                nil
        }

        // MARK: Gesture

        @objc
        private func handleLongPress(
            _ gesture:
                UILongPressGestureRecognizer
        ) {

            guard
                isEnabled,
                gesture.state == .began,
                let mapView
            else {
                return
            }

            let point =
                gesture.location(
                    in:
                        mapView
                )

            let coordinate =
                mapView.convert(
                    point,
                    toCoordinateFrom:
                        mapView
                )

            guard
                CLLocationCoordinate2DIsValid(
                    coordinate
                )
            else {
                return
            }

            onLongPress(
                coordinate
            )
        }

        // MARK: Gesture Coordination

        func gestureRecognizer(
            _ gestureRecognizer:
                UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith otherGestureRecognizer:
                UIGestureRecognizer
        ) -> Bool {

            true
        }

        // MARK: Map Lookup

        private func findMapView(
            in view:
                UIView
        ) -> MKMapView? {

            if let mapView =
                view as? MKMapView
            {
                return mapView
            }

            for subview
                in view.subviews
            {
                if let mapView =
                    findMapView(
                        in:
                            subview
                    )
                {
                    return mapView
                }
            }

            return nil
        }
    }
}

// MARK: - Incident Marker

private struct IncidentMapMarker:
    View
{
    let point:
        TripPoint

    private var markerColor:
        Color
    {
        if point.isPending {
            return .blue
        }

        return point
            .tripLocation
            .tripAnnotation?
            .frightening == true
            ? .red
            : .orange
    }

    var body:
        some View
    {
        VStack(
            spacing:
                4
        ) {

            Image(
                systemName:
                    "exclamationmark.triangle.fill"
            )
            .font(
                .system(
                    size:
                        12,
                    weight:
                        .bold
                )
            )
            .foregroundStyle(
                .white
            )
            .frame(
                width:
                    30,
                height:
                    30
            )
            .background(
                markerColor,
                in:
                    Circle()
            )
            .overlay {

                Circle()
                    .stroke(
                        .white,
                        lineWidth:
                            2
                    )
            }

            Text(
                point.displayTitle
            )
            .font(
                .caption2.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                .primary
            )
            .lineLimit(
                1
            )
            .fixedSize(
                horizontal:
                    true,
                vertical:
                    false
            )
            .padding(
                .horizontal,
                7
            )
            .padding(
                .vertical,
                3
            )
            .background(
                .regularMaterial,
                in:
                    Capsule()
            )
        }
    }
}

// MARK: - Endpoint Marker

private struct TripEndpointMarker:
    View
{
    let title:
        String

    let systemImage:
        String

    let tint:
        Color

    var body:
        some View
    {
        HStack(
            spacing:
                6
        ) {

            Image(
                systemName:
                    systemImage
            )
            .font(
                .caption2.weight(
                    .bold
                )
            )
            .foregroundStyle(
                .white
            )
            .frame(
                width:
                    22,
                height:
                    22
            )
            .background(
                tint,
                in:
                    Circle()
            )

            Text(
                title
            )
            .font(
                .caption.weight(
                    .semibold
                )
            )
            .foregroundStyle(
                .primary
            )
        }
        .padding(
            .leading,
            3
        )
        .padding(
            .trailing,
            10
        )
        .padding(
            .vertical,
            3
        )
        .background(
            .regularMaterial,
            in:
                Capsule()
        )
        .overlay {

            Capsule()
                .stroke(
                    tint.opacity(
                        0.35
                    ),
                    lineWidth:
                        1
                )
        }
    }
}

// MARK: - Bottom Editor

private struct BottomEditor:
    View
{
    @ObservedObject
    var viewModel:
        TripEditViewModel

    var body:
        some View
    {
        RangeSlider(
            startIndex:
                $viewModel.startIndex,
            endIndex:
                $viewModel.endIndex,
            count:
                viewModel.locations.count,
            disabled:
                viewModel.editingDisabled,
            onStartChanged:
                {
                    viewModel
                        .updateStartIndex(
                            $0
                        )
                },
            onEndChanged:
                {
                    viewModel
                        .updateEndIndex(
                            $0
                        )
                }
        )
        .padding(
            .horizontal,
            18
        )
        .padding(
            .vertical,
            14
        )
        .background {

            if #available(
                iOS 26.0,
                *
            ) {

                RoundedRectangle(
                    cornerRadius:
                        24,
                    style:
                        .continuous
                )
                .fill(
                    .clear
                )
                .glassEffect(
                    .regular,
                    in:
                        RoundedRectangle(
                            cornerRadius:
                                24,
                            style:
                                .continuous
                        )
                )

            } else {

                RoundedRectangle(
                    cornerRadius:
                        24,
                    style:
                        .continuous
                )
                .fill(
                    .ultraThinMaterial
                )
            }
        }
    }
}

// MARK: - Range Slider

private struct RangeSlider:
    View
{
    @Binding
    var startIndex:
        Int

    @Binding
    var endIndex:
        Int

    let count:
        Int

    let disabled:
        Bool

    let onStartChanged:
        (Int) -> Void

    let onEndChanged:
        (Int) -> Void

    @State
    private var activeHandle:
        Handle?

    private enum Handle {
        case start
        case end
    }

    var body:
        some View
    {
        GeometryReader { geometry in

            let inset:
                CGFloat = 18

            let width =
                max(
                    geometry.size.width -
                        inset * 2,
                    1
                )

            let maximum =
                max(
                    count - 1,
                    1
                )

            let centerY =
                geometry.size.height /
                2

            let startX =
                position(
                    index:
                        startIndex,
                    maximum:
                        maximum,
                    width:
                        width,
                    inset:
                        inset
                )

            let endX =
                position(
                    index:
                        endIndex,
                    maximum:
                        maximum,
                    width:
                        width,
                    inset:
                        inset
                )

            ZStack {

                Capsule()
                    .fill(
                        Color.primary.opacity(
                            0.12
                        )
                    )
                    .frame(
                        height:
                            6
                    )
                    .position(
                        x:
                            geometry.size.width /
                            2,
                        y:
                            centerY
                    )

                Capsule()
                    .fill(
                        .tint
                    )
                    .frame(
                        width:
                            max(
                                endX -
                                    startX,
                                6
                            ),
                        height:
                            6
                    )
                    .position(
                        x:
                            (
                                startX +
                                endX
                            ) / 2,
                        y:
                            centerY
                    )

                handle(
                    type:
                        .start,
                    x:
                        startX,
                    y:
                        centerY
                )
                .gesture(
                    dragGesture(
                        handle:
                            .start,
                        width:
                            width,
                        inset:
                            inset,
                        maximum:
                            maximum
                    )
                )

                handle(
                    type:
                        .end,
                    x:
                        endX,
                    y:
                        centerY
                )
                .gesture(
                    dragGesture(
                        handle:
                            .end,
                        width:
                            width,
                        inset:
                            inset,
                        maximum:
                            maximum
                    )
                )
            }
        }
        .frame(
            height:
                36
        )
        .opacity(
            disabled
            ? 0.45
            : 1
        )
    }

    // MARK: Handle

    private func handle(
        type:
            Handle,
        x:
            CGFloat,
        y:
            CGFloat
    ) -> some View {

        let color:
            Color =
            type == .start
            ? .green
            : .red

        let iconName =
            type == .start
            ? "play.fill"
            : "flag.checkered"

        return ZStack {

            Circle()
                .fill(
                    .background
                )
                .frame(
                    width:
                        32,
                    height:
                        32
                )

            Circle()
                .stroke(
                    color,
                    lineWidth:
                        activeHandle ==
                        type
                        ? 2.5
                        : 1.5
                )
                .frame(
                    width:
                        32,
                    height:
                        32
                )

            Image(
                systemName:
                    iconName
            )
            .font(
                .caption2.weight(
                    .bold
                )
            )
            .foregroundStyle(
                color
            )
        }
        .scaleEffect(
            activeHandle ==
                type
            ? 1.12
            : 1
        )
        .position(
            x:
                x,
            y:
                y
        )
    }

    // MARK: Drag

    private func dragGesture(
        handle:
            Handle,
        width:
            CGFloat,
        inset:
            CGFloat,
        maximum:
            Int
    ) -> some Gesture {

        DragGesture(
            minimumDistance:
                4,
            coordinateSpace:
                .local
        )
        .onChanged { value in

            guard
                !disabled
            else {
                return
            }

            activeHandle =
                handle

            let normalized =
                min(
                    max(
                        (
                            value.location.x -
                            inset
                        ) /
                        width,
                        0
                    ),
                    1
                )

            let index =
                Int(
                    (
                        normalized *
                        CGFloat(
                            maximum
                        )
                    )
                    .rounded()
                )

            switch handle {

            case .start:

                let newValue =
                    min(
                        max(
                            index,
                            0
                        ),
                        max(
                            endIndex - 1,
                            0
                        )
                    )

                guard
                    newValue !=
                        startIndex
                else {
                    return
                }

                startIndex =
                    newValue

                onStartChanged(
                    newValue
                )

            case .end:

                let newValue =
                    max(
                        min(
                            index,
                            maximum
                        ),
                        min(
                            startIndex + 1,
                            maximum
                        )
                    )

                guard
                    newValue !=
                        endIndex
                else {
                    return
                }

                endIndex =
                    newValue

                onEndChanged(
                    newValue
                )
            }
        }
        .onEnded { _ in

            activeHandle =
                nil
        }
    }

    // MARK: Position

    private func position(
        index:
            Int,
        maximum:
            Int,
        width:
            CGFloat,
        inset:
            CGFloat
    ) -> CGFloat {

        guard
            maximum > 0
        else {
            return inset
        }

        return inset +
            (
                CGFloat(index) /
                CGFloat(maximum)
            ) *
            width
    }
}
