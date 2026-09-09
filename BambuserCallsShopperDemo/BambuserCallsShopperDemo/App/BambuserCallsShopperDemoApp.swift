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

/// DEBUG builds → `.stageUS` (Bambuser-internal staging). Release
/// builds → `productionEnvironment`. `Scripts/prepare-release.sh`
/// scrubs this `#if DEBUG` block out of the staged copy, so the
/// public consumer never sees `.stageUS`.
private var demoEnvironment: BambuserEnvironment {
    return productionEnvironment
}

/// `true` once `demoOrgId` has been filled in.
internal var isBambuserConfigured: Bool {
    !demoOrgId.isEmpty
}

// MARK: - App

/// `BambuserShopperSDK` is a struct, so wrap it in an ObservableObject so
/// SwiftUI's `.environmentObject(...)` plumbing can hand the same instance
/// to any view that needs to fire tracking events.
@MainActor
final class BambuserSDKHolder: ObservableObject {
    let sdk: BambuserShopperSDK

    init(sdk: BambuserShopperSDK) {
        self.sdk = sdk
    }
}

@main
struct BambuserCallsShopperDemoApp: App {

    @StateObject private var navigation = NavigationCoordinator()
    @StateObject private var cart = CartStore()
    @StateObject private var bambuserCall: BambuserCallController
    @StateObject private var bambuserSDKHolder: BambuserSDKHolder

    @State private var bridge: BambuserCallBridge?
    @State private var showSetupAlert: Bool = !isBambuserConfigured

    init() {
        _bambuserCall = StateObject(wrappedValue: BambuserCallController(
            configuration: BambuserCallConfiguration(
                orgId: demoOrgId,
                environment: demoEnvironment
            )
        ))
        _bambuserSDKHolder = StateObject(wrappedValue: BambuserSDKHolder(
            sdk: BambuserShopperSDK(
                environment: demoEnvironment,
                orgId: demoOrgId
            )
        ))
    }

    var body: some Scene {
        WindowGroup {
            RootTabsView()
                .environmentObject(navigation)
                .environmentObject(cart)
                .environmentObject(bambuserCall)
                .environmentObject(bambuserSDKHolder)
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
