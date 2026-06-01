//
//  BambuserSearchResponse.swift
//  BambuserCallsShopperDemo
//
//  Reference search-response model + factory-spec conversion.
//  Guideline only — the SDK deals in `BambuserFactorySpec`, not this
//  type.
//
//  See https://bambuser.com/docs/video-consultation/providing-search-data/
//

import Foundation
import BambuserCallsShopper

public struct BambuserSearchResponse: Codable, Equatable, Sendable {

    public let products: [BambuserSearchProduct]
    public let currency: String
    public let locale: String
    public let pagination: BambuserSearchPagination?

    public init(
        products: [BambuserSearchProduct],
        currency: String,
        locale: String,
        pagination: BambuserSearchPagination? = nil
    ) {
        self.products = products
        self.currency = currency
        self.locale = locale
        self.pagination = pagination
    }
}

public struct BambuserSearchProduct: Codable, Equatable, Sendable {
    public let name: String
    public let imageUrl: String
    public let sku: String
    public let price: BambuserPrice

    public init(name: String, imageUrl: String, sku: String, price: BambuserPrice) {
        self.name = name
        self.imageUrl = imageUrl
        self.sku = sku
        self.price = price
    }
}

public struct BambuserSearchPagination: Codable, Equatable, Sendable {
    public let totalPages: Int
    public let totalMatches: Int
    public let currentPageIndex: Int

    public init(totalPages: Int, totalMatches: Int, currentPageIndex: Int) {
        self.totalPages = totalPages
        self.totalMatches = totalMatches
        self.currentPageIndex = currentPageIndex
    }
}

// MARK: - Factory spec conversion

public extension BambuserSearchResponse {

    /// Factory spec matching the JS chain in
    /// https://bambuser.com/docs/video-consultation/providing-search-data/
    /// Hand this to `controller.provideSearchData(callbackKey:factorySpec:)`.
    var factorySpec: BambuserFactorySpec {
        var calls: [BambuserFactoryCall] = [
            .method("products", items: products.map(\.factoryItem)),
            .method("currency", args: [.string(currency)]),
            .method("locale",   args: [.string(locale)]),
        ]

        if let pagination {
            calls.append(.method("pagination", factory: BambuserFactorySpec([
                .method("totalPages",       args: [.int(pagination.totalPages)]),
                .method("totalMatches",     args: [.int(pagination.totalMatches)]),
                .method("currentPageIndex", args: [.int(pagination.currentPageIndex)]),
            ])))
        }

        return BambuserFactorySpec(calls)
    }
}

extension BambuserSearchProduct {
    var factoryItem: BambuserFactoryItem {
        BambuserFactoryItem(factoryArgs: [], spec: BambuserFactorySpec([
            .method("name",     args: [.string(name)]),
            .method("imageUrl", args: [.string(imageUrl)]),
            .method("sku",      args: [.string(sku)]),
            .method("price",    factory: price.factorySpec),
        ]))
    }
}
