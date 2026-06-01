//
//  BambuserCallHandlers.swift
//  BambuserCallsShopper
//
//  Declarative data-source / event-listener contract. Whatever the host
//  fills in here drives what the SDK subscribes to in JS — no wasted
//  bridge traffic for events the host doesn't care about.
//
//  All closures run on `@MainActor` (the SDK's actor). Async handlers
//  may suspend; the SDK serialises their replies back to the embed via
//  the `invoke` bridge.
//

import Foundation

// MARK: - Cart intent + result

/// The intent the agent sent from their tool. `raw` is the untouched
/// payload from the web — inspect it if you need fields the SDK didn't
/// surface.
public struct BambuserCartIntent: Equatable, Sendable {
    public let sku: String
    public let quantity: Int
    /// Only meaningful on `should-update-item-in-cart`. `nil` for adds.
    public let previousQuantity: Int?
    public let raw: BambuserJSONValue

    public init(sku: String, quantity: Int, previousQuantity: Int?, raw: BambuserJSONValue) {
        self.sku = sku
        self.quantity = quantity
        self.previousQuantity = previousQuantity
        self.raw = raw
    }
}

/// What the host wants to tell the agent tool.
///
/// - `.success` shows the item as added / updated (serializes to `true`).
/// - `.failure(reason:)` surfaces an error message next to the product
///   ("out of stock", "cart locked", etc.) — serializes to `false` or
///   `{success: false, reason: ...}`.
/// - `.raw(BambuserJSONValue)` sends an arbitrary payload verbatim.
///   Use this when the widget starts requiring a reply shape the
///   preset cases don't cover — no SDK release needed to support it.
public enum BambuserCartResult: Sendable, Equatable {
    case success
    case failure(reason: String? = nil)
    case raw(BambuserJSONValue)
}

// MARK: - Handlers container

/// Register a closure per event you want to hear about. Anything left
/// `nil` means the SDK will **not** subscribe to the underlying JS
/// event. The set of non-nil handlers is snapshotted at `show()` time.
///
/// All closures run on `@MainActor`.
public struct BambuserCallHandlers {

    // MARK: Data-source handlers (must return a value; SDK replies to the embed)

    /// The agent added a product in their tool. Return a
    /// `BambuserFactorySpec` describing the `updateProduct(...)` chain
    /// you want the embed to apply, or `nil` to signal "product not
    /// found" (the agent sees an empty-state card).
    ///
    /// The SDK is deliberately unaware of the product shape — model
    /// your product however you like on the host side and produce a
    /// spec. The demo target ships one such reference model.
    ///
    /// The SDK calls this once per ref in the payload; you don't need
    /// to fan out yourself.
    public var provideProductData: (@MainActor (BambuserProductRef) async -> BambuserFactorySpec?)?

    /// The agent is searching the catalog. Return a
    /// `BambuserFactorySpec` describing the `searchResponse(...)` chain
    /// the embed should apply, or `nil` to signal an empty result set.
    public var provideSearchData: (@MainActor (BambuserSearchRequest) async -> BambuserFactorySpec?)?

    /// The agent added an item to the cart. Return `.success` when the
    /// host cart accepted it; `.failure(reason:)` to surface an error.
    public var shouldAddToCart: (@MainActor (BambuserCartIntent) async -> BambuserCartResult)?

    /// The agent updated (or removed via `quantity == 0`) an item in
    /// the cart. Same return contract as `shouldAddToCart`.
    public var shouldUpdateCart: (@MainActor (BambuserCartIntent) async -> BambuserCartResult)?

    // MARK: Event listeners (fire and forget)

    /// The agent asked to send the shopper to a URL (a product page,
    /// the checkout, or any other route). This is the `surf-behind-to`
    /// event — the single point every agent-driven navigation passes
    /// through, including `goto-checkout` (which the widget internally
    /// routes to `floatAbove()` → `surf-behind-to`).
    ///
    /// Wire this into your SwiftUI router:
    /// ```
    /// handlers.onNavigateToURL = { url in navigation.push(url: url) }
    /// ```
    /// If left nil, agent navigation requests are silently dropped and
    /// the call stays where it is.
    public var onNavigateToURL: (@MainActor (URL) -> Void)?

    /// The shopper tapped the checkout button. `payload` is the cart
    /// snapshot the embed sent — decode it however you want. If you
    /// also set `onNavigateToURL`, note that the widget itself will
    /// route checkout through `surf-behind-to`, so you generally want
    /// to route in `onNavigateToURL` and use this event only for
    /// analytics / side effects.
    public var onGotoCheckout: (@MainActor (BambuserJSONValue) -> Void)?

    /// The shopper picked "I prefer to chat" instead of a call. The
    /// widget has already closed by the time this fires.
    public var onGotoChat: (@MainActor () -> Void)?

    /// The widget was closed (by the user or by `destroy()`). The
    /// overlay has already been dismissed natively.
    public var onClose: (@MainActor () -> Void)?

    /// The call moved between `.idle` / `.connecting` / `.connected` /
    /// `.ended`. Also observable via `controller.callState`.
    public var onCallStateChanged: (@MainActor (CallState) -> Void)?

    /// The overlay flipped between full-screen and PiP.
    public var onPresentationChanged: (@MainActor (_ isPiP: Bool, _ presentation: PipPresentation) -> Void)?

    /// Queue opened (or was open at load time).
    public var onQueueOpen: (@MainActor (BambuserQueueOpenState) -> Void)?

    /// Queue closed.
    public var onQueueClosed: (@MainActor (BambuserQueueOpenState) -> Void)?

    /// Number of online agents changed.
    public var onAgentsOnline: (@MainActor (BambuserAgentsOnline) -> Void)?

    /// Estimated waiting time updated.
    public var onQueueWaitingTime: (@MainActor (BambuserQueueWaitingTime) -> Void)?

    /// Analytics event — Bambuser-shape and GA4-shape are both surfaced.
    public var onTrackingEvent: (@MainActor (BambuserTrackingEvent) -> Void)?

    /// Catch-all for embed events the SDK doesn't model explicitly. If
    /// set, the SDK installs the emitter override that captures *every*
    /// event the embed emits and forwards it here. If nil, only events
    /// with explicit handlers cross the bridge.
    public var onEmbedEvent: (@MainActor (_ name: String, _ payload: BambuserJSONValue) -> Void)?

    /// Non-fatal SDK errors (JS eval failures, invalid payloads, etc.).
    public var onError: (@MainActor (BambuserCallError) -> Void)?

    public init() {}
}

// MARK: - Subscriptions snapshot (SDK-internal)

/// Which JS `.on(...)` subscriptions to install for a given handlers
/// snapshot. Frozen at `show()` time; the HTML is templated from this.
internal struct BambuserCallSubscriptions: Equatable {
    var provideProductData: Bool = false
    var provideSearchData: Bool = false
    var shouldAddToCart: Bool = false
    var shouldUpdateCart: Bool = false
    var gotoCheckout: Bool = false
    var gotoChat: Bool = false
    var navigateToURL: Bool = false
    var queueIsOpen: Bool = false
    var queueIsClosed: Bool = false
    var agentsOnline: Bool = false
    var queueWaitingTime: Bool = false
    var trackingEvent: Bool = false
    /// Whether to install the emitter override to forward every
    /// non-explicit event to the host (`onEmbedEvent`).
    var catchAllOther: Bool = false

    init(from h: BambuserCallHandlers) {
        provideProductData = h.provideProductData != nil
        provideSearchData  = h.provideSearchData != nil
        shouldAddToCart    = h.shouldAddToCart != nil
        shouldUpdateCart   = h.shouldUpdateCart != nil
        gotoCheckout       = h.onGotoCheckout != nil
        gotoChat           = h.onGotoChat != nil
        navigateToURL      = h.onNavigateToURL != nil
        queueIsOpen        = h.onQueueOpen != nil
        queueIsClosed      = h.onQueueClosed != nil
        agentsOnline       = h.onAgentsOnline != nil
        queueWaitingTime   = h.onQueueWaitingTime != nil
        trackingEvent      = h.onTrackingEvent != nil
        catchAllOther      = h.onEmbedEvent != nil
    }
}
