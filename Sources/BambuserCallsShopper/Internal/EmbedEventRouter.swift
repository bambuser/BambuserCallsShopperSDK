//
//  EmbedEventRouter.swift
//  BambuserCallsShopper
//

import Foundation

@MainActor
internal struct EmbedEventRouter {

    let controller: BambuserCallController
    var delegate: (any BambuserCallDelegate)? { controller.delegate }

    func handle(rawMessage: String) {
        guard
            let data = rawMessage.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let event = json["event"] as? String
        else { return }

        switch event {
        case "close":
            controller.close()
            emit(.close)

        case "goto-checkout":
            emit(.checkout(cart: json["payload"] as? [String: Any]))

        case "call-started", "call-starting", "call-connecting", "call-ringing":
            controller.setCallState(.connecting)

        case "call-connected", "call-active", "call-accepted", "connected":
            controller.setCallState(.connected)

        case "call-ended", "call-end", "call-disconnected", "call-rejected",
             "disconnected", "ended":
            controller.setCallState(.ended)

        case "should-add-item-to-cart":
            handleCartIntent(json["payload"], eventName: event, add: true)

        case "should-update-item-in-cart":
            handleCartIntent(json["payload"], eventName: event, add: false)

        case "iframe-message":
            handleIframeMessage(detail: json["detail"] as? String ?? "")

        default:
            emit(.other(name: event, payload: json["payload"]))
        }
    }

    private func handleIframeMessage(detail: String) {
        guard
            let data = detail.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let eventType = json["eventType"] as? String
        else { return }

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
            handleForwardedEvent(name: eventName, data: forwarded["data"])

        default:
            break
        }
    }

    private func handleForwardedEvent(name: String, data: Any?) {
        switch name {
        case "navigate-to":
            guard let payload = data as? [String: Any] else {
                emit(error: .invalidEventPayload(eventName: name, reason: "payload not a dictionary"))
                return
            }
            guard let externalId = unwrapExternalId(from: payload) else {
                emit(error: .invalidEventPayload(eventName: name, reason: "no externalId / url found"))
                return
            }
            emit(.navigateTo(externalId: externalId))

        default:
            emit(.other(name: name, payload: data))
        }
    }

    private func unwrapExternalId(from payload: [String: Any]) -> String? {
        if let str = payload["externalId"] as? String, !str.isEmpty { return str }
        if let dict = payload["externalId"] as? [String: Any] {
            if let id = dict["id"] as? String, !id.isEmpty { return id }
            if let id = dict["id"] as? Int { return String(id) }
        }
        if let urlString = payload["url"] as? String, let url = URL(string: urlString) {
            let slug = url.pathComponents.reversed().first(where: { !$0.isEmpty && $0 != "/" })
            if let slug, !slug.isEmpty { return slug }
        }
        return nil
    }

    private func handleCartIntent(_ payload: Any?, eventName: String, add: Bool) {
        guard
            let dict = payload as? [String: Any],
            let callbackKey = dict["callbackId"] as? String,
            let inner = dict["payload"] as? [String: Any]
        else {
            emit(error: .invalidEventPayload(eventName: eventName, reason: "missing callbackId or payload envelope"))
            return
        }

        let sku = (inner["sku"] as? String)
            ?? ((inner["item"] as? [String: Any])?["sku"] as? String)
            ?? ""
        let quantity = (inner["count"] as? Int)
            ?? (inner["quantity"] as? Int)
            ?? 1

        if add {
            emit(.shouldAddToCart(sku: sku, quantity: quantity, callbackKey: callbackKey))
        } else {
            emit(.shouldUpdateCart(sku: sku, quantity: quantity, callbackKey: callbackKey))
        }
    }

    private func emit(_ event: BambuserCallEvent) {
        delegate?.bambuserCall(controller, didEmit: event)
    }

    private func emit(error: BambuserCallError) {
        delegate?.bambuserCall(controller, didEncounterError: error)
    }
}
