//
//  BambuserCustomerEvents.swift
//  BambuserCallsShopperDemo
//
//  Reference tracking wrappers over the SDK's raw
//  `controller.notifyCustomerEvent(_:payload:)`. Living in the demo
//  target because these encode host-side conventions (e.g. what
//  `quantity` means on add vs remove) — the SDK stays generic.
//
//  See https://gitlab.bambuser.com/livecommerce/one-to-one/liveshopping-one-to-one/-/merge_requests/4697
//

import Foundation
import BambuserCallsShopper

/// The three published `CUSTOMER_EVENTS` keys as constants — bind
/// against these rather than hardcoding strings so a typo shows up as
/// a compile error. Extend with a new static if Bambuser ships a new
/// key without an SDK update.
public enum BambuserCustomerEventKey {
    public static let addedToCart      = "ADDED_TO_CART"
    public static let removedFromCart  = "REMOVED_FROM_CART"
    public static let productViewed    = "PRODUCT_VIEWED"
}

public extension BambuserCallController {

    /// Report a shopper-driven **add to cart**.
    ///
    /// - `quantity` is a **delta** — the amount just added, not the
    ///   new total.
    /// - Do NOT call from `shouldAddToCart` (that's agent-driven and
    ///   already known to the widget).
    func trackAddToCart(
        sku: String,
        quantity: Int,
        name: String? = nil,
        price: Double? = nil,
        currency: String? = nil
    ) {
        var payload: [String: BambuserJSONValue] = [
            "sku":      .string(sku),
            "quantity": .int(quantity),
        ]
        if let name     { payload["name"]     = .string(name) }
        if let price    { payload["price"]    = .double(price) }
        if let currency { payload["currency"] = .string(currency) }
        notifyCustomerEvent(BambuserCustomerEventKey.addedToCart, payload: .object(payload))
    }

    /// Report a shopper-driven cart removal.
    /// **`remainingQuantity` is the resulting total**, not the number
    /// removed. Pass `0` to clear the line. This is the *opposite* of
    /// the GA4 `remove_from_cart` convention.
    func trackRemoveFromCart(sku: String, remainingQuantity: Int) {
        notifyCustomerEvent(
            BambuserCustomerEventKey.removedFromCart,
            payload: .object([
                "sku":      .string(sku),
                "quantity": .int(remainingQuantity),
            ])
        )
    }

    /// Report a PDP view. Call from the destination screen's
    /// `.onAppear` / `.task` so it fires on every navigation.
    func trackProductView(sku: String) {
        notifyCustomerEvent(
            BambuserCustomerEventKey.productViewed,
            payload: .object(["sku": .string(sku)])
        )
    }
}
