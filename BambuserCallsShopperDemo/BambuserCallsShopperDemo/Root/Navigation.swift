//
//  Navigation.swift
//  BambuserCallsShopperDemo
//

import SwiftUI

enum DemoTab: Hashable, CaseIterable {
    case products
    case cart
}

/// Holds the selected tab and the navigation path for each tab. The
/// `BambuserCallBridge` writes to this from outside the view tree (e.g.
/// pushing a product detail in response to a `navigate-to` event from the
/// embed), so it has to live as a shared observable object rather than
/// inside any single view's @State.
@MainActor
final class NavigationCoordinator: ObservableObject {

    @Published var currentTab: DemoTab = .products
    @Published var productsPath: [String] = []   // stack of product SKUs

    var productsPathBinding: Binding<[String]> {
        Binding(
            get: { self.productsPath },
            set: { self.productsPath = $0 }
        )
    }

    func switchTo(_ tab: DemoTab) {
        currentTab = tab
    }

    /// Push a product detail screen onto the products tab. Skipping the
    /// push when the same SKU already sits on top avoids growing the stack
    /// with duplicates when the embed re-emits `navigate-to`.
    func pushProduct(sku: String) {
        currentTab = .products
        guard productsPath.last != sku else { return }
        productsPath.append(sku)
    }
}
