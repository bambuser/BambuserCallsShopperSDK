//
//  BambuserCallHandlers.swift
//  BambuserCallsShopper
//

import Foundation

// MARK: - Cart intent

/// Intent sent by the agent from their tool.
public struct BambuserCartIntent: Equatable, Sendable {
    public let sku: String
    public let quantity: Int
    /// Meaningful only on cart updates. `nil` for adds.
    public let previousQuantity: Int?
    /// Full unmodified JSON payload.
    public let raw: BambuserJSONValue

    public init(sku: String, quantity: Int, previousQuantity: Int?, raw: BambuserJSONValue) {
        self.sku = sku
        self.quantity = quantity
        self.previousQuantity = previousQuantity
        self.raw = raw
    }
}

// MARK: - Handler reply

/// Reply for every data-source handler.
///
/// - `.reply(payload)` — send the payload.
/// - `.error(message:)` — show `message` to the agent (the widget's
///   "verify function" throw-inside-callback pattern).
/// - `.skip` — send no reply; the widget times out (~30s). Prefer
///   `.error` in production.
public enum BambuserReply<Payload: Sendable>: Sendable {
    case reply(Payload)
    case error(message: String)
    case skip
}

// MARK: - Cart shorthand

public extension BambuserReply where Payload == BambuserJSONValue {

    /// Cart success.
    static var success: BambuserReply<BambuserJSONValue> {
        .reply(.bool(true))
    }

    /// Cart failure with an optional reason surfaced on the agent's row.
    static func failure(reason: String? = nil) -> BambuserReply<BambuserJSONValue> {
        guard let reason else { return .reply(.bool(false)) }
        return .reply(.object([
            "success": .bool(false),
            "reason":  .string(reason),
        ]))
    }
}

// MARK: - Handlers

/// Data-source contracts. Nil handlers translate to "no JS
/// subscription installed" so the widget doesn't wait for a reply
/// you can't give. Fire-and-forget events live on
/// `BambuserCallDelegate`.
public struct BambuserCallHandlers {

    /// The agent added a product. Return `.reply(spec)`, `.error(message:)`,
    /// or `.skip`.
    public var provideProductData: (@MainActor (BambuserProductRef) async -> BambuserReply<BambuserFactorySpec>)?

    /// The agent is searching the catalog. Same reply shape.
    public var provideSearchData: (@MainActor (BambuserSearchRequest) async -> BambuserReply<BambuserFactorySpec>)?

    /// Agent adds an item to the cart. Return `.success`, `.failure`,
    /// `.reply(customJSON)`, `.error(message:)`, or `.skip`.
    public var shouldAddToCart: (@MainActor (BambuserCartIntent) async -> BambuserReply<BambuserJSONValue>)?

    /// Agent updates a cart line (0 removes). Same reply shape.
    public var shouldUpdateCart: (@MainActor (BambuserCartIntent) async -> BambuserReply<BambuserJSONValue>)?

    public init() {}
}

// MARK: - Subscriptions snapshot (SDK-internal)

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
