//
//  BambuserCustomerData.swift
//  BambuserCallsShopperDemo
//
//  Reference model for the customer info you present to the agent.
//  Guideline only — the SDK's `initialCustomerData` /
//  `updateData(_:)` take a raw `BambuserJSONValue`, so you can shape
//  the payload however your app models a customer.
//
//  See https://bambuser.com/docs/video-consultation/present-customer-data-to-agent/
//

import Foundation
import BambuserCallsShopper

/// Built-in fields the agent tool renders automatically:
///  - externalId, firstName, lastName, email, phone
///
/// Any other `custom` entries are shown to the agent as extra rows.
/// Nested structures are not supported.
public struct BambuserCustomerData: Equatable, Sendable {

    public var externalId: String?
    public var firstName: String?
    public var lastName: String?
    public var email: String?
    public var phone: String?
    public var custom: [String: BambuserJSONValue]

    public init(
        externalId: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        custom: [String: BambuserJSONValue] = [:]
    ) {
        self.externalId = externalId
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.phone = phone
        self.custom = custom
    }

    public var isEmpty: Bool {
        externalId == nil && firstName == nil && lastName == nil
            && email == nil && phone == nil && custom.isEmpty
    }

    /// The `BambuserJSONValue` object literal to hand to the SDK.
    public var jsonValue: BambuserJSONValue {
        var out: [String: BambuserJSONValue] = [:]
        if let externalId { out["externalId"] = .string(externalId) }
        if let firstName  { out["firstName"]  = .string(firstName) }
        if let lastName   { out["lastName"]   = .string(lastName) }
        if let email      { out["email"]      = .string(email) }
        if let phone      { out["phone"]      = .string(phone) }
        for (k, v) in custom { out[k] = v }
        return .object(out)
    }
}
