//
//  BambuserEnvironment.swift
//  BambuserCallsShopper
//

import Foundation

/// A Bambuser region. Hosts pick a value (`.us` or `.eu`); the SDK
/// holds the embed URL. `.custom(URL)` is available for local dev
/// against a self-hosted embed.
public struct BambuserEnvironment: Sendable, Equatable {

    public let embedURL: URL

    public init(embedURL: URL) {
        self.embedURL = embedURL
    }

    /// US production. Use with BamHub on `https://lcx.bambuser.com/`.
    public static let us = BambuserEnvironment(
        embedURL: URL(string: "https://one-to-one.bambuser.com/embed.js")!
    )

    /// EU production. Use with BamHub on `https://lcx-eu.bambuser.com/`.
    public static let eu = BambuserEnvironment(
        embedURL: URL(string: "https://one-to-one.bambuser.com/eu/embed.js")!
    )

    #if DEBUG
    /// Bambuser-internal staging. Debug-only; not for merchant use.
    public static let stageUS = BambuserEnvironment(
        embedURL: URL(string: "https://lvs-121-dev.web.app/embed.js")!
    )
    #endif
}
