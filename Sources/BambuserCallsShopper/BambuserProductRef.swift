//
//  BambuserProductRef.swift
//  BambuserCallsShopper
//

import Foundation

/// One product reference the agent added in their tool. Delivered to
/// the `provideProductData` handler; resolve `ref` to your product and
/// reply with a `BambuserFactorySpec`.
public struct BambuserProductRef: Equatable, Sendable {

    /// How the agent added the product. `.unknown(raw)` covers any
    /// future values Bambuser adds.
    public enum Kind: Equatable, Sendable {
        case url
        case scannedCode
        case productReference
        case unknown(String)

        public init(rawValue: String) {
            switch rawValue {
            case "url":               self = .url
            case "scanned-code":      self = .scannedCode
            case "product-reference": self = .productReference
            default:                  self = .unknown(rawValue)
            }
        }

        public var rawValue: String {
            switch self {
            case .url:              return "url"
            case .scannedCode:      return "scanned-code"
            case .productReference: return "product-reference"
            case .unknown(let s):   return s
            }
        }
    }

    /// Raw reference — SKU, URL, or barcode depending on `kind`.
    public let ref: String

    public let kind: Kind

    /// Embed-generated id. The SDK echoes it back on the reply
    /// automatically.
    public let bambuserId: String

    /// Full unmodified JSON entry — read any field the SDK doesn't
    /// surface as a typed property.
    public let raw: BambuserJSONValue

    public init(ref: String, kind: Kind, bambuserId: String, raw: BambuserJSONValue = .null) {
        self.ref = ref
        self.kind = kind
        self.bambuserId = bambuserId
        self.raw = raw
    }

    /// Decode a `provide-product-data` payload. Never filters —
    /// missing fields fall through as empty strings, unknown `type`
    /// values become `.unknown(rawValue)`.
    public static func decode(from payload: BambuserJSONValue) -> [BambuserProductRef] {
        guard
            case .object(let root) = payload,
            case .array(let items) = root["products"] ?? .null
        else { return [] }

        return items.map { item in
            guard case .object(let m) = item else {
                return BambuserProductRef(ref: "", kind: .unknown(""), bambuserId: "", raw: item)
            }
            let ref = string(m["ref"])
            let type = string(m["type"])
            let id = string(m["id"])
            return BambuserProductRef(
                ref: ref,
                kind: Kind(rawValue: type),
                bambuserId: id,
                raw: item
            )
        }
    }
}

private func string(_ v: BambuserJSONValue?) -> String {
    if case .string(let s) = v ?? .null { return s }
    return ""
}
