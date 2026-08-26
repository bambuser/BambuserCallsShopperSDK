//
//  DemoProduct+Bambuser.swift
//  BambuserCallsShopperDemo
//
//  Maps the demo's flat `DemoProduct` into the demo's reference
//  `BambuserProduct` model (see Bambuser/BambuserProduct.swift). That
//  model then converts to a `BambuserFactorySpec` which is what the
//  SDK's `provideProductData` handler actually returns.
//
//  Each demo SKU is a single-variation product; a real e-com
//  integration would generate multiple variations keyed off
//  colour/size/etc. attributes.
//

import Foundation
import BambuserCallsShopper

extension DemoProduct {

    /// Build a `BambuserProduct` payload for this SKU. The result is what
    /// the host hands back on `.provideProductData` so the agent tool can
    /// render the full product card.
    ///
    /// - Parameter productPageURL: Optional override. When nil, the
    ///   demo product's own `url` is used (if set).
    func toBambuserProduct(
        productPageURL: URL? = nil
    ) -> BambuserProduct {
        let images = ([imageURL] + additionalImages).map(\.absoluteString)
        let effectiveURL = (productPageURL ?? url)?.absoluteString

        let variation = BambuserVariation(
            name: name,
            url: effectiveURL,
            subtitle: brand,
            sku: id,
            inStock: inStock,
            imageUrls: images,
            price: BambuserPrice(current: price),
            attributes: [],
            comparableAttributes: [
                BambuserComparableAttribute(id: "category", name: "Category", value: category),
                BambuserComparableAttribute(id: "brand",    name: "Brand",    value: brand),
            ],
            relatedProducts: [],
            details: description.isEmpty ? [] : [.paragraph(description)],
            rating: nil
        )

        return BambuserProduct(
            currency: currency,
            locale: "en-US",
            product: BambuserProductDetail(
                name: name,
                sku: id,
                defaultVariationIndex: 0,
                description: description,
                url: effectiveURL,
                attributes: [],
                variations: [variation]
            )
        )
    }
}
