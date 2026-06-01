//
//  BambuserSearchRequest.swift
//  BambuserCallsShopper
//
//  Payload type for the `provide-search-data` event. The SDK owns
//  this type because it names the `callbackKey` you must echo back on
//  the reply — the response shape is yours to model and hand to the
//  SDK as a `BambuserFactorySpec`.
//

import Foundation

public struct BambuserSearchRequest: Equatable, Sendable {

    /// Free-text term the agent typed.
    public let term: String

    /// 1-indexed page of results the agent is asking for.
    public let page: Int

    /// Opaque callback id. Pass this back verbatim on the reply.
    public let callbackKey: String

    /// The full unmodified JSON payload from the embed. Access any
    /// field the SDK doesn't surface as a typed property here —
    /// including new fields Bambuser adds later.
    public let raw: BambuserJSONValue

    public init(term: String, page: Int, callbackKey: String, raw: BambuserJSONValue = .null) {
        self.term = term
        self.page = page
        self.callbackKey = callbackKey
        self.raw = raw
    }

    /// Decode a `provide-search-data` payload. Returns `nil` only when
    /// there is no `callbackId` — without it the SDK can't reply.
    /// Missing `term` becomes `""`; missing / non-numeric `page`
    /// becomes `1`.
    public static func decode(from payload: BambuserJSONValue) -> BambuserSearchRequest? {
        guard
            case .object(let m) = payload,
            case .string(let callbackId) = m["callbackId"] ?? .null,
            !callbackId.isEmpty
        else { return nil }

        var term = ""
        if case .string(let s) = m["term"] ?? .null { term = s }

        var page = 1
        switch m["page"] ?? .null {
        case .int(let i):     page = i
        case .double(let d):  page = Int(d)
        case .string(let s):  page = Int(s) ?? 1
        default:              page = 1
        }

        return BambuserSearchRequest(
            term: term,
            page: page,
            callbackKey: callbackId,
            raw: payload
        )
    }
}
