//
//  EmbedEventRouter.swift
//  BambuserCallsShopper
//

import Foundation

@MainActor
internal struct EmbedEventRouter {

    let controller: BambuserCallController

    private var handlers: BambuserCallHandlers { controller.activeHandlers }
    private var delegate: (any BambuserCallDelegate)? { controller.delegate }

    func handle(rawMessage: String) {
        guard
            let data = rawMessage.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let event = json["event"] as? String
        else { return }
        print("event, \(event)")

        switch event {
        // Always subscribed by the SDK

        case "close":
            controller.close()
            emit(.close)

        case "iframe-message":
            handleIframeMessage(detail: json["detail"] as? String ?? "")

        case "__async-response":
            controller.resolveAsyncInvoke(payload: json["payload"] as? [String: Any])

        case "call-connecting", "call-ringing":
            controller.setCallState(.connecting)

        case "call-starting", "call-started",
             "call-connected", "call-active", "call-accepted", "connected":
            controller.setCallState(.connected)

        case "call-ended", "call-end", "call-disconnected", "call-rejected",
             "disconnected", "ended":
            controller.setCallState(.ended)

        // Fire-and-forget → delegate

        case "goto-checkout":
            emit(.checkout(cart: jsonValue(from: json["payload"]) ?? .null))

        case "goto-chat":
            emit(.chatRequested)

        case "surf-behind-to":
            let payload = jsonValue(from: json["payload"]) ?? .null
            if case .object(let m) = payload,
               case .string(let s) = m["url"] ?? .null,
               let url = URL(string: s) {
                emit(.navigateTo(url: url))
            }

        case "queue-is-open":
            emit(.queueOpened(parseQueueOpenState(json["payload"], isOpen: true)))

        case "queue-is-closed":
            emit(.queueClosed(parseQueueOpenState(json["payload"], isOpen: false)))

        case "agents-online":
            emit(.agentsOnlineChanged(parseAgentsOnline(json["payload"])))

        case "queue-estimated-waiting-time":
            emit(.waitingTimeChanged(parseWaitingTime(json["payload"])))

        case "tracking-event":
            emit(.trackingEvent(parseTrackingEvent(json["payload"])))

        // Data-source (needs a reply) → handlers

        case "should-add-item-to-cart":
            routeCartIntent(payload: json["payload"], add: true)

        case "should-update-item-in-cart":
            routeCartIntent(payload: json["payload"], add: false)

        case "provide-product-data":
            routeProvideProductData(payload: jsonValue(from: json["payload"]) ?? .null)

        case "provide-search-data":
            routeProvideSearchData(payload: jsonValue(from: json["payload"]) ?? .null)

        // Catch-all — forwarded only if forwardUnknownEmbedEvents is true
        default:
            emit(.other(name: event, payload: jsonValue(from: json["payload"]) ?? .null))
        }
    }

    private func emit(_ event: BambuserCallEvent) {
        delegate?.bambuserCall(controller, didEmit: event)
    }

    // MARK: - Async data-source routing

    private func routeProvideProductData(payload: BambuserJSONValue) {
        guard let handler = handlers.provideProductData else { return }
        let refs = BambuserProductRef.decode(from: payload)
        for ref in refs {
            let ctrl = controller
            Task { @MainActor in
                switch await handler(ref) {
                case .reply(let spec):
                    ctrl.provideProductData(bambuserId: ref.bambuserId, factorySpec: spec)
                case .error(let message):
                    ctrl.provideProductError(bambuserId: ref.bambuserId, message: message)
                case .skip:
                    break
                }
            }
        }
    }

    private func routeProvideSearchData(payload: BambuserJSONValue) {
        guard let handler = handlers.provideSearchData else { return }
        guard let request = BambuserSearchRequest.decode(from: payload) else {
            controller.reportError(.invalidEventPayload(
                eventName: "provide-search-data",
                reason: "missing callbackId — cannot reply"
            ))
            return
        }
        let ctrl = controller
        Task { @MainActor in
            switch await handler(request) {
            case .reply(let spec):
                ctrl.provideSearchData(callbackKey: request.callbackKey, factorySpec: spec)
            case .error(let message):
                ctrl.provideSearchError(callbackKey: request.callbackKey, message: message)
            case .skip:
                break
            }
        }
    }

    // MARK: - Cart intent routing

    private func routeCartIntent(payload: Any?, add: Bool) {
        let handler: (@MainActor (BambuserCartIntent) async -> BambuserReply<BambuserJSONValue>)? =
            add ? handlers.shouldAddToCart : handlers.shouldUpdateCart
        guard let handler else { return }

        guard
            let dict = payload as? [String: Any],
            let callbackKey = dict["callbackId"] as? String,
            let inner = dict["payload"] as? [String: Any]
        else {
            controller.reportError(.invalidEventPayload(
                eventName: add ? "should-add-item-to-cart" : "should-update-item-in-cart",
                reason: "missing callbackId or payload envelope"
            ))
            return
        }

        let sku = (inner["sku"] as? String)
            ?? ((inner["item"] as? [String: Any])?["sku"] as? String)
            ?? ""
        let quantity = (inner["count"] as? Int)
            ?? (inner["quantity"] as? Int)
            ?? 1
        let previousQuantity = inner["previousQuantity"] as? Int
        let raw = jsonValue(from: inner) ?? .null

        let intent = BambuserCartIntent(
            sku: sku,
            quantity: quantity,
            previousQuantity: previousQuantity,
            raw: raw
        )

        let ctrl = controller
        Task { @MainActor in
            switch await handler(intent) {
            case .reply(let value):
                ctrl.notify(callbackKey: callbackKey, info: jsonLiteral(value))
            case .error(let message):
                // Cart callbacks accept a value, not a builder — map
                // errors to `{success:false, reason}`.
                let obj: BambuserJSONValue = .object([
                    "success": .bool(false),
                    "reason":  .string(message),
                ])
                ctrl.notify(callbackKey: callbackKey, info: jsonLiteral(obj))
            case .skip:
                break
            }
        }
    }

    private func jsonLiteral(_ value: BambuserJSONValue) -> String {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(value),
           let s = String(data: data, encoding: .utf8) {
            return s
        }
        return "null"
    }

    // MARK: - Iframe message

    private func handleIframeMessage(detail: String) {
        guard
            let data = detail.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let eventType = json["eventType"] as? String
        else { return }

        print("handleIframeMessage: \(eventType)")
        switch eventType {
        case "viddget:viewport_mode":
            guard let mode = json["data"] as? String else { return }
            switch mode {
            case "normal", "centerModal":
                controller.expand()
            case "floatingLeftMinimized", "floatingRightMinimized":
                controller.enterPiP(presentation: .minimized)
            case let m where m.hasPrefix("floating"):
                controller.enterPiP(presentation: .floating)
            default:
                break
            }

        case "viddget:forwarded_event":
            guard
                let forwarded = json["data"] as? [String: Any],
                let eventName = forwarded["eventName"] as? String
            else { return }
            guard controller.activeSubscriptions.catchAllOther else { return }
            emit(.other(name: eventName, payload: jsonValue(from: forwarded["data"]) ?? .null))

        default:
            break
        }
    }

    // MARK: - Payload parsers

    private func parseQueueOpenState(_ payload: Any?, isOpen: Bool) -> BambuserQueueOpenState {
        let dict = payload as? [String: Any] ?? [:]
        return BambuserQueueOpenState(
            isOpen: (dict["isOpen"] as? Bool) ?? isOpen,
            nextOpenTime: parseISODate(dict["nextOpenTime"]),
            nextCloseTime: parseISODate(dict["nextCloseTime"]),
            raw: jsonValue(from: payload) ?? .null
        )
    }

    private func parseAgentsOnline(_ payload: Any?) -> BambuserAgentsOnline {
        let dict = payload as? [String: Any] ?? [:]
        return BambuserAgentsOnline(
            numberOfAgentsOnline: (dict["numberOfAgentsOnline"] as? Int) ?? 0,
            queueId: dict["queueId"] as? String,
            raw: jsonValue(from: payload) ?? .null
        )
    }

    private func parseWaitingTime(_ payload: Any?) -> BambuserQueueWaitingTime {
        let dict = payload as? [String: Any] ?? [:]
        return BambuserQueueWaitingTime(
            estimatedWaitingTime: (dict["estimatedWaitingTime"] as? Int) ?? 0,
            agents: (dict["agents"] as? Int) ?? 0,
            place:  (dict["place"]  as? Int) ?? 0,
            queueId: dict["queueId"] as? String,
            raw: jsonValue(from: payload) ?? .null
        )
    }

    private func parseTrackingEvent(_ payload: Any?) -> BambuserTrackingEvent {
        let dict = payload as? [String: Any] ?? [:]
        let raw = jsonValue(from: payload) ?? .object([:])
        return BambuserTrackingEvent(
            eventName: dict["eventName"] as? String,
            eventData: jsonValue(from: dict["eventData"]),
            ga4Event:  dict["event"] as? String,
            ga4Ecommerce: jsonValue(from: dict["ecommerce"]),
            raw: raw
        )
    }

    private func parseISODate(_ any: Any?) -> Date? {
        guard let s = any as? String, !s.isEmpty else { return nil }
        let f1 = ISO8601DateFormatter()
        f1.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = f1.date(from: s) { return d }
        let f2 = ISO8601DateFormatter()
        f2.formatOptions = [.withInternetDateTime]
        return f2.date(from: s)
    }

    private func jsonValue(from any: Any?) -> BambuserJSONValue? {
        guard let any else { return nil }
        switch any {
        case is NSNull:                  return .null
        case let b as Bool:               return .bool(b)
        case let i as Int:                return .int(i)
        case let d as Double:             return .double(d)
        case let s as String:             return .string(s)
        case let arr as [Any]:            return .array(arr.compactMap { jsonValue(from: $0) })
        case let obj as [String: Any]:
            var m: [String: BambuserJSONValue] = [:]
            for (k, v) in obj { if let jv = jsonValue(from: v) { m[k] = jv } }
            return .object(m)
        default:                          return nil
        }
    }
}
