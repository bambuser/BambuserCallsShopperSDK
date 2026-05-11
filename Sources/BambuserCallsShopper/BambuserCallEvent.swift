//
//  BambuserCallEvent.swift
//  BambuserCallsShopper
//

import Foundation

/// Single stream of events emitted by `BambuserCallController` via
/// `BambuserCallDelegate.bambuserCall(_:didEmit:)`. Cases carrying a
/// `callbackKey` expect the host to call
/// `controller.notify(callbackKey: …, info: …)` to resolve the JS-side
/// promise; the rest are fire-and-forget.
public enum BambuserCallEvent {

    /// Embed product click. `externalId` is already unwrapped from its
    /// three possible shapes (string, `{id, feedId}` dict, URL slug).
    case navigateTo(externalId: String)

    /// Embed close event. The overlay has already been dismissed by the
    /// time this is delivered — purely for observation.
    case close

    /// Embed `goto-checkout` event. `cart` is whatever payload the embed
    /// sent (typically a `{ items: [...] }` shape).
    case checkout(cart: [String: Any]?)

    case callStateChanged(CallState)

    /// PiP / full-screen flip. `presentation` is meaningful only when
    /// `isPiP` is true.
    case presentationChanged(isPiP: Bool, presentation: PipPresentation)

    /// Resolve via `controller.notify(callbackKey: callbackKey, info: …)`
    /// — pass `"true"` on success or e.g.
    /// `"{ success: false, reason: 'out-of-stock' }"` on failure.
    case shouldAddToCart(sku: String, quantity: Int, callbackKey: String)

    /// Same callback contract as `shouldAddToCart`.
    case shouldUpdateCart(sku: String, quantity: Int, callbackKey: String)

    /// Any event the framework doesn't model explicitly — a forward-compat
    /// hook and an analytics piggyback point.
    case other(name: String, payload: Any?)
}
