//
//  EntryView.swift
//  iOSFaceRecognition
//
//  Created by mac on 2026/2/24.
//

//
//  EntryView.swift
//  iOSFaceRecognition
//

import SwiftUI

struct EntryView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Face ID Login System")
                    .font(.title2).bold()

                NavigationLink("Register") { RegisterView() }
                    .buttonStyle(.borderedProminent)

                NavigationLink("Login") { LoginView() }
                    .buttonStyle(.bordered)

                NavigationLink("Admin") { AdminEntryView() }
                    .buttonStyle(.bordered)

                Spacer()
            }
            .padding()
        }
    }
}

