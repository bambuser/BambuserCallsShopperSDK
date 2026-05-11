//
//  EmbedWebView.swift
//  BambuserCallsShopper
//

import SwiftUI
import WebKit

internal struct EmbedWebView: UIViewRepresentable {

    let html: String
    let baseURL: URL?
    let configuration: BambuserCallConfiguration
    var onNativeMessage: ((String) -> Void)?
    var onWebViewCreated: ((WKWebView) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(onMessage: onNativeMessage)
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let shim = WKUserScript(
            source: EmbedHTMLBuilder.makeDocumentStartShim(
                injectsLegacyGetUserMediaShim: configuration.injectsLegacyGetUserMediaShim
            ),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        config.userContentController.addUserScript(shim)
        config.userContentController.add(context.coordinator, name: "nativeBridge")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.uiDelegate = context.coordinator
        if let ua = configuration.customUserAgent {
            webView.customUserAgent = ua
        }
        if #available(iOS 16.4, *) {
            webView.isInspectable = configuration.isInspectable
        }
        webView.loadHTMLString(html, baseURL: baseURL)

        if let onWebViewCreated {
            DispatchQueue.main.async { onWebViewCreated(webView) }
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: "nativeBridge")
    }

    final class Coordinator: NSObject, WKScriptMessageHandler, WKUIDelegate {
        let onMessage: ((String) -> Void)?

        init(onMessage: ((String) -> Void)?) {
            self.onMessage = onMessage
        }

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            onMessage?(message.body as? String ?? message.name)
        }

        // Auto-grant camera/mic so the embed's video call can start without
        // an extra WKWebView prompt on top of the iOS-level permission.
        func webView(
            _ webView: WKWebView,
            requestMediaCapturePermissionFor origin: WKSecurityOrigin,
            initiatedByFrame frame: WKFrameInfo,
            type: WKMediaCaptureType,
            decisionHandler: @escaping (WKPermissionDecision) -> Void
        ) {
            decisionHandler(.grant)
        }
    }
}
