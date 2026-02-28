//
//  AdminStore.swift
//  iOSFaceRecognition
//

import Foundation
import UIKit
import Combine

@MainActor
final class AdminStore: ObservableObject {
    @Published private(set) var admins: [AdminUser] = []
    private let key = "admins_db_v2"  // v2: new model without password

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        admins = (try? JSONDecoder().decode([AdminUser].self, from: data)) ?? []
    }

    private func persist() {
        let data = (try? JSONEncoder().encode(admins)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }

    func findAdmin(adminId: String) -> AdminUser? {
        admins.first(where: { $0.adminId == adminId })
    }

    // MARK: - Register Admin (multi-frame embedding)

    func register(name: String, adminId: String, faceImages: [UIImage]) async throws {
        if findAdmin(adminId: adminId) != nil {
            throw RegistrationError.userIdExists
        }
        guard !faceImages.isEmpty else { throw RegistrationError.noFaceImage }

        let service = FaceEmbeddingService.shared
        var embeddings: [[Float]] = []
        for img in faceImages {
            if let emb = await service.extractEmbedding(from: img) {
                embeddings.append(emb)
            }
        }
        guard !embeddings.isEmpty else { throw RegistrationError.faceNotDetected }

        let avgEmbedding = service.averageEmbedding(embeddings)
        var filename: String? = nil
        if let first = faceImages.first {
            filename = "admin_face_\(adminId)_\(UUID().uuidString).jpg"
            try saveImage(first, filename: filename!)
        }

        let admin = AdminUser(
            adminId: adminId,
            name: name,
            faceImageFilename: filename,
            faceEmbedding: avgEmbedding
        )
        admins.append(admin)
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
}
