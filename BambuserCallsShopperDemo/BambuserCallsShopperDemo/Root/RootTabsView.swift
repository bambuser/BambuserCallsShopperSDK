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
            // While a call is active we hide the tab bar (Products +
            // Cart) so the shopper stays on whatever page the agent
            // co-browsed them to — no side-trips out of the flow.
            // Nav state lives on `NavigationCoordinator`, so the
            // pushed PDP survives the view swap.
            if bambuserCall.isVisible {
                switch navigation.currentTab {
                case .products: ProductsListView()
                case .cart:     CartView()
                }
            } else {
                TabView(selection: $navigation.currentTab) {
                    ProductsListView()
                        .tabItem { Label("Products", systemImage: "square.grid.2x2") }
                        .tag(DemoTab.products)

                    CartView()
                        .tabItem { Label("Cart", systemImage: "cart") }
//                        .badge(cartBadge)
                        .tag(DemoTab.cart)
                }
            }

            BambuserCallOverlay(controller: bambuserCall)
        }
    }

    private var cartBadge: Int? {
        cart.totalItems == 0 ? nil : cart.totalItems
    }
}
