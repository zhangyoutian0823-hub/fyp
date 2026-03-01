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
    case adminLoginSuccess    = "Admin Login Success"
    case adminLoginFailed     = "Admin Login Failed"
    case passwordLoginSuccess = "Password Login Success"   // 密码方式登录成功
    case passwordLoginFailed  = "Password Login Failed"    // 密码方式登录失败

    var icon: String {
        switch self {
        case .loginSuccess, .adminLoginSuccess, .passwordLoginSuccess:
            return "checkmark.circle.fill"
        case .loginFailed, .adminLoginFailed, .passwordLoginFailed:
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
        switch self {
        case .loginSuccess, .adminLoginSuccess, .passwordLoginSuccess: return true
        default: return false
        }
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
