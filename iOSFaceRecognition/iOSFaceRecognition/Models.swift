//
//  Models.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import Foundation

struct AppUser: Identifiable, Codable, Equatable {
    var id: String { userId }
    let userId: String
    var name: String
    var password: String
    var faceImageFilename: String? // 注册的人脸照片文件名（保存到 Documents）
}

struct AdminAccount {
    static let adminId = "admin"
    static let password = "admin123"
}

