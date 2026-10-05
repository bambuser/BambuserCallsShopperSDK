# BambuserCallsShopper

Swift Package + demo app that embeds a Bambuser one-to-one expert-chat
call into an iOS shopping app.

The SDK owns the WebView, the JS bridge, and the presentation
(full-screen sheet with PiP mini-player). Host code plugs in:

- **A `BambuserCallDelegate`** for fire-and-forget events (call
  lifecycle, checkout, queue status, tracking, navigation, errors).
- **A `BambuserCallHandlers` set** for the four data-source events
  where the SDK needs a value back (product hydration, search results,
  cart resolution).

Everything else — how you model products, how you shape customer data,
how you route agent-driven navigation — is yours. The SDK stays data
agnostic.

## Requirements

- iOS 16+
- Swift 5.9 / Xcode 15+
- Camera & microphone permissions declared in `Info.plist`
- A Bambuser workspace on `lcx.bambuser.com` (US) or `lcx-eu.bambuser.com` (EU)

## Install

Swift Package Manager:

```swift
.package(url: "https://github.com/bambuser/BambuserCallsShopperSDK", from: "0.1.0")
```

Then add the `BambuserCalls-shopper` product to your target.

## 60-second quick start

```swift
import SwiftUI
import BambuserCallsShopper

@main
struct MyApp: App {
    @StateObject private var call = BambuserCallController(
        configuration: BambuserCallConfiguration(
            orgId: "YOUR_ORG_ID",
            environment: .us   // or .eu
        )
    )
    @State private var delegate: MyBambuserBridge?

    var body: some Scene {
        WindowGroup {
            ZStack {
                MyShoppingApp()
                BambuserCallOverlay(controller: call)   // drop at the root
                    .ignoresSafeArea(edges: .bottom)    // full-bleed bottom
            }
            .onAppear {
                guard delegate == nil else { return }
                let bridge = MyBambuserBridge()
                call.delegate = bridge                  // weak — hold it
                call.handlers.shouldAddToCart = { intent in
                    // ... add intent.sku to your cart
                    return .success
                }
                delegate = bridge
            }
        }
    }
}

@MainActor
final class MyBambuserBridge: BambuserCallDelegate {
    func bambuserCall(_ c: BambuserCallController, didEmit event: BambuserCallEvent) {
        if case .checkout = event { /* route to checkout */ }
    }
    func bambuserCall(_ c: BambuserCallController, didEncounter error: BambuserCallError) {
        print("Bambuser: \(error)")
    }
}
```

Kick off a call:

```swift
call.show(connectId: "abc", queue: "premium")
```

## Persistent pin widget (optional)

`BambuserPinWidget` renders a persistent floating pin on top of your app that opens the full call when tapped. Two modes:

- `.bambuserWidget(...)` — the Bambuser widget's own Overlay Widget inside a WKWebView (BamHub theme drives the visuals)
- `.custom(...)` — a native SwiftUI card with host-provided image / video + text (three variants: `.avatar`, `.video`, `.imageWithText`)

```swift
@StateObject private var pin = BambuserPinWidget(
    configuration: BambuserPinWidgetConfiguration(
        orgId: "YOUR_ORG_ID",
        environment: .us,
        content: .custom(
            BambuserPinWidgetCustomOptions(
                variant: .video(
                    url: Bundle.main.url(forResource: "welcome", withExtension: "mp4")!,
                    title: "Meet our experts",
                    ctaTitle: "Start a call"
                ),
                size: .medium,                 // .small / .medium / .large / .custom
                popupTimeoutSeconds: 5
            )
        )
    )
)
@State private var adapter: BambuserPinWidgetCallAdapter?

// In your view tree:
BambuserPinWidgetView(pin: pin)

.onAppear {
    if adapter == nil {
        adapter = BambuserPinWidgetCallAdapter(pin: pin, call: bambuserCall)
    }
    pin.present()
}
```

The adapter enforces the single-WebView invariant: on tap it dismisses the pin, calls `bambuserCall.show()`, and re-presents the pin when the call closes.

See `video-consultation/mobile-sdk/ios/pin-widget` in the docs for the full API surface.

## Locale and errors

Change the widget language between calls (applied on the next `show()`):

```swift
bambuserCall.updateLocale("de-DE")   // nil = BamHub default
```

Errors arrive in `bambuserCall(_:didEncounter:)` as `BambuserCallError`: `javaScriptEvaluationFailed`, `invalidEventPayload`, `trackingFailed`, `audioSessionActivationFailed`. After a phone call or Siri interrupts a live call, the SDK reactivates the shared audio session so mic and camera recover; `audioSessionActivationFailed` reports when that fails. Add `@unknown default:` when switching over the enum.

## Repository layout

```
BambuserCallsShopperSDK/
├── Sources/BambuserCallsShopper/     ← the SDK
│   ├── BambuserCallController.swift
│   ├── BambuserCallConfiguration.swift
│   ├── BambuserCallEnvironment.swift
│   ├── BambuserCallOverlay.swift
│   ├── BambuserCallHandlers.swift
│   ├── BambuserCallDelegate.swift
│   ├── BambuserCallEvent.swift
│   ├── BambuserCallError.swift
│   ├── BambuserFactorySpec.swift
│   ├── BambuserProductRef.swift
│   ├── BambuserSearchRequest.swift
│   ├── BambuserQueueStatus.swift
│   ├── BambuserTrackingEvent.swift
│   ├── BambuserTrackingTag.swift
│   ├── CallState.swift
│   ├── PipPresentation.swift
│   └── Internal/
│       ├── EmbedHTMLBuilder.swift
│       └── EmbedEventRouter.swift
└── BambuserCallsShopperDemo/          ← the demo app (see below)
```

## Running the demo

1. Open `BambuserCallsShopperDemo/BambuserCallsShopperDemo.xcodeproj`.
2. Set `demoOrgId` at the top of
   `App/BambuserCallsShopperDemoApp.swift` to your Bambuser org id.
3. Run the app on a physical device (WebRTC needs a real device — the
   simulator has no camera). Product pages have a "Talk to expert" button.

The demo ships:

- 55 products lifted from the Bambuser demo shop's product feed, so
  any SKU an agent types in the tool resolves against a real card.
- A reference `BambuserProduct` model + factory-spec conversion in
  `BambuserCallsShopperDemo/Bambuser/`. This is guideline code — swap
  it out for your own product model in a real integration.
- `BambuserCallBridge.swift` — one class that implements the delegate
  and configures the four data-source handlers.

## The SDK on one page

**Presentation.** Add one `BambuserCallOverlay(controller: ...)` to
your root `ZStack`. It renders nothing until `controller.show(...)` is
called, then mounts the WebView full-screen. PiP transitions are
gesture-driven.

**Data sources (handlers).** Fill in only the closures you can answer:

```swift
call.handlers.provideProductData = { ref in
    guard let sku = resolveSKU(from: ref) else { return nil }
    return myProduct(for: sku).toBambuserFactorySpec()
}
call.handlers.shouldAddToCart = { intent in
    try? await cart.add(sku: intent.sku, quantity: intent.quantity)
    return .success   // or .failure(reason: "out-of-stock") or .raw(...)
}
```

Handlers frozen at `show()` — set them before opening the widget.

**Events (delegate).** One switch handles the whole stream:

```swift
func bambuserCall(_ c: BambuserCallController, didEmit event: BambuserCallEvent) {
    switch event {
    case .checkout:            navigation.push(.checkout)
    case .navigateTo(let url): router.push(url)
    case .agentsOnlineChanged(let a) where a.numberOfAgentsOnline == 0:
                               showCTA = false
    default:                   break
    }
}
```

Every fire-and-forget event the widget produces comes through one
method with `BambuserCallEvent` cases. Add `@unknown default:` in
production code so future SDK versions can add cases without breaking
you.

**Outbound methods.** Everything the SDK sends to the widget:

- `show(...)` / `close()` — lifecycle
- `enterPiP()` / `expand()` — presentation
- `notifyProductNavigation(externalId:)` — shopper opened a PDP
- `notifyCustomerEvent("ADDED_TO_CART", payload: ...)` — shopper cart action
- `updateData(_:)` — refresh customer info
- `setTrackingTags(_:)` — analytics tags
- `setQueue(_:)` — switch queue
- `areQueuesOpen()` / `getNumberOfOnlineAgents()` / `getEstimatedWaitingTime()` — async queries
- `floatAbove(url:)` — enter miniplayer
- `destroy()` — teardown
- `updateElement(_:state:)` — customize the drop-in / booking cards
- `invoke(embedMethod:...)` / `invoke(callback:...)` / `invoke(async:...)` — call any embed method, present or future

**Future-proof by construction.** Every incoming payload carries
`raw: BambuserJSONValue`, and every handler returns
`BambuserReply<Payload>` — one unified enum with `.reply(payload)` /
`.error(message:)` / `.skip` cases. New embed fields and new embed
methods don't require an SDK release.

Full details: **[INTEGRATION.md](./INTEGRATION.md)**.

## Environments

| Case  | URL                                            |
| ----- | ---------------------------------------------- |
| `.us` | `https://one-to-one.bambuser.com/embed.js`     |
| `.eu` | `https://one-to-one.bambuser.com/eu/embed.js`  |

Set via `BambuserCallConfiguration(orgId:, environment: .us)`.

## License

Internal / by-arrangement. Contact your Bambuser rep before publishing
apps built with this SDK.
