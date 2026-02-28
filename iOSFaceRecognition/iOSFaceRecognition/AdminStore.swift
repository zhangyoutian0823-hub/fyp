//
//  AdminStore.swift
//  iOSFaceRecognition
//

//
//  AdminStore.swift
//  iOSFaceRecognition
//

//
//  AdminStore.swift
//  iOSFaceRecognition
//

import Foundation
import UIKit
import Combine

struct AdminUser: Identifiable, Codable, Equatable {
    var id: String { adminId }
    let adminId: String
    var name: String
    var password: String
    var faceImageFilename: String?
}

final class AdminStore: ObservableObject {
    @Published private(set) var admins: [AdminUser] = []
    private let key = "admins_db_v1"

    init() { load() }

    func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            admins = []
            return
        }
        admins = (try? JSONDecoder().decode([AdminUser].self, from: data)) ?? []
    }

    private func persist() {
        let data = (try? JSONEncoder().encode(admins)) ?? Data()
        UserDefaults.standard.set(data, forKey: key)
    }

    func findAdmin(adminId: String) -> AdminUser? {
        admins.first(where: { $0.adminId == adminId })
    }

    func register(name: String, adminId: String, password: String, faceImage: UIImage?) throws {
        if findAdmin(adminId: adminId) != nil {
            throw NSError(domain: "AdminRegister", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Admin ID 已存在"])
        }
        var newAdmin = AdminUser(adminId: adminId, name: name, password: password, faceImageFilename: nil)
        if let faceImage = faceImage {
            let filename = "admin_face_\(adminId)_\(UUID().uuidString).jpg"
            try saveImage(faceImage, filename: filename)
            newAdmin.faceImageFilename = filename
        }
        admins.append(newAdmin)
        persist()
    }

    private func docsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private func saveImage(_ image: UIImage, filename: String) throws {
        let url = docsURL().appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.9) else {
            throw NSError(domain: "Image", code: 0,
                          userInfo: [NSLocalizedDescriptionKey: "图片编码失败"])
        }
        try data.write(to: url, options: [.atomic])
    }

    func loadImage(filename: String) -> UIImage? {
        let url = docsURL().appendingPathComponent(filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
}
