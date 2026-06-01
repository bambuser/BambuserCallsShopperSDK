//
//  BambuserCallController.swift
//  BambuserCallsShopper
//

import SwiftUI
import WebKit

/// Owns the embed lifecycle, observable state, and the JS bridge.
///
/// Host code typically holds one as a `@StateObject`, fills in a
/// `BambuserCallHandlers` struct with the closures it wants, drops a
/// `BambuserCallOverlay` in its view tree, and calls `show(...)`.
///
/// The handler set is snapshotted at `show()`; the SDK only wires the
/// JS `.on(...)` subscriptions for events that have a non-nil handler,
/// so unsubscribed events never cross the bridge.
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
    @Published public var embedUrl: URL

    /// Register the closures you want called when the embed fires an
    /// event or asks for data. Only non-nil closures result in a JS
    /// `.on(...)` subscription.
    ///
    /// **Mutation semantics**: the handler set is frozen at `show()`
    /// time. Reassigning `handlers` mid-session logs a warning and has
    /// no effect until the next `show()`. This is intentional — the JS
    /// subscription set is committed to the embed HTML at load time.
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

    /// Frozen snapshot used by the router. Same value as `handlers` at
    /// `show()` time; unchanged for the lifetime of the session.
    internal private(set) var activeHandlers: BambuserCallHandlers = BambuserCallHandlers()

    /// Which JS subscriptions the current HTML installed. Also frozen
    /// at `show()`.
    internal private(set) var activeSubscriptions: BambuserCallSubscriptions = BambuserCallSubscriptions(
        from: BambuserCallHandlers()
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
        self.embedUrl = configuration.embedUrl
    }

    // MARK: - Lifecycle

    /// Mount the overlay and start an expert-chat session. Freezes the
    /// current `handlers` snapshot for this session.
    public func show(
        orgId: String? = nil,
        embedUrl: URL? = nil,
        connectId: String? = nil,
        queue: String? = nil
    ) {
        if let embedUrl { self.embedUrl = embedUrl }
        self.orgId = orgId ?? configuration.orgId
        self.connectId = connectId
        self.queue = queue

        // Freeze the handler snapshot & derived subscription mask.
        activeHandlers = publicHandlers
        activeSubscriptions = BambuserCallSubscriptions(from: publicHandlers)

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
        // Any outstanding async invoke continuations are orphaned when the
        // WebView dies — cancel them so awaiting Tasks get a clean error.
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

    /// Echo a host-side product navigation back into the embed. No-op
    /// when no call is active.
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

    // MARK: - Async invoke (returns embed method's promise result)

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
            // Store first, evaluate second — main-actor serial guarantees
            // the store is visible before any response can arrive.
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

    // MARK: - Convenience: provide-product-data / provide-search-data

    /// Reply to the `provide-product-data` event for a single ref.
    /// Thin wrapper around
    /// `invoke(embedMethod: "updateProduct", primaryArgs: [.string(bambuserId)], factorySpec: spec)`.
    /// Build the spec on the host side from whatever product model you
    /// use — the SDK doesn't know or care what shape it has.
    public func provideProductData(bambuserId: String, factorySpec: BambuserFactorySpec) {
        invoke(
            embedMethod: "updateProduct",
            primaryArgs: [.string(bambuserId)],
            factorySpec: factorySpec
        )
    }

    /// Reply to the `provide-search-data` event using the callback key
    /// carried on the request. Thin wrapper around
    /// `invoke(callback: callbackKey, factorySpec: spec)`.
    public func provideSearchData(callbackKey: String, factorySpec: BambuserFactorySpec) {
        invoke(callback: callbackKey, factorySpec: factorySpec)
    }

    // MARK: - Shopper activity (notifyCustomerEvent)

    /// Report a shopper-driven event to the agent's widget without
    /// going through the dataLayer interceptor. Pair with
    /// `configuration.disableDataLayerInterceptions = true` (SDK
    /// default) so there's exactly one authoritative source per
    /// shopper action.
    ///
    /// Fire-and-forget: safe to call at any time. The embed drops the
    /// message when no call is running.
    ///
    /// - Parameters:
    ///   - eventKey: The **constant name** on
    ///     `BambuserOneToOneEmbed.CUSTOMER_EVENTS` (e.g.
    ///     `"ADDED_TO_CART"`). The SDK's JS helper looks it up at call
    ///     time — future keys work without an SDK update.
    ///   - payload: The event body. Shape it however the embed expects
    ///     for the given key (typically `{sku, quantity, ...}`).
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

    // MARK: - Customer data / tracking tags / queue / widget control / elements

    /// Update the customer data the agent sees. Shape the payload on
    /// the host side — usually a `.object([...])` of built-in fields
    /// (`externalId`, `firstName`, `lastName`, `email`, `phone`) plus
    /// any custom flat properties. Pass `nil` to trigger a refresh
    /// via the initial `data` function configured at init.
    public func updateData(_ data: BambuserJSONValue? = nil) {
        if let data, case .object(let map) = data, !map.isEmpty {
            invoke(embedMethod: "updateData", primaryArgs: [data])
        } else if let data {
            // Non-object payloads still get forwarded — the embed will
            // reject them, but that's the embed's contract, not ours.
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

    /// Call a JS function registered on `window` by name, passing `info`
    /// inline. Used by cart-callback replies and for anything else that
    /// stashed a raw function on window.
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

    // MARK: - Internal state hooks

    internal func setCallState(_ newState: CallState) {
        guard callState != newState else { return }
        print("[BambuserCall] callState: \(callState) → \(newState)")
        if newState == .ended {
            let handler = activeHandlers.onCallStateChanged
            if configuration.dismissOnCallEnd {
                close()
            } else {
                callState = newState
            }
            handler?(.ended)
            return
        }
        callState = newState
        if newState == .connected, isPiP, configuration.autoExpandOnConnect {
            expand()
        }
        activeHandlers.onCallStateChanged?(newState)
    }

    internal func attach(_ webView: WKWebView) {
        self.webView = webView
    }

    internal func reportError(_ error: BambuserCallError) {
        activeHandlers.onError?(error)
    }

    private func emitPresentationChange() {
        activeHandlers.onPresentationChanged?(isPiP, pipPresentation)
    }

    // MARK: - Async invoke plumbing

    private var asyncInvokeSeq: UInt = 0
    private var pendingAsyncInvokes: [String: CheckedContinuation<BambuserJSONValue, Error>] = [:]

    /// Called by the router when a `__async-response` event arrives.
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

    /// Cancel every outstanding async-invoke continuation with an error.
    /// Called on `close()` so awaiting Tasks unblock instead of leaking.
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
            activeHandlers.onError?(.javaScriptEvaluationFailed(operation: operation, underlying: error))
            return nil
        }
    }

    private func evaluate(_ js: String, operation: String) {
        webView?.evaluateJavaScript(js) { [weak self] _, error in
            guard let self, let error else { return }
            print("[BambuserCall] \(operation) failed: \(error)")
            Task { @MainActor [weak self] in
                self?.activeHandlers.onError?(.javaScriptEvaluationFailed(operation: operation, underlying: error))
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
