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
}
