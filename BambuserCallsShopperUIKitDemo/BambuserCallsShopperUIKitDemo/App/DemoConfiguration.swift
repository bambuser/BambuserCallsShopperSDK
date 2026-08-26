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
    static var environment: BambuserEnvironment {
        #if DEBUG
        return .stageUS
        #else
        return productionEnvironment
        #endif
    }

    static var isConfigured: Bool { !orgId.isEmpty }
}
