//
//  SettingsView.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV
//  (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import Foundation
import SwiftUI
import MessageUI
import UserNotifications

private struct RideReminderRule: Codable, Identifiable, Equatable {
    let id: UUID
    var weekday: Int
    var hour: Int
    var minute: Int
}

// MARK: - Settings View

struct SettingsView: View {

    // MARK: - Environment

    @Environment(\.openURL)
    private var openURL

    // MARK: - Constants

    private let minimumTripsToSend = 10

    // MARK: - State

    @State
    private var showDiagnosticAlert = false

    @State
    private var showRidesActionSheet = false

    @State
    private var showMailAlert = false

    @State
    private var showMailComposer = false

    @State
    private var showResultAlert = false

    @State
    private var resultAlertTitle = ""

    @State
    private var resultAlertMessage = ""

    @State
    private var allRidesSizeString = ""

    @State
    private var recentRidesSizeString = ""

    @State
    private var hasEnoughTripsForRecent = false

    @AppStorage("offlineMapMode")
    private var offlineMapMode = false

    @AppStorage("showRecordedRoute")
    private var showRecordedRoute = true

    @AppStorage("appAppearance")
    private var appAppearance = "system"

    @State private var reminderRules: [RideReminderRule] = []
    @State private var reminderWeekday = 2
    @State private var reminderHour = 8
    @State private var reminderMinute = 0

    // MARK: - Body

    var body: some View {
        List {

            // MARK: General

            Section {
                Toggle(
                    NSLocalizedString("Do not show map", comment: "Do not show the map while recording"),
                    isOn: $offlineMapMode
                )

                Toggle(
                    NSLocalizedString("Show recorded route", comment: "Show route on map"),
                    isOn: $showRecordedRoute
                )

                Picker(
                    NSLocalizedString("Appearance", comment: "App appearance"),
                    selection: $appAppearance
                ) {
                    Text(NSLocalizedString("System", comment: "System appearance")).tag("system")
                    Text(NSLocalizedString("Light", comment: "Light appearance")).tag("light")
                    Text(NSLocalizedString("Dark", comment: "Dark appearance")).tag("dark")
                }
            } header: {
                Text(NSLocalizedString("Map display", comment: "Map display settings"))
            }

            Section {
                Toggle(
                    NSLocalizedString("Ride reminder", comment: "Weekly ride reminder"),
                    isOn: Binding(
                        get: { !reminderRules.isEmpty },
                        set: { enabled in
                            if !enabled { reminderRules.removeAll() }
                            else if reminderRules.isEmpty {
                                reminderRules.append(newReminderRule())
                            }
                            scheduleRideReminders()
                        }
                    )
                )

                if !reminderRules.isEmpty {
                    Picker(
                        NSLocalizedString("Weekday", comment: "Reminder weekday"),
                        selection: $reminderWeekday
                    ) {
                        ForEach(1...7, id: \.self) { day in
                            Text(weekdayName(day)).tag(day)
                        }
                    }

                    DatePicker(
                        NSLocalizedString("Time", comment: "Reminder time"),
                        selection: reminderDateBinding,
                        displayedComponents: .hourAndMinute
                    )

                    Button {
                        reminderRules.append(
                            RideReminderRule(
                                id: UUID(),
                                weekday: reminderWeekday,
                                hour: reminderHour,
                                minute: reminderMinute
                            )
                        )
                        scheduleRideReminders()
                    } label: {
                        Label(
                            NSLocalizedString("Save reminder", comment: "Save reminder settings"),
                            systemImage: "bell.badge"
                        )
                    }
                }

                ForEach(reminderRules) { rule in
                    HStack {
                        Text(ruleDescription(rule))
                        Spacer()
                        Button {
                            reminderRules.removeAll { $0.id == rule.id }
                            scheduleRideReminders()
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.red)
                    }
                }
            } header: {
                Text(NSLocalizedString("Notifications", comment: "Notification settings"))
            }

            Section {
                Button {
                    openLocalizedURL(
                        en: "https://www.digital-future.berlin/en/research/projects/simra/",
                        de: "https://www.digital-future.berlin/forschung/projekte/simra/"
                    )
                } label: {
                    Label(
                        NSLocalizedString(
                            "About",
                            comment: "About"
                        ),
                        systemImage: "info.circle"
                    )
                }

                Button {
                    openLocalizedURL(
                        en: "https://www.tu.berlin/en/3s/research/projects/simra-privacy-policy-statement",
                        de: "https://www.tu.berlin/3s/forschung/projekte/simra-datenschutzerklaerung"
                    )
                } label: {
                    Label(
                        NSLocalizedString(
                            "Privacy",
                            comment: "Privacy"
                        ),
                        systemImage: "hand.raised"
                    )
                }

                Button {
                    showHowTo()
                } label: {
                    Label(
                        NSLocalizedString(
                            "How To",
                            comment: "How To"
                        ),
                        systemImage: "questionmark.circle"
                    )
                }

                Button {
                    handleFeedbackAction()
                } label: {
                    Label(
                        NSLocalizedString(
                            "Feedback",
                            comment: "Feedback"
                        ),
                        systemImage: "envelope"
                    )
                }

                Button {
                    openLocalizedURL(
                        en: "https://www.tu.berlin/en/footer/site-credits",
                        de: "https://www.tu.berlin/footer/impressum"
                    )
                } label: {
                    Label(
                        NSLocalizedString(
                            "Imprint",
                            comment: "Imprint"
                        ),
                        systemImage: "building.columns"
                    )
                }
            }

            // MARK: User

            Section {
                NavigationLink {
                    StatisticsDashboardView()
                } label: {
                    Label(
                        NSLocalizedString("Statistics", comment: "Statistics"),
                        systemImage: "chart.bar.xaxis"
                    )
                }

                NavigationLink {
                    ProfileView()
                } label: {
                    Label(
                        NSLocalizedString("Profile", comment: "Profile"),
                        systemImage: "person.crop.circle"
                    )
                }

                NavigationLink {
                    TripSettingsView()
                } label: {
                    Label(
                        NSLocalizedString("Trip Settings", comment: "Trip settings"),
                        systemImage: "slider.horizontal.3"
                    )
                }
            }

            // MARK: Diagnostics

            Section {
                Button {
                    showDiagnosticAlert = true
                } label: {
                    HStack {
                        Text(versionString)

                        Spacer()
                    }
                }
                .foregroundStyle(.primary)
                .accessibilityLabel(
                    NSLocalizedString(
                        "App version",
                        comment:
                            "Accessibility label for app version"
                    )
                )
                .accessibilityHint(
                    NSLocalizedString(
                        "Tap to send diagnostic data to the SimRa team.",
                        comment:
                            "Accessibility hint for app version"
                    )
                )
            }
        }
        .navigationTitle(
            NSLocalizedString(
                "Settings",
                comment: "Settings"
            )
        )
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadReminderRules()
        }

        // MARK: Diagnostic Confirmation

        .alert(
            NSLocalizedString(
                "Send local app data to SimRa team",
                comment:
                    "Diagnostic upload title"
            ),
            isPresented: $showDiagnosticAlert
        ) {
            Button(
                NSLocalizedString(
                    "Cancel",
                    comment: "Cancel"
                ),
                role: .cancel
            ) {
                // Nothing to do.
            }

            Button(
                NSLocalizedString(
                    "Continue",
                    comment: "Continue"
                )
            ) {
                Utility.writeSimRaPrefs()
                prepareAndShowRidesActionSheet()
            }
        } message: {
            Text(
                NSLocalizedString(
                    "Attention! Only tap the Continue button if you were asked to do so by the SimRa team. By pressing the Upload button in the next step, you send your SimRa configuration to the SimRa team. You can also specify to upload the last 10 rides or all rides.",
                    comment:
                        "Diagnostic upload explanation"
                )
            )
        }

        // MARK: Ride Selection

        .confirmationDialog(
            NSLocalizedString(
                "Do you also want to send rides?",
                comment:
                    "Ride upload question"
            ),
            isPresented: $showRidesActionSheet,
            titleVisibility: .visible
        ) {
            Button(
                String(
                    format: "%@ (%@)",
                    NSLocalizedString(
                        "Yes, all",
                        comment:
                            "Upload all rides"
                    ),
                    allRidesSizeString
                )
            ) {
                sendZipToServer(
                    allTrips: true
                )
            }

            if hasEnoughTripsForRecent {
                Button(
                    String(
                        format: "%@ %d (%@)",
                        NSLocalizedString(
                            "Yes, the last",
                            comment:
                                "Upload recent rides"
                        ),
                        minimumTripsToSend,
                        recentRidesSizeString
                    )
                ) {
                    sendZipToServer(
                        allTrips: false
                    )
                }
            }

            Button(
                NSLocalizedString(
                    "No, don't send any rides",
                    comment:
                        "Don't upload rides"
                ),
                role: .cancel
            ) {
                // Nothing to do.
            }
        }

        // MARK: Mail Unavailable

        .alert(
            NSLocalizedString(
                "SimRa",
                comment: "SimRa"
            ),
            isPresented: $showMailAlert
        ) {
            Button(
                NSLocalizedString(
                    "OK",
                    comment: "OK"
                ),
                role: .cancel
            ) {
                // Nothing to do.
            }
        } message: {
            Text(
                NSLocalizedString(
                    "Configure your Email, please!",
                    comment:
                        "Mail configuration required"
                )
            )
        }

        // MARK: Upload Result

        .alert(
            resultAlertTitle,
            isPresented: $showResultAlert
        ) {
            Button(
                NSLocalizedString(
                    "OK",
                    comment: "OK"
                ),
                role: .cancel
            ) {
                // Nothing to do.
            }
        } message: {
            Text(resultAlertMessage)
        }

        // MARK: Mail Composer

        .sheet(
            isPresented: $showMailComposer
        ) {
            MailView()
        }
    }

    // MARK: - Version

    private var versionString: String {
        let info = Bundle.main.infoDictionary

        let name =
            info?["CFBundleName"] as? String
            ?? "SimRa"

        let version =
            info?["CFBundleVersion"] as? String
            ?? ""

        let language =
            Locale.current.language.languageCode?.identifier
            ?? ""

        return "\(name)-\(version)-\(language)"
    }

    // MARK: - How To

    private func showHowTo() {
        let language =
            Locale.current.language.languageCode?.identifier
            ?? "de"

        let urlString =
            language == "en"
            ? "https://simra-backend.3s-rg.de:4998/SimRa_Instructions_IOS.pdf"
            : "https://simra-backend.3s-rg.de:4998/SimRa_Anleitung_IOS.pdf"

        guard let url = URL(string: urlString) else {
            return
        }

        openURL(url)
    }

    private var reminderDateBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(
                    from: DateComponents(
                        hour: reminderHour,
                        minute: reminderMinute
                    )
                ) ?? .now
            },
            set: { date in
                let components = Calendar.current.dateComponents(
                    [.hour, .minute],
                    from: date
                )
                reminderHour = components.hour ?? 8
                reminderMinute = components.minute ?? 0
            }
        )
    }

    private func weekdayName(_ weekday: Int) -> String {
        let symbols = Calendar.current.weekdaySymbols
        guard symbols.indices.contains(weekday - 1) else {
            return ""
        }
        return symbols[weekday - 1]
    }

    private func newReminderRule() -> RideReminderRule {
        RideReminderRule(
            id: UUID(),
            weekday: reminderWeekday,
            hour: reminderHour,
            minute: reminderMinute
        )
    }

    private func ruleDescription(_ rule: RideReminderRule) -> String {
        let day = weekdayName(rule.weekday)
        return String(format: "%@ · %02d:%02d", day, rule.hour, rule.minute)
    }

    private func loadReminderRules() {
        guard
            let data = UserDefaults.standard.data(forKey: "rideReminderRules"),
            let rules = try? JSONDecoder().decode([RideReminderRule].self, from: data)
        else { return }
        reminderRules = rules
    }

    private func scheduleRideReminders() {
        if let data = try? JSONEncoder().encode(reminderRules) {
            UserDefaults.standard.set(data, forKey: "rideReminderRules")
        }

        let center = UNUserNotificationCenter.current()
        let identifiers = reminderRules.map { "simra.ride.reminder.\($0.id.uuidString)" }
        let previousIdentifiers = UserDefaults.standard.stringArray(
            forKey: "rideReminderNotificationIDs"
        ) ?? []
        center.removePendingNotificationRequests(
            withIdentifiers: previousIdentifiers
        )
        UserDefaults.standard.set(
            identifiers,
            forKey: "rideReminderNotificationIDs"
        )

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else {
                return
            }

            for (rule, identifier) in zip(self.reminderRules, identifiers) {
                var components = DateComponents()
                components.weekday = rule.weekday
                components.hour = rule.hour
                components.minute = rule.minute
                let content = UNMutableNotificationContent()
                content.title = NSLocalizedString("Ready to ride?", comment: "Ride reminder title")
                content.body = NSLocalizedString("Start a SimRa recording for your next ride.", comment: "Ride reminder body")
                content.sound = .default
                center.add(UNNotificationRequest(
                    identifier: identifier,
                    content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                ))
            }
        }
    }

    // MARK: - Localized URL

    private func openLocalizedURL(
        en: String,
        de: String
    ) {
        let language =
            Locale.current.language.languageCode?.identifier
            ?? "de"

        let urlString =
            language == "en"
            ? en
            : de

        guard let url = URL(string: urlString) else {
            return
        }

        openURL(url)
    }

    // MARK: - Feedback

    private func handleFeedbackAction() {
        if MFMailComposeViewController.canSendMail() {
            showMailComposer = true
        } else {
            showMailAlert = true
        }
    }

    // MARK: - Ride Upload Preparation

    private func prepareAndShowRidesActionSheet() {
        let totalTrips =
            Trip
                .allStoredIdentifiers()
                .count

        allRidesSizeString =
            getTripsSize(
                allTrips: true
            )

        recentRidesSizeString =
            getTripsSize(
                allTrips: false
            )

        hasEnoughTripsForRecent =
            totalTrips >= minimumTripsToSend

        showRidesActionSheet = true
    }

    // MARK: - Trip Files

    private func tripFilePaths(
        allTrips: Bool
    ) -> [String] {
        let tripIdentifiers =
            Trip
                .allStoredIdentifiers()
                .sorted {
                    $0.compare($1) == .orderedAscending
                }

        guard !tripIdentifiers.isEmpty else {
            return []
        }

        let selectedIdentifiers: [NSNumber]

        if !allTrips &&
            tripIdentifiers.count > minimumTripsToSend {
            selectedIdentifiers =
                Array(
                    tripIdentifiers.suffix(
                        minimumTripsToSend
                    )
                )
        } else {
            selectedIdentifiers =
                tripIdentifiers
        }

        guard
            let docsPath =
                Utility.getDocumentDirectory()
        else {
            return []
        }

        let documentsDirectory =
            docsPath as NSString

        var paths: [String] = []

        paths.reserveCapacity(
            selectedIdentifiers.count * 2
        )

        for tripIdentifier in selectedIdentifiers {
            let index =
                tripIdentifier.intValue

            let tripPath =
                documentsDirectory
                    .appendingPathComponent(
                        "Trip-\(index).json"
                    )

            let tripInfoPath =
                documentsDirectory
                    .appendingPathComponent(
                        "TripInfo-\(index).json"
                    )

            paths.append(tripPath)
            paths.append(tripInfoPath)
        }

        return paths
    }

    // MARK: - Size

    private func getTripsSize(
        allTrips: Bool
    ) -> String {
        let paths =
            tripFilePaths(
                allTrips: allTrips
            )

        guard !paths.isEmpty else {
            return ByteCountFormatter.string(
                fromByteCount: 0,
                countStyle: .file
            )
        }

        let fileManager =
            FileManager.default

        var totalBytes: Int64 = 0

        for path in paths {
            guard
                let attributes =
                    try? fileManager.attributesOfItem(
                        atPath: path
                    ),
                let size =
                    attributes[.size] as? Int64
            else {
                continue
            }

            totalBytes += size
        }

        return ByteCountFormatter.string(
            fromByteCount: totalBytes,
            countStyle: .file
        )
    }

    // MARK: - Create ZIP

    private func createZipFile(
        allTrips: Bool
    ) -> String? {
        let fileManager =
            FileManager.default

        let temporaryDirectory =
            URL(
                fileURLWithPath:
                    NSTemporaryDirectory(),
                isDirectory: true
            )

        let zipURL =
            temporaryDirectory
                .appendingPathComponent(
                    "Logger.zip"
                )

        var paths =
            Utility.getAllDocumentsPrefLinks()

        paths.append(
            contentsOf:
                tripFilePaths(
                    allTrips: allTrips
                )
        )

        paths =
            paths.filter {
                fileManager.fileExists(
                    atPath: $0
                )
            }

        guard !paths.isEmpty else {
            return nil
        }

        do {
            if fileManager.fileExists(
                atPath: zipURL.path
            ) {
                try fileManager.removeItem(
                    at: zipURL
                )
            }
        } catch {
            print(
                "Failed to remove old Logger.zip:",
                error
            )

            return nil
        }

        let created =
            SimpleZipArchiver.createZipFile(
                atPath: zipURL.path,
                withFilesAtPaths: paths
            )

        return created
            ? zipURL.path
            : nil
    }

    // MARK: - Upload ZIP

    private func sendZipToServer(
        allTrips: Bool
    ) {
        guard
            let zipFilePath =
                createZipFile(
                    allTrips: allTrips
                )
        else {
            showUploadResult(
                success: false
            )
            return
        }

        guard
            let zipData =
                try? Data(
                    contentsOf:
                        URL(
                            fileURLWithPath:
                                zipFilePath
                        )
                ),
            !zipData.isEmpty
        else {
            showUploadResult(
                success: false
            )
            return
        }

        let apiPrefix =
            API.apiPrefix()

        let clientHash =
            UIDevice.current
                .identifierForVendor?
                .uuidString
            ?? "unknown"

        let baseURL =
            "\(apiPrefix)/debug"

        guard
            var components =
                URLComponents(
                    string: baseURL
                )
        else {
            showUploadResult(
                success: false
            )
            return
        }

        components.queryItems = [
            URLQueryItem(
                name: "clientHash",
                value: clientHash
            )
        ]

        guard
            let url =
                components.url
        else {
            showUploadResult(
                success: false
            )
            return
        }

        let boundary =
            "SimRa-\(UUID().uuidString)"

        var request =
            URLRequest(
                url: url
            )

        request.httpMethod = "POST"

        request.setValue(
            "multipart/form-data; boundary=\(boundary)",
            forHTTPHeaderField:
                "Content-Type"
        )

        var body =
            Data()

        let header =
            """
            --\(boundary)\r
            Content-Disposition: form-data; name="file"; filename="Logger.zip"\r
            Content-Type: application/zip\r
            \r
            """

        body.append(
            Data(
                header.utf8
            )
        )

        body.append(
            zipData
        )

        let footer =
            "\r\n--\(boundary)--\r\n"

        body.append(
            Data(
                footer.utf8
            )
        )

        request.httpBody =
            body

        URLSession.shared.dataTask(
            with: request
        ) { _, response, error in

            DispatchQueue.main.async {
                if error != nil {
                    showUploadResult(
                        success: false
                    )
                    return
                }

                guard
                    let httpResponse =
                        response as? HTTPURLResponse
                else {
                    showUploadResult(
                        success: false
                    )
                    return
                }

                showUploadResult(
                    success:
                        (200...299).contains(
                            httpResponse.statusCode
                        )
                )
            }
        }
        .resume()
    }

    // MARK: - Upload Result

    private func showUploadResult(
        success: Bool
    ) {
        resultAlertTitle =
            NSLocalizedString(
                "SimRa",
                comment: "SimRa"
            )

        resultAlertMessage =
            success
            ? NSLocalizedString(
                "Files uploaded successfully",
                comment:
                    "Upload succeeded"
            )
            : NSLocalizedString(
                "Something went wrong. Please try again later",
                comment:
                    "Upload failed"
            )

        showResultAlert = true
    }
}

private struct StatisticsDashboardView: View {
    private struct Summary: Identifiable {
        let id: Int
        let date: Date
        let distance: Int
        let incidents: Int
        let uploaded: Bool
    }

    @State private var summaries: [Summary] = []

    private var totalDistance: Int {
        summaries.reduce(0) { $0 + $1.distance }
    }

    private var totalIncidents: Int {
        summaries.reduce(0) { $0 + $1.incidents }
    }

    private var uploadedShare: Double {
        guard !summaries.isEmpty else { return 0 }
        return Double(summaries.filter(\.uploaded).count) / Double(summaries.count)
    }

    private var timeOfDay: [Int] {
        let suffix = AppDelegate.shared().regions.regionId == 0
            ? ""
            : "-\(AppDelegate.shared().regions.regionId)"
        let stored =
            UserDefaults.standard.array(
                forKey:
                    "totalSlots\(suffix)"
            ) as? [Int] ?? []

        if stored.count >= 24 {
            return stride(from: 0, to: 24, by: 6).map { start in
                stored[start..<start + 6].reduce(0, +)
            }
        }

        return summaries.reduce(into: Array(repeating: 0, count: 4)) { result, summary in
            let hour = Calendar.current.component(.hour, from: summary.date)
            result[min(hour / 6, 3)] += 1
        }
    }

    private func persistedStatistic(_ key: String) -> Int {
        let regionID = AppDelegate.shared().regions.regionId
        let suffix = regionID == 0 ? "" : "-\(regionID)"
        return UserDefaults.standard.integer(forKey: "\(key)\(suffix)")
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3_600
        let minutes = (seconds % 3_600) / 60
        return hours > 0
            ? String(format: "%dh %02dm", hours, minutes)
            : String(format: "%dm", minutes)
    }

    private var yearly: [(Int, Int)] {
        Dictionary(grouping: summaries) {
            Calendar.current.component(.year, from: $0.date)
        }
        .map { ($0.key, $0.value.count) }
        .sorted { $0.0 > $1.0 }
    }

    var body: some View {
        List {
            Section {
                metric("Trips", value: "\(summaries.count)", symbol: "bicycle")
                metric("Total distance", value: formatDistance(totalDistance), symbol: "point.topleft.down.curvedto.point.bottomright.up")
                metric("Incidents", value: "\(totalIncidents)", symbol: "exclamationmark.triangle")
                metric("Total duration", value: formatDuration(persistedStatistic("totalDuration")), symbol: "clock")
                metric("Idle time", value: formatDuration(persistedStatistic("totalIdle")), symbol: "pause.circle")
                metric("Scary incidents", value: "\(persistedStatistic("numberOfScary"))", symbol: "exclamationmark.octagon")
                metric("Uploaded", value: "\(Int(uploadedShare * 100))%", symbol: "arrow.up.circle")
            } header: {
                Text(NSLocalizedString("Overview", comment: "Statistics overview"))
            }

            Section {
                HStack(alignment: .bottom, spacing: 12) {
                    ForEach(Array(timeOfDay.enumerated()), id: \.offset) { index, count in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.tint)
                                .frame(height: CGFloat(max(count, 1)) * 12)
                            Text(["00–06", "06–12", "12–18", "18–24"][index])
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(height: 120, alignment: .bottom)
            } header: {
                Text(NSLocalizedString("Rides by time of day", comment: "Time of day distribution"))
            }

            Section {
                ForEach(yearly, id: \.0) { year, count in
                    LabeledContent(String(year), value: "\(count)")
                }
            } header: {
                Text(NSLocalizedString("Trips by year", comment: "Yearly distribution"))
            }
        }
        .navigationTitle(NSLocalizedString("Statistics", comment: "Statistics"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadSummaries()
        }
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        LabeledContent {
            Text(value).fontWeight(.semibold).monospacedDigit()
        } label: {
            Label(NSLocalizedString(title, comment: "Statistics metric"), systemImage: symbol)
        }
    }

    private func formatDistance(_ meters: Int) -> String {
        String(format: "%.1f km", Double(meters) / 1000)
    }

    private func loadSummaries() {
        summaries = TripInfo.allStoredIdentifiers().compactMap { number in
            guard let info = TripInfo(fromStorage: number.intValue) else { return nil }
            return Summary(
                id: info.identifier,
                date: info.duration.startDate,
                distance: info.length,
                incidents: info.validAnnotationsCount,
                uploaded: info.uploaded
            )
        }
        .sorted { $0.date > $1.date }
    }
}

// MARK: - Mail View

struct MailView: UIViewControllerRepresentable {

    @Environment(\.presentationMode)
    private var presentationMode

    final class Coordinator:
        NSObject,
        MFMailComposeViewControllerDelegate
    {
        @Binding
        var presentation:
            PresentationMode

        init(
            presentation:
                Binding<PresentationMode>
        ) {
            _presentation =
                presentation
        }

        func mailComposeController(
            _ controller:
                MFMailComposeViewController,
            didFinishWith result:
                MFMailComposeResult,
            error:
                Error?
        ) {
            presentation.dismiss()
        }
    }

    func makeCoordinator()
        -> Coordinator
    {
        Coordinator(
            presentation:
                presentationMode
        )
    }

    func makeUIViewController(
        context:
            Context
    ) -> MFMailComposeViewController {

        let viewController =
            MFMailComposeViewController()

        viewController.mailComposeDelegate =
            context.coordinator

        viewController.setToRecipients([
            "ask@mcc.tu-berlin.de"
        ])

        viewController.setSubject(
            NSLocalizedString(
                "Feedback SimRa",
                comment:
                    "Feedback email subject"
            )
        )

        viewController.setMessageBody(
            NSLocalizedString(
                "Dear SimRa Team",
                comment:
                    "Feedback email body"
            ),
            isHTML: false
        )

        return viewController
    }

    func updateUIViewController(
        _ uiViewController:
            MFMailComposeViewController,
        context:
            Context
    ) {
        // Nothing to update.
    }
}
