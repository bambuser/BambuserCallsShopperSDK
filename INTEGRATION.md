# BambuserCalls-shopper — Integration guide

A practical walkthrough of every public function the package exposes and what a host app needs to do to wire each one up. Read alongside [`README.md`](README.md), which has the quick-start summary.

---

## Contents

1. [What the package does](#what-the-package-does)
2. [Add the package](#add-the-package)
3. [Required Info.plist entries](#required-infoplist-entries)
4. [Bootstrapping at app launch](#bootstrapping-at-app-launch)
5. [Public API reference](#public-api-reference)
   - [`BambuserCallConfiguration`](#bambusercallconfiguration)
   - [`BambuserCallController`](#bambusercallcontroller)
   - [`BambuserCallOverlay`](#bambusercalloverlay)
   - [`BambuserCallDelegate`](#bambusercalldelegate)
   - [`BambuserCallEvent`](#bambusercallevent)
   - [`BambuserCallError`](#bambusercallerror)
   - [Enums](#enums)
6. [Implementation checklist](#implementation-checklist)
7. [Cart integration in detail](#cart-integration-in-detail)
8. [PiP customization](#pip-customization)
9. [Common pitfalls](#common-pitfalls)

---

## What the package does

It hides three things behind a small SwiftUI surface:

- A `WKWebView` that loads the Bambuser one-to-one embed script and grants camera/mic permissions automatically.
- A draggable picture-in-picture overlay that resizes itself between a slim ringing strip and a full mini-player as the SDK reports viewport-mode changes.
- A two-way JS bridge that turns SDK events into Swift delegate callbacks and lets you push notifications back into the embed.

You implement a two-method delegate to bridge the bridge to your app's navigation stack and cart.

---

## Add the package

In Xcode: **File → Add Package Dependencies → Add Local…** and point at `Example/Packages/BambuserCalls-shopper/`. Add the **BambuserCalls-shopper** library to the app target. In code, write `import BambuserCallsShopper` (Swift module names can't contain hyphens, so the camelCase form is used in code).

Two legacy library aliases — `BambuserCall` and `BambuserExpertChat` — point at the same target. They exist so existing project references keep linking; remove them from `Package.swift` after migrating fully.

---

## Required Info.plist entries

Video calls won't start without these permission strings:

| Key | Value (suggestion) |
|---|---|
| `NSCameraUsageDescription` | "We need access to your camera so the expert can see you during the call." |
| `NSMicrophoneUsageDescription` | "We need microphone access so the expert can hear you during the call." |

The framework auto-grants `WKWebView`'s media-capture prompt once iOS has approved them at the system level.

---

## Bootstrapping at app launch

Construct one controller, hold a delegate strongly, drop one overlay into your view tree.

```swift
import SwiftUI
import BambuserCallsShopper

@main
struct MyApp: App {
    @StateObject var navigationManager = NavigationManager()

    @StateObject var bambuserCall = BambuserCallController(
        configuration: BambuserCallConfiguration(orgId: "your-org-id")
    )

    @State private var bridge: AppBambuserCallDelegate?

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(bambuserCall)
                .environmentObject(navigationManager)
                .overlay(BambuserCallOverlay(controller: bambuserCall))
                .onAppear {
                    if bridge == nil {
                        let b = AppBambuserCallDelegate(navigationManager: navigationManager)
                        bridge = b
                        bambuserCall.delegate = b
                    }
                }
        }
    }
}
```

Two things to note:

- `BambuserCallController.delegate` is `weak`. The app must keep a strong reference (a `@State` property is the simplest place).
- `BambuserCallOverlay` belongs above your main UI so the floating PiP sits on top of everything else.

To start a session from anywhere:

```swift
@EnvironmentObject var bambuserCall: BambuserCallController
…
Button("Talk to expert") {
    bambuserCall.show()
}
```

---

## Public API reference

### `BambuserCallConfiguration`

Frozen at init. Only `orgId` is required. The public surface intentionally exposes only the six knobs hosts realistically flip; embed triggers, navigation/fill modes, ringing-strip size, animation curve, custom user agent, and the legacy media-shim flag all live as internal defaults.

```swift
public struct BambuserCallConfiguration {
    public var orgId: String
    public var embedUrl: URL              // default https://one-to-one.bambuser.com/embed.js
    public var floatingPipSize: CGSize    // default 180×260
    public var isInspectable: Bool        // default true in DEBUG, false in release
    public var autoExpandOnConnect: Bool  // default true
    public var dismissOnCallEnd: Bool     // default true

    public init(
        orgId: String,
        embedUrl: URL = .defaultEmbedUrl,
        floatingPipSize: CGSize = .defaultFloatingPipSize,
        isInspectable: Bool = .defaultIsInspectable,
        autoExpandOnConnect: Bool = true,
        dismissOnCallEnd: Bool = true
    )
}
```

What each one does:

- **`orgId`** — Bambuser organization id, hardcoded into the JS embed call.
- **`embedUrl`** — embed script URL. Override for staging / labs / branch builds.
- **`floatingPipSize`** — frame for the connected mini-player. The smaller ringing-strip size is handled internally.
- **`isInspectable`** — whether `WKWebView.isInspectable` is true. DEBUG-on, release-off by default.
- **`autoExpandOnConnect`** — if the user minimized to PiP during the connecting phase, the overlay auto-restores full-screen the moment the call goes live.
- **`dismissOnCallEnd`** — when true (default), the overlay closes itself the moment the SDK reports `call-ended` and friends.

### `BambuserCallController`

`@MainActor public final class BambuserCallController: ObservableObject`

#### Init

```swift
public init(configuration: BambuserCallConfiguration)
```

Hold the controller as `@StateObject` at app root and inject via `.environmentObject(...)`.

#### Published state

```swift
@Published public private(set) var isVisible: Bool
@Published public private(set) var isPiP: Bool
@Published public private(set) var pipPresentation: PipPresentation
@Published public private(set) var orgId: String?
@Published public private(set) var callState: CallState
@Published public var embedUrl: URL                      // mutable, hot-swappable
public weak var delegate: (any BambuserCallDelegate)?    // assign at startup
public var isCallActive: Bool { get }                    // .connecting OR .connected
```

#### Lifecycle methods

```swift
public func show(orgId: String? = nil, embedUrl: URL? = nil)
public func close()
public func expand()
public func enterPiP(presentation: PipPresentation = .floating)
```

- **`show()`** — opens the overlay full-screen. Uses `configuration.orgId` unless you pass an override.
- **`close()`** — fully tears down the embed and resets all state to idle. Called automatically at call-end if `dismissOnCallEnd` is true, and on every `close` event from the embed.
- **`expand()` / `enterPiP()`** — manual presentation control. The SDK itself flips between full and floating based on user actions, but exposing these lets you script overlays from buttons elsewhere in the app.

#### Outbound bridge

```swift
public func notifyProductNavigation(externalId: String)
public func notify(callbackKey: String, info: Any)
```

- **`notifyProductNavigation(externalId:)`** — call whenever the user navigates to a product *outside* the embed (taps a card on a different tab, follows a deep link, etc.). The embed's product carousel mirrors the new selection. Gated on `isCallActive`, safe to fire-and-forget.
- **`notify(callbackKey:info:)`** — invoke `window[callbackKey](info)` on the JS side. Primary use is resolving the cart-add and cart-update callbacks the embed hands you via `BambuserCallEvent.shouldAddToCart` / `.shouldUpdateCart`. `info` is interpolated verbatim — pass `true`, `42`, `"'string'"`, or `"{ id: 1 }"` (a JS literal as a Swift string).

### `BambuserCallOverlay`

```swift
public struct BambuserCallOverlay: View {
    public init(controller: BambuserCallController)
}
```

Place exactly one in your view tree (typically as `.overlay(...)` on the root or as a sibling in a `ZStack`). Renders nothing while the controller is hidden, so it has no ambient cost when you're not in a call.

### `BambuserCallDelegate`

Two methods total. The delegate is `@MainActor`.

```swift
@MainActor
public protocol BambuserCallDelegate: AnyObject {
    func bambuserCall(_ controller: BambuserCallController, didEmit event: BambuserCallEvent)
    func bambuserCall(_ controller: BambuserCallController, didEncounterError error: BambuserCallError)
}
```

`didEncounterError` has an empty default — host implements it only if they want to log/handle errors. `didEmit` is required (no default).

### `BambuserCallEvent`

Every interesting thing the framework wants to tell the host arrives here:

```swift
public enum BambuserCallEvent {
    case navigateTo(externalId: String)
    case close
    case checkout(cart: [String: Any]?)
    case callStateChanged(CallState)
    case presentationChanged(isPiP: Bool, presentation: PipPresentation)
    case shouldAddToCart(sku: String, quantity: Int, callbackKey: String)
    case shouldUpdateCart(sku: String, quantity: Int, callbackKey: String)
    case other(name: String, payload: Any?)
}
```

Per-case meaning:

| Case | When | Notes |
|---|---|---|
| `.navigateTo(externalId:)` | Embed product click | `externalId` is already unwrapped from its three possible shapes (string, `{id, feedId}` dict, URL slug). |
| `.close` | Embed close event | Overlay has already been dismissed by the framework — case is purely for observation. |
| `.checkout(cart:)` | Embed `goto-checkout` event | Cart payload is whatever the embed posted (typically `{ items: [...] }`). |
| `.callStateChanged(_)` | Call lifecycle transition | Fires once per change. |
| `.presentationChanged(...)` | PiP enter/exit/resize | `presentation` only meaningful when `isPiP` is true. |
| `.shouldAddToCart(...)` | Embed cart-add | Host must reply via `controller.notify(callbackKey: callbackKey, info: ...)`. |
| `.shouldUpdateCart(...)` | Embed cart-update | Same callback contract as `.shouldAddToCart`. |
| `.other(name:payload:)` | Anything the SDK doesn't model explicitly | Forward-compat hook and analytics piggyback point. |

### `BambuserCallError`

```swift
public enum BambuserCallError: Error {
    case javaScriptEvaluationFailed(operation: String, underlying: Error)
    case invalidEventPayload(eventName: String, reason: String)
}
```

`javaScriptEvaluationFailed` fires when a `notifyProductNavigation` or `notify` call to the WebView fails. `invalidEventPayload` fires when the router can't parse an incoming event — the event is dropped instead of emitted in a malformed form.

### Enums

```swift
public enum CallState: Equatable, Sendable {
    case idle, connecting, connected, ended
}

public enum PipPresentation: Equatable, Sendable {
    case minimized   // 60pt ringing strip (floatingLeftMinimized / RightMinimized)
    case floating    // 260pt mini-player (floating)
}
```

---

## Implementation checklist

What's in the package vs. what your host has to write.

| Step | Where it lives |
|---|---|
| Add Info.plist camera + microphone usage strings. | Host |
| Construct `BambuserCallController` at app root. | Host (≈5 lines) |
| Place `BambuserCallOverlay` in the root view tree. | Host (1 line) |
| Implement `BambuserCallDelegate.bambuserCall(_:didEmit:)`. | Host (required) |
| Handle `.navigateTo` — push your product detail screen. | Host |
| Handle `.checkout` — switch to your cart screen. | Host |
| Handle `.shouldAddToCart` / `.shouldUpdateCart` — mutate cart, reply via `controller.notify(callbackKey:info:)`. | Host |
| Optionally implement `bambuserCall(_:didEncounterError:)` for logging. | Host (optional) |
| Optionally call `notifyProductNavigation` when user navigates outside chat. | Host (≈2 lines) |
| PiP placement, drag, resize, lifecycle. | Package — automatic |
| Auto-grant camera/mic, browser-detection UA, JS bridge. | Package — automatic |
| Auto-dismiss on call-end / auto-expand on connect. | Package — flag-driven |
| Diagnostic emoji logs for cart and checkout payloads. | Package — automatic |

---

## Cart integration in detail

When the embed needs to add or update an item in the cart, the framework hands you a `BambuserCallEvent.shouldAddToCart(sku:quantity:callbackKey:)` (or the `.shouldUpdateCart` variant). You mutate your real cart and then resolve the JS-side promise via `controller.notify(callbackKey:info:)`.

```swift
case let .shouldAddToCart(sku, quantity, callbackKey),
     let .shouldUpdateCart(sku, quantity, callbackKey):
    Task {
        do {
            try await cartService.add(sku: sku, quantity: quantity)
            controller.notify(callbackKey: callbackKey, info: true)
        } catch {
            controller.notify(
                callbackKey: callbackKey,
                info: "{ success: false, reason: 'out-of-stock' }"
            )
        }
    }
```

`info` is interpolated verbatim into `window[callbackKey](info)`. Pass `true` for success, or a Swift string containing a JS object literal for a richer failure reason.

The framework also logs the incoming events to the console:

```
🛒 [BambuserCall] should-add-item-to-cart raw payload: { … }
🛒 [BambuserCall] should-add-item-to-cart sku=1232 quantity=1 callbackKey=cb_1
🔄 [BambuserCall] should-update-item-in-cart sku=1232 quantity=2 callbackKey=cb_2
💳 [BambuserCall] goto-checkout payload: { items: [...] }
```

Useful for verifying the embed-side shape matches what your delegate parses.

---

## PiP customization

Override the connected mini-player frame:

```swift
BambuserCallConfiguration(
    orgId: "your-org-id",
    floatingPipSize: CGSize(width: 200, height: 280)
)
```

That's the only PiP knob exposed publicly. The framework picks the right size for the dial-up ringing strip internally and parks the floater bottom-right with safe-area + tab-bar margins. Users can drag it anywhere from there; drag offset resets each time PiP is re-entered so every session starts at the resting position.

To programmatically open in PiP:

```swift
bambuserCall.show()              // opens full-screen
bambuserCall.enterPiP(.floating) // immediately goes to PiP
```

---

## Common pitfalls

**Delegate held weakly.** `BambuserCallController.delegate` is `weak`. Keep a strong reference at app root or it will silently deallocate.

**`isCallActive` is false when you expected it to be true.** The framework only flips `callState` when the embed emits one of the recognized lifecycle event names. If your SDK build emits something else, observe the `.other` case in `didEmit` for visibility, and file a bug so we can expand the recognized list.

**Embed lists won't scroll inside the PiP.** Drag-to-move only intercepts touches when `controller.isPiP` is true. If you experience the issue in *full-screen* mode, double-check you didn't wrap the overlay in a gesture-stealing container.

**Cart event completion never resolves on the JS side.** The embed holds the cart UI in a loading state until you call `controller.notify(callbackKey: callbackKey, info: ...)` with the key from the event. Forgetting that call leaves the embed spinning.

**Calling `notifyProductNavigation` from a screen the user reached without an active call does nothing.** Intentional — `isCallActive` gates the JS bridge so we don't spam the embed when no expert is watching.

---

## What's *not* in the public API

These are intentionally internal:

- `EmbedWebView` — the `UIViewRepresentable` wrapping `WKWebView`.
- `EmbedHTMLBuilder` — generates the host page + JS bridge.
- `EmbedEventRouter` — parses native-bridge messages.

If you need WebView customization (custom `WKUIDelegate`, additional user scripts), open an issue and we can expose a focused customization protocol rather than leaking `WKWebView` directly.

---

## What's *not* here yet

**Product hydration.** The `provide-product-data` round-trip was part of the v1.0.0 baseline and has been removed pending a redesign — the previous shape didn't fit Bambuser's actual product-builder semantics. If you need to hydrate products today, do it through your own JS handler injected on top of the embed and resolve it via `controller.notify(callbackKey:info:)`. A first-class hydration API will land in a later version.
