//
//  SharedComponents.swift
//  iOSFaceRecognition
//
//  Shared shapes, gradients, and helpers used across all screens.
//

import SwiftUI

// MARK: - Scanner Bracket Shape
// Corner-bracket overlay that gives camera frames a "face scanner" look.

struct ScannerBracketShape: Shape {
    var cornerLength: CGFloat = 28

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let l = cornerLength

        // Top-left
        p.move(to: CGPoint(x: rect.minX, y: rect.minY + l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.minY))
        // Top-right
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + l))
        // Bottom-left
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - l))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX + l, y: rect.maxY))
        // Bottom-right
        p.move(to: CGPoint(x: rect.maxX - l, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - l))

        return p
    }
}

// MARK: - Top-Rounded Rectangle
// A rectangle that only rounds the top two corners, used for bottom-sheet cards.

struct TopRoundedRectangle: Shape {
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - App Gradients

extension LinearGradient {
    /// FaceVault signature gradient — rich blue with subtle indigo depth.
    static var appHeroBlue: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.14, green: 0.22, blue: 0.58),  // vivid mid-blue
                Color(red: 0.06, green: 0.08, blue: 0.36),  // deep navy
                Color(red: 0.04, green: 0.05, blue: 0.26)   // near-black blue
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Section Header Style

struct SectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        Label(title, systemImage: icon)
            .font(.footnote.bold())
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Container

struct AppCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Primary Button Style

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color.opacity(configuration.isPressed ? 0.75 : 1.0))
            .foregroundStyle(.white)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Secondary Button Style

struct SecondaryButtonStyle: ButtonStyle {
    var color: Color = .blue

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(color.opacity(configuration.isPressed ? 0.12 : 0.08))
            .foregroundStyle(color)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Password Strength

enum PasswordStrength: Int {
    case weak = 1, fair = 2, good = 3, strong = 4

    var label: String {
        switch self {
        case .weak:   return "Weak"
        case .fair:   return "Fair"
        case .good:   return "Good"
        case .strong: return "Strong"
        }
    }

    var color: Color {
        switch self {
        case .weak:   return .red
        case .fair:   return .orange
        case .good:   return Color(red: 0.85, green: 0.65, blue: 0.0)   // amber
        case .strong: return .green
        }
    }

    /// Scores the password on 5 criteria and maps to 4 strength levels.
    static func evaluate(_ password: String) -> PasswordStrength {
        guard !password.isEmpty else { return .weak }
        var score = 0
        if password.count >= 8  { score += 1 }
        if password.count >= 14 { score += 1 }
        if password.range(of: "[A-Z]",        options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[0-9]",        options: .regularExpression) != nil { score += 1 }
        if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }
        switch score {
        case 0...1: return .weak
        case 2:     return .fair
        case 3:     return .good
        default:    return .strong
        }
    }
}

/// A compact 4-segment strength bar + label, suitable for embedding in a Form row.
struct PasswordStrengthBar: View {
    let password: String

    private var strength: PasswordStrength { PasswordStrength.evaluate(password) }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 5) {
                ForEach(1...4, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(level <= strength.rawValue ? strength.color : Color(.systemFill))
                        .frame(height: 4)
                }
            }
            Text(strength.label)
                .font(.caption2.bold())
                .foregroundStyle(strength.color)
                .frame(minWidth: 46, alignment: .trailing)
        }
        .animation(.easeInOut(duration: 0.25), value: strength.rawValue)
        .padding(.vertical, 2)
    }
}

// MARK: - Password Generator Logic

enum PasswordGenerator {
    static func generate(
        length: Int,
        useUppercase: Bool,
        useDigits: Bool,
        useSymbols: Bool
    ) -> String {
        let lower   = "abcdefghijklmnopqrstuvwxyz"
        let upper   = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        let digits  = "0123456789"
        let symbols = "!@#$%^&*()-_=+[]{}|;:,.<>?"

        var pool = lower
        var required: [Character] = [lower.randomElement()!]

        if useUppercase { pool += upper;   required.append(upper.randomElement()!)   }
        if useDigits    { pool += digits;  required.append(digits.randomElement()!)  }
        if useSymbols   { pool += symbols; required.append(symbols.randomElement()!) }

        let poolArr = Array(pool)
        var chars   = required
        let extra   = max(0, length - required.count)
        for _ in 0..<extra {
            chars.append(poolArr[Int.random(in: 0..<poolArr.count)])
        }
        return String(chars.shuffled())
    }
}
