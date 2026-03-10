//
//  FaceOverlayView.swift
//  iOSFaceRecognition
//
//  实时人脸检测框 overlay，显示绿色边界框和黄色关键点。
//  叠加在 CameraView 之上使用。
//
//  坐标转换说明：
//  - Vision 坐标系：原点左下，Y 向上，归一化 [0,1]
//  - 绿框 convertBoundingBox() 用 previewLayer.layerPointConverted() 做一次性转换
//  - Landmark dots 直接在已转换的 screenBox 内插值，保证和绿框完全同源
//

import SwiftUI
import Vision
import AVFoundation

// MARK: - FaceOverlayView

struct FaceOverlayView: View {
    let observations: [VNFaceObservation]
    /// CameraView 创建的 previewLayer，由 CameraService.previewLayer 提供。
    /// 不传时退回简单归一化换算（兼容 Canvas preview）。
    var previewLayer: AVCaptureVideoPreviewLayer? = nil

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ForEach(Array(observations.enumerated()), id: \.offset) { _, obs in
                let rect = convertBoundingBox(obs.boundingBox, size: size)
                // 横向框：宽 = 高 × 1.6，高保持不变，水平居中
                let hWidth  = rect.height * 1.6
                let hRect   = CGRect(x: rect.midX - hWidth / 2,
                                     y: rect.minY,
                                     width: hWidth,
                                     height: rect.height)

                // 绿色检测框
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.green, lineWidth: 2)
                    .frame(width: hRect.width, height: hRect.height)
                    .position(x: hRect.midX, y: hRect.midY)

                // Landmark 关键点：直接用 screenBox（rect）插值，与绿框同坐标系
                if let landmarks = obs.landmarks {
                    LandmarkDotsView(landmarks: landmarks, screenBox: rect)
                }
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Bounding Box 转换

    /// Vision boundingBox（y-up）→ SwiftUI 视图坐标
    private func convertBoundingBox(_ box: CGRect, size: CGSize) -> CGRect {
        if let layer = previewLayer, layer.bounds.width > 0 {
            // 利用 previewLayer 自动处理 aspectFill / 旋转 / 镜像
            // capture device 坐标：(0,0) = 左上，(1,1) = 右下，y 向下
            let tl = layer.layerPointConverted(
                fromCaptureDevicePoint: CGPoint(x: box.minX,  y: 1 - box.maxY))
            let br = layer.layerPointConverted(
                fromCaptureDevicePoint: CGPoint(x: box.maxX,  y: 1 - box.minY))

            // layer 坐标 → GeometryReader 坐标（等比缩放）
            let scaleX = size.width  / layer.bounds.width
            let scaleY = size.height / layer.bounds.height
            return CGRect(
                x: tl.x * scaleX,
                y: tl.y * scaleY,
                width:  (br.x - tl.x) * scaleX,
                height: (br.y - tl.y) * scaleY
            )
        } else {
            // Fallback（Canvas 预览 / layer 未就绪时）
            return CGRect(
                x:      box.minX * size.width,
                y:      (1 - box.maxY) * size.height,
                width:  box.width  * size.width,
                height: box.height * size.height
            )
        }
    }
}

// MARK: - LandmarkDotsView

private struct LandmarkDotsView: View {
    let landmarks: VNFaceLandmarks2D
    /// 已转换到 SwiftUI 视图坐标的人脸 bounding box（与绿框 rect 同源）。
    /// landmark normalizedPoints 的 (x,y) 是 bbox 内归一化坐标，y-down。
    let screenBox: CGRect

    var body: some View {
        Canvas { ctx, _ in
            // normalizedPoints Y-UP（0=下巴，1=额头），转屏幕坐标需翻转 Y
            // X 使用 origin.x + pt.x * width，兼容前置镜像（width 可能为负）
            for pt in collectPoints() {
                let sx = screenBox.origin.x + pt.x * screenBox.width
                let sy = screenBox.maxY    - pt.y * screenBox.height
                let dot = CGRect(x: sx - 2.5, y: sy - 2.5, width: 5, height: 5)
                ctx.fill(Circle().path(in: dot), with: .color(.yellow))
            }
        }
    }

    private func collectPoints() -> [CGPoint] {
        var result: [CGPoint] = []

        // 左眼/左眉：拉宽 + 下移 + 往内侧推（Vision x 减小 = 向内）
        let eyeIn: CGFloat = 0.12
        for r in [landmarks.leftEye, landmarks.leftEyebrow].compactMap({ $0 }) {
            result += stretchX(r.normalizedPoints, scale: 1.6, yShift: -0.05, xShift: -eyeIn)
        }
        // 右眼/右眉：拉宽 + 下移 + 往内侧推（Vision x 增大 = 向内）
        for r in [landmarks.rightEye, landmarks.rightEyebrow].compactMap({ $0 }) {
            result += stretchX(r.normalizedPoints, scale: 1.6, yShift: -0.05, xShift: +eyeIn)
        }
        // 鼻子：原比例
        for r in [landmarks.nose, landmarks.noseCrest].compactMap({ $0 }) {
            result += r.normalizedPoints
        }
        // 嘴巴：水平拉宽 1.5×，整体上移 0.05（Y-UP，增大 y = 屏幕往上）
        for r in [landmarks.outerLips, landmarks.innerLips].compactMap({ $0 }) {
            result += stretchX(r.normalizedPoints, scale: 1.5, yShift: 0.05)
        }

        return result
    }

    /// 以点集 X 质心为轴水平缩放，并整体偏移 X/Y
    /// xShift: Vision 坐标偏移（正 = 右/外侧左眼，负 = 左/外侧右眼）
    /// yShift: Y-UP 坐标偏移（正 = 上移，负 = 下移）
    private func stretchX(_ pts: [CGPoint], scale: CGFloat,
                          yShift: CGFloat = 0, xShift: CGFloat = 0) -> [CGPoint] {
        guard !pts.isEmpty else { return [] }
        let cx = pts.reduce(0) { $0 + $1.x } / CGFloat(pts.count)
        return pts.map { CGPoint(x: cx + ($0.x - cx) * scale + xShift, y: $0.y + yShift) }
    }
}
