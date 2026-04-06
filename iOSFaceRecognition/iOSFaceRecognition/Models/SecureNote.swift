//
//  SecureNote.swift
//  iOSFaceRecognition
//
//  Vault item type for sensitive free-form text — license keys, bank PINs,
//  security-question answers, SSH passphrases, etc.
//  Title is visible without authentication; content requires face verification.
//

import Foundation

struct SecureNote: Identifiable, Codable {
    let id: UUID
    var userId:     String
    var title:      String   // Visible in lists (no face auth required)
    var content:    String   // Sensitive — face auth required to reveal
    var isFavorite: Bool
    var createdAt:  Date
    var updatedAt:  Date
    var deletedAt:  Date?    // nil = active, non-nil = soft-deleted

    init(userId: String, title: String, content: String) {
        self.id         = UUID()
        self.userId     = userId
        self.title      = title
        self.content    = content
        self.isFavorite = false
        self.createdAt  = Date()
        self.updatedAt  = Date()
        self.deletedAt  = nil
    }

    // MARK: - Computed helpers

    /// First letter of title for alphabetical grouping; "#" for non-letter starts.
    var firstLetter: String {
        guard let char = title.first, char.isLetter else { return "#" }
        return char.uppercased()
    }

    /// Number of days since this note was soft-deleted, or nil if still active.
    var daysSinceDeleted: Int? {
        guard let d = deletedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: d, to: Date()).day
    }
}
