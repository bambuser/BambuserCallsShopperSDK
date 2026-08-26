//
//  PassthroughWindow.swift
//  BambuserCallsShopper
//

import UIKit
import WebKit

/// A `UIWindow` that only claims touches which reach the embed's
/// `WKWebView` (or a subview of it). Empty regions fall through to
/// the window below.
@MainActor
public final class PassthroughWindow: UIWindow {

    public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let hit = super.hitTest(point, with: event) else { return nil }
        var v: UIView? = hit
        while let cur = v {
            if cur is WKWebView { return hit }
            v = cur.superview
        }
        return nil
    }
}
