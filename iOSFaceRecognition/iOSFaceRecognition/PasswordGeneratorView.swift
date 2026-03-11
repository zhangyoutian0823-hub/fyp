//
//  PasswordGeneratorView.swift
//  iOSFaceRecognition
//
//  密码生成器 Sheet — 可配置长度与字符集，预览后一键回填表单。
//

import SwiftUI

struct PasswordGeneratorView: View {

    /// Called with the chosen password when the user taps "Use Password".
    var onUse: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var length:       Double = 16
    @State private var useUppercase: Bool   = true
    @State private var useDigits:    Bool   = true
    @State private var useSymbols:   Bool   = true
    @State private var preview:      String = ""
    @State private var copied:       Bool   = false

    var body: some View {
        NavigationStack {
            Form {

                // ── Preview ──────────────────────────────────────────
                Section {
                    HStack(alignment: .top, spacing: 12) {
                        Text(preview.isEmpty ? "Generating…" : preview)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(preview.isEmpty ? .tertiary : .primary)
                            .lineLimit(4)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if !preview.isEmpty {
                            Button {
                                UIPasteboard.general.string = preview
                                withAnimation { copied = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { copied = false }
                                }
                            } label: {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                    .foregroundStyle(copied ? .green : .blue)
                                    .contentTransition(.symbolEffect(.replace))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)

                    // Inline strength bar for the generated password
                    if !preview.isEmpty {
                        PasswordStrengthBar(password: preview)
                    }
                } header: {
                    Text("Generated Password")
                }

                // ── Options ──────────────────────────────────────────
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Length", systemImage: "ruler")
                            Spacer()
                            Text("\(Int(length))")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        Slider(value: $length, in: 8...32, step: 1) { editing in
                            if !editing { regenerate() }
                        }
                        .tint(.blue)
                    }
                    .padding(.vertical, 4)

                    Toggle(isOn: $useUppercase) {
                        Label("Uppercase  A–Z", systemImage: "textformat.size.larger")
                    }
                    .onChange(of: useUppercase) { _, _ in regenerate() }

                    Toggle(isOn: $useDigits) {
                        Label("Numbers  0–9", systemImage: "number")
                    }
                    .onChange(of: useDigits) { _, _ in regenerate() }

                    Toggle(isOn: $useSymbols) {
                        Label("Symbols  !@#$…", systemImage: "at.circle")
                    }
                    .onChange(of: useSymbols) { _, _ in regenerate() }

                } header: {
                    Text("Options")
                }

                // ── Regenerate ────────────────────────────────────────
                Section {
                    Button {
                        regenerate()
                    } label: {
                        Label("Generate New Password", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .navigationTitle("Password Generator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Password") {
                        onUse(preview)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(preview.isEmpty)
                }
            }
            .onAppear { regenerate() }
        }
    }

    // MARK: - Private

    private func regenerate() {
        preview = PasswordGenerator.generate(
            length:       Int(length),
            useUppercase: useUppercase,
            useDigits:    useDigits,
            useSymbols:   useSymbols
        )
        copied = false
    }
}
