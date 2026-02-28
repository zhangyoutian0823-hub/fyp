//
//  FaceOverlayView.swift
//  iOSFaceRecognition
//
//  实时人脸检测框 overlay，显示绿色边界框和黄色关键点。
//  叠加在 CameraView 之上使用。
//

import SwiftUI
import Vision

/// 将 Vision 归一化坐标转为 SwiftUI 视图坐标。
/// Vision 坐标系：原点左下，Y 向上；SwiftUI 坐标系：原点左上，Y 向下。
private func convertBox(_ box: CGRect, viewSize: CGSize) -> CGRect {
    CGRect(
        x: box.minX * viewSize.width,
        y: (1 - box.maxY) * viewSize.height,
        width: box.width * viewSize.width,
        height: box.height * viewSize.height
    )
}

// MARK: - FaceOverlayView

struct FaceOverlayView: View {
    let observations: [VNFaceObservation]

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ForEach(Array(observations.enumerated()), id: \.offset) { _, obs in
                let rect = convertBox(obs.boundingBox, viewSize: size)

                // 绿色检测框
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)

                // Landmark 关键点
                if let landmarks = obs.landmarks {
                    LandmarkDotsView(landmarks: landmarks,
                                     faceRect: rect)
                }
            }
        }
        .allowsHitTesting(false)   // 不拦截触摸事件
    }
}

// MARK: - LandmarkDotsView

private struct LandmarkDotsView: View {
    let landmarks: VNFaceLandmarks2D
    let faceRect: CGRect

    var body: some View {
        Canvas { ctx, _ in
            let allPoints = collectPoints()
            for pt in allPoints {
                // landmark 点坐标在 bounding box 内归一化
                let screenX = faceRect.minX + pt.x * faceRect.width
                let screenY = faceRect.minY + (1 - pt.y) * faceRect.height
                let dot = CGRect(x: screenX - 2, y: screenY - 2, width: 4, height: 4)
                ctx.fill(Circle().path(in: dot), with: .color(.yellow))
            }
        }
    }

    private func collectPoints() -> [CGPoint] {
        let regions: [VNFaceLandmarkRegion2D?] = [
            landmarks.leftEye,
            landmarks.rightEye,
            landmarks.leftEyebrow,
            landmarks.rightEyebrow,
            landmarks.nose,
            landmarks.noseCrest,
            landmarks.outerLips
        ]
        return regions.compactMap { $0 }.flatMap { $0.normalizedPoints }
    }
}
