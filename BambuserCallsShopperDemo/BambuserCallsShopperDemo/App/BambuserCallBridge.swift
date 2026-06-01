//
//  BambuserCallBridge.swift
//  BambuserCallsShopperDemo
//
//  Builds a `BambuserCallHandlers` for the demo. No delegate protocol
//  any more — each closure below is one JS `.on(...)` subscription the
//  SDK will install. Omit a closure to opt out of the underlying event.
//

import Foundation
import BambuserCallsShopper

@MainActor
enum BambuserCallBridge {

    /// Configure a controller with the demo's cart / navigation /
    /// product / search hooks. Call once before `controller.show(...)`.
    static func configure(
        controller: BambuserCallController,
        navigation: NavigationCoordinator,
        cart: CartStore
    ) {
        var handlers = BambuserCallHandlers()

        // MARK: Product data ------------------------------------------------

        handlers.provideProductData = { ref in
            guard let sku = resolveSKU(from: ref) else {
                print("[BambuserCallBridge] unresolved provide-product-data ref: \(ref)")
                return nil
            }
            guard let product = ProductCatalog.product(for: sku) else {
                print("[BambuserCallBridge] no catalog match for sku='\(sku)' (ref=\(ref))")
                return nil
            }
            // Build via the demo's reference `BambuserProduct` model,
            // then convert to the generic factory spec the SDK expects.
            return product.toBambuserProduct().factorySpec
        }

        // MARK: Search ------------------------------------------------------

//        handlers.provideSearchData = { request in
//            print("[BambuserCallBridge] provide-search-data ref: \(request)")
//
//            let query = request.term
//                .trimmingCharacters(in: .whitespacesAndNewlines)
//                .lowercased()
//
//            let matches: [DemoProduct]
//            if query.isEmpty {
//                matches = ProductCatalog.all
//            } else {
//                matches = ProductCatalog.all.filter { p in
//                    p.name.lowercased().contains(query)
//                        || p.brand.lowercased().contains(query)
//                        || p.category.lowercased().contains(query)
//                        || p.id.lowercased().contains(query)
//                }
//            }
//
//            let pageSize = 10
//            let totalMatches = matches.count
//            let totalPages = max(1, Int(ceil(Double(totalMatches) / Double(pageSize))))
//            let pageIndex = max(1, min(request.page, totalPages))
//            let start = (pageIndex - 1) * pageSize
//            let end = min(start + pageSize, totalMatches)
//            let pageItems = totalMatches == 0 ? [] : Array(matches[start..<end])
//
//            let products: [BambuserSearchProduct] = pageItems.map { p in
//                BambuserSearchProduct(
//                    name: p.name,
//                    imageUrl: p.imageURL.absoluteString,
//                    sku: p.id,
//                    price: BambuserPrice(current: p.price)
//                )
//            }
//
//            let response = BambuserSearchResponse(
//                products: products,
//                currency: pageItems.first?.currency ?? "USD",
//                locale: "en-US",
//                pagination: BambuserSearchPagination(
//                    totalPages: totalPages,
//                    totalMatches: totalMatches,
//                    currentPageIndex: pageIndex
//                )
//            )
//            return response.factorySpec
//        }

        // MARK: Cart --------------------------------------------------------

        handlers.shouldAddToCart = { intent in
            guard !intent.sku.isEmpty else { return .failure(reason: "missing-sku") }
            cart.setQuantity(intent.quantity, for: intent.sku)
            return .success
        }
        handlers.shouldUpdateCart = { intent in
            guard !intent.sku.isEmpty else { return .failure(reason: "missing-sku") }
            cart.setQuantity(intent.quantity, for: intent.sku)
            return .success
        }

        // MARK: Widget events -----------------------------------------------

        handlers.onGotoCheckout = { _ in navigation.switchTo(.cart) }

        handlers.onGotoChat = {
            print("[BambuserCallBridge] shopper picked chat instead of call")
        }

        handlers.onQueueOpen = { state in
            print("[BambuserCallBridge] queue open (nextClose=\(state.nextCloseTime as Any))")
        }
        handlers.onQueueClosed = { state in
            print("[BambuserCallBridge] queue closed (nextOpen=\(state.nextOpenTime as Any))")
        }
        handlers.onAgentsOnline = { a in
            print("[BambuserCallBridge] agents online = \(a.numberOfAgentsOnline)")
        }
        handlers.onQueueWaitingTime = { w in
            print("[BambuserCallBridge] estimated wait = \(w.estimatedWaitingTime)s (place=\(w.place))")
        }
        handlers.onTrackingEvent = { e in
            if let name = e.eventName {
                print("[BambuserCallBridge] tracking bam: \(name)")
            } else if let ga4 = e.ga4Event {
                print("[BambuserCallBridge] tracking ga4: \(ga4)")
            }
        }
        handlers.onError = { error in
            print("[BambuserCallBridge] error: \(error)")
        }

        // NOTE: we deliberately leave `onEmbedEvent` nil — the SDK
        // won't forward the firehose of unknown events. Set it if you
        // want a catch-all.

        controller.handlers = handlers
    }

    /// Turn whatever the agent tool sent (SKU, URL, or scanned barcode)
    /// into a catalog SKU string. For the demo URLs, we assume the last
    /// path component is the SKU.
    private static func resolveSKU(from ref: BambuserProductRef) -> String? {
        switch ref.kind {
        case .productReference, .scannedCode:
            return ref.ref.isEmpty ? nil : ref.ref
        case .url:
            guard let url = URL(string: ref.ref) else { return nil }
            return url.pathComponents.reversed().first(where: { !$0.isEmpty && $0 != "/" })
        case .unknown:
            return ref.ref.isEmpty ? nil : ref.ref
        }
    }
}
