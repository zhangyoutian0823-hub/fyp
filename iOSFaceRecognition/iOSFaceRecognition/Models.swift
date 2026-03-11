//
//  Models.swift
//  iOSFaceRecognition
//

import Foundation

// MARK: - 用户角色

enum UserRole: String, Codable, CaseIterable {
    case standard = "Standard"
    case vip      = "VIP"
}

// MARK: - 普通用户模型

struct AppUser: Identifiable, Codable, Equatable {
    var id: String { userId }
    let userId: String
    var name: String
    /// 注册时拍摄的人脸图片文件名（存于 Documents 目录）
    var faceImageFilename: String?
    /// 128 维 L2 归一化特征向量（核心识别依据）
    var faceEmbedding: [Float]?
    /// SHA-256 哈希后的密码
    var passwordHash: String?
    /// 用户角色
    var role: UserRole
    /// 注册时间
    var createdAt: Date

    // MARK: Security fields (v3 — backward compatible)

    /// 连续登录失败次数（累计，达到阈值后锁定账号）
    var failedAttempts: Int
    /// 锁定到期时间（nil 表示未锁定）
    var lockedUntil: Date?
    /// 账号是否启用（管理员可禁用）
    var isActive: Bool

    init(userId: String,
         name: String,
         faceImageFilename: String? = nil,
         faceEmbedding: [Float]? = nil,
         passwordHash: String? = nil,
         role: UserRole = .standard,
         createdAt: Date = Date(),
         failedAttempts: Int = 0,
         lockedUntil: Date? = nil,
         isActive: Bool = true) {
        self.userId = userId
        self.name = name
        self.faceImageFilename = faceImageFilename
        self.faceEmbedding = faceEmbedding
        self.passwordHash = passwordHash
        self.role = role
        self.createdAt = createdAt
        self.failedAttempts = failedAttempts
        self.lockedUntil = lockedUntil
        self.isActive = isActive
    }

    // MARK: - Codable (backward compatible — old JSON won't have new fields)

    enum CodingKeys: String, CodingKey {
        case userId, name, faceImageFilename, faceEmbedding
        case passwordHash, role, createdAt
        case failedAttempts, lockedUntil, isActive
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        userId           = try  c.decode(String.self,      forKey: .userId)
        name             = try  c.decode(String.self,      forKey: .name)
        faceImageFilename = try? c.decodeIfPresent(String.self,  forKey: .faceImageFilename) ?? nil
        faceEmbedding    = try? c.decodeIfPresent([Float].self,  forKey: .faceEmbedding)    ?? nil
        passwordHash     = try? c.decodeIfPresent(String.self,   forKey: .passwordHash)     ?? nil
        role             = (try? c.decode(UserRole.self,          forKey: .role))            ?? .standard
        createdAt        = try  c.decode(Date.self,               forKey: .createdAt)
        // v3 fields — default when missing from old data
        failedAttempts   = (try? c.decodeIfPresent(Int.self,     forKey: .failedAttempts))  ?? 0
        lockedUntil      = try? c.decodeIfPresent(Date.self,     forKey: .lockedUntil)      ?? nil
        isActive         = (try? c.decodeIfPresent(Bool.self,    forKey: .isActive))         ?? true
    }
}

