//
//  BambuserProduct+FactorySpec.swift
//  BambuserCallsShopperDemo
//
//  Converts the reference `BambuserProduct` model into a
//  `BambuserFactorySpec` the SDK's `provideProductData` handler can
//  return. Lives in the demo target — the SDK doesn't know about
//  products.
//

import Foundation
import BambuserCallsShopper

public extension BambuserProduct {

    /// Factory spec matching the JS chain in
    /// https://bambuser.com/docs/video-consultation/provide-product-data/
    /// Hand this to `controller.provideProductData(bambuserId:factorySpec:)`.
    var factorySpec: BambuserFactorySpec {
        BambuserFactorySpec([
            .method("currency", args: [.string(currency)]),
            .method("locale",   args: [.string(locale)]),
            .method("product",  factory: product.factorySpec),
        ])
    }
}

public extension BambuserProductDetail {
    var factorySpec: BambuserFactorySpec {
        var calls: [BambuserFactoryCall] = []
        if let name                  { calls.append(.method("name",                  args: [.string(name)])) }
        if let sku                   { calls.append(.method("sku",                   args: [.string(sku)])) }
        if let defaultVariationIndex { calls.append(.method("defaultVariationIndex", args: [.int(defaultVariationIndex)])) }
        if let description           { calls.append(.method("description",           args: [.string(description)])) }
        if let url                   { calls.append(.method("url",                   args: [.string(url)])) }

        if !attributes.isEmpty {
            calls.append(.method("attributes", items: attributes.map(\.factoryItem)))
        }
        calls.append(.method("variations", items: variations.map(\.factoryItem)))
        return BambuserFactorySpec(calls)
    }
}

extension BambuserAttributeDefinition {
    var factoryItem: BambuserFactoryItem {
        var calls: [BambuserFactoryCall] = []
        if let name { calls.append(.method("name", args: [.string(name)])) }
        calls.append(.method("options", items: options.map(\.factoryItem)))
        return BambuserFactoryItem(
            factoryArgs: [.string(id)],
            spec: BambuserFactorySpec(calls)
        )
    }
}

extension BambuserAttributeOption {
    var factoryItem: BambuserFactoryItem {
        var calls: [BambuserFactoryCall] = []
        if let name { calls.append(.method("name", args: [.string(name)])) }
        return BambuserFactoryItem(
            factoryArgs: [.string(id)],
            spec: BambuserFactorySpec(calls)
        )
    }
}

extension BambuserVariation {
    var factoryItem: BambuserFactoryItem {
        var calls: [BambuserFactoryCall] = [
            .method("name", args: [.string(name)]),
            .method("sku",  args: [.string(sku)]),
        ]
        if let url      { calls.append(.method("url",      args: [.string(url)])) }
        if let subtitle { calls.append(.method("subtitle", args: [.string(subtitle)])) }
        calls.append(.method("inStock", args: [.bool(inStock)]))
        calls.append(.method("imageUrls", args: [.array(imageUrls.map { .string($0) })]))

        if let price {
            calls.append(.method("price", factory: price.factorySpec))
        }

        if !attributes.isEmpty {
            calls.append(.method("attributes", items: attributes.map { attr in
                BambuserFactoryItem(
                    factoryArgs: [.string(attr.attributeId), .string(attr.optionId)],
                    spec: BambuserFactorySpec()
                )
            }))
        }

        if !comparableAttributes.isEmpty {
            calls.append(.method("comparableAttributes", items: comparableAttributes.map(\.factoryItem)))
        }

        if !relatedProducts.isEmpty {
            calls.append(.method("relatedProducts", items: relatedProducts.map(\.factoryItem)))
        }

        if !details.isEmpty {
            calls.append(.method("details", items: details.map(\.factoryItem)))
        }

        if let rating {
            calls.append(.method("rating", factory: rating.factorySpec))
        }

        return BambuserFactoryItem(factoryArgs: [], spec: BambuserFactorySpec(calls))
    }
}

extension BambuserPrice {
    var factorySpec: BambuserFactorySpec {
        var calls: [BambuserFactoryCall] = []
        if let original {
            calls.append(.method("original", args: [.double(original)]))
        }
        calls.append(.method("current", args: [.double(current)]))
        return BambuserFactorySpec(calls)
    }
}

extension BambuserComparableAttribute {
    var factoryItem: BambuserFactoryItem {
        var calls: [BambuserFactoryCall] = []
        if let name { calls.append(.method("name", args: [.string(name)])) }
        return BambuserFactoryItem(
            factoryArgs: [.string(id), .string(value)],
            spec: BambuserFactorySpec(calls)
        )
    }
}

extension BambuserRelatedProduct {
    var factoryItem: BambuserFactoryItem {
        let calls: [BambuserFactoryCall] = [
            .method("title",    args: [.string(title)]),
            .method("sku",      args: [.string(sku)]),
            .method("imageUrl", args: [.string(imageUrl)]),
            .method("price",    factory: price.factorySpec),
        ]
        return BambuserFactoryItem(factoryArgs: [], spec: BambuserFactorySpec(calls))
    }
}

extension BambuserDetail {
    var factoryItem: BambuserFactoryItem {
        switch kind {
        case .bullets:
            return BambuserFactoryItem(
                factoryArgs: [.string("BULLETS"), .array((bullets ?? []).map { .string($0) })],
                spec: BambuserFactorySpec()
            )
        case .paragraph:
            return BambuserFactoryItem(
                factoryArgs: [.string("PARAGRAPH"), .string(paragraph ?? "")],
                spec: BambuserFactorySpec()
            )
        }
    }
}

extension BambuserRating {
    var factorySpec: BambuserFactorySpec {
        var calls: [BambuserFactoryCall] = [
            .method("maxValue", args: [.int(maxValue)]),
            .method("rating",   args: [.double(rating)]),
        ]
        if let numberOfRatings {
            calls.append(.method("numberOfRatings", args: [.int(numberOfRatings)]))
        }
        return BambuserFactorySpec(calls)
    }
}
