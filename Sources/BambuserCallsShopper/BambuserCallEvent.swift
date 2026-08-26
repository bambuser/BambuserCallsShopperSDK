//
//  BambuserCallEvent.swift
//  BambuserCallsShopper
//

import Foundation

/// Fire-and-forget events delivered via
/// `BambuserCallDelegate.bambuserCall(_:didEmit:)`. Events that need
/// a reply (product hydration, search, cart) live on
/// `BambuserCallHandlers` instead.
public enum BambuserCallEvent: Sendable {

    // MARK: - Lifecycle

    /// Widget was closed. Overlay has already been dismissed natively.
    case close

    /// Call moved between states. Also observable via `controller.callState`.
    case callStateChanged(CallState)

    /// Overlay flipped between full-screen and PiP.
    case presentationChanged(isPiP: Bool, presentation: PipPresentation)

    // MARK: - Widget actions

    /// Shopper tapped checkout. Widget also routes checkout through
    /// `.navigateTo`, so this event is mainly for analytics.
    case checkout(cart: BambuserJSONValue)

    /// Shopper picked "I prefer to chat" instead of the call.
    case chatRequested

    /// Agent asked to send the shopper to a URL. Route into your
    /// navigation stack.
    case navigateTo(url: URL)

    // MARK: - Queue

    case queueOpened(BambuserQueueOpenState)
    case queueClosed(BambuserQueueOpenState)
    case agentsOnlineChanged(BambuserAgentsOnline)
    case waitingTimeChanged(BambuserQueueWaitingTime)

    // MARK: - Analytics

    case trackingEvent(BambuserTrackingEvent)

    // MARK: - Firehose

    /// Any event the SDK doesn't model explicitly. Only fires when
    /// `BambuserCallConfiguration.forwardUnknownEmbedEvents == true`.
    case other(name: String, payload: BambuserJSONValue)
}
