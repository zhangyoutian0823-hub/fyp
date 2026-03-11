//
//  AccessLog.swift
//  iOSFaceRecognition
//
//  记录每次认证事件，包括成功/失败、相似度分数、时间戳等。
//

import Foundation

// MARK: - 认证事件类型

enum AccessEventType: String, Codable, CaseIterable {
    case loginSuccess         = "Login Success"
    case loginFailed          = "Login Failed"
    case faceMatchFailed      = "Face Match Failed"
    case userNotFound         = "User Not Found"
    case noFaceDetected       = "No Face Detected"
    case passwordLoginSuccess = "Password Login Success"
    case passwordLoginFailed  = "Password Login Failed"

    var icon: String {
        switch self {
        case .loginSuccess, .passwordLoginSuccess:
            return "checkmark.circle.fill"
        case .loginFailed, .passwordLoginFailed:
            return "xmark.circle.fill"
        case .faceMatchFailed:
            return "face.smiling.inverse"
        case .userNotFound:
            return "person.slash"
        case .noFaceDetected:
            return "eye.slash"
        }
    }

    var isSuccess: Bool {
        self == .loginSuccess || self == .passwordLoginSuccess
    }
}

// MARK: - 访问日志模型

struct AccessLog: Identifiable, Codable {
    let id: UUID
    let userId: String          // 尝试登录的用户 ID
    let timestamp: Date
    let eventType: AccessEventType
    let similarityScore: Float? // 人脸匹配相似度（0.0 ~ 1.0），无法计算时为 nil
    let deviceName: String      // 设备名称（用于多终端场景）

    init(
        userId: String,
        eventType: AccessEventType,
        similarityScore: Float? = nil
    ) {
        self.id = UUID()
        self.userId = userId
        self.timestamp = Date()
        self.eventType = eventType
        self.similarityScore = similarityScore
        self.deviceName = UIDevice.current.name
    }
}

// MARK: - 导入 UIDevice
import UIKit
