//
//  BambuserSearchRequest.swift
//  BambuserCallsShopper
//

import Foundation

/// Payload for the `provideSearchData` handler. The SDK owns the
/// `callbackKey` you must echo back — the response shape is yours to
/// model and return as a `BambuserFactorySpec`.
public struct BambuserSearchRequest: Equatable, Sendable {

    /// Free-text term the agent typed.
    public let term: String

    /// 1-indexed page of results the agent is asking for.
    public let page: Int

    /// Opaque callback id. Passed back verbatim on the reply by the SDK.
    public let callbackKey: String

    /// Full unmodified JSON payload — read any field the SDK doesn't
    /// surface as a typed property.
    public let raw: BambuserJSONValue

    public init(term: String, page: Int, callbackKey: String, raw: BambuserJSONValue = .null) {
        self.term = term
        self.page = page
        self.callbackKey = callbackKey
        self.raw = raw
    }

    /// Returns `nil` when there is no `callbackId`. Missing `term`
    /// becomes `""`; missing / non-numeric `page` becomes `1`.
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
