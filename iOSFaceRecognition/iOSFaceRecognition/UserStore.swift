//
//  UserStore.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

import Foundation
import Combine
import UIKit


@MainActor
final class UserStore: ObservableObject {
    @Published private(set) var users: [AppUser] = []
    private let key = "users_db_v1"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            users = []
            return
        }
        users = (try? JSONDecoder().decode([AppUser].self, from: data)) ?? []
    }

    private func persist() {
        let data = (try? JSONEncoder().encode(users)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }

    func findUser(userId: String) -> AppUser? {
        users.first(where: { $0.userId == userId })
    }

    func register(name: String, userId: String, password: String, faceImage: UIImage?) throws {
        if findUser(userId: userId) != nil {
            throw NSError(domain: "Register", code: 1, userInfo: [NSLocalizedDescriptionKey: "User ID 已存在"])
        }

        var newUser = AppUser(userId: userId, name: name, password: password, faceImageFilename: nil)

        if let faceImage {
            let filename = "face_\(userId)_\(UUID().uuidString).jpg"
            try saveImage(faceImage, filename: filename)
            newUser.faceImageFilename = filename
        }

        users.append(newUser)
        persist()
    }

    func updatePassword(userId: String, newPassword: String) throws {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else {
            throw NSError(domain: "UpdatePassword", code: 1, userInfo: [NSLocalizedDescriptionKey: "用户不存在"])
        }
        users[idx].password = newPassword
        persist()
    }

    func updateFace(userId: String, faceImage: UIImage) throws {
        guard let idx = users.firstIndex(where: { $0.userId == userId }) else {
            throw NSError(domain: "UpdateFace", code: 1, userInfo: [NSLocalizedDescriptionKey: "用户不存在"])
        }
        // 删除旧图（可选）
        if let old = users[idx].faceImageFilename {
            deleteImage(filename: old)
        }
        let filename = "face_\(userId)_\(UUID().uuidString).jpg"
        try saveImage(faceImage, filename: filename)
        users[idx].faceImageFilename = filename
        persist()
    }

    func deleteUser(userId: String) {
        if let u = findUser(userId: userId), let fn = u.faceImageFilename {
            deleteImage(filename: fn)
        }
        users.removeAll { $0.userId == userId }
        persist()
    }

    // MARK: - Image Storage

    private func docsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveImage(_ image: UIImage, filename: String) throws {
        let url = docsURL().appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "Image", code: 0, userInfo: [NSLocalizedDescriptionKey: "图片编码失败"])
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
}

