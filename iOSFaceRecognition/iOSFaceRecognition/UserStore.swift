//
//  UserStore.swift
//  iOSFaceRecognition
//

import Foundation
import Combine
import UIKit
import CryptoKit

@MainActor
final class UserStore: ObservableObject {
    @Published private(set) var users: [AppUser] = []
    private let key = "users_db_v2"   // v2: stored in Keychain (AES-256 encrypted)

    init() { load() }

    // MARK: - Query

    func load() {
        guard let data = KeychainHelper.load(account: key) else { return }
        users = (try? JSONDecoder().decode([AppUser].self, from: data)) ?? []
    }

    func findUser(userId: String) -> AppUser? {
        users.first(where: { $0.userId == userId })
    }

    // MARK: - Password Hashing

    /// SHA-256 哈希密码（不可逆，不明文存储）
    func hashPassword(_ raw: String) -> String {
        let digest = SHA256.hash(data: Data(raw.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// 验证密码是否匹配
    func verifyPassword(userId: String, password: String) -> Bool {
        guard let user = findUser(userId: userId),
              let storedHash = user.passwordHash else { return false }
        return hashPassword(password) == storedHash
    }

    // MARK: - Register (multi-frame embedding + password)

    /// Register a new user.
    /// - Parameters:
    ///   - name: Display name
    ///   - userId: Unique user ID
    ///   - password: Plain-text password (will be SHA-256 hashed before storage)
    ///   - faceImages: Multiple face capture images (recommend 3 frames)
    func register(name: String,
                  userId: String,
                  password: String,
                  faceImages: [UIImage],
                  role: UserRole = .standard) async throws {
        if findUser(userId: userId) != nil {
            throw RegistrationError.userIdExists
        }
        guard password.count >= 6 else {
            throw RegistrationError.weakPassword
        }
        guard !faceImages.isEmpty else {
            throw RegistrationError.noFaceImage
        }

        // Extract embedding from each frame
        let service = FaceEmbeddingService.shared
        var embeddings: [[Float]] = []
        for img in faceImages {
            if let emb = await service.extractEmbedding(from: img) {
                embeddings.append(emb)
            }
        }
        guard !embeddings.isEmpty else {
            throw RegistrationError.faceNotDetected
        }

        // Average multi-frame embeddings for better accuracy
        let avgEmbedding = service.averageEmbedding(embeddings)

        // Save face image (first frame as display thumbnail)
        var filename: String? = nil
        if let firstImg = faceImages.first {
            filename = "face_\(userId)_\(UUID().uuidString).jpg"
            try saveImage(firstImg, filename: filename!)
        }

        let user = AppUser(
            userId: userId,
            name: name,
            faceImageFilename: filename,
            faceEmbedding: avgEmbedding,
            passwordHash: hashPassword(password),
            role: role
        )
        users.append(user)
        persist()
    }

    // MARK: - Update Password

    /// 更新用户密码哈希值（由 UpdatePasswordView 调用，已验证旧密码后才调用此方法）
    func updatePasswordHash(userId: String, newHash: String) {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else { return }
        users[idx].passwordHash = newHash
        persist()
    }

    // MARK: - Update Face

    func updateFace(userId: String, faceImages: [UIImage]) async throws {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else {
            throw RegistrationError.userNotFound
        }
        guard !faceImages.isEmpty else { throw RegistrationError.noFaceImage }

        // Remove old image
        if let old = users[idx].faceImageFilename { deleteImage(filename: old) }

        let service = FaceEmbeddingService.shared
        var embeddings: [[Float]] = []
        for img in faceImages {
            if let emb = await service.extractEmbedding(from: img) {
                embeddings.append(emb)
            }
        }
        guard !embeddings.isEmpty else { throw RegistrationError.faceNotDetected }

        let avgEmbedding = service.averageEmbedding(embeddings)
        let filename = "face_\(userId)_\(UUID().uuidString).jpg"
        try saveImage(faceImages[0], filename: filename)

        users[idx].faceEmbedding = avgEmbedding
        users[idx].faceImageFilename = filename
        persist()
    }

    // MARK: - Lockout Management

    private var maxFailedAttempts: Int { AppSettings.maxFailedAttempts }
    private var lockDurationSeconds: TimeInterval { TimeInterval(AppSettings.lockoutMinutes * 60) }

    /// 账号是否仍在锁定期内
    func isLocked(userId: String) -> Bool {
        guard let user = findUser(userId: userId),
              let until = user.lockedUntil else { return false }
        return Date() < until
    }

    /// 锁定剩余分钟数（向上取整）
    func lockRemainingMinutes(userId: String) -> Int {
        guard let user = findUser(userId: userId),
              let until = user.lockedUntil,
              Date() < until else { return 0 }
        return max(1, Int(ceil(until.timeIntervalSinceNow / 60)))
    }

    /// 记录一次失败尝试，达到阈值后锁定账号
    func recordFailedAttempt(userId: String) {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else { return }
        users[idx].failedAttempts += 1
        if users[idx].failedAttempts >= maxFailedAttempts {
            users[idx].lockedUntil = Date().addingTimeInterval(lockDurationSeconds)
        }
        persist()
    }

    /// 清除失败计数（登录成功后调用）
    func clearFailedAttempts(userId: String) {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else { return }
        users[idx].failedAttempts = 0
        users[idx].lockedUntil = nil
        persist()
    }

    /// 管理员手动解锁账号
    func unlockAccount(userId: String) {
        clearFailedAttempts(userId: userId)
    }

    // MARK: - Account Active / Disable

    /// 管理员启用或禁用账号
    func setActive(userId: String, isActive: Bool) {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else { return }
        users[idx].isActive = isActive
        persist()
    }

    // MARK: - Update Name

    /// 用户修改自己的显示名称
    func updateName(userId: String, newName: String) {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else { return }
        users[idx].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        persist()
    }

    // MARK: - Update Role

    /// 管理员修改用户角色
    func updateRole(userId: String, newRole: UserRole) {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else { return }
        users[idx].role = newRole
        persist()
    }

    // MARK: - Delete User

    func deleteUser(userId: String,
                    passwordStore: PasswordStore? = nil,
                    noteStore: NoteStore? = nil,
                    wifiStore: WiFiStore? = nil) {
        if let u = findUser(userId: userId), let fn = u.faceImageFilename {
            deleteImage(filename: fn)
        }
        users.removeAll { $0.userId == userId }
        persist()
        // 同步删除该用户的全部数据，防止孤立记录残留
        passwordStore?.deleteAll(for: userId)
        noteStore?.deleteAll(for: userId)
        wifiStore?.deleteAll(for: userId)
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

    private func deleteImage(filename: String) {
        let url = docsURL().appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - 1:N Face Identification

    /// 在全部已激活且已注册人脸的用户中，找出与 queryEmbedding 最相似的人。
    /// - Returns: (userId, score)；userId 为 nil 表示没有任何注册用户可比对。
    ///   调用方需自行判断 score 是否 >= 阈值。
    func identifyUser(from queryEmbedding: [Float]) -> (userId: String?, score: Float) {
        var bestId: String? = nil
        var bestScore: Float = 0
        for user in users {
            guard user.isActive, let emb = user.faceEmbedding else { continue }
            let score = FaceMatchService.shared.similarity(queryEmbedding, emb)
            if score > bestScore {
                bestScore = score
                bestId = user.userId
            }
        }
        return (bestId, bestScore)
    }

    // MARK: - Persistence

    private func persist() {
        let data = (try? JSONEncoder().encode(users)) ?? Data()
        KeychainHelper.save(data, account: key)
    }
}

// MARK: - Error Types

enum RegistrationError: LocalizedError {
    case userIdExists
    case noFaceImage
    case faceNotDetected
    case userNotFound
    case imageSaveFailed
    case weakPassword
    case passwordMismatch
    case invalidInviteCode

    var errorDescription: String? {
        switch self {
        case .userIdExists:      return "User ID already exists."
        case .noFaceImage:       return "No face image provided."
        case .faceNotDetected:   return "No face detected in the image. Please retake."
        case .userNotFound:      return "User not found."
        case .imageSaveFailed:   return "Failed to save image."
        case .weakPassword:      return "Password must be at least 6 characters."
        case .passwordMismatch:  return "Passwords do not match."
        case .invalidInviteCode: return "Invalid or expired admin invite code."
        }
    }
}
