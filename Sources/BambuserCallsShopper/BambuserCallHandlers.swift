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

// MARK: - Unified handler reply

/// One reply type for every data-source handler. The `Payload` is
/// specialised per handler:
///
///  - `provideProductData` / `provideSearchData` → `BambuserReply<BambuserFactorySpec>`
///    (payload is a chained-builder description; SDK invokes the
///    widget's factory callback with a builder derived from the spec)
///
///  - `shouldAddToCart` / `shouldUpdateCart` → `BambuserReply<BambuserJSONValue>`
///    (payload is a raw JSON value the widget's callback accepts;
///    the SDK passes it verbatim to `window[callback](value)`)
///
/// The three cases:
///
///  - `.reply(payload)` — send the payload; shape depends on the
///    specialisation above.
///  - `.error(message:)` — show `message` to the agent. For factory
///    handlers, dispatched as `callback(() => { throw new Error(message) })`
///    (the documented "we don't sell that" / "verify function"
///    pattern). For cart handlers, dispatched as
///    `callback({success: false, reason: message})`.
///  - `.skip` — send no reply. Widget times out after ~30s. Prefer
///    `.error(message:)` in production so the agent sees something
///    actionable.
public enum BambuserReply<Payload: Sendable>: Sendable {
    case reply(Payload)
    case error(message: String)
    case skip
}

// MARK: - Cart shorthand

public extension BambuserReply where Payload == BambuserJSONValue {

    /// Cart success — equivalent to `.reply(.bool(true))`.
    static var success: BambuserReply<BambuserJSONValue> {
        .reply(.bool(true))
    }

    /// Cart failure with an optional reason.
    /// - `nil` reason → `.reply(.bool(false))` (`callback(false)`).
    /// - non-nil reason → `.reply(.object([success:false, reason:...]))`,
    ///   which the widget surfaces on the product row.
    static func failure(reason: String? = nil) -> BambuserReply<BambuserJSONValue> {
        guard let reason else { return .reply(.bool(false)) }
        return .reply(.object([
            "success": .bool(false),
            "reason":  .string(reason),
        ]))
    }
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

    /// The agent added a product in their tool. Return:
    ///  - `.reply(spec)` with a `BambuserFactorySpec` for the product,
    ///  - `.error(message:)` to signal "we don't sell that" (widget
    ///    calls `updateProduct` with a callback that throws),
    ///  - `.skip` to send no reply (agent tool times out; prefer
    ///    `.error` in production).
    public var provideProductData: (@MainActor (BambuserProductRef) async -> BambuserReply<BambuserFactorySpec>)?

    /// The agent is searching the catalog. Return:
    ///  - `.reply(spec)` with a `BambuserFactorySpec` for the results,
    ///  - `.error(message:)` for a validation / backend error (the
    ///    "verify function" pattern from the JS docs,
    ///    `if (!validSearch(...)) throw ...`),
    ///  - `.skip` to send no reply.
    public var provideSearchData: (@MainActor (BambuserSearchRequest) async -> BambuserReply<BambuserFactorySpec>)?

    /// Agent adds an item to the cart. Return `.success`, `.failure`,
    /// `.reply(customJSON)`, `.error(message:)`, or `.skip`.
    public var shouldAddToCart: (@MainActor (BambuserCartIntent) async -> BambuserReply<BambuserJSONValue>)?

    /// Agent updates a cart line (or removes with `quantity == 0`).
    /// Same reply shape as `shouldAddToCart`.
    public var shouldUpdateCart: (@MainActor (BambuserCartIntent) async -> BambuserReply<BambuserJSONValue>)?

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
