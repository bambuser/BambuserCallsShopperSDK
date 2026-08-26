//
//  BambuserCallHostView.swift
//  BambuserCallsShopper
//

import UIKit
import WebKit

/// UIKit-native container hosting a `BambuserCallViewController` as
/// a full-frame subview. Passes taps outside the embed's `WKWebView`
/// through to the UIKit view behind.
///
/// Wire the child-VC lifecycle when adding to your VC:
/// ```
/// let host = BambuserCallHostView(controller: bambuserCall)
/// addChild(host.callViewController)
/// view.addSubview(host)
/// // pin edges…
/// host.callViewController.didMove(toParent: self)
/// ```
@MainActor
public final class BambuserCallHostView: UIView {

    public let callViewController: BambuserCallViewController

    public init(controller: BambuserCallController) {
        self.callViewController = BambuserCallViewController(controller: controller)
        super.init(frame: .zero)
        commonInit()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("BambuserCallHostView does not support NSCoder init")
    }

    private func commonInit() {
        backgroundColor = .clear
        isOpaque = false

        let child = callViewController.view!
        child.backgroundColor = .clear
        child.isOpaque = false
        child.translatesAutoresizingMaskIntoConstraints = false

        addSubview(child)
        NSLayoutConstraint.activate([
            child.leadingAnchor.constraint(equalTo: leadingAnchor),
            child.trailingAnchor.constraint(equalTo: trailingAnchor),
            child.topAnchor.constraint(equalTo: topAnchor),
            child.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

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
