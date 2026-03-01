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
    /// SHA-256 哈希后的密码（可选，兼容旧账户；注册时必填）
    var passwordHash: String?
    /// 用户角色
    var role: UserRole
    /// 注册时间
    var createdAt: Date

    init(userId: String,
         name: String,
         faceImageFilename: String? = nil,
         faceEmbedding: [Float]? = nil,
         passwordHash: String? = nil,
         role: UserRole = .standard,
         createdAt: Date = Date()) {
        self.userId = userId
        self.name = name
        self.faceImageFilename = faceImageFilename
        self.faceEmbedding = faceEmbedding
        self.passwordHash = passwordHash
        self.role = role
        self.createdAt = createdAt
    }
}

// MARK: - 管理员模型

struct AdminUser: Identifiable, Codable, Equatable {
    var id: String { adminId }
    let adminId: String
    var name: String
    var faceImageFilename: String?
    var faceEmbedding: [Float]?
    /// SHA-256 哈希后的密码（注册时必填）
    var passwordHash: String?
    var createdAt: Date

    init(adminId: String,
         name: String,
         faceImageFilename: String? = nil,
         faceEmbedding: [Float]? = nil,
         passwordHash: String? = nil,
         createdAt: Date = Date()) {
        self.adminId = adminId
        self.name = name
        self.faceImageFilename = faceImageFilename
        self.faceEmbedding = faceEmbedding
        self.passwordHash = passwordHash
        self.createdAt = createdAt
    }
}
