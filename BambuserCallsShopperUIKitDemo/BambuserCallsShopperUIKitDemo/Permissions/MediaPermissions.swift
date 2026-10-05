//
//  MediaPermissions.swift
//  BambuserCallsShopperUIKitDemo
//
//  Native AVCaptureDevice permission requests for camera + mic, fired
//  before the widget loads so the OS popup shows on a screen the host
//  owns instead of mid-widget-load.
//

import AVFoundation

enum MediaPermissions {

    /// Ask for camera + mic. Returns true only if both are `.authorized`.
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
