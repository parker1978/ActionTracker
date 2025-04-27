//
//  CharacterPickerView.swift
//  ActionTracker
//
//  Created by Stephen Parker on 4/27/25.
//

import SwiftUI
import SwiftData

struct CharacterPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    
    var body: some View {
        NavigationStack {
            VStack {
                if appViewModel.characters.isEmpty {
                    ContentUnavailableView(
                        "No Characters Available",
                        systemImage: "person.fill.questionmark",
                        description: Text("Create some characters first by going to the Characters tab")
                    )
                } else {
                    List {
                        ForEach(appViewModel.filteredCharacters) { character in
                            Button {
                                appViewModel.selectCharacter(character)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        HStack {
                                            if character.isFavorite {
                                                Image(systemName: "star.fill")
                                                    .foregroundColor(.yellow)
                                                    .font(.caption)
                                            }
                                            Text(character.name)
                                                .font(.headline)
                                        }
                                        
                                        if let set = character.set, !set.isEmpty {
                                            Text(set)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if appViewModel.selectedCharacter?.id == character.id {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .searchable(text: $appViewModel.searchText, prompt: "Search characters")
                }
            }
            .navigationTitle("Select Character")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Refresh character list
                appViewModel.fetchCharacters()
            }
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var viewModel = AppViewModel()
        
        var body: some View {
            CharacterPickerView()
                .environmentObject(viewModel)
        }
    }
    
    return PreviewWrapper()
}