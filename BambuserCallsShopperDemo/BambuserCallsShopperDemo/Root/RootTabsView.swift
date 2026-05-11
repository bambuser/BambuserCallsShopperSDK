//
//  RootTabsView.swift
//  BambuserCallsShopperDemo
//

import SwiftUI
import BambuserCallsShopper

struct RootTabsView: View {
    @EnvironmentObject private var navigation: NavigationCoordinator
    @EnvironmentObject private var cart: CartStore
    @EnvironmentObject private var bambuserCall: BambuserCallController

    var body: some View {
        ZStack {
            TabView(selection: $navigation.currentTab) {
                ProductsListView()
                    .tabItem { Label("Products", systemImage: "square.grid.2x2") }
                    .tag(DemoTab.products)

                CartView()
                    .tabItem { Label("Cart", systemImage: "cart") }
//                    .badge(cartBadge)
                    .tag(DemoTab.cart)
            }

            BambuserCallOverlay(controller: bambuserCall)
        }
    }

    private var cartBadge: Int? {
        cart.totalItems == 0 ? nil : cart.totalItems
    }
}
