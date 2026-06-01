//
//  BambuserCallsShopperDemoApp.swift
//  BambuserCallsShopperDemo
//

import SwiftUI
import BambuserCallsShopper

// MARK: - Bambuser settings — fill these in before running the demo.

/// Your Bambuser organization id. Get this from your Bambuser dashboard.
private let demoOrgId = "rakODREyCuvCZj1wvWUa"

/// The Bambuser embed script URL.
///
/// - Production:  `https://one-to-one.bambuser.com/embed.js`
/// - Production:  `https://one-to-one.bambuser.com/eu/embed.js`

/// - Labs branch: `https://labs.bambuser.com/one-to-one/gitlab-mr/<id>/embed.js`
private let demoEmbedUrlString = "https://lvs-121-dev.web.app/embed.js"

private var demoEmbedUrl: URL? { URL(string: demoEmbedUrlString) }

/// `true` once both `demoOrgId` and `demoEmbedUrlString` have been filled
/// in with valid values. The UI uses this to gate the "Talk to expert"
/// button and show a setup prompt at launch.
internal var isBambuserConfigured: Bool {
    !demoOrgId.isEmpty && demoEmbedUrl != nil
}

// MARK: - App

@main
struct BambuserCallsShopperDemoApp: App {

    @StateObject private var navigation = NavigationCoordinator()
    @StateObject private var cart = CartStore()
    @StateObject private var bambuserCall: BambuserCallController

    @State private var handlersConfigured: Bool = false
    @State private var showSetupAlert: Bool = !isBambuserConfigured

    init() {
        // Use the placeholder org id verbatim and fall back to the SDK's
        // default embed URL if the demo URL is empty. The configuration is
        // built either way so the rest of the app can mount cleanly — the
        // "Talk to expert" button is gated separately on isBambuserConfigured.
        let url = demoEmbedUrl ?? BambuserCallConfiguration.defaultEmbedUrl
        _bambuserCall = StateObject(wrappedValue: BambuserCallController(
            configuration: BambuserCallConfiguration(
                orgId: demoOrgId,
                embedUrl: url
            )
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootTabsView()
                .environmentObject(navigation)
                .environmentObject(cart)
                .environmentObject(bambuserCall)
                .onAppear {
                    guard !handlersConfigured else { return }
                    BambuserCallBridge.configure(
                        controller: bambuserCall,
                        navigation: navigation,
                        cart: cart
                    )
                    handlersConfigured = true
                }
                .alert("Bambuser credentials missing", isPresented: $showSetupAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Set demoOrgId and demoEmbedUrlString at the top of BambuserCallsShopperDemoApp.swift before starting an expert call.")
                }
        }
    }
}
