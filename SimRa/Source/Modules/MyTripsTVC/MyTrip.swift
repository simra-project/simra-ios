//
//  MyTrip.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import SwiftUI
import CoreLocation

// MARK: - My Trips View

struct MyTripsView: View {

    // MARK: State

    @State private var items: [TripListItem] = []
    @State private var selectedTripIDs: Set<Int> = []

    @State private var isLoading = false
    @State private var hasLoaded = false
    @State private var searchText = ""

    @StateObject private var uploadCoordinator =
        TripBatchUploadCoordinator()

    @Environment(\.editMode)
    private var editMode

    // MARK: Derived State

    private var isEditing: Bool {
        editMode?.wrappedValue.isEditing == true
    }

    private var pendingItems: [TripListItem] {
        items.filter {
            !$0.isUploaded && matchesSearch($0)
        }
    }

    private var uploadedItems: [TripListItem] {
        items.filter {
            $0.isUploaded && matchesSearch($0)
        }
    }

    private func matchesSearch(
        _ item: TripListItem
    ) -> Bool {

        let query =
            searchText
                .trimmingCharacters(
                    in: .whitespacesAndNewlines
                )

        guard !query.isEmpty else {
            return true
        }

        return String(item.id)
            .localizedCaseInsensitiveContains(query)
    }

    private var selectedItems: [TripListItem] {
        items.filter {
            selectedTripIDs.contains($0.id)
        }
    }

    private var selectedPendingItems: [TripListItem] {
        selectedItems.filter {
            !$0.isUploaded
        }
    }

    private var allPendingSelected: Bool {

        let ids =
            Set(
                pendingItems.map(\.id)
            )

        guard !ids.isEmpty else {
            return false
        }

        return ids.isSubset(
            of: selectedTripIDs
        )
    }

    // MARK: Body

    var body: some View {

        List(
            selection:
                $selectedTripIDs
        ) {

            pendingSection
            uploadedSection

            if hasLoaded &&
                items.isEmpty {

                emptyState
            }
        }
        .listStyle(
            .insetGrouped
        )
        .navigationTitle(
            NSLocalizedString(
                "My Trips",
                comment:
                    "My Trips"
            )
        )
        .navigationBarTitleDisplayMode(
            .inline
        )
        .searchable(
            text:
                $searchText,
            prompt:
                NSLocalizedString(
                    "Search trips",
                    comment:
                        "Search trips"
                )
        )
        .toolbar {
            toolbar
        }
        .task {
            await loadTripsIfNeeded()
        }
        .refreshable {
            await reloadTrips()
        }
        .onChange(
            of: isEditing
        ) { _, editing in

            if !editing {
                selectedTripIDs.removeAll()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for:
                    .tripEdited
            )
        ) { _ in

            Task {
                await reloadTrips()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for:
                    .tripAttributesChanged
            )
        ) { _ in

            Task {
                await reloadTrips()
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(
                for:
                    .tripAnnotationChanged
            )
        ) { _ in

            Task {
                await reloadTrips()
            }
        }
        .alert(
            uploadCoordinator.alertTitle,
            isPresented:
                $uploadCoordinator.showAlert
        ) {

            Button(
                NSLocalizedString(
                    "OK",
                    comment:
                        "OK"
                ),
                role:
                    .cancel
            ) {

                Task {
                    await reloadTrips()
                }
            }

        } message: {

            Text(
                uploadCoordinator.alertMessage
            )
        }
    }

    // MARK: Pending Section

    @ViewBuilder
    private var pendingSection:
        some View {

        if !pendingItems.isEmpty {

            Section {

                ForEach(
                    pendingItems
                ) { item in

                    tripRow(
                        item
                    )
                }

            } header: {

                sectionHeader(
                    NSLocalizedString(
                        "Not Uploaded",
                        comment:
                            "Trips not uploaded"
                    )
                )
            }
        }
    }

    // MARK: Uploaded Section

    @ViewBuilder
    private var uploadedSection:
        some View {

        if !uploadedItems.isEmpty {

            Section {

                ForEach(
                    uploadedItems
                ) { item in

                    tripRow(
                        item
                    )
                }

            } header: {

                sectionHeader(
                    NSLocalizedString(
                        "Uploaded",
                        comment:
                            "Uploaded trips"
                    )
                )
            }
        }
    }

    // MARK: Empty State

    private var emptyState:
        some View {

        ContentUnavailableView(
            NSLocalizedString(
                "No trips",
                comment:
                    "No trips"
            ),
            systemImage:
                "bicycle",
            description:
                Text(
                    NSLocalizedString(
                        "Once trips are recorded, they will appear here.",
                        comment:
                            "Empty trips description"
                    )
                )
        )
        .listRowBackground(
            Color.clear
        )
        .listRowSeparator(
            .hidden
        )
    }

    // MARK: Toolbar

    @ToolbarContentBuilder
    private var toolbar:
        some ToolbarContent {

        ToolbarItem(
            placement:
                .topBarTrailing
        ) {

            EditButton()
        }

        if isEditing {

            ToolbarItem(
                placement:
                    .topBarLeading
            ) {

                Button {
                    toggleSelectAll()
                } label: {

                    Text(
                        allPendingSelected
                        ? NSLocalizedString(
                            "None",
                            comment:
                                "Deselect all"
                        )
                        : NSLocalizedString(
                            "All",
                            comment:
                                "Select all"
                        )
                    )
                }
                .disabled(
                    pendingItems.isEmpty
                )
            }

            ToolbarItemGroup(
                placement:
                    .bottomBar
            ) {

                Button {
                    uploadSelected()
                } label: {

                    if uploadCoordinator.isUploading {

                        ProgressView()
                            .controlSize(
                                .small
                            )

                    } else {

                        Label(
                            NSLocalizedString(
                                "Upload",
                                comment:
                                    "Upload"
                            ),
                            systemImage:
                                "icloud.and.arrow.up"
                        )
                    }
                }
                .disabled(
                    selectedPendingItems.isEmpty ||
                    uploadCoordinator.isUploading
                )

                Spacer()

                Button(
                    role:
                        .destructive
                ) {

                    deleteSelected()

                } label: {

                    Label(
                        NSLocalizedString(
                            "Delete",
                            comment:
                                "Delete"
                        ),
                        systemImage:
                            "trash"
                    )
                }
                .disabled(
                    selectedItems.isEmpty ||
                    uploadCoordinator.isUploading
                )
            }
        }
    }

    // MARK: Section Header

    private func sectionHeader(
        _ title: String
    ) -> some View {

        Text(title)
            .font(
                .subheadline.weight(
                    .semibold
                )
            )
            .textCase(nil)
    }

    // MARK: Trip Row

    @ViewBuilder
    private func tripRow(
        _ item:
            TripListItem
    ) -> some View {

        NavigationLink {

            LazyTripEditDestination(
                identifier:
                    item.id
            )

        } label: {

            TripRow(
                item:
                    item
            )
        }
        .swipeActions(
            edge:
                .leading,
            allowsFullSwipe:
                false
        ) {

            if !item.isUploaded {

                Button {

                    if let trip =
                        item.loadTrip() {

                        uploadSingle(
                            trip
                        )
                    }

                } label: {

                    Label(
                        NSLocalizedString(
                            "Upload",
                            comment:
                                "Upload"
                        ),
                        systemImage:
                            "icloud.and.arrow.up"
                    )
                }
                .tint(
                    .accentColor
                )
                .disabled(
                    uploadCoordinator.isUploading
                )
            }
        }
        .swipeActions(
            edge:
                .trailing,
            allowsFullSwipe:
                true
        ) {

            Button(
                role:
                    .destructive
            ) {

                delete(
                    item.id
                )

            } label: {

                Label(
                    NSLocalizedString(
                        "Delete",
                        comment:
                            "Delete"
                    ),
                    systemImage:
                        "trash"
                )
            }
            .disabled(
                uploadCoordinator.isUploading
            )
        }
    }

    // MARK: Loading

    private func loadTripsIfNeeded() async {

        guard !hasLoaded else {
            return
        }

        await reloadTrips()
    }

    private func reloadTrips() async {

        guard !isLoading else {
            return
        }

        isLoading = true
        hasLoaded = false
        selectedTripIDs.removeAll()

        items.removeAll(
            keepingCapacity:
                true
        )

        /*
         Load identifiers first.

         The identifier is only used as a fallback for ordering.
         The actual date always comes from the trip's own locations.
         */

        let identifiers =
            Set(
                TripInfo.allStoredIdentifiers()
                    +
                Trip.allStoredIdentifiers()
            )
            .sorted {
                $0.intValue > $1.intValue
            }

        var batchCount = 0

        for identifier in identifiers {

            guard !Task.isCancelled else {
                break
            }

            let tripIdentifier =
                identifier.intValue

            /*
             Prefer TripInfo for metadata, but independently load
             the Trip so that the actual recording timestamps come
             from this specific trip.
             */

            /*
             Read only the compact TripInfo record for the first paint.
             Loading the full location stream is deferred until the row
             is already visible.
             */

            guard let info =
                TripInfo(
                    fromStorage:
                        tripIdentifier
                )
            else {
                continue
            }

            let item =
                TripListItem(
                    info:
                        info,
                    startDate:
                        info.duration.startDate,
                    endDate:
                        info.duration.endDate
                )

            items.append(
                item
            )

            batchCount += 1

            /*
             Give SwiftUI an opportunity to render the already
             loaded rows before continuing.
             */

            if batchCount >= 3 {

                batchCount = 0

                await Task.yield()
            }
        }

        /*
         Final ordering:
         1. Real recording start date, newest first.
         2. Trip identifier as deterministic fallback.

         This prevents equal/missing dates from producing an
         unpredictable order.
         */

        items.sort {

            switch (
                $0.startDate,
                $1.startDate
            ) {

            case let (
                lhs?,
                rhs?
            ):

                if lhs != rhs {
                    return lhs > rhs
                }

                return $0.id > $1.id

            case (
                _?,
                nil
            ):

                return true

            case (
                nil,
                _?
            ):

                return false

            case (
                nil,
                nil
            ):

                return $0.id > $1.id
            }
        }

        let summaryIdentifiers =
            items.map(\.id)

        isLoading = false
        hasLoaded = true

        Task {
            for identifier in summaryIdentifiers {
                guard !Task.isCancelled else {
                    return
                }

                await calculateSummary(
                    forIdentifier:
                        identifier
                )

                // Keep the first-render path responsive when many rides exist.
                await Task.yield()
            }
        }
    }

    // MARK: Summary Calculation

    private func calculateSummary(
        forIdentifier identifier: Int
    ) async {
        guard !Task.isCancelled else {
            return
        }

        let summary: TripSummary? =
            await Task.detached(
                priority:
                    .utility
            ) { () -> TripSummary? in
                guard let trip = Trip(fromStorage: identifier) else {
                    return nil
                }

                let input =
                    TripSummaryBuilder.makeInput(
                        from:
                            trip
                    )

                return TripSummaryBuilder.calculate(
                    input:
                        input
                )
            }
            .value

        guard
            !Task.isCancelled,
            let summary,
            let index =
                items.firstIndex(
                    where: {
                        $0.id == identifier
                    }
                )
        else {
            return
        }

        items[index].summaryOverride = summary
    }

    // MARK: Selection

    private func toggleSelectAll() {

        let ids =
            Set(
                pendingItems.map(
                    \.id
                )
            )

        guard !ids.isEmpty else {
            return
        }

        if allPendingSelected {

            selectedTripIDs.subtract(
                ids
            )

        } else {

            selectedTripIDs.formUnion(
                ids
            )
        }
    }

    // MARK: Upload

    private func uploadSingle(
        _ trip: Trip
    ) {

        guard
            !trip.uploaded,
            !uploadCoordinator.isUploading
        else {
            return
        }

        uploadCoordinator.upload(
            trips:
                [trip]
        )
    }

    private func uploadSelected() {

        let trips =
            selectedPendingItems.compactMap {
                $0.loadTrip()
            }

        guard !trips.isEmpty else {
            return
        }

        uploadCoordinator.upload(
            trips:
                trips
        )
    }

    // MARK: Delete

    private func delete(
        _ identifier: Int
    ) {

        guard
            !uploadCoordinator.isUploading
        else {
            return
        }

        AppDelegate
            .shared()
            .trips
            .deleteTrip(
                withIdentifier:
                    identifier
            )

        selectedTripIDs.remove(
            identifier
        )

        items.removeAll {
            $0.id ==
                identifier
        }
    }

    private func deleteSelected() {

        guard
            !uploadCoordinator.isUploading
        else {
            return
        }

        let ids =
            Array(
                selectedTripIDs
            )

        guard !ids.isEmpty else {
            return
        }

        for identifier in ids {

            AppDelegate
                .shared()
                .trips
                .deleteTrip(
                    withIdentifier:
                        identifier
                )
        }

        items.removeAll {
            ids.contains(
                $0.id
            )
        }

        selectedTripIDs.removeAll()
    }

    // MARK: Dates

    private func tripLocations(
        for trip: Trip
    ) -> [TripLocation] {

        (trip.tripLocations as NSArray)
            .compactMap {
                $0 as? TripLocation
            }
    }

    private func firstDate(
        for trip: Trip
    ) -> Date? {

        tripLocations(
            for:
                trip
        )
        .map {
            $0.location.timestamp
        }
        .min()
    }

    private func lastDate(
        for trip: Trip
    ) -> Date? {

        tripLocations(
            for:
                trip
        )
        .map {
            $0.location.timestamp
        }
        .max()
    }
}

// MARK: - Lazy Trip Edit Destination

private struct LazyTripEditDestination:
    View {

    let identifier:
        Int

    @State private var trip:
        Trip?

    @State private var failed =
        false

    var body: some View {

        Group {

            if let trip {

                TripEditView(
                    viewModel:
                        TripEditViewModel(
                            trip:
                                trip
                        )
                )

            } else if failed {

                ContentUnavailableView(
                    NSLocalizedString(
                        "Trip unavailable",
                        comment:
                            "Trip unavailable"
                    ),
                    systemImage:
                        "exclamationmark.triangle"
                )

            } else {

                ProgressView(
                    NSLocalizedString(
                        "Loading trip",
                        comment:
                            "Loading trip"
                    )
                )
            }
        }
        .task {

            trip =
                Trip(
                    fromStorage:
                        identifier
                )

            failed =
                trip == nil
        }
    }
}

// MARK: - Trip List Item

private struct TripListItem:
    Identifiable {

    let info:
        TripInfo

    /*
     These dates intentionally belong to the individual Trip
     and are not taken from TripInfo.duration.
     */

    let startDate:
        Date?

    let endDate:
        Date?

    var summaryOverride:
        TripSummary? = nil

    var id: Int {
        info.identifier
    }

    var isUploaded: Bool {
        info.uploaded
    }

    var summary:
        TripSummary {

        summaryOverride ??
        TripSummary(
            distanceMeters:
                max(
                    Double(
                        info.length
                    ),
                    0
                ),

            duration:
                calculatedDuration,

            averageSpeedKmh:
                nil,

            maximumSpeedKmh:
                nil,

            pointCount:
                0,

            startDate:
                startDate,

            endDate:
                endDate
        )
        }

    private var calculatedDuration:
        TimeInterval {

        /*
         Prefer the actual location timestamps.

         If those are unavailable, fall back to the stored
         TripInfo duration.
         */

        if let startDate,
           let endDate {

            return max(
                endDate.timeIntervalSince(
                    startDate
                ),
                0
            )
        }

        return max(
            info.duration.duration,
            0
        )
    }

    func loadTrip() -> Trip? {

        Trip(
            fromStorage:
                info.identifier
        )
    }
}

// MARK: - Calculation Point

private struct TripCalculationPoint:
    Sendable {

    let latitude:
        Double

    let longitude:
        Double

    let timestamp:
        TimeInterval

    let speed:
        Double
}

// MARK: - Calculation Input

private struct TripCalculationInput:
    Sendable {

    let points:
        [TripCalculationPoint]

    let startDate:
        Date?

    let endDate:
        Date?
}

// MARK: - Trip Summary

private struct TripSummary:
    Sendable {

    let distanceMeters:
        Double

    let duration:
        TimeInterval

    let averageSpeedKmh:
        Double?

    let maximumSpeedKmh:
        Double?

    let pointCount:
        Int

    let startDate:
        Date?

    let endDate:
        Date?
}

// MARK: - Trip Summary Builder

private enum TripSummaryBuilder {

    // MARK: Extract

    static func makeInput(
        from trip: Trip
    ) -> TripCalculationInput {

        let locations =
            (trip.tripLocations as NSArray)
                .compactMap {
                    $0 as? TripLocation
                }

        var points:
            [TripCalculationPoint] = []

        points.reserveCapacity(
            locations.count
        )

        for location in locations {

            let coordinate =
                location
                    .location
                    .coordinate

            let speed =
                location
                    .location
                    .speed

            points.append(
                TripCalculationPoint(
                    latitude:
                        coordinate.latitude,

                    longitude:
                        coordinate.longitude,

                    timestamp:
                        location
                            .location
                            .timestamp
                            .timeIntervalSince1970,

                    speed:
                        speed
                )
            )
        }

        /*
         Use min/max rather than first/last.

         This makes the calculation robust even if the underlying
         relationship is not returned in timestamp order.
         */

        let startDate =
            locations
                .map {
                    $0.location.timestamp
                }
                .min()

        let endDate =
            locations
                .map {
                    $0.location.timestamp
                }
                .max()

        return TripCalculationInput(
            points:
                points,

            startDate:
                startDate,

            endDate:
                endDate
        )
    }

    // MARK: Calculate

    static func calculate(
        input:
            TripCalculationInput
    ) -> TripSummary {

        guard !input.points.isEmpty else {

            return TripSummary(
                distanceMeters:
                    0,

                duration:
                    0,

                averageSpeedKmh:
                    nil,

                maximumSpeedKmh:
                    nil,

                pointCount:
                    0,

                startDate:
                    input.startDate,

                endDate:
                    input.endDate
            )
        }

        var distanceMeters =
            0.0

        var maximumSpeedKmh =
            0.0

        var previousPoint:
            TripCalculationPoint?

        for point in input.points {

            if let previousPoint {

                let firstLocation =
                    CLLocation(
                        latitude:
                            previousPoint.latitude,
                        longitude:
                            previousPoint.longitude
                    )

                let secondLocation =
                    CLLocation(
                        latitude:
                            point.latitude,
                        longitude:
                            point.longitude
                    )

                let segmentDistance =
                    secondLocation.distance(
                        from:
                            firstLocation
                    )

                if segmentDistance.isFinite &&
                    segmentDistance >= 0 {

                    distanceMeters +=
                        segmentDistance
                }
            }

            if point.speed.isFinite &&
                point.speed >= 0 {

                maximumSpeedKmh =
                    max(
                        maximumSpeedKmh,
                        point.speed * 3.6
                    )
            }

            previousPoint =
                point
        }

        let duration:
            TimeInterval

        if let startDate =
            input.startDate,
           let endDate =
            input.endDate {

            duration =
                max(
                    endDate.timeIntervalSince(
                        startDate
                    ),
                    0
                )

        } else {

            duration =
                0
        }

        let averageSpeed:
            Double?

        if duration > 0 &&
            distanceMeters > 0 {

            let hours =
                duration / 3_600

            averageSpeed =
                hours > 0
                ? (
                    distanceMeters / 1_000
                ) / hours
                : nil

        } else {

            averageSpeed =
                nil
        }

        return TripSummary(
            distanceMeters:
                distanceMeters,

            duration:
                duration,

            averageSpeedKmh:
                averageSpeed,

            maximumSpeedKmh:
                maximumSpeedKmh > 0
                ? maximumSpeedKmh
                : nil,

            pointCount:
                input.points.count,

            startDate:
                input.startDate,

            endDate:
                input.endDate
        )
    }
}

// MARK: - Trip Row

private struct TripRow:
    View {

    let item:
        TripListItem

    var body: some View {

        HStack(
            alignment:
                .center,
            spacing:
                12
        ) {

            tripIcon

            VStack(
                alignment:
                    .leading,
                spacing:
                    4
            ) {

                Text(
                    title
                )
                .font(
                    .subheadline.weight(
                        .semibold
                    )
                )
                .foregroundStyle(
                    .primary
                )
                .lineLimit(
                    1
                )

                summaryView

                let summary =
                    item.summary

                if summary.pointCount > 0 {

                    Text(
                        detailLine(
                            summary
                        )
                    )
                    .font(
                        .caption2
                    )
                    .foregroundStyle(
                        .tertiary
                    )
                    .lineLimit(
                        1
                    )
                }
            }

            Spacer(
                minLength:
                    8
            )

            statusIcon
        }
        .padding(
            .vertical,
            5
        )
    }

    // MARK: Icon

    private var tripIcon:
        some View {

        Image(
            systemName:
                "bicycle"
        )
        .font(
            .system(
                size:
                    15,
                weight:
                    .medium
            )
        )
        .foregroundStyle(
            .tint
        )
        .frame(
            width:
                36,
            height:
                36
        )
        .background(
            Color.secondary.opacity(
                0.09
            ),
            in:
                Circle()
        )
    }

    // MARK: Title

    private var title:
        String {

        guard let date =
            item.startDate
        else {

            return NSLocalizedString(
                "Trip",
                comment:
                    "Trip"
            )
        }

        let calendar =
            Calendar.current

        let time =
            date.formatted(
                .dateTime
                    .hour()
                    .minute()
            )

        if calendar.isDateInToday(
            date
        ) {

            return String(
                format:
                    "%@ · %@",
                NSLocalizedString(
                    "Today",
                    comment:
                        "Today"
                ),
                time
            )
        }

        if calendar.isDateInYesterday(
            date
        ) {

            return String(
                format:
                    "%@ · %@",
                NSLocalizedString(
                    "Yesterday",
                    comment:
                        "Yesterday"
                ),
                time
            )
        }

        if calendar.dateInterval(
            of:
                .weekOfYear,
            for:
                .now
        )?.contains(
            date
        ) == true {

            let weekday =
                date.formatted(
                    .dateTime
                        .weekday(
                            .wide
                        )
                )

            return String(
                format:
                    "%@ · %@",
                weekday,
                time
            )
        }

        return date.formatted(
            .dateTime
                .day()
                .month(
                    .abbreviated
                )
                .year()
                .hour()
                .minute()
        )
    }

    // MARK: Summary

    @ViewBuilder
    private var summaryView:
        some View {

        let summary =
            item.summary

        HStack(
            spacing:
                5
        ) {

            Text(
                formatDistance(
                    summary.distanceMeters
                )
            )

            Text("·")
                .foregroundStyle(
                    .tertiary
                )

            Text(
                formatDuration(
                    summary.duration
                )
            )

            if let speed =
                summary.averageSpeedKmh {

                Text("·")
                    .foregroundStyle(
                        .tertiary
                    )

                Text(
                    String(
                        format:
                            "Ø %.1f km/h",
                        speed
                    )
                )
            }
        }
        .font(
            .caption.weight(
                .medium
            )
        )
        .monospacedDigit()
        .foregroundStyle(
            .secondary
        )
        .lineLimit(
            1
        )
    }

    // MARK: Secondary Detail

    private func detailLine(
        _ summary:
            TripSummary
    ) -> String {

        var values:
            [String] = []

        if let maximum =
            summary.maximumSpeedKmh {

            values.append(
                String(
                    format:
                        "max %.1f km/h",
                    maximum
                )
            )
        }

        if summary.pointCount > 0 {

            values.append(
                String(
                    format:
                        "%d GPS",
                    summary.pointCount
                )
            )
        }

        return values.joined(
            separator:
                " · "
        )
    }

    // MARK: Status

    private var statusIcon:
        some View {

        Image(
            systemName:
                item.isUploaded
                ? "checkmark.circle.fill"
                : "icloud.and.arrow.up"
        )
        .font(
            .caption
        )
        .foregroundStyle(
            item.isUploaded
            ? Color.green
            : Color.secondary
        )
        .accessibilityHidden(
            true
        )
    }

    // MARK: Formatting

    private func formatDistance(
        _ meters:
            Double
    ) -> String {

        let safe =
            max(
                meters,
                0
            )

        if safe >= 1_000 {

            return String(
                format:
                    "%.1f km",
                safe / 1_000
            )
        }

        return String(
            format:
                "%.0f m",
            safe
        )
    }

    private func formatDuration(
        _ duration:
            TimeInterval
    ) -> String {

        let seconds =
            max(
                Int(
                    duration.rounded()
                ),
                0
            )

        let hours =
            seconds / 3_600

        let minutes =
            (
                seconds % 3_600
            ) / 60

        let remaining =
            seconds % 60

        if hours > 0 {

            return String(
                format:
                    "%d:%02d:%02d",
                hours,
                minutes,
                remaining
            )
        }

        return String(
            format:
                "%02d:%02d",
            minutes,
            remaining
        )
    }
}

// MARK: - Batch Upload Coordinator

@MainActor
final class TripBatchUploadCoordinator:
    NSObject,
    ObservableObject {

    @Published var showAlert =
        false

    @Published private(set)
    var alertTitle =
        "SimRa"

    @Published private(set)
    var alertMessage =
        ""

    @Published private(set)
    var isUploading =
        false

    @Published private(set)
    var completedCount =
        0

    @Published private(set)
    var totalCount =
        0

    @Published private(set)
    var progress =
        0.0

    private var queue:
        [Trip] = []

    private var currentIndex =
        0

    private var successCount =
        0

    private var failureCount =
        0

    private var isProcessing =
        false

    private var didFinish =
        false

    // MARK: Upload

    func upload(
        trips:
            [Trip]
    ) {

        guard !isUploading else {
            return
        }

        queue =
            trips
                .filter {
                    !$0.uploaded
                }
                .sorted {
                    $0.identifier <
                    $1.identifier
                }

        currentIndex =
            0

        successCount =
            0

        failureCount =
            0

        completedCount =
            0

        totalCount =
            queue.count

        progress =
            0

        isProcessing =
            false

        didFinish =
            false

        guard !queue.isEmpty else {

            alertMessage =
                NSLocalizedString(
                    "No unuploaded trips selected.",
                    comment:
                        "No unuploaded trips selected"
                )

            showAlert =
                true

            return
        }

        isUploading =
            true

        uploadNext()
    }

    // MARK: Error

    @objc
    func uploadTripError(
        _ error:
            NSError
    ) {

        guard isProcessing else {
            return
        }

        isProcessing =
            false

        failureCount +=
            1

        registerCompletion()

        uploadNext()
    }

    // MARK: Completion

    @objc
    func uploadTripCompleted(
        _ dictionary:
            NSDictionary
    ) {

        guard isProcessing else {
            return
        }

        isProcessing =
            false

        if
            let response =
                dictionary["response"]
                    as? HTTPURLResponse,
            (200...299).contains(
                response.statusCode
            ) {

            successCount +=
                1

        } else {

            failureCount +=
                1
        }

        registerCompletion()

        uploadNext()
    }

    // MARK: Progress

    private func registerCompletion() {

        completedCount =
            min(
                completedCount + 1,
                totalCount
            )

        progress =
            totalCount > 0
            ? Double(
                completedCount
            ) /
            Double(
                totalCount
            )
            : 0
    }

    // MARK: Next

    private func uploadNext() {

        guard
            currentIndex <
                queue.count
        else {

            finish()
            return
        }

        guard !isProcessing else {
            return
        }

        let trip =
            queue[
                currentIndex
            ]

        currentIndex +=
            1

        isProcessing =
            true

        trip.uploadFile(
            "ride",
            withController:
                self,
            error:
                #selector(
                    uploadTripError(_:)
                ),
            completion:
                #selector(
                    uploadTripCompleted(_:)
                )
        )
    }

    // MARK: Finish

    private func finish() {

        guard !didFinish else {
            return
        }

        didFinish =
            true

        isProcessing =
            false

        isUploading =
            false

        completedCount =
            totalCount

        progress =
            totalCount > 0
            ? 1
            : 0

        if failureCount == 0 {

            if successCount == 1 {

                alertMessage =
                    NSLocalizedString(
                        "Trip uploaded successfully.",
                        comment:
                            "Trip upload success"
                    )

            } else {

                alertMessage =
                    String(
                        format:
                            NSLocalizedString(
                                "%d trips uploaded successfully.",
                                comment:
                                    "Trips upload success"
                            ),
                        successCount
                    )
            }

        } else {

            alertMessage =
                String(
                    format:
                        NSLocalizedString(
                            "%d succeeded, %d failed.",
                            comment:
                                "Partial upload failure"
                        ),
                    successCount,
                    failureCount
                )
        }

        NotificationCenter.default.post(
            name:
                .tripAttributesChanged,
            object:
                nil
        )

        showAlert =
            true

        queue.removeAll()

        currentIndex =
            0
    }
}

// MARK: - Notifications

private extension Notification.Name {

    static let tripEdited =
        Notification.Name(
            "tripEdited"
        )

    static let tripAttributesChanged =
        Notification.Name(
            "attributesChanged"
        )

    static let tripAnnotationChanged =
        Notification.Name(
            "annotationChanged"
        )
}
