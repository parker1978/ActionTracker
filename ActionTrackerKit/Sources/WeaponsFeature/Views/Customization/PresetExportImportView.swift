//
//  PresetExportImportView.swift
//  WeaponsFeature
//
//  Export and import preset configurations as JSON
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import CoreDomain

public struct PresetExportImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let preset: DeckPreset

    @State private var showExportSuccess = false
    @State private var showImportPicker = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var exportedData: Data?

    private var customizationService: CustomizationService {
        CustomizationService(context: modelContext)
    }

    public init(preset: DeckPreset) {
        self.preset = preset
    }

    public var body: some View {
        NavigationStack {
            contentList
                .navigationTitle("Export / Import")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Preset exported successfully. Use the share sheet to save or send the file.")
        }
        .alert("Import Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showImportPicker) {
            DocumentPicker(contentTypes: [.json]) { url in
                importPreset(from: url)
            }
        }
        .sheet(item: shareBinding) { identifiableData in
            ShareSheet(data: identifiableData.data, filename: "\(preset.name).json")
        }
    }

    private var contentList: some View {
        List {
            Section {
                Text(preset.name)
                    .font(.headline)
                Text("\(preset.customizations.count) customizations")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section {
                Button {
                    exportPreset()
                } label: {
                    Label("Export as JSON", systemImage: "square.and.arrow.up")
                }
            } header: {
                Text("Export")
            } footer: {
                Text("Export this preset to a JSON file that can be shared with others or imported on another device.")
            }

            Section {
                Button {
                    showImportPicker = true
                } label: {
                    Label("Import from JSON", systemImage: "square.and.arrow.down")
                }
            } header: {
                Text("Import")
            } footer: {
                Text("Import a preset from a JSON file. This will create a new preset without modifying the current one.")
            }
        }
    }

    private var shareBinding: Binding<IdentifiableData?> {
        Binding(
            get: { exportedData.map { IdentifiableData(data: $0) } },
            set: { exportedData = $0?.data }
        )
    }

    private func exportPreset() {
        do {
            let data = try customizationService.exportPreset(preset)
            exportedData = data
            showExportSuccess = true
        } catch {
            errorMessage = "Failed to export preset: \(error.localizedDescription)"
            showError = true
        }
    }

    private func importPreset(from url: URL) {
        do {
            let data = try Data(contentsOf: url)

            Task {
                do {
                    _ = try await customizationService.importPreset(from: data, setAsDefault: false)
                    dismiss()
                } catch {
                    errorMessage = "Failed to import preset: \(error.localizedDescription)"
                    showError = true
                }
            }
        } catch {
            errorMessage = "Failed to read file: \(error.localizedDescription)"
            showError = true
        }
    }
}

// MARK: - Supporting Types

private struct IdentifiableData: Identifiable {
    let id = UUID()
    let data: Data
}

// MARK: - Document Picker

private struct DocumentPicker: UIViewControllerRepresentable {
    let contentTypes: [UTType]
    let onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            onPick(url)
        }
    }
}

// MARK: - Share Sheet

private struct ShareSheet: UIViewControllerRepresentable {
    let data: Data
    let filename: String

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create temporary file
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)

        let activityVC = UIActivityViewController(
            activityItems: [tempURL],
            applicationActivities: nil
        )
        return activityVC
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: DeckPreset.self, configurations: config)
    let context = ModelContext(container)

    let preset = DeckPreset(name: "Test Preset", description: "Test", isDefault: false)
    context.insert(preset)

    return PresetExportImportView(preset: preset)
        .modelContainer(container)
}
