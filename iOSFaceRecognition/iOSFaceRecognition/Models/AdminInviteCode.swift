//
//  AdminInviteCode.swift
//  iOSFaceRecognition
//
//  管理员邀请码数据模型。
//  邀请码由现有管理员生成，8位字母数字混合，有效期24小时，单次使用即失效。
//

import Foundation

struct AdminInviteCode: Identifiable, Codable {
    let id: UUID
    /// 8位字母数字随机码
    let code: String
    /// 生成此码的管理员 ID
    let createdByAdminId: String
    /// 生成时间
    let createdAt: Date
    /// 是否已使用
    var isUsed: Bool
    /// 使用时间（已使用时记录）
    var usedAt: Date?

    /// 是否已过期（超过24小时）
    var isExpired: Bool {
        Date().timeIntervalSince(createdAt) > 86_400   // 24 hours
    }

    /// 是否有效（未使用且未过期）
    var isValid: Bool { !isUsed && !isExpired }

    /// 剩余有效时间（小时），方便 UI 显示
    var remainingHours: Double {
        max(0, 24.0 - Date().timeIntervalSince(createdAt) / 3600)
    }

    init(code: String, createdByAdminId: String) {
        self.id = UUID()
        self.code = code
        self.createdByAdminId = createdByAdminId
        self.createdAt = Date()
        self.isUsed = false
        self.usedAt = nil
    }
}
