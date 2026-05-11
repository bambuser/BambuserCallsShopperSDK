//
//  BambuserCallConfiguration.swift
//  BambuserCallsShopper
//

import SwiftUI

/// Frozen-at-init configuration for a `BambuserCallController`. The public
/// surface is intentionally narrow — six knobs hosts realistically flip.
/// Everything else (embed triggers, fill modes, animation curves, etc.)
/// has internal defaults and isn't part of the supported API.
public struct BambuserCallConfiguration {

    /// Bambuser organization id. Hardcoded into the JS embed call.
    public var orgId: String

    /// Embed script URL. Override for staging / labs / branch builds.
    public var embedUrl: URL

    /// Frame for the connected mini-player (full video tile + controls).
    /// Default 180×260.
    public var floatingPipSize: CGSize

    /// Whether `WKWebView.isInspectable` is set. Defaults to `true` in
    /// DEBUG, `false` in release builds.
    public var isInspectable: Bool

    /// When the call transitions to `.connected` while the user is in PiP,
    /// auto-restore to full screen. Default `true`.
    public var autoExpandOnConnect: Bool

    /// When the call ends (`call-ended` and friends), automatically dismiss
    /// the overlay. Default `true`.
    public var dismissOnCallEnd: Bool

    // Internal defaults — not part of the public API.
    internal var triggers: [String] = ["always", "connect-link"]
    internal var floatingNavigationMode: String = "manual"
    internal var floatingFillMode: String = "cover"
    internal var minimizedPipSize: CGSize = CGSize(width: 180, height: 60)
    internal var pipMargin: CGFloat = 16
    internal var bottomReserve: CGFloat = 49
    internal var transitionAnimation: Animation = .easeInOut(duration: 0.22)
    internal var customUserAgent: String? = BambuserCallConfiguration.bambuserSafariUserAgent
    internal var injectsLegacyGetUserMediaShim: Bool = true

    public init(
        orgId: String,
        embedUrl: URL = BambuserCallConfiguration.defaultEmbedUrl,
        floatingPipSize: CGSize = BambuserCallConfiguration.defaultFloatingPipSize,
        isInspectable: Bool = BambuserCallConfiguration.defaultIsInspectable,
        autoExpandOnConnect: Bool = true,
        dismissOnCallEnd: Bool = true
    ) {
        self.orgId = orgId
        self.embedUrl = embedUrl
        self.floatingPipSize = floatingPipSize
        self.isInspectable = isInspectable
        self.autoExpandOnConnect = autoExpandOnConnect
        self.dismissOnCallEnd = dismissOnCallEnd
    }

    public static let defaultEmbedUrl = URL(string: "https://one-to-one.bambuser.com/embed.js")!

    public static let defaultFloatingPipSize = CGSize(width: 180, height: 260)

    public static var defaultIsInspectable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    /// Safari iOS UA used by default so the embed's browser-detection
    /// check recognizes the WebKit context as a supported browser.
    internal static let bambuserSafariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.7 Mobile/21H16 Safari/604.1"
}
