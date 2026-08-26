//
//  BambuserCallController.swift
//  BambuserCallsShopper
//

import SwiftUI
import WebKit

/// Owns the embed lifecycle, observable state, and the JS bridge.
/// Host code holds one as a `@StateObject`, assigns handlers +
/// delegate, drops a `BambuserCallOverlay` in its view tree, and
/// calls `show(...)`.
///
/// The handler set is snapshotted at `show()`; the SDK only wires
/// the JS `.on(...)` subscriptions for events that have a non-nil
/// handler.
@MainActor
public final class BambuserCallController: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var isVisible: Bool = false
    @Published public private(set) var isPiP: Bool = false
    @Published public private(set) var pipPresentation: PipPresentation = .floating
    @Published public private(set) var orgId: String?
    @Published public private(set) var callState: CallState = .idle
    @Published public private(set) var connectId: String?
    @Published public private(set) var queue: String?

    // MARK: - Configuration

    public let configuration: BambuserCallConfiguration
    @Published public var environment: BambuserEnvironment

    internal var embedUrl: URL { environment.embedURL }

    /// Data-source closures. Frozen at `show()` — reassigning
    /// mid-session takes effect on the next `show()`.
    public var handlers: BambuserCallHandlers {
        get { publicHandlers }
        set {
            publicHandlers = newValue
            if isVisible {
                print("[BambuserCall] handlers changed during an active session — changes take effect at next show()")
            }
        }
    }
    private var publicHandlers: BambuserCallHandlers = BambuserCallHandlers()

    /// Fire-and-forget event stream. Weak — the host holds the
    /// strong reference.
    public weak var delegate: (any BambuserCallDelegate)?

    /// Frozen snapshot used by the router.
    internal private(set) var activeHandlers: BambuserCallHandlers = BambuserCallHandlers()

    /// JS subscriptions installed for the current session.
    internal private(set) var activeSubscriptions: BambuserCallSubscriptions = BambuserCallSubscriptions(
        handlers: BambuserCallHandlers(),
        forwardUnknownEmbedEvents: false
    )

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
        self.environment = configuration.environment
    }

    // MARK: - Lifecycle

    /// Mount the overlay and start an expert-chat session. Freezes
    /// the current `handlers` snapshot.
    public func show(
        orgId: String? = nil,
        connectId: String? = nil,
        queue: String? = nil
    ) {
        self.orgId = orgId ?? configuration.orgId
        self.connectId = connectId
        self.queue = queue

        activeHandlers = publicHandlers
        activeSubscriptions = BambuserCallSubscriptions(
            handlers: publicHandlers,
            forwardUnknownEmbedEvents: configuration.forwardUnknownEmbedEvents
        )

        self.isVisible = true
        self.isPiP = false
    }

    public func close() {
        isVisible = false
        isPiP = false
        orgId = nil
        connectId = nil
        queue = nil
        callState = .idle
        cancelPendingAsyncInvokes(reason: "call closed")
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

    // MARK: - Outbound (host → embed)

    /// Echo a host-side product navigation back into the embed.
    /// No-op when no call is active.
    public func notifyProductNavigation(externalId: String) {
        guard isCallActive else {
            print("[BambuserCall] skipping notifyProductNavigation('\(externalId)') — call inactive (state=\(callState))")
            return
        }
        let escaped = JSEscape.escape(externalId)
        let js = "window.notifyBambuserProductNavigation('\(escaped)')"
        evaluate(js, operation: "notifyProductNavigation('\(externalId)')")
    }

    // MARK: - Generic invoke (fire-and-forget)

    /// Call a method on the live `oneToOneEmbed` instance, optionally
    /// appending a builder callback derived from a `BambuserFactorySpec`.
    public func invoke(
        embedMethod: String,
        primaryArgs: [BambuserJSONValue] = [],
        factorySpec: BambuserFactorySpec? = nil
    ) {
        guard webView != nil else {
            print("[BambuserCall] invoke(embedMethod: \(embedMethod)) — webView not ready")
            return
        }

        guard
            let argsJSON = encodeJS(primaryArgs, operation: "invoke(embedMethod: \(embedMethod))")
        else { return }

        let specJSON: String
        if let factorySpec {
            guard
                let spec = encodeJS(factorySpec, operation: "invoke(embedMethod: \(embedMethod))")
            else { return }
            specJSON = spec
        } else {
            specJSON = "null"
        }

        let escapedName = JSEscape.escape(embedMethod)
        let js = "window.__bambuserInvokeEmbedMethod('\(escapedName)', \(argsJSON), \(specJSON));"
        evaluate(js, operation: "invoke(embedMethod: \(embedMethod))")
    }

    /// Call an embed method with a throwing callback appended as the
    /// last argument. Used by `provideProductError`.
    internal func invokeEmbedMethodWithError(
        embedMethod: String,
        primaryArgs: [BambuserJSONValue],
        errorMessage: String
    ) {
        guard webView != nil else {
            print("[BambuserCall] invokeEmbedMethodWithError(\(embedMethod)) — webView not ready")
            return
        }
        guard
            let argsJSON = encodeJS(primaryArgs, operation: "invokeEmbedMethodWithError(\(embedMethod))")
        else { return }

        let escapedName = JSEscape.escape(embedMethod)
        let escapedMsg  = JSEscape.escape(errorMessage)
        let js = "window.__bambuserInvokeEmbedMethodWithError('\(escapedName)', \(argsJSON), '\(escapedMsg)');"
        evaluate(js, operation: "invokeEmbedMethodWithError(\(embedMethod))")
    }

    /// Invoke a stashed callback with a throwing builder. Used by
    /// `provideSearchError`.
    internal func applyErrorToCallback(
        callbackKey: String,
        errorMessage: String,
        deleteAfterUse: Bool = true
    ) {
        guard webView != nil else {
            print("[BambuserCall] applyErrorToCallback(\(callbackKey)) — webView not ready")
            return
        }
        let escapedKey = JSEscape.escape(callbackKey)
        let escapedMsg = JSEscape.escape(errorMessage)
        let js = "window.__bambuserApplyToCallbackWithError('\(escapedKey)', '\(escapedMsg)', \(deleteAfterUse ? "true" : "false"));"
        evaluate(js, operation: "applyErrorToCallback(\(callbackKey))")
    }

    /// Reply to a live callback the embed handed us.
    public func invoke(
        callback callbackKey: String,
        factorySpec: BambuserFactorySpec,
        deleteAfterUse: Bool = true
    ) {
        guard webView != nil else {
            print("[BambuserCall] invoke(callback: \(callbackKey)) — webView not ready")
            return
        }

        guard
            let specJSON = encodeJS(factorySpec, operation: "invoke(callback: \(callbackKey))")
        else { return }

        let escapedKey = JSEscape.escape(callbackKey)
        let js = "window.__bambuserApplyToCallback('\(escapedKey)', \(specJSON), \(deleteAfterUse ? "true" : "false"));"
        evaluate(js, operation: "invoke(callback: \(callbackKey))")
    }

    // MARK: - Async invoke

    @discardableResult
    public func invoke(
        async embedMethod: String,
        primaryArgs: [BambuserJSONValue] = []
    ) async throws -> BambuserJSONValue {
        guard webView != nil else {
            throw BambuserCallError.javaScriptEvaluationFailed(
                operation: "invoke(async: \(embedMethod))",
                underlying: NSError(
                    domain: "BambuserCall", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "webView not ready"]
                )
            )
        }

        asyncInvokeSeq &+= 1
        let requestId = "async_\(asyncInvokeSeq)"
        let argsJSON = encodeJS(primaryArgs, operation: "invoke(async: \(embedMethod))") ?? "[]"
        let escapedName = JSEscape.escape(embedMethod)
        let escapedId = JSEscape.escape(requestId)
        let js = "window.__bambuserInvokeEmbedAsync('\(escapedId)', '\(escapedName)', \(argsJSON));"

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<BambuserJSONValue, Error>) in
            pendingAsyncInvokes[requestId] = continuation
            webView?.evaluateJavaScript(js) { [weak self] _, error in
                guard let error else { return }
                Task { @MainActor [weak self] in
                    if let cont = self?.pendingAsyncInvokes.removeValue(forKey: requestId) {
                        cont.resume(throwing: BambuserCallError.javaScriptEvaluationFailed(
                            operation: "invoke(async: \(embedMethod))",
                            underlying: error
                        ))
                    }
                }
            }
        }
    }

    // MARK: - Provide product / search data

    /// Reply to `provide-product-data` for a single ref.
    public func provideProductData(bambuserId: String, factorySpec: BambuserFactorySpec) {
        invoke(
            embedMethod: "updateProduct",
            primaryArgs: [.string(bambuserId)],
            factorySpec: factorySpec
        )
    }

    /// Reply to `provide-product-data` with an agent-visible error
    /// (the "we don't sell that" pattern).
    public func provideProductError(bambuserId: String, message: String) {
        invokeEmbedMethodWithError(
            embedMethod: "updateProduct",
            primaryArgs: [.string(bambuserId)],
            errorMessage: message
        )
    }

    /// Reply to `provide-search-data` using the callback key from the request.
    public func provideSearchData(callbackKey: String, factorySpec: BambuserFactorySpec) {
        invoke(callback: callbackKey, factorySpec: factorySpec)
    }

    /// Reply to `provide-search-data` with an agent-visible error.
    public func provideSearchError(callbackKey: String, message: String) {
        applyErrorToCallback(callbackKey: callbackKey, errorMessage: message)
    }

    // MARK: - Shopper activity

    /// Report a shopper-driven event to the agent's widget.
    /// - Parameters:
    ///   - eventKey: Constant name on `BambuserOneToOneEmbed.CUSTOMER_EVENTS`
    ///     (e.g. `"ADDED_TO_CART"`). Looked up at call time — future
    ///     keys work without an SDK update.
    ///   - payload: The event body (typically `{sku, quantity, ...}`).
    public func notifyCustomerEvent(_ eventKey: String, payload: BambuserJSONValue) {
        guard webView != nil else {
            print("[BambuserCall] notifyCustomerEvent(\(eventKey)) — webView not ready")
            return
        }
        guard
            let payloadJSON = encodeJS(payload, operation: "notifyCustomerEvent(\(eventKey))")
        else { return }
        let escaped = JSEscape.escape(eventKey)
        let js = "window.__bambuserNotifyCustomerEvent('\(escaped)', \(payloadJSON));"
        evaluate(js, operation: "notifyCustomerEvent(\(eventKey))")
    }

    // MARK: - Customer data / tracking tags / queue / widget control

    /// Update the customer data the agent sees. Pass `nil` to trigger
    /// a refresh via the initial `data` function.
    public func updateData(_ data: BambuserJSONValue? = nil) {
        if let data {
            invoke(embedMethod: "updateData", primaryArgs: [data])
        } else {
            invoke(embedMethod: "updateData")
        }
    }

    public func setTrackingTags(_ tags: [BambuserTrackingTag]) {
        invoke(embedMethod: "setTrackingTags", primaryArgs: [tags.toJSONArray()])
    }

    public func setQueue(_ queueTerm: String) {
        invoke(embedMethod: "setQueue", primaryArgs: [.string(queueTerm)])
        self.queue = queueTerm
    }

    public func areQueuesOpen() async throws -> BambuserQueueOpenState {
        let result = try await invoke(async: "areQueuesOpen")
        return decodeQueueOpenState(result)
    }

    public func getNumberOfOnlineAgents(queue: String? = nil) async throws -> BambuserAgentsOnline {
        let args: [BambuserJSONValue] = queue.map { [.string($0)] } ?? []
        let result = try await invoke(async: "getNumberOfOnlineAgents", primaryArgs: args)
        return decodeAgentsOnline(result)
    }

    public func getEstimatedWaitingTime(queue: String? = nil) async throws -> BambuserQueueWaitingTime {
        let args: [BambuserJSONValue] = queue.map { [.string($0)] } ?? []
        let result = try await invoke(async: "getEstimatedWaitingTime", primaryArgs: args)
        return decodeWaitingTime(result)
    }

    public func destroy() {
        invoke(embedMethod: "destroy")
        close()
    }

    public func floatAbove(url: String? = nil) {
        let args: [BambuserJSONValue] = url.map { [.string($0)] } ?? []
        invoke(embedMethod: "floatAbove", primaryArgs: args)
    }

    public func updateElement(_ element: BambuserElement, state: BambuserElementState?) {
        let payload: BambuserJSONValue = state?.jsonValue ?? .null
        invoke(embedMethod: "updateElement", primaryArgs: [.string(element.rawValue), payload])
    }

    // MARK: - Generic notify

    /// Call a JS function registered on `window` by name, passing
    /// `info` inline.
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

    // MARK: - Internal hooks

    internal func setCallState(_ newState: CallState) {
        guard callState != newState else { return }
        print("[BambuserCall] callState: \(callState) → \(newState)")
        if newState == .ended {
            if configuration.dismissOnCallEnd {
                close()
            } else {
                callState = newState
            }
            emitEvent(.callStateChanged(.ended))
            return
        }
        callState = newState
        if newState == .connected, isPiP, configuration.autoExpandOnConnect {
            expand()
        }
        emitEvent(.callStateChanged(newState))
    }

    internal func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    internal func reportError(_ error: BambuserCallError) {
        delegate?.bambuserCall(self, didEncounter: error)
    }

    internal func emitEvent(_ event: BambuserCallEvent) {
        delegate?.bambuserCall(self, didEmit: event)
    }

    private func emitPresentationChange() {
        emitEvent(.presentationChanged(isPiP: isPiP, presentation: pipPresentation))
    }

    // MARK: - Async invoke plumbing

    private var asyncInvokeSeq: UInt = 0
    private var pendingAsyncInvokes: [String: CheckedContinuation<BambuserJSONValue, Error>] = [:]

    internal func resolveAsyncInvoke(payload: [String: Any]?) {
        guard let payload, let requestId = payload["requestId"] as? String else { return }
        guard let cont = pendingAsyncInvokes.removeValue(forKey: requestId) else { return }
        let ok = (payload["ok"] as? Bool) ?? false
        if ok {
            let value = decodeJSONValue(payload["value"]) ?? .null
            cont.resume(returning: value)
        } else {
            let message = (payload["error"] as? String) ?? "unknown error"
            cont.resume(throwing: BambuserCallError.javaScriptEvaluationFailed(
                operation: "invoke(async)",
                underlying: NSError(
                    domain: "BambuserCall", code: -2,
                    userInfo: [NSLocalizedDescriptionKey: message]
                )
            ))
        }
    }

    private func cancelPendingAsyncInvokes(reason: String) {
        guard !pendingAsyncInvokes.isEmpty else { return }
        let dead = pendingAsyncInvokes
        pendingAsyncInvokes.removeAll()
        let err = BambuserCallError.javaScriptEvaluationFailed(
            operation: "invoke(async)",
            underlying: NSError(
                domain: "BambuserCall", code: -3,
                userInfo: [NSLocalizedDescriptionKey: reason]
            )
        )
        for (_, cont) in dead { cont.resume(throwing: err) }
    }

    // MARK: - JSON helpers

    private func encodeJS<T: Encodable>(_ value: T, operation: String) -> String? {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(value)
            return String(data: data, encoding: .utf8)
        } catch {
            print("[BambuserCall] \(operation) encode failed: \(error)")
            delegate?.bambuserCall(self, didEncounter: .javaScriptEvaluationFailed(operation: operation, underlying: error))
            return nil
        }
    }

    private func evaluate(_ js: String, operation: String) {
        webView?.evaluateJavaScript(js) { [weak self] _, error in
            guard let self, let error else { return }
            print("[BambuserCall] \(operation) failed: \(error)")
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.delegate?.bambuserCall(self, didEncounter: .javaScriptEvaluationFailed(operation: operation, underlying: error))
            }
        }
    }
}

// MARK: - JS escape

internal enum JSEscape {
    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
            .replacingOccurrences(of: "\n", with: "\\n")
    }
}

// MARK: - Custom elements

public enum BambuserElement: String, Sendable, CaseIterable {
    case dropInCard = "drop-in-card"
    case bookingCard = "book-meeting-card"
}

public struct BambuserElementState: Equatable, Sendable {

    public var disableCTA: Bool?
    public var title: String?
    public var subtitle: String?
    public var buttonText: String?

    public init(
        disableCTA: Bool? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        buttonText: String? = nil
    ) {
        self.disableCTA = disableCTA
        self.title = title
        self.subtitle = subtitle
        self.buttonText = buttonText
    }

    var jsonValue: BambuserJSONValue {
        var out: [String: BambuserJSONValue] = [:]
        if let disableCTA { out["disableCTA"] = .bool(disableCTA) }
        var content: [String: BambuserJSONValue] = [:]
        if let title      { content["title"]      = .string(title) }
        if let subtitle   { content["subtitle"]   = .string(subtitle) }
        if let buttonText { content["buttonText"] = .string(buttonText) }
        if !content.isEmpty {
            out["content"] = .object(content)
        }
        return .object(out)
    }
}

// MARK: - Decoding helpers

@MainActor
internal func decodeQueueOpenState(_ value: BambuserJSONValue) -> BambuserQueueOpenState {
    guard case .object(let m) = value else {
        return BambuserQueueOpenState(isOpen: false)
    }
    let isOpen: Bool = {
        if case .bool(let b) = m["isOpen"] ?? .null { return b }
        return false
    }()
    return BambuserQueueOpenState(
        isOpen: isOpen,
        nextOpenTime:  isoDate(from: m["nextOpenTime"]),
        nextCloseTime: isoDate(from: m["nextCloseTime"])
    )
}

@MainActor
internal func decodeAgentsOnline(_ value: BambuserJSONValue) -> BambuserAgentsOnline {
    guard case .object(let m) = value else {
        return BambuserAgentsOnline(numberOfAgentsOnline: 0)
    }
    let n: Int = {
        if case .int(let i)    = m["numberOfAgentsOnline"] ?? .null { return i }
        if case .double(let d) = m["numberOfAgentsOnline"] ?? .null { return Int(d) }
        return 0
    }()
    var queueId: String?
    if case .string(let s) = m["queueId"] ?? .null { queueId = s }
    return BambuserAgentsOnline(numberOfAgentsOnline: n, queueId: queueId)
}

@MainActor
internal func decodeWaitingTime(_ value: BambuserJSONValue) -> BambuserQueueWaitingTime {
    guard case .object(let m) = value else {
        return BambuserQueueWaitingTime(estimatedWaitingTime: 0, agents: 0, place: 0)
    }
    func intField(_ key: String) -> Int {
        if case .int(let i)    = m[key] ?? .null { return i }
        if case .double(let d) = m[key] ?? .null { return Int(d) }
        return 0
    }
    var queueId: String?
    if case .string(let s) = m["queueId"] ?? .null { queueId = s }
    return BambuserQueueWaitingTime(
        estimatedWaitingTime: intField("estimatedWaitingTime"),
        agents: intField("agents"),
        place:  intField("place"),
        queueId: queueId
    )
}

@MainActor
private func isoDate(from value: BambuserJSONValue?) -> Date? {
    guard case .string(let s) = value ?? .null, !s.isEmpty else { return nil }
    let f1 = ISO8601DateFormatter()
    f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f1.date(from: s) { return d }
    let f2 = ISO8601DateFormatter()
    f2.formatOptions = [.withInternetDateTime]
    return f2.date(from: s)
}

@MainActor
internal func decodeJSONValue(_ any: Any?) -> BambuserJSONValue? {
    guard let any else { return nil }
    switch any {
    case is NSNull:                    return .null
    case let b as Bool:                 return .bool(b)
    case let i as Int:                  return .int(i)
    case let d as Double:               return .double(d)
    case let s as String:               return .string(s)
    case let arr as [Any]:              return .array(arr.compactMap { decodeJSONValue($0) })
    case let obj as [String: Any]:
        var m: [String: BambuserJSONValue] = [:]
        for (k, v) in obj { if let jv = decodeJSONValue(v) { m[k] = jv } }
        return .object(m)
    default:                            return nil
    }
}
