//
//  BambuserTrackingEvent.swift
//  BambuserCallsShopper
//

import Foundation

/// Payload of the `tracking-event` stream. Either the Bambuser-shaped
/// pair (`eventName` + `eventData`) or the GA4 pair (`ga4Event` +
/// `ga4Ecommerce`) is populated per event.
///
/// See https://bambuser.com/docs/video-consultation/tracking-events/
public struct BambuserTrackingEvent: Equatable, Sendable {

    public let eventName: String?
    public let eventData: BambuserJSONValue?
    public let ga4Event: String?
    public let ga4Ecommerce: BambuserJSONValue?

    /// Whichever payload was populated, as an untyped dictionary.
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
