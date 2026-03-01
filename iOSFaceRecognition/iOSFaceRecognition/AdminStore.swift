//
//  AdminStore.swift
//  iOSFaceRecognition
//
//  管理员 ViewModel。注册时要求密码 + 人脸，
//  并通过邀请码机制限制注册权限（首位管理员无需邀请码）。
//

import Foundation
import UIKit
import Combine
import CryptoKit

@MainActor
final class AdminStore: ObservableObject {
    @Published private(set) var admins: [AdminUser] = []
    private let key = "admins_db_v2"

    init() { load() }

    // MARK: - First Setup Detection

    /// 当前系统是否尚无管理员（首次设置模式）
    var isFirstSetup: Bool { admins.isEmpty }

    // MARK: - Persistence

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        admins = (try? JSONDecoder().decode([AdminUser].self, from: data)) ?? []
    }

    private func persist() {
        let data = (try? JSONEncoder().encode(admins)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }

    // MARK: - Query

    func findAdmin(adminId: String) -> AdminUser? {
        admins.first(where: { $0.adminId == adminId })
    }

    // MARK: - Password Hashing

    func hashPassword(_ raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - Register Admin

    /// 注册管理员账号。
    /// - Parameters:
    ///   - name: 管理员姓名
    ///   - adminId: 管理员 ID（唯一）
    ///   - password: 明文密码（≥6位），将 SHA-256 哈希后存储
    ///   - inviteCode: 邀请码（当系统已有管理员时必填）
    ///   - faceImages: 多帧人脸图像（建议3帧）
    func register(name: String,
                  adminId: String,
                  password: String,
                  inviteCode: String? = nil,
                  faceImages: [UIImage]) async throws {

        // 1. 唯一性检查
        if findAdmin(adminId: adminId) != nil {
            throw RegistrationError.userIdExists
        }

        // 2. 密码强度检查
        guard password.count >= 6 else {
            throw RegistrationError.weakPassword
        }

        // 3. 邀请码检查（非首次注册时强制验证）
        if !isFirstSetup {
            let code = (inviteCode ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !code.isEmpty, AdminInviteService.shared.validate(code) else {
                throw RegistrationError.invalidInviteCode
            }
        }

        // 4. 人脸检查
        guard !faceImages.isEmpty else { throw RegistrationError.noFaceImage }

        // 5. 提取多帧 embedding 取平均
        let service = FaceEmbeddingService.shared
        var embeddings: [[Float]] = []
        for img in faceImages {
            if let emb = await service.extractEmbedding(from: img) {
                embeddings.append(emb)
            }
        }
        guard !embeddings.isEmpty else { throw RegistrationError.faceNotDetected }
        let avgEmbedding = service.averageEmbedding(embeddings)

        // 6. 保存人脸照片
        var filename: String? = nil
        if let first = faceImages.first {
            filename = "admin_face_\(adminId)_\(UUID().uuidString).jpg"
            try saveImage(first, filename: filename!)
        }

        // 7. 创建管理员记录
        let admin = AdminUser(
            adminId: adminId,
            name: name,
            faceImageFilename: filename,
            faceEmbedding: avgEmbedding,
            passwordHash: hashPassword(password)
        )
        admins.append(admin)
        persist()

        // 8. 消费邀请码（注册成功后才失效）
        if !isFirstSetup, let code = inviteCode {
            AdminInviteService.shared.consume(code.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }

    // MARK: - Image Storage

    private func docsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveImage(_ image: UIImage, filename: String) throws {
        let url = docsURL().appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw RegistrationError.imageSaveFailed
        }
        try data.write(to: url, options: [.atomic])
    }

    func loadImage(filename: String) -> UIImage? {
        let url = docsURL().appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
