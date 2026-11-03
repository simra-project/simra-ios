//
//  SimRaApp.swift
//  SimRa
//
//  Created by Emil Pauls on 27.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//


import SwiftUI
import CoreLocation
import CoreMotion

@main
struct SimRaApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var bluetoothObserver = BluetoothObserver()
    @AppStorage("appAppearance") private var appAppearance: String = "auto"
    
    var body: some Scene {
        WindowGroup {
            MainView()
                .preferredColorScheme(colorScheme)
                .alert("SimRa", isPresented: $bluetoothObserver.showDisconnectAlert) {
                    Button("Return", role: .cancel) { }
                } message: {
                    Text("Device disconnected")
                }
                .onOpenURL { url in
                    handleDeeplink(url: url)
                }
        }
    }

    // MARK: - Color Scheme

    private var colorScheme: ColorScheme? {
        switch appAppearance {
        case "light":
            return .light
        case "dark":
            return .dark
        case "system", "auto":
            return nil // Follow system

        default:
            return nil
        }
    }

    // MARK: - Deeplink Handling (simra://)

    private func handleDeeplink(url: URL) {
        guard url.scheme == "simra" else { return }

        if url.host == "recording" {
            if url.path == "/start" {
                _ = RecordingShortcutBridge.startRecording()
            } else if url.path == "/stop" {
                _ = RecordingShortcutBridge.stopRecording()
            } else if url.path == "/danger" {
                _ = RecordingShortcutBridge.markIncident(
                    0,
                    source: "Widget"
                )
            }
        } else if url.host == "incident" {
            let components = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )
            let incidentType = Int(
                components?.queryItems?.first {
                    $0.name == "type"
                }?.value ?? "0"
            ) ?? 0
            _ = RecordingShortcutBridge.markIncident(
                incidentType,
                source: "Live Activity"
            )
        }
    }
}
