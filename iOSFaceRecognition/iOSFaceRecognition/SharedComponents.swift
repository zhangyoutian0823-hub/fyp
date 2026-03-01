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
    /// Deep navy-blue gradient — user-facing hero screens.
    static var appHeroBlue: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.11, green: 0.18, blue: 0.50),
                Color(red: 0.04, green: 0.08, blue: 0.32)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Deep indigo-purple gradient — admin portal hero screens.
    static var appHeroIndigo: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.24, green: 0.10, blue: 0.52),
                Color(red: 0.10, green: 0.04, blue: 0.32)
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
