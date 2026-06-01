//
//  BambuserProduct.swift
//  BambuserCallsShopperDemo
//
//  Reference product model, mirroring the JS payload the embed's
//  `updateProduct(bambuserId, factory => ...)` chain expects.
//
//  This file is NOT part of BambuserCallsShopper — it lives in the
//  demo target as a guideline for how a host might shape their reply
//  to the `provide-product-data` event. Copy it, adapt it, replace it
//  entirely — the SDK only knows about `BambuserFactorySpec`, not
//  about products.
//
//  See https://bambuser.com/docs/video-consultation/provide-product-data/
//

import Foundation
import BambuserCallsShopper

// MARK: - Top-level envelope

public struct BambuserProduct: Codable, Equatable, Sendable {
    public let currency: String
    public let locale: String
    public let product: BambuserProductDetail

    public init(currency: String, locale: String, product: BambuserProductDetail) {
        self.currency = currency
        self.locale = locale
        self.product = product
    }
}

// MARK: - Product detail

public struct BambuserProductDetail: Codable, Equatable, Sendable {
    public let name: String?
    public let sku: String?
    public let defaultVariationIndex: Int?
    public let description: String?
    public let url: String?
    public let attributes: [BambuserAttributeDefinition]
    public let variations: [BambuserVariation]

    public init(
        name: String? = nil,
        sku: String? = nil,
        defaultVariationIndex: Int? = 0,
        description: String? = nil,
        url: String? = nil,
        attributes: [BambuserAttributeDefinition] = [],
        variations: [BambuserVariation]
    ) {
        self.name = name
        self.sku = sku
        self.defaultVariationIndex = defaultVariationIndex
        self.description = description
        self.url = url
        self.attributes = attributes
        self.variations = variations
    }
}

// MARK: - Attributes

public struct BambuserAttributeDefinition: Codable, Equatable, Sendable {
    public let id: String
    public let name: String?
    public let options: [BambuserAttributeOption]

    public init(id: String, name: String? = nil, options: [BambuserAttributeOption]) {
        self.id = id
        self.name = name
        self.options = options
    }
}

public struct BambuserAttributeOption: Codable, Equatable, Sendable {
    public let id: String
    public let name: String?

    public init(id: String, name: String? = nil) {
        self.id = id
        self.name = name
    }
}

// MARK: - Variation

public struct BambuserVariation: Codable, Equatable, Sendable {
    public let name: String
    public let url: String?
    public let subtitle: String?
    public let sku: String
    public let inStock: Bool
    public let imageUrls: [String]
    public let price: BambuserPrice?
    public let attributes: [BambuserVariationAttribute]
    public let comparableAttributes: [BambuserComparableAttribute]
    public let relatedProducts: [BambuserRelatedProduct]
    public let details: [BambuserDetail]
    public let rating: BambuserRating?

    public init(
        name: String,
        url: String? = nil,
        subtitle: String? = nil,
        sku: String,
        inStock: Bool = true,
        imageUrls: [String],
        price: BambuserPrice? = nil,
        attributes: [BambuserVariationAttribute] = [],
        comparableAttributes: [BambuserComparableAttribute] = [],
        relatedProducts: [BambuserRelatedProduct] = [],
        details: [BambuserDetail] = [],
        rating: BambuserRating? = nil
    ) {
        self.name = name
        self.url = url
        self.subtitle = subtitle
        self.sku = sku
        self.inStock = inStock
        self.imageUrls = imageUrls
        self.price = price
        self.attributes = attributes
        self.comparableAttributes = comparableAttributes
        self.relatedProducts = relatedProducts
        self.details = details
        self.rating = rating
    }
}

public struct BambuserVariationAttribute: Codable, Equatable, Sendable {
    public let attributeId: String
    public let optionId: String

    public init(attributeId: String, optionId: String) {
        self.attributeId = attributeId
        self.optionId = optionId
    }
}

// MARK: - Price

public struct BambuserPrice: Codable, Equatable, Sendable {
    public let current: Double
    public let original: Double?

    public init(current: Double, original: Double? = nil) {
        self.current = current
        self.original = original
    }
}

// MARK: - Comparable / Related

public struct BambuserComparableAttribute: Codable, Equatable, Sendable {
    public let id: String
    public let name: String?
    public let value: String

    public init(id: String, name: String? = nil, value: String) {
        self.id = id
        self.name = name
        self.value = value
    }
}

public struct BambuserRelatedProduct: Codable, Equatable, Sendable {
    public let title: String
    public let sku: String
    public let imageUrl: String
    public let price: BambuserPrice

    public init(title: String, sku: String, imageUrl: String, price: BambuserPrice) {
        self.title = title
        self.sku = sku
        self.imageUrl = imageUrl
        self.price = price
    }
}

// MARK: - Details (USPs)

public struct BambuserDetail: Codable, Equatable, Sendable {

    public enum Kind: String, Codable, Equatable, Sendable {
        case bullets = "BULLETS"
        case paragraph = "PARAGRAPH"
    }

    public let kind: Kind
    public let bullets: [String]?
    public let paragraph: String?

    private init(kind: Kind, bullets: [String]?, paragraph: String?) {
        self.kind = kind
        self.bullets = bullets
        self.paragraph = paragraph
    }

    public static func bullets(_ items: [String]) -> BambuserDetail {
        .init(kind: .bullets, bullets: items, paragraph: nil)
    }

    public static func paragraph(_ text: String) -> BambuserDetail {
        .init(kind: .paragraph, bullets: nil, paragraph: text)
    }
}

// MARK: - Rating

public struct BambuserRating: Codable, Equatable, Sendable {
    public let maxValue: Int
    public let rating: Double
    public let numberOfRatings: Int?

    public init(maxValue: Int, rating: Double, numberOfRatings: Int? = nil) {
        self.maxValue = maxValue
        self.rating = rating
        self.numberOfRatings = numberOfRatings
    }
}
