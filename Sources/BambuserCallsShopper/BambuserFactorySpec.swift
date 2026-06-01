//
//  BambuserFactorySpec.swift
//  BambuserCallsShopper
//
//  Data description of a Bambuser embed builder chain, so hosts can drive
//  any `oneToOneEmbed.someMethod(..., factory => ...)` flow — present or
//  future — without SDK changes.
//
//  Every method call in a Bambuser factory chain is one of three shapes:
//
//   • A leaf call with plain arguments:
//       .currency("USD")
//   • A call whose last argument is a builder callback:
//       .product(df => df.name(...).sku(...))
//   • A call whose last argument is an "items callback" — the embed
//     hands you a factory, you invoke it once per item and chain from
//     the result:
//       .variations(vf => arr.map(v => vf().name(v.name)))
//       .attributes(a  => arr.map(x => a(x.id).name(...)))
//
//  `BambuserFactorySpec` captures the three uniformly. The JS reducer
//  `window.__bambuserApplyFactorySpec` applies a spec to any factory
//  handed out by the embed.
//
//  Example — reply to a `provide-search-data` request without touching
//  the SDK:
//
//      let spec = BambuserFactorySpec([
//          .method("products", items: results.map { r in
//              BambuserFactoryItem(spec: BambuserFactorySpec([
//                  .method("name",     args: [.string(r.name)]),
//                  .method("imageUrl", args: [.string(r.image)]),
//                  .method("sku",      args: [.string(r.sku)]),
//                  .method("price", factory: BambuserFactorySpec([
//                      .method("current", args: [.double(r.price)]),
//                  ])),
//              ]))
//          }),
//          .method("currency", args: [.string("USD")]),
//          .method("locale",   args: [.string("en-US")]),
//      ])
//      controller.replyToCallback(callbackKey: req.callbackKey, factorySpec: spec)
//

import Foundation

// MARK: - Spec

public struct BambuserFactorySpec: Codable, Equatable, Sendable {

    /// Ordered list of builder method calls. Empty is legal — the reducer
    /// returns the factory unchanged, which is useful when an item factory
    /// is called with args (`attribute(id, optionId)`) and needs no
    /// further chaining.
    public let calls: [BambuserFactoryCall]

    public init(_ calls: [BambuserFactoryCall] = []) {
        self.calls = calls
    }
}

// MARK: - Call

public struct BambuserFactoryCall: Codable, Equatable, Sendable {

    /// Name of the builder method to invoke on the current factory.
    public let method: String

    /// Plain args passed before any callback. Empty when the method only
    /// takes a builder.
    public let args: [BambuserJSONValue]

    /// When present, the last argument to `method` is a builder callback:
    /// `method(...args, f => applySpec(f, factory))`.
    public let factory: BambuserFactorySpec?

    /// When present, the last argument to `method` is an "items callback":
    /// `method(...args, itemFactory => items.map(item => applySpec(itemFactory(...item.factoryArgs), item.spec)))`.
    public let items: [BambuserFactoryItem]?

    public init(
        method: String,
        args: [BambuserJSONValue] = [],
        factory: BambuserFactorySpec? = nil,
        items: [BambuserFactoryItem]? = nil
    ) {
        self.method = method
        self.args = args
        self.factory = factory
        self.items = items
    }

    // MARK: Convenience constructors

    /// Leaf call — `factory.method(args...)`.
    public static func method(
        _ name: String,
        args: [BambuserJSONValue] = []
    ) -> Self {
        .init(method: name, args: args)
    }

    /// Nested builder — `factory.method(args..., f => applySpec(f, factory))`.
    public static func method(
        _ name: String,
        args: [BambuserJSONValue] = [],
        factory: BambuserFactorySpec
    ) -> Self {
        .init(method: name, args: args, factory: factory)
    }

    /// Items builder — `factory.method(args..., itemFactory => items.map(...))`.
    public static func method(
        _ name: String,
        args: [BambuserJSONValue] = [],
        items: [BambuserFactoryItem]
    ) -> Self {
        .init(method: name, args: args, items: items)
    }
}

// MARK: - Item

public struct BambuserFactoryItem: Codable, Equatable, Sendable {

    /// Args to invoke the item factory with. Empty means `itemFactory()`
    /// (e.g. `variations()`); non-empty means the factory is called with
    /// values (e.g. `attribute(attributeId, optionId)`).
    public let factoryArgs: [BambuserJSONValue]

    /// Chain applied to the value returned by `itemFactory(...factoryArgs)`.
    /// Empty when the factory call itself is the entire item (e.g.
    /// `attribute(id, optionId)` with no further chaining).
    public let spec: BambuserFactorySpec

    public init(
        factoryArgs: [BambuserJSONValue] = [],
        spec: BambuserFactorySpec = .init()
    ) {
        self.factoryArgs = factoryArgs
        self.spec = spec
    }
}

// MARK: - JSON value

/// Type-safe JSON tree used for factory-call arguments. Serializes to
/// natural JSON — no discriminators, no wrappers.
public indirect enum BambuserJSONValue: Sendable, Equatable {
    case null
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case array([BambuserJSONValue])
    case object([String: BambuserJSONValue])
}

extension BambuserJSONValue: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let b = try? container.decode(Bool.self) {
            self = .bool(b)
        } else if let i = try? container.decode(Int.self) {
            self = .int(i)
        } else if let d = try? container.decode(Double.self) {
            self = .double(d)
        } else if let s = try? container.decode(String.self) {
            self = .string(s)
        } else if let a = try? container.decode([BambuserJSONValue].self) {
            self = .array(a)
        } else if let o = try? container.decode([String: BambuserJSONValue].self) {
            self = .object(o)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported JSON value"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:            try container.encodeNil()
        case .bool(let b):     try container.encode(b)
        case .int(let i):      try container.encode(i)
        case .double(let d):   try container.encode(d)
        case .string(let s):   try container.encode(s)
        case .array(let a):    try container.encode(a)
        case .object(let o):   try container.encode(o)
        }
    }
}

// MARK: - Literal ergonomics

extension BambuserJSONValue: ExpressibleByStringLiteral {
    public init(stringLiteral value: String) { self = .string(value) }
}
extension BambuserJSONValue: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int) { self = .int(value) }
}
extension BambuserJSONValue: ExpressibleByFloatLiteral {
    public init(floatLiteral value: Double) { self = .double(value) }
}
extension BambuserJSONValue: ExpressibleByBooleanLiteral {
    public init(booleanLiteral value: Bool) { self = .bool(value) }
}
extension BambuserJSONValue: ExpressibleByNilLiteral {
    public init(nilLiteral: ()) { self = .null }
}
extension BambuserJSONValue: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: BambuserJSONValue...) { self = .array(elements) }
}
extension BambuserJSONValue: ExpressibleByDictionaryLiteral {
    public init(dictionaryLiteral elements: (String, BambuserJSONValue)...) {
        self = .object(Dictionary(uniqueKeysWithValues: elements))
    }
}

// MARK: - Optional-friendly helpers

public extension BambuserJSONValue {
    /// `.string(s)` when `s` is non-nil, else `.null`.
    static func string(_ s: String?) -> BambuserJSONValue { s.map { .string($0) } ?? .null }
    /// `.int(i)` when `i` is non-nil, else `.null`.
    static func int(_ i: Int?) -> BambuserJSONValue { i.map { .int($0) } ?? .null }
    /// `.double(d)` when `d` is non-nil, else `.null`.
    static func double(_ d: Double?) -> BambuserJSONValue { d.map { .double($0) } ?? .null }
    /// `.bool(b)` when `b` is non-nil, else `.null`.
    static func bool(_ b: Bool?) -> BambuserJSONValue { b.map { .bool($0) } ?? .null }
}
