//
//  RootTabBarController.swift
//  BambuserCallsShopperUIKitDemo
//
//  Two tabs — Products (with nav stack) and Cart. Owns the shared
//  BambuserCallController so downstream VCs can call `.show()`
//  from a PDP without any singleton plumbing.
//

import UIKit
import Combine
import BambuserCallsShopper

final class RootTabBarController: UITabBarController {

    let navigation: NavigationCoordinator
    let cart: CartStore
    let bambuserCall: BambuserCallController
    let bambuserSDK: BambuserShopperSDK

    private var cancellables = Set<AnyCancellable>()

    init(
        navigation: NavigationCoordinator,
        cart: CartStore,
        bambuserCall: BambuserCallController,
        bambuserSDK: BambuserShopperSDK
    ) {
        self.navigation = navigation
        self.cart = cart
        self.bambuserCall = bambuserCall
        self.bambuserSDK = bambuserSDK
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Products tab (wrapped in a nav controller).
        let productsList = ProductsListViewController(
            cart: cart,
            bambuserCall: bambuserCall
        )
        productsList.title = "Products"
        productsList.onProductSelected = { [weak self] product in
            guard let self else { return }
            let detail = ProductDetailViewController(
                product: product,
                cart: self.cart,
                bambuserCall: self.bambuserCall,
                bambuserSDK: self.bambuserSDK
            )
            productsList.navigationController?.pushViewController(detail, animated: true)
        }
        let productsNav = UINavigationController(rootViewController: productsList)
        productsNav.tabBarItem = UITabBarItem(
            title: "Products",
            image: UIImage(systemName: "square.grid.2x2"),
            tag: DemoTab.products.rawValue
        )

        // Cart tab.
        let cartVC = CartViewController(cart: cart, bambuserSDK: bambuserSDK)
        cartVC.title = "Cart"
        let cartNav = UINavigationController(rootViewController: cartVC)
        cartNav.tabBarItem = UITabBarItem(
            title: "Cart",
            image: UIImage(systemName: "cart"),
            tag: DemoTab.cart.rawValue
        )

        viewControllers = [productsNav, cartNav]

        // Wire the coordinator so the bridge can drive us from outside.
        navigation.tabBarController = self
        navigation.productsNavigationController = productsNav

        // Cart badge — updates whenever the cart mutates.
        cart.$lines
            .receive(on: DispatchQueue.main)
            .sink { [weak cartNav, weak cart] _ in
                let total = cart?.totalItems ?? 0
                cartNav?.tabBarItem.badgeValue = total == 0 ? nil : String(total)
            }
            .store(in: &cancellables)

        // Hide the tab bar (Products + Cart) while a call is active,
        // so the shopper stays on whatever page the agent co-browsed
        // them to — no side-trips out of the flow.
        bambuserCall.$isVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isVisible in
                self?.tabBar.isHidden = isVisible
            }
            .store(in: &cancellables)
    }
}
