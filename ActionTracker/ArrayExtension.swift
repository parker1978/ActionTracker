//
//  ArrayExtension.swift
//  ZombicideCharacters
//
//  Created by Stephen Parker on 4/11/25.
//

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
