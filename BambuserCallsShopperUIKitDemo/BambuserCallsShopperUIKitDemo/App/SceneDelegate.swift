//
//  SceneDelegate.swift
//  BambuserCallsShopperUIKitDemo
//

import UIKit
import BambuserCallsShopper

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    // App-scope state, held for the lifetime of the scene.
    private lazy var navigation = NavigationCoordinator()
    private lazy var cart       = CartStore()

    private lazy var bambuserCall: BambuserCallController = BambuserCallController(
        configuration: BambuserCallConfiguration(
            orgId: DemoConfiguration.orgId,
            environment: DemoConfiguration.environment
        )
    )

    /// App-scope shopper analytics handle. Independent of the call
    /// controller — checkout can fire `track(...)` events hours after
    /// a call ended.
    private lazy var bambuserSDK: BambuserShopperSDK = DemoConfiguration.makeShopperSDK()

    /// Strong reference — `controller.delegate` is weak.
    private var bridge: BambuserCallBridge?

    /// Two mounting options:
    ///  - `BambuserCallWindowPresenter` — floats above the whole app
    ///    on its own passthrough UIWindow.
    ///  - `BambuserCallHostView` — inline embed in the current VC.
    private var overlayPresenter: BambuserCallWindowPresenter?
    private var overlayHostView:  BambuserCallHostView?
    private let useOverlayWindow = true

    // MARK: - UIWindowSceneDelegate

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // 1. Main app window.
        let main = UIWindow(windowScene: windowScene)
        let root = RootTabBarController(
            navigation: navigation,
            cart: cart,
            bambuserCall: bambuserCall,
            bambuserSDK: bambuserSDK
        )
        main.rootViewController = root
        main.makeKeyAndVisible()
        self.window = main

        // 2. Delegate + handlers on the controller.
        self.bridge = BambuserCallBridge.configure(
            controller: bambuserCall,
            navigation: navigation,
            cart: cart
        )

        // 3. Mount the overlay.
        if useOverlayWindow {
            let presenter = BambuserCallWindowPresenter(controller: bambuserCall)
            presenter.attach(to: windowScene)
            self.overlayPresenter = presenter
        } else {
            let host = BambuserCallHostView(controller: bambuserCall)
            root.addChild(host.callViewController)
            root.view.addSubview(host)
            host.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: root.view.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: root.view.trailingAnchor),
                host.topAnchor.constraint(equalTo: root.view.topAnchor),
                host.bottomAnchor.constraint(equalTo: root.view.bottomAnchor),
            ])
            host.callViewController.didMove(toParent: root)
            self.overlayHostView = host
        }

        // 4. Setup-alert if the demo hasn't been configured yet.
        if !DemoConfiguration.isConfigured {
            DispatchQueue.main.async { [weak self] in
                self?.presentSetupAlert()
            }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        overlayPresenter?.detach()
        overlayPresenter = nil
    }

    private func presentSetupAlert() {
        let alert = UIAlertController(
            title: "Bambuser credentials missing",
            message: "Set DemoConfiguration.orgId in App/DemoConfiguration.swift before starting an expert call.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        window?.rootViewController?.present(alert, animated: true)
    }
}
