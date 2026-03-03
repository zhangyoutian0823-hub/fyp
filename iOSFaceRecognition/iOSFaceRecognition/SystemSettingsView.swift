//
//  SystemSettingsView.swift
//  iOSFaceRecognition
//
//  Admin-only system configuration page.
//  All settings persist to UserDefaults via AppSettings and take effect immediately.
//

import SwiftUI

struct SystemSettingsView: View {
    @EnvironmentObject var session: SessionStore

    // Live state mirroring AppSettings (so Sliders/Steppers bind reactively)
    @State private var threshold: Double     = Double(AppSettings.faceThreshold)
    @State private var maxAttempts: Int      = AppSettings.maxFailedAttempts
    @State private var lockoutMinutes: Int   = AppSettings.lockoutMinutes
    @State private var timeoutMinutes: Int   = AppSettings.sessionTimeoutMinutes
    @State private var showResetAlert        = false
    @State private var showSavedBanner       = false

    private let lockoutOptions  = [5, 10, 15, 30]
    private let timeoutOptions  = [5, 15, 30, 60]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {

                // ── Face Recognition ──
                settingsSection(title: "Face Recognition", icon: "faceid") {
                    // Threshold slider
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Similarity Threshold")
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(String(format: "%.2f  (%.0f%%)", threshold, threshold * 100))
                                .font(.subheadline.bold())
                                .foregroundStyle(thresholdColor)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                        Slider(value: $threshold, in: 0.60...0.90, step: 0.01)
                            .tint(thresholdColor)
                            .padding(.horizontal, 16)
                            .onChange(of: threshold) { _, v in
                                AppSettings.faceThreshold = Float(v)
                            }

                        HStack {
                            Text("60% (Lenient)")
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text("90% (Strict)")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)

                        Divider().padding(.leading, 16)

                        // Preset buttons
                        HStack(spacing: 10) {
                            presetButton("Lenient",  value: 0.68, color: .green)
                            presetButton("Default",  value: 0.75, color: .blue)
                            presetButton("Strict",   value: 0.82, color: .orange)
                            presetButton("Secure",   value: 0.88, color: .red)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 14)
                    }
                }

                // ── Account Security ──
                settingsSection(title: "Account Security", icon: "lock.shield") {
                    // Max failed attempts
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Max Failed Attempts")
                                .font(.subheadline)
                            Text("Before account lockout")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Stepper("\(maxAttempts)", value: $maxAttempts, in: 3...10)
                            .labelsHidden()
                            .onChange(of: maxAttempts) { _, v in
                                AppSettings.maxFailedAttempts = v
                            }
                        Text("\(maxAttempts)")
                            .font(.subheadline.bold())
                            .foregroundStyle(.primary)
                            .frame(width: 28)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)

                    Divider().padding(.leading, 16)

                    // Lockout duration
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lockout Duration")
                                .font(.subheadline)
                            Text("Minutes account stays locked")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $lockoutMinutes) {
                            ForEach(lockoutOptions, id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: lockoutMinutes) { _, v in
                            AppSettings.lockoutMinutes = v
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                // ── Session ──
                settingsSection(title: "Session", icon: "timer") {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Idle Timeout")
                                .font(.subheadline)
                            Text("Auto-logout after inactivity")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Picker("", selection: $timeoutMinutes) {
                            ForEach(timeoutOptions, id: \.self) { min in
                                Text("\(min) min").tag(min)
                            }
                        }
                        .pickerStyle(.menu)
                        .onChange(of: timeoutMinutes) { _, v in
                            AppSettings.sessionTimeoutMinutes = v
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                // ── Current values summary ──
                currentValuesSummary

                // ── Reset ──
                AppCard {
                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        HStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            Text("Reset to Defaults")
                                .font(.body)
                                .foregroundStyle(.red)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                    }
                }

                Spacer(minLength: 24)
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("System Settings")
        .navigationBarTitleDisplayMode(.large)
        .alert("Reset to Defaults?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                AppSettings.resetToDefaults()
                threshold      = Double(AppSettings.faceThreshold)
                maxAttempts    = AppSettings.maxFailedAttempts
                lockoutMinutes = AppSettings.lockoutMinutes
                timeoutMinutes = AppSettings.sessionTimeoutMinutes
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will restore all settings to their default values. Current configurations will be lost.")
        }
        .overlay(alignment: .top) {
            if showSavedBanner {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Settings saved")
                }
                .font(.caption.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.green)
                .clipShape(Capsule())
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSavedBanner)
    }

    // MARK: - Sub-views

    @ViewBuilder
    private func settingsSection<Content: View>(
        title: String, icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: icon)
                .font(.footnote.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.bottom, 8)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func presetButton(_ label: String, value: Double, color: Color) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { threshold = value }
            AppSettings.faceThreshold = Float(value)
        } label: {
            Text(label)
                .font(.caption.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(abs(threshold - value) < 0.005
                            ? color.opacity(0.18)
                            : Color(uiColor: .tertiarySystemGroupedBackground))
                .foregroundStyle(abs(threshold - value) < 0.005 ? color : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(abs(threshold - value) < 0.005
                                ? color.opacity(0.4) : Color.clear, lineWidth: 1)
                )
        }
    }

    @ViewBuilder
    private var currentValuesSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Active Configuration", systemImage: "checklist")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 4)

            HStack(spacing: 12) {
                summaryPill(
                    icon: "faceid",
                    text: String(format: "%.0f%%", threshold * 100),
                    color: thresholdColor,
                    label: "Threshold"
                )
                summaryPill(
                    icon: "lock.fill",
                    text: "\(maxAttempts) tries",
                    color: .orange,
                    label: "Max Fails"
                )
                summaryPill(
                    icon: "clock.fill",
                    text: "\(lockoutMinutes)m",
                    color: .red,
                    label: "Lockout"
                )
                summaryPill(
                    icon: "timer",
                    text: "\(timeoutMinutes)m",
                    color: .purple,
                    label: "Timeout"
                )
            }
        }
    }

    private func summaryPill(icon: String, text: String, color: Color, label: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(color)
            Text(text)
                .font(.caption.bold())
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var thresholdColor: Color {
        if threshold < 0.70 { return .green }
        if threshold < 0.80 { return .blue }
        if threshold < 0.86 { return .orange }
        return .red
    }
}
