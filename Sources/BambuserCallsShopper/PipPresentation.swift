//
//  PipPresentation.swift
//  BambuserCallsShopper
//

import Foundation

/// Floating layout the embed is rendering. `.floating` is the connected
/// mini-player; `.minimized` is the ringing / dial-up strip.
public enum PipPresentation: Equatable, Sendable {
    case minimized
    case floating
}
