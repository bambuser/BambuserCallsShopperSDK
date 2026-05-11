# BambuserCalls-shopper

A focused Swift package that wraps Bambuser's one-to-one video-consultation web embed in a native iOS surface. Provides:

- A SwiftUI overlay that hosts the embed inside a `WKWebView` with auto-granted camera/mic permissions.
- A draggable PiP / floating mini-player that sizes itself to match the embed's viewport (slim ringing strip during connect, full mini-player after).
- A two-method delegate (event stream + error channel) so the host can react to navigation, cart, checkout, and lifecycle events with a single `switch`.
- An outbound `notify(callbackKey:info:)` helper for resolving JS-side callbacks from native code.

> **Names**
> - **Package / library**: `BambuserCalls-shopper` (the SwiftPM-facing name; this is what you write in `dependencies`).
> - **Module / `import` name**: `BambuserCallsShopper` (Swift module names can't contain hyphens, so the camelCase form is used in code).

## Add the package

In Xcode: **File → Add Package Dependencies → Add Local…** and select this folder. Then add the `BambuserCalls-shopper` library to your app target. Legacy `BambuserCall` and `BambuserExpertChat` product aliases also point at the same module for backwards compatibility.

## Quick start

```swift
import BambuserCallsShopper

@main
struct MyApp: App {
    @StateObject private var bambuserCall = BambuserCallController(
        configuration: BambuserCallConfiguration(orgId: "your-org-id")
    )
    @State private var bridge: AppCallBridge?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bambuserCall)
                .overlay(BambuserCallOverlay(controller: bambuserCall))
                .onAppear {
                    if bridge == nil {
                        let b = AppCallBridge()
                        bridge = b
                        bambuserCall.delegate = b
                    }
                }
        }
    }
}
```

`BambuserCallController.delegate` is `weak` — keep it strongly held somewhere (a `@State` property at app root works fine).

Open a session from anywhere:

```swift
@EnvironmentObject var bambuserCall: BambuserCallController
…
Button("Talk to expert") {
    bambuserCall.show()
}
```

## Configure

Only `orgId` is required. The rest have sensible defaults.

```swift
let config = BambuserCallConfiguration(
    orgId: "your-org-id",
    embedUrl: URL(string: "https://one-to-one.bambuser.com/embed.js")!,
    floatingPipSize: CGSize(width: 200, height: 280),  // default 180×260
    isInspectable: true,                                // DEBUG default
    autoExpandOnConnect: true,                          // default
    dismissOnCallEnd: true                              // default
)
```

Internal-only knobs (embed triggers, fill modes, animation curve, ringing-strip size, user agent, etc.) live behind sensible defaults inside the package and aren't part of the supported public API.

## Bridge to the host app

Implement `BambuserCallDelegate` — two methods, one switch:

```swift
final class AppCallBridge: BambuserCallDelegate {
    func bambuserCall(
        _ controller: BambuserCallController,
        didEmit event: BambuserCallEvent
    ) {
        switch event {
        case .navigateTo(let externalId):
            navigationManager.push(.productDetail(externalId), in: .products)
            controller.notifyProductNavigation(externalId: externalId)

        case .checkout:
            navigationManager.switchTo(.cart)

        case let .shouldAddToCart(sku, quantity, callbackKey),
             let .shouldUpdateCart(sku, quantity, callbackKey):
            cart.update(productId: sku, quantity: quantity)
            controller.notify(callbackKey: callbackKey, info: true)

        case .close, .callStateChanged, .presentationChanged, .other:
            break
        }
    }

    func bambuserCall(
        _ controller: BambuserCallController,
        didEncounterError error: BambuserCallError
    ) {
        print("BambuserCall error: \(error)")
    }
}
```

`didEncounterError` has an empty default — implement it only if you want visibility into JS-evaluation failures or malformed event payloads.

## Calling into the embed

```swift
// Echo a host-side product navigation back into the embed. Gated on
// isCallActive — safe to fire-and-forget.
controller.notifyProductNavigation(externalId: "1232")

// Generic JS-callback resolver. Used to reply to cart events.
controller.notify(callbackKey: "cb_3", info: true)
controller.notify(callbackKey: "cb_3", info: "{ success: false, reason: 'out-of-stock' }")
```

`notify` interpolates `info` verbatim into `window[callbackKey](info)` — pass `true` / a number directly, or a string containing a JS literal for object/array shapes.

## Required Info.plist entries

Video calls won't start without these permission strings:

| Key | Suggested value |
|---|---|
| `NSCameraUsageDescription` | "We need camera access so the expert can see you during the call." |
| `NSMicrophoneUsageDescription` | "We need microphone access so the expert can hear you during the call." |

The framework auto-grants `WKWebView`'s media-capture prompt once iOS has approved them at the system level.

## Public API at a glance

| Type | Purpose |
|---|---|
| `BambuserCallController` | `@MainActor ObservableObject`. State, lifecycle, JS bridge. |
| `BambuserCallOverlay` | `View`. Renders the embed at the right frame for the current state. |
| `BambuserCallConfiguration` | Frozen value type holding the six public knobs. |
| `BambuserCallDelegate` | Two-method protocol: `didEmit` + `didEncounterError`. |
| `BambuserCallEvent` | Enum carrying every event the framework recognizes. |
| `BambuserCallError` | Enum for JS-evaluation and payload-parse failures. |
| `CallState` | `idle / connecting / connected / ended`. |
| `PipPresentation` | `minimized / floating`. |

## Internals (not public API)

- `EmbedWebView` — `UIViewRepresentable` wrapping `WKWebView`.
- `EmbedHTMLBuilder` — generates the host page + JS bridge.
- `EmbedEventRouter` — parses `nativeBridge` messages and dispatches into the delegate.

These are intentionally internal; if you need WebView customization (custom `WKUIDelegate`, additional user scripts, etc.), open an issue and we can expose a focused customization protocol.

## What's not here

Product hydration (the `provide-product-data` round-trip) was part of v1.0.0 and has been removed pending a redesign — the previous shape didn't fit Bambuser's actual product-builder semantics. If you need to hydrate products today, do it through your own JS handler injected on top of the embed and resolve it via `controller.notify(callbackKey:info:)`. A first-class hydration API will land in a later version.

---

## Important Note:

This is an unreleased Bambuser SDK shared for evaluation only — please don't redistribute. Check with your Bambuser contact before using it in production; the public API and embed contract may still change.
