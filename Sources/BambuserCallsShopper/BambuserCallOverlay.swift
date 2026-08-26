//
//  BambuserCallOverlay.swift
//  BambuserCallsShopper
//

import SwiftUI
import UIKit

/// SwiftUI mount surface for `BambuserCallController`. Drop into a
/// `ZStack` at the root of your view tree.
public struct BambuserCallOverlay: UIViewControllerRepresentable {

    @ObservedObject private var controller: BambuserCallController

    public init(controller: BambuserCallController) {
        self.controller = controller
    }

    public func makeUIViewController(context: Context) -> BambuserCallViewController {
        BambuserCallViewController(controller: controller)
    }

    public func updateUIViewController(_ vc: BambuserCallViewController, context: Context) {}
}
