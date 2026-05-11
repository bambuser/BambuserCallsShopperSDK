//
//  PipPresentation.swift
//  BambuserCallsShopper
//

import Foundation

/// Floating layout the embed is rendering. Drives the native PiP frame
/// size: `.minimized` for the dial-up ringing strip, `.floating` for the
/// connected mini-player.
public enum PipPresentation: Equatable, Sendable {
    case minimized
    case floating
}
