//
//  BambuserCallViewController.swift
//  BambuserCallsShopper
//

import Combine
import UIKit
import WebKit

/// UIKit-native mount of the Bambuser call embed. Owns the WKWebView
/// directly; drives full-screen ↔ PiP transitions, PiP drag, and
/// the JS bridge. Used internally by `BambuserCallOverlay`,
/// `BambuserCallHostView`, and `BambuserCallWindowPresenter`.
@MainActor
public final class BambuserCallViewController: UIViewController {

    private let controller: BambuserCallController
    private var webView: WKWebView?
    private var bridgeCoordinator: EmbedBridgeCoordinator?

    private var pipLeadingConstraint: NSLayoutConstraint?
    private var pipTopConstraint: NSLayoutConstraint?
    private var pipWidthConstraint: NSLayoutConstraint?
    private var pipHeightConstraint: NSLayoutConstraint?

    private var fullScreenConstraints: [NSLayoutConstraint] = []
    private var pipConstraints: [NSLayoutConstraint] = []

    private var pipDragOffset: CGSize = .zero
    private var pipDragStart: CGSize = .zero

    private var cancellables = Set<AnyCancellable>()

    public init(controller: BambuserCallController) {
        self.controller = controller
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) { fatalError() }

    public override func loadView() {
        let v = UIView()
        v.backgroundColor = .clear
        v.isOpaque = false
        self.view = v
    }

    public override func viewDidLoad() {
        super.viewDidLoad()

        controller.$isVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                if visible { self?.mountWebViewIfNeeded() }
                else       { self?.dismountWebView() }
            }
            .store(in: &cancellables)

        controller.$isPiP
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isPiP in self?.applyPresentation(isPiP: isPiP, animated: true) }
            .store(in: &cancellables)

        controller.$pipPresentation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, self.controller.isPiP else { return }
                self.applyPresentation(isPiP: true, animated: true)
            }
            .store(in: &cancellables)
    }

    // MARK: - Web view lifecycle

    private func mountWebViewIfNeeded() {
        guard webView == nil, let orgId = controller.orgId else { return }
        let cfg = controller.configuration

        let wkConfig = WKWebViewConfiguration()
        wkConfig.allowsInlineMediaPlayback = true
        wkConfig.mediaTypesRequiringUserActionForPlayback = []

        let shim = WKUserScript(
            source: EmbedHTMLBuilder.makeDocumentStartShim(
                injectsLegacyGetUserMediaShim: cfg.injectsLegacyGetUserMediaShim
            ),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        wkConfig.userContentController.addUserScript(shim)

        let coordinator = EmbedBridgeCoordinator { [weak self] raw in
            guard let self else { return }
            EmbedEventRouter(controller: self.controller).handle(rawMessage: raw)
        }
        wkConfig.userContentController.add(coordinator, name: "nativeBridge")

        let wv = WKWebView(frame: .zero, configuration: wkConfig)
        wv.uiDelegate = coordinator
        wv.backgroundColor = .clear
        wv.isOpaque = false
        wv.scrollView.backgroundColor = .clear
        // Propagates safe-area insets into CSS env(safe-area-inset-*).
        wv.scrollView.contentInsetAdjustmentBehavior = .always
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false
        if let ua = cfg.customUserAgent {
            wv.customUserAgent = ua
        }
        if #available(iOS 16.4, *) {
            wv.isInspectable = cfg.isInspectable
        }
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.layer.cornerRadius = 0
        wv.layer.masksToBounds = true

        view.addSubview(wv)

        // Edge-to-edge in full-screen; the widget's own CSS handles
        // safe-area for its header + controls.
        fullScreenConstraints = [
            wv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            wv.topAnchor.constraint(equalTo: view.topAnchor),
            wv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ]

        pipLeadingConstraint = wv.leadingAnchor.constraint(equalTo: view.leadingAnchor)
        pipTopConstraint     = wv.topAnchor.constraint(equalTo: view.topAnchor)
        pipWidthConstraint   = wv.widthAnchor.constraint(equalToConstant: cfg.floatingPipSize.width)
        pipHeightConstraint  = wv.heightAnchor.constraint(equalToConstant: cfg.floatingPipSize.height)
        pipConstraints = [pipLeadingConstraint!, pipTopConstraint!, pipWidthConstraint!, pipHeightConstraint!]

        let options = makeEmbedOptions(orgId: orgId)
        let html = EmbedHTMLBuilder.makeHTML(options: options)
        wv.loadHTMLString(html, baseURL: EmbedHTMLBuilder.baseURL(for: controller.embedUrl))

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePipPan(_:)))
        pan.delegate = coordinator
        view.addGestureRecognizer(pan)
        coordinator.pipPanGesture = pan
        coordinator.controllerRef = controller

        self.webView = wv
        self.bridgeCoordinator = coordinator

        controller.attach(wv)

        applyPresentation(isPiP: controller.isPiP, animated: false)
    }

    private func dismountWebView() {
        webView?.configuration.userContentController.removeScriptMessageHandler(forName: "nativeBridge")
        webView?.removeFromSuperview()
        webView = nil
        bridgeCoordinator = nil
        fullScreenConstraints = []
        pipConstraints = []
        pipLeadingConstraint = nil
        pipTopConstraint = nil
        pipWidthConstraint = nil
        pipHeightConstraint = nil
        pipDragOffset = .zero
        pipDragStart = .zero
    }

    // MARK: - Presentation

    private func applyPresentation(isPiP: Bool, animated: Bool) {
        guard let wv = webView else { return }

        NSLayoutConstraint.deactivate(fullScreenConstraints + pipConstraints)
        if isPiP {
            let size = currentPipSize()
            pipWidthConstraint?.constant  = size.width
            pipHeightConstraint?.constant = size.height
            let origin = defaultPipOrigin(size: size)
            pipLeadingConstraint?.constant = origin.x + pipDragOffset.width
            pipTopConstraint?.constant     = origin.y + pipDragOffset.height
            NSLayoutConstraint.activate(pipConstraints)

            wv.layer.cornerRadius = 16
            wv.layer.shadowColor = UIColor.black.cgColor
            wv.layer.shadowOpacity = 0.25
            wv.layer.shadowRadius = 12
            wv.layer.shadowOffset = CGSize(width: 0, height: 6)
        } else {
            NSLayoutConstraint.activate(fullScreenConstraints)
            pipDragOffset = .zero
            pipDragStart = .zero
            wv.layer.cornerRadius = 0
            wv.layer.shadowOpacity = 0
        }

        if animated {
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.85,
                initialSpringVelocity: 0,
                options: [.beginFromCurrentState, .allowUserInteraction],
                animations: { self.view.layoutIfNeeded() }
            )
        } else {
            view.layoutIfNeeded()
        }
    }

    private func currentPipSize() -> CGSize {
        let cfg = controller.configuration
        switch controller.pipPresentation {
        case .minimized: return cfg.minimizedPipSize
        case .floating:  return cfg.floatingPipSize
        }
    }

    private func defaultPipOrigin(size: CGSize) -> CGPoint {
        let cfg = controller.configuration
        let frame = view.bounds
        let safe = view.safeAreaInsets
        return CGPoint(
            x: frame.width - size.width - cfg.pipMargin,
            y: frame.height - size.height - safe.bottom - cfg.bottomReserve - cfg.pipMargin
        )
    }

    // MARK: - PiP drag

    @objc private func handlePipPan(_ pan: UIPanGestureRecognizer) {
        guard controller.isPiP else { return }
        let translation = pan.translation(in: view)
        switch pan.state {
        case .changed:
            let size = currentPipSize()
            let origin = defaultPipOrigin(size: size)
            pipLeadingConstraint?.constant = origin.x + pipDragStart.width + translation.x
            pipTopConstraint?.constant     = origin.y + pipDragStart.height + translation.y
        case .ended, .cancelled, .failed:
            pipDragStart.width  += translation.x
            pipDragStart.height += translation.y
            pipDragOffset = pipDragStart
        default: break
        }
    }

    // MARK: - Embed options

    private func makeEmbedOptions(orgId: String) -> EmbedHTMLBuilder.Options {
        let cfg = controller.configuration
        let tags: BambuserJSONValue? = cfg.initialTrackingTags.isEmpty
            ? nil
            : cfg.initialTrackingTags.toJSONArray()

        return EmbedHTMLBuilder.Options(
            orgId: orgId,
            embedUrl: controller.embedUrl,
            connectId: controller.connectId,
            queue: controller.queue ?? cfg.initialQueue,
            triggers: cfg.triggers,
            floatingNavigationMode: cfg.floatingNavigationMode,
            floatingFillMode: cfg.floatingFillMode,
            locale: cfg.locale,
            data: cfg.initialCustomerData,
            trackingTags: tags,
            dropInEnabled: cfg.dropInEnabled,
            bookingsEnabled: cfg.bookingsEnabled,
            openBookingPage: cfg.openBookingPage,
            bookingServiceIds: cfg.bookingServiceIds,
            bookingResourceId: cfg.bookingResourceId,
            bookingIframeUrl: cfg.bookingIframeUrl,
            enableScanning: cfg.enableScanning,
            merchantBaseUrl: cfg.merchantBaseUrl,
            disableCoBrowsing: cfg.disableCoBrowsing,
            themeId: cfg.themeId,
            allowFirstPartyCookies: cfg.allowFirstPartyCookies,
            disableDataLayerInterceptions: cfg.disableDataLayerInterceptions,
            subscriptions: controller.activeSubscriptions
        )
    }
}

// MARK: - Bridge coordinator

@MainActor
private final class EmbedBridgeCoordinator: NSObject, WKScriptMessageHandler, WKUIDelegate, UIGestureRecognizerDelegate {

    let onMessage: (String) -> Void
    weak var pipPanGesture: UIPanGestureRecognizer?
    weak var controllerRef: BambuserCallController?

    init(onMessage: @escaping (String) -> Void) {
        self.onMessage = onMessage
    }

    nonisolated func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        let body = (message.body as? String) ?? message.name
        Task { @MainActor in self.onMessage(body) }
    }

    nonisolated func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping (WKPermissionDecision) -> Void
    ) {
        decisionHandler(.grant)
    }

    nonisolated func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        false
    }

    // Only fire the PiP pan when actually in PiP; defer to WebKit's
    // own recognizers in full-screen.
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return controllerRef?.isPiP == true
    }
}
