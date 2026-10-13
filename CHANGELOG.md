# Changelog

All notable changes to this project will be documented in this file. The
format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

<!--
This is the **public**, business-facing changelog that ships to the
GitHub mirror. Keep entries short, outcome-focused, and free of
Bambuser-internal terminology. The full technical changelog lives in
the internal CHANGELOG.md and stays on GitLab.
-->

## [Unreleased]




## [1.4.2] - 2026-10-13

### Added

- The SDK now sends usage metrics to Bambuser when the pin widget is shown and when a video call is opened.

## [1.4.1] - 2026-10-13

### Fixed

- SwiftUI demo app compiles again: the demo's org id and environment settings are now visible to the rest of the demo.

## [1.4.0] - 2026-10-05

### Added

- **`BambuserCallController.updateLocale(_:)`** — change the widget's locale between calls without reconstructing the controller. Useful when your app supports language switching mid-session. The new value applies to the next call `.show()`; running calls keep the locale they were opened with. Pass `nil` to fall back to the merchant's default.
- **`BambuserPinWidget`** — persistent floating pin overlay that opens the full Calls Widget on tap. Drop `BambuserPinWidgetView` at your app's root and the pin follows the shopper across every screen. Two rendering modes selected by `BambuserPinWidgetConfiguration.content`:
  - `.bambuserWidget(...)` — renders the Bambuser widget's own Overlay Widget inside a WKWebView. Content driven by your BamHub theme.
  - `.custom(...)` — a native SwiftUI card with host-provided content. Three variants (`.avatar`, `.video`, `.imageWithText`) and preset sizes (`.small` / `.medium` / `.large` / `.custom`). Draggable, dismissible, no WebView needed.

  State transitions surface via `BambuserPinWidgetDelegate` for full host visibility.
- **`BambuserPinWidgetCallAdapter`** — one-liner wiring between the pin and your existing `BambuserCallController`. Automatically hands off from pin → full call when the shopper taps, and restores the pin when the call ends. Only one WebView is alive at a time. A call opened any other way also hides the pin while it runs.
- **`BambuserPinWidgetWindowPresenter`** — show the pin in UIKit apps on its own window, same pattern as `BambuserCallWindowPresenter`.
- **`BambuserCallError.audioSessionActivationFailed(underlying:)`** — reported when the audio session can't be reactivated after an interruption. If you `switch` over `BambuserCallError`, add `@unknown default:`.

### Changed

- Shopper tracking events now report `source: "clienteling-sdk"` (previously `"call"`).

### Fixed

- **Audio / video restored after a cellular call or Siri interrupts a Bambuser call.** Previously the call session stayed connected at the app layer but the microphone and camera went dead on resume. The SDK now reactivates the shared audio session on interruption end so WebRTC can reclaim the input hardware.
- The full-screen call reaches the bottom edge of the screen on iOS 17+. SwiftUI apps should mount `BambuserCallOverlay` with `.ignoresSafeArea(edges: .bottom)`.

## [1.3.0] - 2026-09-09

### Added

- **Shopper analytics.** New `BambuserShopperSDK` entry point with a single `track(event:with:)` method for reporting shopper events (purchase, add-to-cart, refund, and more). Events attribute to the shopper's most recent Video Consultation call — including purchases made hours or days after the call ends.
- Purchase-tracking demo flow in both SwiftUI and UIKit sample apps.

### Changed

- SDK now ships as a prebuilt XCFramework. Faster consumer builds, smaller integration surface. Xcode 15+ required.
- Enter Picture-in-Picture (`enterPiP`) now switches the widget itself into its mini video player. Previously the widget kept rendering its cart tool inside the shrunken frame.

### Fixed

- SwiftUI overlay was blocking taps on the tab bar and product list even when the widget wasn't visible. Touches now pass through to the underlying UI.
- Mini-player drag felt "sticky" on iOS — required a long-press before it followed the finger. Now drags immediately.
- Chat input was pushed off-screen when the keyboard opened. The WebView now shrinks above the keyboard so inputs stay in view.
- Mini-player could be dragged off the edge of the screen and disappear. It now stays inside the visible area.
- Mini-player drag moved opposite to the finger in right-to-left languages (Arabic, Hebrew). Fixed.
- Widget-initiated Picture-in-Picture transitions (e.g. agent-driven minimize) were being reverted by the SDK. Fixed.
- Small whitespace/inset regressions in the widget layout after keyboard interactions.


## [1.2.0] - 2026-09-03

### Changed

- Call state transitions to "connected" the moment the agent's cart tool is ready to receive customer events (previously it lingered on "connecting"), so host apps can gate cart interactions accurately.
- Product events sent from the host app now include `name`, `price`, and `currency` alongside `sku`/`quantity`.


## [1.1.0] - 2026-08-26

### Added

- **UIKit support.** Full UIKit integration path with `BambuserCallHostView` and `BambuserCallWindowPresenter`. UIKit apps can now embed the SDK without wrapping SwiftUI.
- Complete UIKit demo app mirroring the SwiftUI reference demo.

### Changed

- Unified SwiftUI and UIKit under a single presentation layer. Both hosts now share the same WebView, JS bridge, presentation stack, and drag gesture — every future fix lands on both surfaces at once.

### Fixed

- Widget top-bar controls (back / close) unresponsive when embedded in a UIKit host, because `env(safe-area-inset-*)` was resolving to zero. The SDK now propagates safe-area insets into the WebView on both mount surfaces.


## [1.0.0] - 2026-08-18

First stable release.

### Added

- Agent-visible error messages surfaced from product and search handlers, so shoppers see contextual failure messages instead of silent errors.

### Changed

- Refreshed documentation and demo app.

### Fixed

- Stability and lifecycle improvements around the WebView bridge.


## [0.3.0] - 2026-08-15

### Added

- Region selection for the widget backend (US / EU).

### Changed

- Reworked the public API to separate product data sources from event notifications. Cleaner integration surface, no more mixing "here's the data" with "the shopper did X".
- Made the SDK data-shape agnostic — future widget-side changes generally won't require an SDK release on the app.


## [0.2.0] - 2026-07-10

### Added

- Product and cart flows (add-to-cart, cart updates, product detail).
- Queue-status observability and query APIs.
- Shopper-activity reporting APIs.
- Broader configuration surface for the widget.

### Changed

- Internal cleanup and API polish.


## [0.1.0] - 2026-06-01

Initial release of the Bambuser Calls Shopper SDK for iOS.

### Added

- SwiftUI presentation layer for the video call widget.
- Native handling for the widget's core events (call state, product events, queue events).
- Reference demo app.
