//
//  BambuserCallConfiguration.swift
//  BambuserCallsShopper
//

import SwiftUI

/// Frozen-at-init configuration for a `BambuserCallController`.
///
/// The public surface covers the six presentation knobs the SDK owns and
/// every option the JS embed constructor accepts. Nullable options
/// (`dropInEnabled`, `bookingsEnabled`, etc.) are only forwarded when
/// the host explicitly sets them — otherwise the embed's own default
/// applies.
///
/// See https://bambuser.com/docs/video-consultation/calls-widget-api-reference/#configuration-options
public struct BambuserCallConfiguration {

    // MARK: - Presentation (SDK-owned)

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

    // MARK: - Embed constructor options (forwarded to JS)

    /// Language + region for the embed UI (e.g. `"sv-SE"`). Must match a
    /// translation enabled in BamHub. Default is the embed's own default
    /// (`en-US`).
    public var locale: String?

    /// Initial customer data presented to the agent — a
    /// `.object([...])` payload. Shape it however you want on the host
    /// side (typically the embed's built-in `externalId` / `firstName`
    /// / `lastName` / `email` / `phone` fields, plus any flat custom
    /// properties). Update later with `controller.updateData(_:)`.
    public var initialCustomerData: BambuserJSONValue?

    /// Initial analytics tags for the session. Update later with
    /// `controller.setTrackingTags(_:)`. Max 20; last-key-wins on dupes.
    public var initialTrackingTags: [BambuserTrackingTag]

    /// Initial queue for drop-in calls. Overrides the workspace default.
    /// Update later with `controller.setQueue(_:)`.
    public var initialQueue: String?

    /// Show the drop-in card on the start screen. `nil` → embed default
    /// (`true`).
    public var dropInEnabled: Bool?

    /// Show the booking card on the start screen. `nil` → BamHub setting.
    public var bookingsEnabled: Bool?

    /// Open the widget directly on the booking page. Default `false`.
    public var openBookingPage: Bool

    /// Restrict which booking services are visible. `nil` → all
    /// published services.
    public var bookingServiceIds: [String]?

    /// Pin the widget to a specific booking resource.
    public var bookingResourceId: String?

    /// Custom booking iframe URL — typically for external booking system
    /// integrations.
    public var bookingIframeUrl: String?

    /// Enable barcode / QR scanning in the agent mobile app during a
    /// call. Default `false`.
    public var enableScanning: Bool

    /// Base URL to send the agent to when they enter co-browsing mode.
    /// Defaults to `window.origin` (which for the mobile SDK resolves to
    /// the embed host, not particularly useful — set this explicitly if
    /// you use co-browsing).
    public var merchantBaseUrl: String?

    /// Disable the co-browsing feature. Default `false` (embed decides).
    public var disableCoBrowsing: Bool

    /// Override the active BamHub theme.
    public var themeId: String?

    /// Whether the embed can write first-party cookies. `nil` → embed
    /// default (`true`). Note: the WebView's own cookie policy is
    /// separate and configured natively.
    public var allowFirstPartyCookies: Bool?

    // MARK: - Internal defaults — not part of the public API

    internal var triggers: [String] = ["always", "connect-link"]
    internal var floatingNavigationMode: String = "manual"
    internal var floatingFillMode: String = "cover"
    internal var minimizedPipSize: CGSize = CGSize(width: 180, height: 60)
    internal var pipMargin: CGFloat = 16
    internal var bottomReserve: CGFloat = 49
    internal var transitionAnimation: Animation = .easeInOut(duration: 0.22)
    internal var customUserAgent: String? = BambuserCallConfiguration.bambuserSafariUserAgent
    internal var injectsLegacyGetUserMediaShim: Bool = true

    /// Always `true` for the mobile SDK — the merchant's page-level
    /// GTM / GA data layer does not exist inside our WebView, so the
    /// embed's data-layer interceptors have nothing to attach to and
    /// their probes just add noise (and occasional crashes on some
    /// embed builds). Not part of the public API — hosts don't need
    /// to think about this.
    internal var disableDataLayerInterceptions: Bool = true

    // MARK: - Init

    public init(
        orgId: String,
        embedUrl: URL = BambuserCallConfiguration.defaultEmbedUrl,
        floatingPipSize: CGSize = BambuserCallConfiguration.defaultFloatingPipSize,
        isInspectable: Bool = BambuserCallConfiguration.defaultIsInspectable,
        autoExpandOnConnect: Bool = true,
        dismissOnCallEnd: Bool = true,
        locale: String? = nil,
        initialCustomerData: BambuserJSONValue? = nil,
        initialTrackingTags: [BambuserTrackingTag] = [],
        initialQueue: String? = nil,
        dropInEnabled: Bool? = nil,
        bookingsEnabled: Bool? = nil,
        openBookingPage: Bool = false,
        bookingServiceIds: [String]? = nil,
        bookingResourceId: String? = nil,
        bookingIframeUrl: String? = nil,
        enableScanning: Bool = false,
        merchantBaseUrl: String? = nil,
        disableCoBrowsing: Bool = false,
        themeId: String? = nil,
        allowFirstPartyCookies: Bool? = nil
    ) {
        self.orgId = orgId
        self.embedUrl = embedUrl
        self.floatingPipSize = floatingPipSize
        self.isInspectable = isInspectable
        self.autoExpandOnConnect = autoExpandOnConnect
        self.dismissOnCallEnd = dismissOnCallEnd
        self.locale = locale
        self.initialCustomerData = initialCustomerData
        self.initialTrackingTags = initialTrackingTags
        self.initialQueue = initialQueue
        self.dropInEnabled = dropInEnabled
        self.bookingsEnabled = bookingsEnabled
        self.openBookingPage = openBookingPage
        self.bookingServiceIds = bookingServiceIds
        self.bookingResourceId = bookingResourceId
        self.bookingIframeUrl = bookingIframeUrl
        self.enableScanning = enableScanning
        self.merchantBaseUrl = merchantBaseUrl
        self.disableCoBrowsing = disableCoBrowsing
        self.themeId = themeId
        self.allowFirstPartyCookies = allowFirstPartyCookies
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
