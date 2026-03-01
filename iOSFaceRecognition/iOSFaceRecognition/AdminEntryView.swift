//
//  AdminEntryView.swift
//  iOSFaceRecognition
//
//  Admin portal landing — indigo hero with register/login options.
//

import SwiftUI

struct AdminEntryView: View {

    private let accentColor = Color(red: 0.24, green: 0.10, blue: 0.52)

    var body: some View {
        ZStack(alignment: .bottom) {
            // Indigo-purple hero gradient
            LinearGradient.appHeroIndigo
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Hero content
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.05))
                            .frame(width: 160, height: 160)
                        Circle()
                            .fill(.white.opacity(0.09))
                            .frame(width: 122, height: 122)
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 88, height: 88)
                        Image(systemName: "person.badge.shield.checkmark")
                            .font(.system(size: 42, weight: .light))
                            .foregroundStyle(.white)
                    }

                    VStack(spacing: 8) {
                        Text("Admin Portal")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Face authentication required for all\nadmin operations")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.60))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Bottom action card
                VStack(spacing: 14) {
                    NavigationLink(destination: AdminLoginView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.shield.checkmark")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Admin Sign In")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(.white)
                        .foregroundStyle(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    NavigationLink(destination: AdminRegisterView()) {
                        HStack(spacing: 10) {
                            Image(systemName: "person.badge.plus")
                                .font(.system(size: 17, weight: .semibold))
                            Text("Register as Admin")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(accentColor.opacity(0.10))
                        .foregroundStyle(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(accentColor.opacity(0.30), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 30)
                .padding(.bottom, 40)
                .background(
                    TopRoundedRectangle(radius: 32)
                        .fill(Color(uiColor: .systemBackground))
                        .shadow(color: .black.opacity(0.22), radius: 24, y: -6)
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}
