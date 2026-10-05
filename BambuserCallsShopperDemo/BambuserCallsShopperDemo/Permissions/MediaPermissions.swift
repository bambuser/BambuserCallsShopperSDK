//
//  MediaPermissions.swift
//  BambuserCallsShopperDemo
//
//  Native AVCaptureDevice permission requests for camera + mic, fired
//  before the widget loads so the OS popup shows on a screen the host
//  owns instead of mid-widget-load.
//
//  Required for the reduced-journey flow (tenant setting
//  `client.mediaPermissionPreboarding.enabled = false`) — without the
//  widget's own permission-preboarding screen, the SDK's WKUIDelegate
//  auto-grants at the WebView layer but iOS still gates on the app's
//  AVCaptureDevice state. Requesting upfront keeps the flow snappy.
//

import AVFoundation

enum MediaPermissions {

    /// Ask for camera + mic. Returns true only if both are `.authorized`.
    /// Fires the OS prompt on first call; subsequent calls return the
    /// current state without prompting.
    @MainActor
    static func request() async -> Bool {
        let camera = await requestAccess(for: .video)
        let mic = await requestAccess(for: .audio)
        return camera && mic
    }

    private static func requestAccess(for mediaType: AVMediaType) async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: mediaType) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: mediaType)
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }
    }
}
