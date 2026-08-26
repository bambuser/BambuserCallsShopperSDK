//
//  NavigationCoordinator.swift
//  BambuserCallsShopperUIKitDemo
//
//  Same surface as the SwiftUI demo's coordinator, but backed by
//  UIKit primitives — a UITabBarController and a UINavigationController
//  for the products tab. Consumed by BambuserCallBridge to push
//  product detail screens and switch tabs in response to embed events.
//

import UIKit

enum DemoTab: Int, CaseIterable {
    case products = 0
    case cart     = 1
}

@MainActor
final class NavigationCoordinator {

    /// Set by `RootTabBarController` at boot; used to switch tabs from
    /// outside the view tree (e.g. checkout → cart).
    weak var tabBarController: UITabBarController?

    /// Set by `RootTabBarController`; the nav controller wrapping the
    /// products tab, so the bridge can push product-detail VCs.
    weak var productsNavigationController: UINavigationController?

    func switchTo(_ tab: DemoTab) {
        tabBarController?.selectedIndex = tab.rawValue
    }

    /// Push a product detail VC onto the products tab. Skipping the
    /// push when the same SKU already sits on top avoids growing the
    /// stack with duplicates when the embed re-emits `navigate-to`.
    func pushProduct(sku: String) {
        switchTo(.products)

        guard let nav = productsNavigationController else { return }

        if let topDetail = nav.topViewController as? ProductDetailViewController,
           topDetail.product.id == sku {
            return
        }
        guard let product = ProductCatalog.product(for: sku) else { return }

        // Presenter host owns the call controller; grab it back through
        // the tab bar so we don't need to pass it around.
        guard let root = tabBarController as? RootTabBarController else { return }
        let detail = ProductDetailViewController(
            product: product,
            cart: root.cart,
            bambuserCall: root.bambuserCall
        )
        nav.pushViewController(detail, animated: true)
    }
}
