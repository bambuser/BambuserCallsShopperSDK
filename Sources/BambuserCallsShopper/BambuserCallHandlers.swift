//
//  BambuserCallHandlers.swift
//  BambuserCallsShopper
//
//  Data-source handlers only — closures that return a value the SDK
//  hands back to the embed. Fire-and-forget events live on
//  `BambuserCallDelegate` instead.
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

// MARK: - Product / search data results

/// Result of a `provideProductData` handler.
///
/// - `.product(spec)` — the mapped product; SDK dispatches
///   `updateProduct(bambuserId, factory => applySpec(factory, spec))`.
/// - `.error(message:)` — surface a message to the agent. The SDK
///   dispatches `updateProduct(bambuserId, () => { throw new Error(message) })`,
///   which is the documented way to signal "we don't sell that". The
///   message text is shown verbatim to the agent.
/// - `.skip` — deliberately no reply. The agent tool spins for ~30s
///   then shows its own timeout state. **Prefer `.error(message:)`
///   in production** so the agent sees something actionable.
public enum BambuserProductDataResult: Sendable {
    case product(BambuserFactorySpec)
    case error(message: String)
    case skip
}

/// Result of a `provideSearchData` handler. Mirrors
/// `BambuserProductDataResult` — throwing inside the widget's
/// `searchResponse` callback is the documented way to signal
/// "invalid search" / "search backend error" to the agent.
public enum BambuserSearchDataResult: Sendable {
    case results(BambuserFactorySpec)
    case error(message: String)
    case skip
}

// MARK: - Handlers

/// Data-source contracts. Only fill in what you actually implement —
/// nil handlers translate to "no JS subscription installed", so the
/// widget won't waste time waiting for a reply you can't give.
///
/// Every non-nil handler returns a value the SDK dispatches to the
/// embed. For fire-and-forget notifications (checkout, queue events,
/// tracking, navigation, close, errors), use `BambuserCallDelegate`
/// on the controller.
///
/// All closures run on `@MainActor`.
public struct BambuserCallHandlers {

    /// The agent added a product in their tool. Return a
    /// `BambuserFactorySpec` describing the `updateProduct(...)` chain
    /// you want applied, or `nil` for "product not found".
    public var provideProductData: (@MainActor (BambuserProductRef) async -> BambuserFactorySpec?)?

    /// The agent is searching the catalog. Return a spec for the
    /// `searchResponse(...)` chain, or `nil` for empty results.
    public var provideSearchData: (@MainActor (BambuserSearchRequest) async -> BambuserFactorySpec?)?

    /// Agent adds an item to the cart. Return `.success`, `.failure`,
    /// or `.raw(...)`.
    public var shouldAddToCart: (@MainActor (BambuserCartIntent) async -> BambuserCartResult)?

    /// Agent updates a cart line (or removes with `quantity == 0`).
    public var shouldUpdateCart: (@MainActor (BambuserCartIntent) async -> BambuserCartResult)?

    public init() {}
}

// MARK: - Subscriptions snapshot (SDK-internal)

/// Which JS `.on(...)` subscriptions to install for a given session.
/// Data-source events gate on individual handlers; fire-and-forget
/// events (delegate-routed) are always installed. The catch-all
/// emitter override is gated on the config's
/// `forwardUnknownEmbedEvents`.
internal struct BambuserCallSubscriptions: Equatable {
    var provideProductData: Bool = false
    var provideSearchData: Bool = false
    var shouldAddToCart: Bool = false
    var shouldUpdateCart: Bool = false
    var catchAllOther: Bool = false

    init(handlers: BambuserCallHandlers, forwardUnknownEmbedEvents: Bool) {
        provideProductData = handlers.provideProductData != nil
        provideSearchData  = handlers.provideSearchData != nil
        shouldAddToCart    = handlers.shouldAddToCart != nil
        shouldUpdateCart   = handlers.shouldUpdateCart != nil
        catchAllOther      = forwardUnknownEmbedEvents
    }
}
