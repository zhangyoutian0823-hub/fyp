//
//  CameraView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import SwiftUI
import AVFoundation

struct CameraView: UIViewRepresentable {
    @ObservedObject var service: CameraService

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let layer = AVCaptureVideoPreviewLayer(session: service.session)
        layer.videoGravity = .resizeAspectFill
        layer.connection?.videoOrientation = .portrait
        view.layer.addSublayer(layer)
        context.coordinator.layer = layer
        service.previewLayer = layer   // 注入给 FaceOverlayView 做坐标转换
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.layer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var layer: AVCaptureVideoPreviewLayer?
    }
}

