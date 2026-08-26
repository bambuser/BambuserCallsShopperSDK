//
//  BambuserFactorySpec.swift
//  BambuserCallsShopper
//

import Foundation

/// Description of a Bambuser embed builder chain. Every method call
/// is a leaf (plain args), a nested builder (last arg is a callback),
/// or an "items callback" (last arg is a factory called once per item).
/// The JS reducer applies a spec to any factory handed out by the embed.
public struct BambuserFactorySpec: Codable, Equatable, Sendable {

    /// Ordered list of builder method calls. Empty is legal — the
    /// reducer returns the factory unchanged.
    public let calls: [BambuserFactoryCall]

    public init(_ calls: [BambuserFactoryCall] = []) {
        self.calls = calls
    }
}

// MARK: - Call

public struct BambuserFactoryCall: Codable, Equatable, Sendable {

    /// Builder method to invoke on the current factory.
    public let method: String

    /// Plain args passed before any callback.
    public let args: [BambuserJSONValue]

    /// If set, the last argument to `method` is a builder callback.
    public let factory: BambuserFactorySpec?

    /// If set, the last argument to `method` is an "items callback".
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

    /// Args to invoke the item factory with. Empty means `itemFactory()`;
    /// non-empty means `factory(...factoryArgs)` (e.g. `attribute(id, optionId)`).
    public let factoryArgs: [BambuserJSONValue]

    /// Chain applied to the value returned by the item factory.
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
    static func string(_ s: String?) -> BambuserJSONValue { s.map { .string($0) } ?? .null }
    static func int(_ i: Int?)     -> BambuserJSONValue { i.map { .int($0) }     ?? .null }
    static func double(_ d: Double?) -> BambuserJSONValue { d.map { .double($0) } ?? .null }
    static func bool(_ b: Bool?)   -> BambuserJSONValue { b.map { .bool($0) }   ?? .null }
}
