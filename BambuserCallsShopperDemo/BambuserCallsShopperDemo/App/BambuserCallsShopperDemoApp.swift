//
//  BambuserCallsShopperDemoApp.swift
//  BambuserCallsShopperDemo
//

import SwiftUI
import BambuserCallsShopper

// MARK: - Bambuser settings — fill these in before running the demo.

/// Your Bambuser organization id. Get this from your Bambuser dashboard.
private let demoOrgId = ""

/// Which Bambuser region this demo talks to in **release** builds.
/// Change to `.eu` if your workspace is on the EU cluster.
private let productionEnvironment: BambuserEnvironment = .us

/// DEBUG builds → `.stageUS` (internal staging, `#if DEBUG`-gated
/// inside the SDK). Release builds → `productionEnvironment`.
private var demoEnvironment: BambuserEnvironment {
    #if DEBUG
    return .stageUS
    #else
    return productionEnvironment
    #endif
}

/// `true` once `demoOrgId` has been filled in.
internal var isBambuserConfigured: Bool {
    !demoOrgId.isEmpty
}

// MARK: - App

@main
struct BambuserCallsShopperDemoApp: App {

    @StateObject private var navigation = NavigationCoordinator()
    @StateObject private var cart = CartStore()
    @StateObject private var bambuserCall: BambuserCallController

    @State private var bridge: BambuserCallBridge?
    @State private var showSetupAlert: Bool = !isBambuserConfigured

    init() {
        _bambuserCall = StateObject(wrappedValue: BambuserCallController(
            configuration: BambuserCallConfiguration(
                orgId: demoOrgId,
                environment: demoEnvironment
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
                    guard bridge == nil else { return }
                    // Hold a strong reference — controller.delegate is weak.
                    bridge = BambuserCallBridge.configure(
                        controller: bambuserCall,
                        navigation: navigation,
                        cart: cart
                    )
                }
                .alert("Bambuser credentials missing", isPresented: $showSetupAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Set demoOrgId at the top of BambuserCallsShopperDemoApp.swift before starting an expert call.")
                }
        }
    }
}
