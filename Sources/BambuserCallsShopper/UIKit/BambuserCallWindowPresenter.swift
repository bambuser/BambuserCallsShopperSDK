//
//  BambuserCallWindowPresenter.swift
//  BambuserCallsShopper
//

import UIKit

/// Mounts a `BambuserCallViewController` on a dedicated
/// `PassthroughWindow` above the app's main window. Call
/// `attach(to:)` once at app startup; `BambuserCallController.show()`
/// / `close()` drive visibility.
@MainActor
public final class BambuserCallWindowPresenter {

    private let controller: BambuserCallController

    /// The passthrough window hosting the call VC. `nil` until
    /// `attach(to:)`; back to `nil` after `detach()`.
    public private(set) var window: PassthroughWindow?

    /// Window level. Default `.normal + 1` — above the app, below
    /// system alerts + the keyboard's container.
    public var windowLevel: UIWindow.Level = .normal + 1

    public init(controller: BambuserCallController) {
        self.controller = controller
    }

    public func attach(to scene: UIWindowScene) {
        if window != nil { return }

        let callVC = BambuserCallViewController(controller: controller)

        let w = PassthroughWindow(windowScene: scene)
        w.rootViewController = callVC
        w.backgroundColor = .clear
        w.isOpaque = false
        w.windowLevel = windowLevel
        w.isUserInteractionEnabled = true
        // Key so `WKWebView`'s own tap/pan recognizers fire.
        w.makeKeyAndVisible()

        self.window = w
    }

    public func detach() {
        window?.resignKey()
        window?.isHidden = true
        window?.rootViewController = nil
        window = nil
    }
}
