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

    // Pin widget + adapter. Created once at RootTabsView init so it
    // survives recomposition and drives the pin's WebView lifecycle
    // independently of the call controller. The adapter takes care
    // of the pin ↔ call handoff (single WebView invariant).
    // Swap `content` to try each mode:
    //   .bambuserWidget(...)  — BamHub-configured OLW rendered by
    //                           the Bambuser widget
    //   .custom(...)          — SDK-drawn SwiftUI pin, host-provided
    //                           content
    @StateObject private var pin = BambuserPinWidget(
        configuration: BambuserPinWidgetConfiguration(
            orgId: demoOrgId,
            environment: demoEnvironment,
            content: .bambuserWidget(
                BambuserPinWidgetBambuserOptions(
                    variantOverride: .video,   // .avatar / .sideDock / .video / nil
                    popupTimeoutSeconds: 5        // nil → merchant's BamHub default
                )
            )
        )
    )
    @State private var adapter: BambuserPinWidgetCallAdapter?

    var body: some View {
        ZStack {
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
                        .tag(DemoTab.cart)
                }
            }

            // Full call widget
            BambuserCallOverlay(controller: bambuserCall)
                .ignoresSafeArea(edges: .bottom)

            // Persistent pin widget on top of everything
            BambuserPinWidgetView(pin: pin)
        }
        .onAppear {
            if adapter == nil {
                adapter = BambuserPinWidgetCallAdapter(
                    pin: pin,
                    call: bambuserCall,
                    representAfterCallEnds: true
                )
            }
            pin.present()
        }
    }
}
