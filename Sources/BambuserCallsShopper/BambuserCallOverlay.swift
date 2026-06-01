//
//  BambuserCallOverlay.swift
//  BambuserCallsShopper
//

import SwiftUI

/// SwiftUI surface for a `BambuserCallController`. Renders the embed as a
/// full-screen sheet or, when `controller.isPiP` is true, as a draggable
/// floating mini-player. Drop one into a `ZStack` at the root of your view
/// tree.
public struct BambuserCallOverlay: View {

    @ObservedObject private var controller: BambuserCallController

    @State private var pipDragOffset: CGSize = .zero
    @State private var pipDragStart: CGSize = .zero

    public init(controller: BambuserCallController) {
        self.controller = controller
    }

    public var body: some View {
        GeometryReader { geo in
            if controller.isVisible, let orgId = controller.orgId {
                let pipSize = currentPipSize
                let isPiP = controller.isPiP

                EmbedWebView(
                    html: EmbedHTMLBuilder.makeHTML(
                        options: makeEmbedOptions(orgId: orgId)
                    ),
                    baseURL: EmbedHTMLBuilder.baseURL(for: controller.embedUrl),
                    configuration: controller.configuration,
                    onNativeMessage: { raw in
                        EmbedEventRouter(controller: controller).handle(rawMessage: raw)
                    },
                    onWebViewCreated: { webView in
                        controller.attach(webView)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: isPiP ? 16 : 0))
                .shadow(
                    color: .black.opacity(isPiP ? 0.25 : 0),
                    radius: isPiP ? 12 : 0,
                    x: 0,
                    y: isPiP ? 6 : 0
                )
                .frame(
                    width: isPiP ? pipSize.width : geo.size.width,
                    height: isPiP ? pipSize.height : geo.size.height
                )
                .contentShape(Rectangle())
                .offset(currentOffset(in: geo, pipSize: pipSize))
                .highPriorityGesture(
                    DragGesture(minimumDistance: 4)
                        .onChanged { value in
                            guard isPiP else { return }
                            pipDragOffset = CGSize(
                                width: pipDragStart.width + value.translation.width,
                                height: pipDragStart.height + value.translation.height
                            )
                        }
                        .onEnded { _ in
                            guard isPiP else { return }
                            pipDragStart = pipDragOffset
                        },
                    including: isPiP ? .all : .subviews
                )
                .animation(controller.configuration.transitionAnimation, value: controller.isPiP)
                .animation(controller.configuration.transitionAnimation, value: controller.pipPresentation)
                .onChange(of: controller.isPiP) { _ in
                    pipDragOffset = .zero
                    pipDragStart = .zero
                }
            }
        }
        .ignoresSafeArea()
    }

    private func makeEmbedOptions(orgId: String) -> EmbedHTMLBuilder.Options {
        let cfg = controller.configuration
        let data = cfg.initialCustomerData
        let tags: BambuserJSONValue? = cfg.initialTrackingTags.isEmpty
            ? nil
            : cfg.initialTrackingTags.toJSONArray()

        return EmbedHTMLBuilder.Options(
            orgId: orgId,
            embedUrl: controller.embedUrl,
            connectId: controller.connectId,
            queue: controller.queue ?? cfg.initialQueue,
            triggers: cfg.triggers,
            floatingNavigationMode: cfg.floatingNavigationMode,
            floatingFillMode: cfg.floatingFillMode,
            locale: cfg.locale,
            data: data,
            trackingTags: tags,
            dropInEnabled: cfg.dropInEnabled,
            bookingsEnabled: cfg.bookingsEnabled,
            openBookingPage: cfg.openBookingPage,
            bookingServiceIds: cfg.bookingServiceIds,
            bookingResourceId: cfg.bookingResourceId,
            bookingIframeUrl: cfg.bookingIframeUrl,
            enableScanning: cfg.enableScanning,
            merchantBaseUrl: cfg.merchantBaseUrl,
            disableCoBrowsing: cfg.disableCoBrowsing,
            themeId: cfg.themeId,
            allowFirstPartyCookies: cfg.allowFirstPartyCookies,
            disableDataLayerInterceptions: cfg.disableDataLayerInterceptions,
            subscriptions: controller.activeSubscriptions
        )
    }

    private var currentPipSize: CGSize {
        switch controller.pipPresentation {
        case .minimized: return controller.configuration.minimizedPipSize
        case .floating:  return controller.configuration.floatingPipSize
        }
    }

    private func currentOffset(in geo: GeometryProxy, pipSize: CGSize) -> CGSize {
        guard controller.isPiP else { return .zero }
        let base = defaultOrigin(in: geo, pipSize: pipSize)
        return CGSize(
            width: base.width + pipDragOffset.width,
            height: base.height + pipDragOffset.height
        )
    }

    private func defaultOrigin(in geo: GeometryProxy, pipSize: CGSize) -> CGSize {
        let cfg = controller.configuration
        return CGSize(
            width: geo.size.width - pipSize.width - cfg.pipMargin,
            height: geo.size.height
                - pipSize.height
                - geo.safeAreaInsets.bottom
                - cfg.bottomReserve
                - cfg.pipMargin
        )
    }
}
