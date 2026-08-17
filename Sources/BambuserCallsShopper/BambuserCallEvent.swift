//
//  BambuserCallEvent.swift
//  BambuserCallsShopper
//
//  Single event stream delivered via
//  `BambuserCallDelegate.bambuserCall(_:didEmit:)`. Fire-and-forget —
//  the SDK doesn't need a reply for any of these. Data-source events
//  (product hydration, search, cart) that DO need a reply live on
//  `BambuserCallHandlers` instead.
//

import Foundation

public enum BambuserCallEvent: Sendable {

    // MARK: - Lifecycle

    /// The widget was closed (by the user or by `destroy()`). The
    /// overlay has already been dismissed natively.
    case close

    /// Call moved between `.idle` / `.connecting` / `.connected` /
    /// `.ended`. Also observable via `controller.callState`.
    case callStateChanged(CallState)

    /// Overlay flipped between full-screen and PiP. `presentation`
    /// is meaningful only when `isPiP` is true.
    case presentationChanged(isPiP: Bool, presentation: PipPresentation)

    // MARK: - Widget actions

    /// Shopper tapped the checkout button. `cart` is the raw payload
    /// the embed sent (typically `{ items: [...] }`). If you also
    /// handle `.navigateTo`, note the widget routes checkout through
    /// that path (`surf-behind-to`) so this event is mainly useful
    /// for analytics or side effects.
    case checkout(cart: BambuserJSONValue)

    /// Shopper picked "I prefer to chat" instead of the call. The
    /// widget has already closed by the time this fires.
    case chatRequested

    /// Agent asked to send the shopper to a URL. The single point
    /// every agent-driven navigation passes through in MANUAL
    /// floatingPlayer mode (checkout too). Route into your SwiftUI
    /// navigation stack.
    case navigateTo(url: URL)

    // MARK: - Queue

    case queueOpened(BambuserQueueOpenState)
    case queueClosed(BambuserQueueOpenState)
    case agentsOnlineChanged(BambuserAgentsOnline)
    case waitingTimeChanged(BambuserQueueWaitingTime)

    // MARK: - Analytics

    case trackingEvent(BambuserTrackingEvent)

    // MARK: - Firehose (forward-compat)

    /// Any event the SDK doesn't model explicitly. Only fires when
    /// `BambuserCallConfiguration.forwardUnknownEmbedEvents == true`
    /// (default `false`) — installing the emitter override is a
    /// firehose you opt into.
    case other(name: String, payload: BambuserJSONValue)
}
