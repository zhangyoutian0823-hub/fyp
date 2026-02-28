//
//  UserStore.swift
//  iOSFaceRecognition
//

import Foundation
import Combine
import UIKit

@MainActor
final class UserStore: ObservableObject {
    @Published private(set) var users: [AppUser] = []
    private let key = "users_db_v2"   // v2: new model without password

    init() { load() }

    // MARK: - Query

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        users = (try? JSONDecoder().decode([AppUser].self, from: data)) ?? []
    }

    func findUser(userId: String) -> AppUser? {
        users.first(where: { $0.userId == userId })
    }

    // MARK: - Register (multi-frame embedding)

    /// Register a new user.
    /// - Parameters:
    ///   - name: Display name
    ///   - userId: Unique user ID
    ///   - faceImages: Multiple face capture images (recommend 3 frames)
    func register(name: String,
                  userId: String,
                  faceImages: [UIImage],
                  role: UserRole = .standard) async throws {
        if findUser(userId: userId) != nil {
            throw RegistrationError.userIdExists
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
            role: role
        )
        users.append(user)
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

    // MARK: - Delete User

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

    // MARK: - Persistence

    private func persist() {
        let data = (try? JSONEncoder().encode(users)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }
}

// MARK: - Error Types

enum RegistrationError: LocalizedError {
    case userIdExists
    case noFaceImage
    case faceNotDetected
    case userNotFound
    case imageSaveFailed

    var errorDescription: String? {
        switch self {
        case .userIdExists:     return "User ID already exists."
        case .noFaceImage:      return "No face image provided."
        case .faceNotDetected:  return "No face detected in the image. Please retake."
        case .userNotFound:     return "User not found."
        case .imageSaveFailed:  return "Failed to save image."
        }
    }
}
