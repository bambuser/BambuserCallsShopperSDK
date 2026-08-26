//
//  CallState.swift
//  BambuserCallsShopper
//

import Foundation

/// Lifecycle of a one-to-one call.
public enum CallState: Equatable, Sendable {
    case idle
    case connecting
    case connected
    case ended
}
