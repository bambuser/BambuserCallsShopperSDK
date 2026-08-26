//
//  BambuserCallConfiguration.swift
//  BambuserCallsShopper
//

import SwiftUI

/// Frozen-at-init configuration for a `BambuserCallController`.
/// Nullable options are only forwarded to the embed when the host
/// explicitly sets them; otherwise the embed's default applies.
///
/// See https://bambuser.com/docs/video-consultation/calls-widget-api-reference/#configuration-options
public struct BambuserCallConfiguration {

    // MARK: - Presentation (SDK-owned)

    /// Bambuser organization id.
    public var orgId: String

    /// Which Bambuser region to talk to.
    public var environment: BambuserEnvironment

    /// Frame for the connected mini-player. Default 180×260.
    public var floatingPipSize: CGSize

    /// `WKWebView.isInspectable`. Defaults to `true` in DEBUG, `false` in release.
    public var isInspectable: Bool

    /// Auto-restore full screen when the call connects while in PiP. Default `true`.
    public var autoExpandOnConnect: Bool

    /// Auto-dismiss the overlay when the call ends. Default `true`.
    public var dismissOnCallEnd: Bool

    // MARK: - Embed constructor options

    /// Language + region for the embed UI (e.g. `"sv-SE"`). Must
    /// match a translation enabled in BamHub.
    public var locale: String?

    /// Initial customer data presented to the agent. Update at
    /// runtime with `controller.updateData(_:)`.
    public var initialCustomerData: BambuserJSONValue?

    /// Initial analytics tags. Max 20; last-key-wins on dupes.
    /// Update at runtime with `controller.setTrackingTags(_:)`.
    public var initialTrackingTags: [BambuserTrackingTag]

    /// Initial queue for drop-in calls. Overrides the workspace
    /// default. Update at runtime with `controller.setQueue(_:)`.
    public var initialQueue: String?

    /// Show the drop-in card on the start screen. `nil` → embed default.
    public var dropInEnabled: Bool?

    /// Show the booking card on the start screen. `nil` → BamHub setting.
    public var bookingsEnabled: Bool?

    /// Open the widget directly on the booking page. Default `false`.
    public var openBookingPage: Bool

    /// Restrict visible booking services. `nil` → all published services.
    public var bookingServiceIds: [String]?

    /// Pin the widget to a specific booking resource.
    public var bookingResourceId: String?

    /// Custom booking iframe URL for external booking-system integrations.
    public var bookingIframeUrl: String?

    /// Enable barcode / QR scanning in the agent app. Default `false`.
    public var enableScanning: Bool

    /// Base URL sent to the agent for co-browsing.
    public var merchantBaseUrl: String?

    /// Disable co-browsing. Default `false`.
    public var disableCoBrowsing: Bool

    /// Override the active BamHub theme.
    public var themeId: String?

    /// Whether the embed can write first-party cookies. `nil` → embed default.
    public var allowFirstPartyCookies: Bool?

    /// Forward every embed event to `BambuserCallEvent.other`.
    /// Default `false`. Turn on for forward-compat or analytics tees.
    public var forwardUnknownEmbedEvents: Bool

    // MARK: - Internal defaults

    internal var triggers: [String] = ["always", "connect-link"]
    internal var floatingNavigationMode: String = "manual"
    internal var floatingFillMode: String = "cover"
    internal var minimizedPipSize: CGSize = CGSize(width: 180, height: 60)
    internal var pipMargin: CGFloat = 16
    internal var bottomReserve: CGFloat = 49
    internal var transitionAnimation: Animation = .easeInOut(duration: 0.22)
    internal var customUserAgent: String? = BambuserCallConfiguration.bambuserSafariUserAgent
    internal var injectsLegacyGetUserMediaShim: Bool = true
    internal var disableDataLayerInterceptions: Bool = true

    // MARK: - Init

    public init(
        orgId: String,
        environment: BambuserEnvironment = .us,
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
        allowFirstPartyCookies: Bool? = nil,
        forwardUnknownEmbedEvents: Bool = false
    ) {
        self.orgId = orgId
        self.environment = environment
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
        self.forwardUnknownEmbedEvents = forwardUnknownEmbedEvents
    }

    public static let defaultFloatingPipSize = CGSize(width: 180, height: 260)

    public static var defaultIsInspectable: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }

    internal static let bambuserSafariUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.7 Mobile/21H16 Safari/604.1"
}
