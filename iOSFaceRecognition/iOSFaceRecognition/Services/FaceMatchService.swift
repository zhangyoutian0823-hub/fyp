//
//  FaceMatchService.swift
//  iOSFaceRecognition
//
//  使用余弦相似度对两个 L2 归一化特征向量进行人脸匹配。
//  因为输入向量已 L2 归一化，余弦相似度等同于向量点积。
//  使用 Accelerate.vDSP 进行硬件加速计算。
//

import Foundation
import Accelerate

/// 人脸特征向量匹配服务（单例）
final class FaceMatchService {

    static let shared = FaceMatchService()
    private init() {}

    /// 默认匹配阈值。相似度 >= threshold 认为是同一人。
    /// 范围 [0, 1]，推荐 0.72 ~ 0.80
    var threshold: Float = 0.75

    // MARK: - 公开接口

    /// 判断 query 与 stored 是否为同一人。
    func match(query: [Float], against stored: [Float]) -> Bool {
        similarity(query, stored) >= threshold
    }

    /// 计算两个特征向量的余弦相似度。
    /// - Returns: 值域 [-1, 1]，越接近 1 越相似。
    func similarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        // 使用 vDSP_dotpr 进行向量点积（硬件加速）
        var result: Float = 0
        vDSP_dotpr(a, 1, b, 1, &result, vDSP_Length(a.count))

        // 输入已 L2 归一化，点积即余弦相似度，夹紧到 [-1, 1]
        return max(-1, min(1, result))
    }

    /// 将相似度映射为 [0, 100] 的百分比字符串，便于 UI 展示。
    func similarityPercent(_ a: [Float], _ b: [Float]) -> String {
        let s = similarity(a, b)
        let pct = Int(max(0, s) * 100)
        return "\(pct)%"
    }

    /// 对多个 stored embedding 取最大相似度（1-to-N 匹配，用于多帧注册）。
    func bestMatch(query: [Float], candidates: [[Float]]) -> (matched: Bool, score: Float) {
        guard !candidates.isEmpty else { return (false, 0) }
        let best = candidates.map { similarity(query, $0) }.max() ?? 0
        return (best >= threshold, best)
    }
}
