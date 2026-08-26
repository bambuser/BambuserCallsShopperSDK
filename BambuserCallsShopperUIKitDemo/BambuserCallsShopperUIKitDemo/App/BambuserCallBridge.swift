//
//  BambuserCallBridge.swift
//  BambuserCallsShopperUIKitDemo
//
//  Reference wiring you can copy into your own app:
//   1. Implements `BambuserCallDelegate` — fire-and-forget events.
//   2. Configures data-source handlers on the controller.
//

import Foundation
import BambuserCallsShopper

@MainActor
final class BambuserCallBridge: BambuserCallDelegate {

    private let navigation: NavigationCoordinator
    private let cart: CartStore

    init(navigation: NavigationCoordinator, cart: CartStore) {
        self.navigation = navigation
        self.cart = cart
    }

    /// Wire the bridge to a controller. Returns the bridge so the
    /// host can hold a strong reference — `controller.delegate` is
    /// `weak`.
    @discardableResult
    static func configure(
        controller: BambuserCallController,
        navigation: NavigationCoordinator,
        cart: CartStore
    ) -> BambuserCallBridge {
        let bridge = BambuserCallBridge(navigation: navigation, cart: cart)
        controller.delegate = bridge
        controller.handlers = makeHandlers(cart: cart)
        return bridge
    }

    // MARK: - Data-source handlers

    private static func makeHandlers(cart: CartStore) -> BambuserCallHandlers {
        var handlers = BambuserCallHandlers()

        // NOTE: If your product catalogue is uploaded to BamHub (or
        // connected as a product feed), skip provideProductData and
        // provideSearchData entirely — Bambuser hydrates product
        // cards and search automatically from the feed. Only wire
        // these when the catalogue can't be exposed to BamHub.

        handlers.provideProductData = { ref in
            print("[BambuserCallBridge] provideProductData ref=\(ref.ref) kind=\(ref.kind.rawValue)")

            guard let sku = resolveSKU(from: ref) else {
                return .error(message: "Unrecognised product reference: '\(ref.ref)'")
            }
            guard let product = ProductCatalog.product(for: sku) else {
                return .error(message: "We don't sell '\(sku)'")
            }
            return .reply(product.toBambuserProduct().factorySpec)
        }

        handlers.provideSearchData = { request in
            print("[BambuserCallBridge] provideSearchData term='\(request.term)' page=\(request.page)")

            let query = request.term
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()

            guard query.count <= 100 else {
                return .error(message: "Search term too long")
            }

            let matches = query.isEmpty
                ? ProductCatalog.all
                : ProductCatalog.all.filter { p in
                    p.name.lowercased().contains(query)
                        || p.brand.lowercased().contains(query)
                        || p.category.lowercased().contains(query)
                        || p.id.lowercased().contains(query)
                }

            let pageSize = 10
            let totalMatches = matches.count
            let totalPages = max(1, Int(ceil(Double(totalMatches) / Double(pageSize))))
            let pageIndex = max(1, min(request.page, totalPages))
            let start = (pageIndex - 1) * pageSize
            let end = min(start + pageSize, totalMatches)
            let pageItems = totalMatches == 0 ? [] : Array(matches[start..<end])

            let products: [BambuserSearchProduct] = pageItems.map { p in
                BambuserSearchProduct(
                    name: p.name,
                    imageUrl: p.imageURL.absoluteString,
                    sku: p.id,
                    price: BambuserPrice(current: p.price)
                )
            }

            let response = BambuserSearchResponse(
                products: products,
                currency: pageItems.first?.currency ?? "USD",
                locale: "en-US",
                pagination: BambuserSearchPagination(
                    totalPages: totalPages,
                    totalMatches: totalMatches,
                    currentPageIndex: pageIndex
                )
            )
            return .reply(response.factorySpec)
        }

        // Cart handlers are independent of BamHub — wire these when
        // you want video-call "add to cart" to land in your app's
        // own cart.
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

        return handlers
    }

    /// SKU / URL / scanned-code → catalog SKU string. Adapt to your
    /// own URL scheme.
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

    // MARK: - BambuserCallDelegate

    func bambuserCall(_ controller: BambuserCallController, didEmit event: BambuserCallEvent) {
        switch event {
        case .close:
            print("[BambuserCallBridge] call closed")

        case .callStateChanged(let state):
            print("[BambuserCallBridge] callState → \(state)")

        case .presentationChanged(let isPiP, let presentation):
            print("[BambuserCallBridge] presentation → isPiP=\(isPiP), \(presentation)")

        case .checkout:
            navigation.switchTo(.cart)

        case .chatRequested:
            print("[BambuserCallBridge] shopper picked chat instead of call")

        case .navigateTo(let url):
            // Push into your UIKit navigation stack when you wire
            // co-browse into the shopper's actual navigation.
            print("[BambuserCallBridge] agent asked to navigate to: \(url)")

        case .queueOpened(let state):
            print("[BambuserCallBridge] queue open (nextClose=\(state.nextCloseTime as Any))")

        case .queueClosed(let state):
            print("[BambuserCallBridge] queue closed (nextOpen=\(state.nextOpenTime as Any))")

        case .agentsOnlineChanged(let a):
            print("[BambuserCallBridge] agents online = \(a.numberOfAgentsOnline)")

        case .waitingTimeChanged(let w):
            print("[BambuserCallBridge] estimated wait = \(w.estimatedWaitingTime)s (place=\(w.place))")

        case .trackingEvent(let e):
            if let name = e.eventName {
                print("[BambuserCallBridge] tracking bam: \(name)")
            } else if let ga4 = e.ga4Event {
                print("[BambuserCallBridge] tracking ga4: \(ga4)")
            }

        case .other(let name, _):
            print("[BambuserCallBridge] unhandled embed event: \(name)")
        }
    }

    func bambuserCall(_ controller: BambuserCallController, didEncounter error: BambuserCallError) {
        print("[BambuserCallBridge] error: \(error)")
    }
}
