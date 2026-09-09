//
//  DemoConfiguration.swift
//  BambuserCallsShopperUIKitDemo
//
//  Fill these in before running the demo. Mirrors the settings block
//  at the top of the SwiftUI demo's App file.
//

import Foundation
import BambuserCallsShopper

enum DemoConfiguration {

    /// Your Bambuser organization id.
    static let orgId: String = ""

    /// Release-build environment. Change to `.eu` if your workspace is
    /// on the EU cluster.
    static let productionEnvironment: BambuserEnvironment = .us

    /// Environment the demo actually uses:
    ///  - DEBUG builds → `.stageUS` (Bambuser-internal staging).
    ///  - Release builds → whatever `productionEnvironment` is set to.
    /// `Scripts/prepare-release.sh` scrubs the `#if DEBUG` block out
    /// of the staged copy, so the public consumer never sees `.stageUS`.
    static var environment: BambuserEnvironment {
        return productionEnvironment
    }

    static var isConfigured: Bool { !orgId.isEmpty }

    /// Build the app-scope shopper analytics handle. Held for the
    /// lifetime of the scene so `track(...)` calls can attribute events
    /// to a Bambuser call even after it ended.
    @MainActor
    static func makeShopperSDK() -> BambuserShopperSDK {
        BambuserShopperSDK(environment: environment, orgId: orgId)
    }
}
