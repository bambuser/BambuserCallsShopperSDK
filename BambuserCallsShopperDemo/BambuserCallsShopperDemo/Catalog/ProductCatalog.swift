//
//  ProductCatalog.swift
//  BambuserCallsShopperDemo
//
//  The five demo SKUs the app sells. SKUs match the ids the Bambuser
//  embed will hand back via `navigate-to` and cart events, so a lookup
//  with the bare id resolves directly.
//

import Foundation

enum ProductCatalog {

    static let all: [DemoProduct] = [
        DemoProduct(
            id: "1791",
            name: "3-Pack Resistance Bands",
            brand: "Bambuser",
            category: "Sports",
            price: 30,
            currency: "USD",
            inStock: true,
            description: "Crafted from premium, durable rubber, our FlexFit Resistance Bands provide the perfect amount of tension for a challenging and effective workout. Whether you're looking to build strength, increase flexibility, or improve your overall fitness level, these bands are a must-have addition to your exercise routine.",
            imageURL: URL(string: "https://demo.bambuser.shop/wp-content/uploads/2023/06/Sport_4.png")!,
            additionalImages: [],
            url: URL(string: "https://demo.bambuser.shop/product/1791/3-pack-resistance-bands/")
        ),
        DemoProduct(
            id: "1269",
            name: "Smartphone",
            brand: "Bambuser",
            category: "Consumer Electronics",
            price: 499,
            currency: "USD",
            inStock: true,
            description: "Experience stunning visuals and vibrant colors on our smartphone's immersive display. With its high-resolution screen and edge-to-edge design, every image, video, and game is brought to life with incredible clarity and detail. Whether you're browsing the web, streaming your favorite content, or editing photos, the visual experience is truly captivating.",
            imageURL: URL(string: "https://demo.bambuser.shop/wp-content/uploads/2023/05/ConsumerElectronics_5.png")!,
            additionalImages: [],
            url: nil  // not in the current demo.bambuser.shop feed
        ),
        DemoProduct(
            id: "1234",
            name: "The Classic Eyeliner",
            brand: "Bambuser",
            category: "Beauty",
            price: 18,
            currency: "USD",
            inStock: true,
            description: "Unleash your inner artist and create stunning eye looks with our revolutionary eyeliner. Experience effortless precision and long-lasting definition with our smudge-proof formula, designed to elevate your eye game to new heights.",
            imageURL: URL(string: "https://demo.bambuser.shop/wp-content/uploads/2023/05/Makeup_4.png")!,
            additionalImages: [],
            url: nil  // not in the current demo.bambuser.shop feed
        ),
        DemoProduct(
            id: "1233",
            name: "Precision Eyelash Curler",
            brand: "Bambuser",
            category: "Beauty",
            price: 15,
            currency: "USD",
            inStock: true,
            description: "Our Precision Curl Eyelash Curler features a sleek and ergonomic design, allowing for a comfortable grip and precise control. The specially crafted silicone pad gently lifts and curls your lashes from the base to the tip, creating a long-lasting curl that opens up your eyes and enhances their natural beauty.",
            imageURL: URL(string: "https://demo.bambuser.shop/wp-content/uploads/2023/05/Makeup_6.png")!,
            additionalImages: [],
            url: nil  // not in the current demo.bambuser.shop feed
        ),
        DemoProduct(
            id: "1810",
            name: "8-pieces Rainbow",
            brand: "Bambuser",
            category: "Kids",
            price: 16,
            currency: "USD",
            inStock: true,
            description: "This playful rainbow consists of bows in different colors and sizes. Stack them in the right order, and a nice rainbow emerges. Or experiment and make your own unique designs. Fun to play with and at the same time looks nice in the children's room.",
            imageURL: URL(string: "https://demo.bambuser.shop/wp-content/uploads/2023/06/Kids_1.1-1.png")!,
            additionalImages: [
                URL(string: "https://demo.bambuser.shop/wp-content/uploads/2023/06/Kids_1.2-1.png")!,
                URL(string: "https://demo.bambuser.shop/wp-content/uploads/2023/06/Kids_1.3-1.png")!
            ],
            url: URL(string: "https://demo.bambuser.shop/product/1810/8-pieces-rainbow/")
        )
    ]

    /// `id`-keyed dictionary for O(1) lookups. Used by the call bridge to
    /// resolve `externalId`s the embed sends back via `navigate-to`.
    static let bySku: [String: DemoProduct] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static func product(for sku: String) -> DemoProduct? {
        bySku[sku]
    }
}
