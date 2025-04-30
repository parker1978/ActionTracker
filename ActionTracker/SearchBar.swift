//
//  SearchBar.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/29/25.
//

import SwiftUI

struct SearchBar: View {
    @Binding var text: String
    @FocusState private var isSearchFocused: Bool
    
    private func insertTextAtCursor(_ text: String) {
        if isSearchFocused {
            self.text.append(text)
        }
    }
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search by name, set, or skill", text: $text)
                .autocorrectionDisabled()
                .focused($isSearchFocused)
                .submitLabel(.search)
                .onSubmit {
                    isSearchFocused = false
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .onTapGesture {
            // This helps with tapping on the search bar background to focus
            if !isSearchFocused {
                isSearchFocused = true
            }
        }
        .overlay(
            // Invisible button that covers the entire screen when search is active
            // to enable tapping outside to dismiss
            Group {
                if isSearchFocused {
                    GeometryReader { _ in
                        Button("") {
                            isSearchFocused = false
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.clear)
                    }
                    .ignoresSafeArea()
                }
            }
        )
        .keyboardToolbar(
            onInsertText: { insertTextAtCursor($0) },
            onDone: { isSearchFocused = false }
        )
    }
}
