//
//  BambuserCallController.swift
//  BambuserCallsShopper
//

import SwiftUI
import WebKit

/// Owns the embed lifecycle, observable state, and the JS bridge. Host code
/// typically holds one as a `@StateObject`, drops a `BambuserCallOverlay` in
/// its view tree, and assigns a `BambuserCallDelegate`.
@MainActor
public final class BambuserCallController: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var isPiP: Bool = false
    @Published public private(set) var pipPresentation: PipPresentation = .floating
    @Published public private(set) var orgId: String?
    @Published public private(set) var callState: CallState = .idle

    // MARK: - Configuration

    public let configuration: BambuserCallConfiguration
    @Published public var embedUrl: URL
    public weak var delegate: (any BambuserCallDelegate)?

    public var isCallActive: Bool {
        switch callState {
        case .connecting, .connected: return true
        case .idle, .ended:           return false
        }
    }

    private weak var webView: WKWebView?

    // MARK: - Init

    public init(configuration: BambuserCallConfiguration) {
        self.configuration = configuration
        self.embedUrl = configuration.embedUrl
    }

    // MARK: - Lifecycle

    public func show(orgId: String? = nil, embedUrl: URL? = nil) {
        if let embedUrl { self.embedUrl = embedUrl }
        self.orgId = orgId ?? configuration.orgId
        self.isVisible = true
        self.isPiP = false
    }

    public func close() {
        isVisible = false
        isPiP = false
        orgId = nil
        callState = .idle
    }

    public func expand() {
        let wasPiP = isPiP
        isPiP = false
        if wasPiP { emitPresentationChange() }
    }

    public func enterPiP(presentation: PipPresentation = .floating) {
        let changed = (isPiP == false) || (pipPresentation != presentation)
        pipPresentation = presentation
        isPiP = true
        if changed { emitPresentationChange() }
    }

    // MARK: - Outbound bridge

    /// Echo a host-side product navigation back into the embed. No-ops when
    /// no call is active.
    public func notifyProductNavigation(externalId: String) {
        guard isCallActive else {
            print("[BambuserCall] skipping notifyProductNavigation('\(externalId)') — call inactive (state=\(callState))")
            return
        }
        let escaped = JSEscape.escape(externalId)
        let js = "window.notifyBambuserProductNavigation('\(escaped)')"
        evaluate(js, operation: "notifyProductNavigation('\(externalId)')")
    }

    /// Call a JS function registered on `window` by name, passing `info`
    /// inline. The caller shapes `info` as a valid JS expression — string
    /// literal, number, object literal, etc.
    public func notify(callbackKey: String, info: Any) {
        let escapedKey = JSEscape.escape(callbackKey)
        let js = """
        try {
          window['\(escapedKey)'](\(info));
        } catch (err) {
          throw err;
        }
        """
        evaluate(js, operation: "notify('\(callbackKey)')")
    }

    // MARK: - Internal

    internal func setCallState(_ newState: CallState) {
        guard callState != newState else { return }
        print("[BambuserCall] callState: \(callState) → \(newState)")
        if newState == .ended {
            if configuration.dismissOnCallEnd {
                close()
            } else {
                callState = newState
            }
            emit(.callStateChanged(.ended))
            return
        }
        callState = newState
        if newState == .connected, isPiP, configuration.autoExpandOnConnect {
            expand()
        }
        emit(.callStateChanged(newState))
    }

    internal func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    internal func emit(_ event: BambuserCallEvent) {
        delegate?.bambuserCall(self, didEmit: event)
    }

    internal func emit(error: BambuserCallError) {
        delegate?.bambuserCall(self, didEncounterError: error)
    }

    private func emitPresentationChange() {
        emit(.presentationChanged(isPiP: isPiP, presentation: pipPresentation))
    }

    private func evaluate(_ js: String, operation: String) {
        webView?.evaluateJavaScript(js) { [weak self] _, error in
            guard let self, let error else { return }
            print("[BambuserCall] \(operation) failed: \(error)")
            Task { @MainActor [weak self] in
                self?.emit(error: .javaScriptEvaluationFailed(operation: operation, underlying: error))
            }
        }
    }
}

internal enum JSEscape {
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}
