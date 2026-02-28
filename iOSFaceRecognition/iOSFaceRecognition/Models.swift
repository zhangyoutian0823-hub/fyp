//
//  Models.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

//
//  Models.swift
//  iOSFaceRecognition
//

import Foundation

struct AppUser: Identifiable, Codable, Equatable {
    var id: String { userId }
    let userId: String
    var name: String
    var password: String
    var faceImageFilename: String?
}
