//
//  BambuserTrackingTag.swift
//  BambuserCallsShopper
//

import Foundation

/// Analytics tag attached to a session. Max 20 per session; string
/// values capped at 1KB by the embed.
public struct BambuserTrackingTag: Equatable, Sendable {

    public let key: String
    public let value: BambuserJSONValue

    public init(key: String, value: BambuserJSONValue) {
        self.key = key
        self.value = value
    }

    public init(key: String, string value: String) {
        self.init(key: key, value: .string(value))
    }
    public init(key: String, number value: Double) {
        self.init(key: key, value: .double(value))
    }
    public init(key: String, bool value: Bool) {
        self.init(key: key, value: .bool(value))
    }

    public var jsonValue: BambuserJSONValue {
        .object(["key": .string(key), "value": value])
    }
}

internal extension Array where Element == BambuserTrackingTag {
    /// Deduplicate on key (last one wins) and encode as JSON array.
    func toJSONArray() -> BambuserJSONValue {
        var seen: [String: BambuserTrackingTag] = [:]
        var order: [String] = []
        for tag in self {
            if seen[tag.key] == nil { order.append(tag.key) }
            seen[tag.key] = tag
        }
        return .array(order.compactMap { seen[$0]?.jsonValue })
    }
}
