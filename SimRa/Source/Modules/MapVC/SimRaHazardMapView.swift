//
//  SimRaHazardMapView.swift
//  SimRa
//
//  Created by Emil Pauls on 29.08.26.
//  Copyright © 2026 Mobile Cloud Computing an der Fakultät IV (Elektrotechnik und Informatik) der TU Berlin. All rights reserved.
//

import SwiftUI
import WebKit

struct SimRaHazardMapView: View {

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            SimRaHazardWebView(
                url: URL(
                    string:
                        "https://simra.3s-rg.de/streets/map"
                )!
            )
            .ignoresSafeArea(
                edges: .bottom
            )
            .navigationTitle(NSLocalizedString("Hazard Map", comment: "Hazard Map"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(
                    placement: .topBarTrailing
                ) {
                    Button(NSLocalizedString("Done", comment: "Done")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - WKWebView

private struct SimRaHazardWebView:
    UIViewRepresentable
{

    let url: URL

    func makeCoordinator()
        -> Coordinator
    {
        Coordinator()
    }

    func makeUIView(
        context:
            Context
    ) -> WKWebView {

        let configuration =
            WKWebViewConfiguration()

        configuration.websiteDataStore =
            .default()

        configuration.defaultWebpagePreferences
            .allowsContentJavaScript = true

        let webView =
            WKWebView(
                frame: .zero,
                configuration:
                    configuration
            )

        webView.navigationDelegate =
            context.coordinator

        webView.allowsBackForwardNavigationGestures =
            true

        webView.scrollView.contentInsetAdjustmentBehavior =
            .never

        let request =
            URLRequest(
                url: url,
                cachePolicy:
                    .useProtocolCachePolicy,
                timeoutInterval:
                    30
            )

        webView.load(request)

        return webView
    }

    func updateUIView(
        _ webView: WKWebView,
        context:
            Context
    ) {
        // The page is intentionally loaded only once.
        // Nothing is reloaded on SwiftUI updates.
    }

    // MARK: - Coordinator

    final class Coordinator:
        NSObject,
        WKNavigationDelegate
    {

        func webView(
            _ webView: WKWebView,
            didFail navigation:
                WKNavigation?,
            withError error:
                Error
        ) {

            print(
                "[SimRaHazardMap] Navigation failed:",
                error.localizedDescription
            )
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation:
                WKNavigation?,
            withError error:
                Error
        ) {

            print(
                "[SimRaHazardMap] Initial navigation failed:",
                error.localizedDescription
            )
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction:
                WKNavigationAction,
            decisionHandler:
                @escaping (
                    WKNavigationActionPolicy
                ) -> Void
        ) {

            guard
                let url =
                    navigationAction
                        .request
                        .url
            else {
                decisionHandler(.cancel)
                return
            }

            // Keep normal HTTP(S) navigation inside
            // the dashboard. External custom schemes
            // are passed to the system.
            if
                let scheme =
                    url.scheme?.lowercased(),
                scheme != "http",
                scheme != "https"
            {

                UIApplication.shared.open(
                    url
                )

                decisionHandler(.cancel)
                return
            }

            decisionHandler(.allow)
        }
    }
}
