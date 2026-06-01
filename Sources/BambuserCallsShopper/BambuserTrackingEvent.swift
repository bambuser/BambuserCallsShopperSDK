//
//  BambuserTrackingEvent.swift
//  BambuserCallsShopper
//
//  Payload of the `tracking-event` stream. The embed emits two shapes:
//
//   • Bambuser call/product/cart events:  { eventName, eventData }
//   • GA4 ecommerce events:               { event, ecommerce }
//
//  We keep both accessible under a single case so hosts can route
//  either into their own analytics stack.
//
//  See https://bambuser.com/docs/video-consultation/tracking-events/
//

import Foundation

public struct BambuserTrackingEvent: Equatable, Sendable {

    /// Bambuser-shaped event name (e.g. `"call_started"`, `"joined_queue"`).
    /// `nil` for GA4-shaped events.
    public let eventName: String?

    /// Bambuser-shaped event payload.
    public let eventData: BambuserJSONValue?

    /// GA4-shaped event name (e.g. `"add_to_cart"`, `"purchase"`).
    /// `nil` for Bambuser-shaped events.
    public let ga4Event: String?

    /// GA4 ecommerce payload.
    public let ga4Ecommerce: BambuserJSONValue?

    /// Whichever payload was populated, as an untyped dictionary. Handy
    /// when you just want to forward everything.
    public let raw: BambuserJSONValue

    public init(
        eventName: String?,
        eventData: BambuserJSONValue?,
        ga4Event: String?,
        ga4Ecommerce: BambuserJSONValue?,
        raw: BambuserJSONValue
    ) {
        self.eventName = eventName
        self.eventData = eventData
        self.ga4Event = ga4Event
        self.ga4Ecommerce = ga4Ecommerce
        self.raw = raw
    }
}
