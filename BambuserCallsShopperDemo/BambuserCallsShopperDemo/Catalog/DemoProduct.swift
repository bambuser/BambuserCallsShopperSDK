//
//  DemoProduct.swift
//  BambuserCallsShopperDemo
//

import Foundation

/// Flat product model used across the demo. Each SKU in this app is a
/// single-variation product, so we don't need the colour/size/sku tree the
/// SDK can hydrate — `id` is the SKU at every level.
struct DemoProduct: Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let brand: String
    let category: String
    let price: Double
    let currency: String
    let inStock: Bool
    let description: String
    let imageURL: URL
    let additionalImages: [URL]
    /// Product-page URL on demo.bambuser.shop, when the product is
    /// actually live on the demo site. `nil` for products that were
    /// retired from the demo catalog (agent's carousel will just skip
    /// the link).
    let url: URL?
}
