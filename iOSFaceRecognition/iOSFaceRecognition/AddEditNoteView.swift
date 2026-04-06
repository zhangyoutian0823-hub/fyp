//
//  AddEditNoteView.swift
//  iOSFaceRecognition
//
//  新增 / 编辑加密备忘录的表单视图（Sheet 呈现）。
//

import SwiftUI

struct AddEditNoteView: View {
    @EnvironmentObject var noteStore: NoteStore
    @EnvironmentObject var logStore:  LogStore
    @Environment(\.dismiss) private var dismiss

    /// 传入 nil = 新增模式；传入现有条目 = 编辑模式
    let userId: String
    var existing: SecureNote? = nil

    @State private var title      = ""
    @State private var content    = ""
    @State private var isFavorite = false

    private var isEditing: Bool { existing != nil }
    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !content.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                // ── 标题 ──
                Section {
                    LabeledContent {
                        TextField("e.g. License Key, Bank PIN", text: $title)
                            .multilineTextAlignment(.trailing)
                    } label: {
                        Label("Title", systemImage: "tag")
                    }
                } header: {
                    Text("Note")
                }

                // ── 内容 ──
                Section {
                    TextEditor(text: $content)
                        .frame(minHeight: 140)
                        .font(.body)
                } header: {
                    Text("Content")
                } footer: {
                    Text("Content is protected — face verification required to view.")
                        .font(.caption)
                }

                // ── 其他 ──
                Section {
                    Toggle(isOn: $isFavorite) {
                        Label("Favourite", systemImage: "star")
                    }
                    .tint(.yellow)
                } header: {
                    Text("Options")
                }
            }
            .navigationTitle(isEditing ? "Edit Note" : "New Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .onAppear { prefill() }
        }
    }

    // MARK: - Helpers

    private func prefill() {
        guard let e = existing else { return }
        title      = e.title
        content    = e.content
        isFavorite = e.isFavorite
    }

    private func save() {
        if var e = existing {
            let trimTitle = title.trimmingCharacters(in: .whitespaces)
            let hasChanges = e.title != trimTitle || e.content != content || e.isFavorite != isFavorite
            e.title      = trimTitle
            e.content    = content
            e.isFavorite = isFavorite
            noteStore.update(e)
            if hasChanges {
                logStore.add(userId: userId, eventType: .noteItemEdited, detail: e.title)
            }
        } else {
            let note = SecureNote(
                userId:  userId,
                title:   title.trimmingCharacters(in: .whitespaces),
                content: content
            )
            // Apply favorite after init (init always sets false)
            var saved = note
            saved.isFavorite = isFavorite
            noteStore.add(saved)
        }
        dismiss()
    }
}
