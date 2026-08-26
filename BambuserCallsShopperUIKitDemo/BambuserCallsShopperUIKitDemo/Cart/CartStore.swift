//
//  CartStore.swift
//  BambuserCallsShopperDemo
//

import Foundation

/// Observable cart shared across the app. Tracks `[sku: quantity]`. Both the
/// manual "Add to cart" button and the Bambuser cart events mutate this.
@MainActor
final class CartStore: ObservableObject {

    @Published private(set) var lines: [String: Int] = [:]

    func quantity(for sku: String) -> Int {
        lines[sku] ?? 0
    }

    func add(sku: String, quantity: Int = 1) {
        guard quantity > 0 else { return }
        lines[sku, default: 0] += quantity
    }

    /// Replace the line's quantity. `0` removes it entirely.
    func setQuantity(_ quantity: Int, for sku: String) {
        if quantity <= 0 {
            lines.removeValue(forKey: sku)
        } else {
            lines[sku] = quantity
        }
    }

    func remove(sku: String) {
        lines.removeValue(forKey: sku)
    }

    func clear() {
        lines.removeAll()
    }

    var totalItems: Int {
        lines.values.reduce(0, +)
    }

    /// Convenience for rendering the cart. Returns concrete `DemoProduct`s
    /// alongside their quantities, in catalog order so the cart sorts
    /// deterministically.
    var orderedLines: [(product: DemoProduct, quantity: Int)] {
        ProductCatalog.all.compactMap { product in
            guard let qty = lines[product.id], qty > 0 else { return nil }
            return (product, qty)
        }
    }

    var subtotal: Double {
        orderedLines.reduce(0) { $0 + $1.product.price * Double($1.quantity) }
    }

    /// Currency for the subtotal. The demo only sells USD products, so we
    /// just take the first line's currency (or fall back to USD when empty).
    var currency: String {
        orderedLines.first?.product.currency ?? "USD"
    }
}
