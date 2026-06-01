//
//  BambuserProductRef.swift
//  BambuserCallsShopper
//
//  Payload type for the `provide-product-data` event. The SDK owns
//  this type because it names the `bambuserId` you must echo back on
//  the reply — the rest of the product shape (what you send back) is
//  yours to model however you like and hand to the SDK as a
//  `BambuserFactorySpec`.
//

import Foundation

/// One product reference the agent added in the tool. Delivered as an
/// array on the `provideProductData` handler; resolve each `ref` to
/// your own product type and reply via
/// `controller.provideProductData(bambuserId:factorySpec:)`.
public struct BambuserProductRef: Equatable, Sendable {

    /// How the agent added the product. `.unknown(raw)` covers any
    /// future values Bambuser adds — the SDK never drops entries.
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

    /// Raw reference — a SKU, a URL, or a barcode depending on `kind`.
    public let ref: String

    /// How the reference was captured on the agent side.
    public let kind: Kind

    /// The embed-generated id you MUST pass back to
    /// `provideProductData(bambuserId:factorySpec:)` so the widget can
    /// associate the response with the pending request.
    public let bambuserId: String

    /// The full unmodified JSON entry the embed sent for this ref.
    /// Read this to access any field the SDK doesn't surface as a
    /// typed property — including new fields Bambuser adds later.
    /// The SDK never drops fields; anything the web sends is here.
    public let raw: BambuserJSONValue

    public init(ref: String, kind: Kind, bambuserId: String, raw: BambuserJSONValue = .null) {
        self.ref = ref
        self.kind = kind
        self.bambuserId = bambuserId
        self.raw = raw
    }

    /// Decode a `provide-product-data` payload into a list of refs.
    /// Never filters — every entry the web sent is preserved, missing
    /// fields fall through as empty strings, unknown `type` values are
    /// carried as `.unknown(rawValue)`.
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

// MARK: - Helpers

private func string(_ v: BambuserJSONValue?) -> String {
    if case .string(let s) = v ?? .null { return s }
    return ""
}
