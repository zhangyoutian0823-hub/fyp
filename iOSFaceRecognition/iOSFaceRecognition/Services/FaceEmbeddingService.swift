//
//  FaceEmbeddingService.swift
//  iOSFaceRecognition
//
//  使用 Apple Vision 框架的 VNDetectFaceLandmarksRequest 提取人脸特征向量。
//  策略：提取 8 个 landmark 区域的归一化坐标 + 关键几何比例，
//  组合为 128 维 L2 归一化特征向量，用于余弦相似度匹配。
//

import Vision
import UIKit

/// 人脸特征向量提取服务（单例）
final class FaceEmbeddingService {

    static let shared = FaceEmbeddingService()
    private init() {}

    // MARK: - 公开接口

    /// 从 UIImage 提取 128 维特征向量。
    /// - Returns: 归一化特征向量；如图中未检测到人脸则返回 nil。
    func extractEmbedding(from image: UIImage) async -> [Float]? {
        guard let cgImage = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNDetectFaceLandmarksRequest { [weak self] req, _ in
                guard
                    let self,
                    let results = req.results as? [VNFaceObservation],
                    let face = results.first
                else {
                    continuation.resume(returning: nil)
                    return
                }
                let vec = self.buildVector(from: face)
                continuation.resume(returning: vec)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage,
                                                orientation: imageOrientation(from: image),
                                                options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    /// 对多个特征向量取平均，再做 L2 归一化。
    /// 注册时用多帧采集后调用此方法提高精度。
    func averageEmbedding(_ embeddings: [[Float]]) -> [Float]? {
        guard !embeddings.isEmpty else { return nil }
        let dim = embeddings[0].count
        var sum = [Float](repeating: 0, count: dim)
        for vec in embeddings {
            for i in 0..<dim { sum[i] += vec[i] }
        }
        let n = Float(embeddings.count)
        let avg = sum.map { $0 / n }
        return l2Normalize(avg)
    }

    // MARK: - 特征向量构建

    private func buildVector(from face: VNFaceObservation) -> [Float] {
        guard let landmarks = face.landmarks else {
            return [Float](repeating: 0, count: 128)
        }

        var features: [Float] = []

        // ── 1. 各 landmark 区域的归一化坐标（每区域取前5点，x+y各一维）
        let regions: [VNFaceLandmarkRegion2D?] = [
            landmarks.leftEye,          // 0..9
            landmarks.rightEye,         // 10..19
            landmarks.leftEyebrow,      // 20..29
            landmarks.rightEyebrow,     // 30..39
            landmarks.nose,             // 40..49
            landmarks.noseCrest,        // 50..59
            landmarks.outerLips,        // 60..69
            landmarks.innerLips         // 70..79
        ]

        for region in regions {
            let pts = region?.normalizedPoints ?? []
            for i in 0..<5 {
                if i < pts.count {
                    features.append(Float(pts[i].x))
                    features.append(Float(pts[i].y))
                } else {
                    features.append(0)
                    features.append(0)
                }
            }
        }
        // 到此 features.count == 80

        // ── 2. 关键几何距离比（光照/尺度不变特征）共 20 维
        let geoFeatures = extractGeometricRatios(landmarks: landmarks)
        features.append(contentsOf: geoFeatures)
        // 到此 features.count == 100

        // ── 3. 脸部宽高比及边界框特征（8 维补充）
        let bbox = face.boundingBox
        features.append(Float(bbox.width))
        features.append(Float(bbox.height))
        features.append(Float(bbox.width / max(bbox.height, 1e-5)))  // 宽高比
        features.append(Float(bbox.midX))
        features.append(Float(bbox.midY))
        features.append(Float(bbox.minX))
        features.append(Float(bbox.minY))
        features.append(Float(bbox.maxX))
        // 到此 features.count == 108

        // ── 4. 补零至 128 维
        while features.count < 128 { features.append(0) }
        let truncated = Array(features.prefix(128))

        return l2Normalize(truncated)
    }

    /// 提取 20 个几何比例特征（对人脸大小、光照变化具备不变性）
    private func extractGeometricRatios(landmarks: VNFaceLandmarks2D) -> [Float] {
        var ratios = [Float](repeating: 0, count: 20)

        let leftEyePts  = landmarks.leftEye?.normalizedPoints  ?? []
        let rightEyePts = landmarks.rightEye?.normalizedPoints ?? []
        let nosePts     = landmarks.nose?.normalizedPoints     ?? []
        let lipPts      = landmarks.outerLips?.normalizedPoints ?? []
        let lBrowPts    = landmarks.leftEyebrow?.normalizedPoints  ?? []
        let rBrowPts    = landmarks.rightEyebrow?.normalizedPoints ?? []

        // 左眼中心
        let leftEyeCenter  = centroid(leftEyePts)
        // 右眼中心
        let rightEyeCenter = centroid(rightEyePts)
        // 鼻尖（nose 区域最后一点）
        let noseTip  = nosePts.last ?? CGPoint(x: 0.5, y: 0.5)
        // 嘴中心
        let mouthCenter = centroid(lipPts)
        // 眉毛中心
        let lBrowCenter = centroid(lBrowPts)
        let rBrowCenter = centroid(rBrowPts)

        // 眼距
        let eyeDist = distance(leftEyeCenter, rightEyeCenter)

        if eyeDist > 1e-4 {
            // 0: 眼距（绝对值）
            ratios[0] = Float(eyeDist)
            // 1: 鼻尖 Y 到眼中线的距离 / 眼距
            let eyeMidY = (leftEyeCenter.y + rightEyeCenter.y) / 2
            ratios[1] = Float(abs(noseTip.y - eyeMidY) / eyeDist)
            // 2: 嘴中心 Y 到眼中线的距离 / 眼距
            ratios[2] = Float(abs(mouthCenter.y - eyeMidY) / eyeDist)
            // 3: 左眼到鼻尖 / 眼距
            ratios[3] = Float(distance(leftEyeCenter, noseTip) / eyeDist)
            // 4: 右眼到鼻尖 / 眼距
            ratios[4] = Float(distance(rightEyeCenter, noseTip) / eyeDist)
            // 5: 左眉到左眼 / 眼距
            ratios[5] = Float(distance(lBrowCenter, leftEyeCenter) / eyeDist)
            // 6: 右眉到右眼 / 眼距
            ratios[6] = Float(distance(rBrowCenter, rightEyeCenter) / eyeDist)
            // 7: 嘴宽 / 眼距（嘴两端点距离）
            if lipPts.count >= 2 {
                let lipWidth = distance(lipPts.first!, lipPts[lipPts.count / 2])
                ratios[7] = Float(lipWidth / eyeDist)
            }
            // 8: 眼中线 X 偏移（人脸左右对称性）
            let eyeMidX = (leftEyeCenter.x + rightEyeCenter.x) / 2
            ratios[8] = Float(abs(noseTip.x - eyeMidX) / eyeDist)
            // 9: 鼻到嘴的距离 / 眼距
            ratios[9] = Float(distance(noseTip, mouthCenter) / eyeDist)
        }
        // 10-19: 留零作为未来特征扩展预留位

        return ratios
    }

    // MARK: - 工具函数

    private func centroid(_ pts: [CGPoint]) -> CGPoint {
        guard !pts.isEmpty else { return .zero }
        let sx = pts.reduce(0.0) { $0 + $1.x }
        let sy = pts.reduce(0.0) { $0 + $1.y }
        let n = CGFloat(pts.count)
        return CGPoint(x: sx / n, y: sy / n)
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(b.x - a.x, b.y - a.y)
    }

    private func l2Normalize(_ v: [Float]) -> [Float] {
        let norm = sqrt(v.reduce(0) { $0 + $1 * $1 })
        guard norm > 1e-8 else { return v }
        return v.map { $0 / norm }
    }

    private func imageOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up:            return .up
        case .down:          return .down
        case .left:          return .left
        case .right:         return .right
        case .upMirrored:    return .upMirrored
        case .downMirrored:  return .downMirrored
        case .leftMirrored:  return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default:    return .up
        }
    }
}
