//
//  BambuserCallBridge.swift
//  BambuserCallsShopperDemo
//
//  Bridges the SDK's event stream to the demo's navigation and cart.
//

import Foundation
import BambuserCallsShopper

@MainActor
final class BambuserCallBridge: BambuserCallDelegate {

    let navigation: NavigationCoordinator
    let cart: CartStore

    init(navigation: NavigationCoordinator, cart: CartStore) {
        self.navigation = navigation
        self.cart = cart
    }

    // MARK: - Event stream

    func bambuserCall(
        _ controller: BambuserCallController,
        didEmit event: BambuserCallEvent
    ) {
        switch event {
        case .navigateTo(let externalId):
            handleNavigateTo(externalId: externalId, controller: controller)

        case .checkout:
            navigation.switchTo(.cart)

        case let .shouldAddToCart(sku, quantity, callbackKey),
             let .shouldUpdateCart(sku, quantity, callbackKey):
            handleCart(
                sku: sku,
                quantity: quantity,
                callbackKey: callbackKey,
                controller: controller
            )

        case .close, .callStateChanged, .presentationChanged, .other:
            break
        }
    }

    func bambuserCall(
        _ controller: BambuserCallController,
        didEncounterError error: BambuserCallError
    ) {
        print("[BambuserCallBridge] error: \(error)")
    }

    // MARK: - Navigation

    private func handleNavigateTo(externalId: String, controller: BambuserCallController) {
        guard ProductCatalog.product(for: externalId) != nil else {
            print("[BambuserCallBridge] no product for externalId='\(externalId)'")
            return
        }
        navigation.pushProduct(sku: externalId)
        controller.notifyProductNavigation(externalId: externalId)
    }

    // MARK: - Cart

    private func handleCart(
        sku: String,
        quantity: Int,
        callbackKey: String,
        controller: BambuserCallController
    ) {
        guard !sku.isEmpty else {
            controller.notify(
                callbackKey: callbackKey,
                info: "{ success: false, reason: 'missing-sku' }"
            )
            return
        }

        cart.setQuantity(quantity, for: sku)
        controller.notify(callbackKey: callbackKey, info: true)
    }
}
