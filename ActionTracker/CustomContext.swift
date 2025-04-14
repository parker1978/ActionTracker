//
//  Context.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/12/25.
//

import SwiftUI
import SwiftData

class Context: NSObject, UIDocumentPickerDelegate {
    static let shared = Context()
    static var modelContext: ModelContext?

    static func configure(with context: ModelContext) {
        modelContext = context
    }

    func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
        guard let url = urls.first, let context = Context.modelContext else { return }

        guard url.startAccessingSecurityScopedResource() else {
            print("Failed to access security-scoped resource.")
            return
        }

        defer { url.stopAccessingSecurityScopedResource() } // 🧹 Clean up after

        do {
            for character in try context.fetch(FetchDescriptor<Character>()) {
                context.delete(character)
            }

            let content = try String(contentsOf: url, encoding: .utf8)
            let rows = content.components(separatedBy: CharacterSet.newlines).dropFirst()
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
