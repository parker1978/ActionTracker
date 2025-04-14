//
//  Context.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/12/25.
//

import SwiftUI
import SwiftData

class CustomContext: NSObject, UIDocumentPickerDelegate {
    static let shared = CustomContext()
    private var modelContext: ModelContext?
    private var importCompletionHandler: (() -> Void)?

    func configure(with context: ModelContext, completion: (() -> Void)? = nil) {
        self.modelContext = context
        self.importCompletionHandler = completion
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let context = self.modelContext else { 
            print("ModelContext not available")
            return 
        }

        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource.")
            return
        }

        defer { url.stopAccessingSecurityScopedResource() } // 🧹 Clean up after

        do {
            // Delete existing characters first
            for character in try context.fetch(FetchDescriptor<Character>()) {
                context.delete(character)
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: CharacterSet.newlines).dropFirst()
            
            // Parse and insert new characters
            for line in rows {
                guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { continue }
                let columns = parseCSVLine(line)
                guard columns.count >= 4 else { continue }

                let name = columns[0]
                let set = columns[1].isEmpty ? nil : columns[1]
                let notes = columns[2].isEmpty ? nil : columns[2]
                let skills = columns[3].split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }

                let newChar = Character(name: name, set: set, allSkills: skills, notes: notes)
                context.insert(newChar)
            }
            
            // Save changes immediately
            try context.save()
            
            // Call completion handler if provided
            DispatchQueue.main.async {
                self.importCompletionHandler?()
            }
            
            print("Import successful: \(rows.count) characters")
        } catch {
            print("Import failed: \(error)")
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var results: [String] = []
        var value = ""
        var insideQuotes = false

        var iterator = line.makeIterator()
        while let char = iterator.next() {
            switch char {
            case "\"":
                insideQuotes.toggle()
            case ",":
                if insideQuotes {
                    value.append(char)
                } else {
                    results.append(value)
                    value = ""
                }
            default:
                value.append(char)
            }
        }
        results.append(value)
        return results.map { $0.replacingOccurrences(of: "\"\"", with: "\"") }
    }
}
