// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ActionTrackerKit",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        // Foundation Layer
        .library(name: "CoreDomain", targets: ["CoreDomain"]),
        .library(name: "DataLayer", targets: ["DataLayer"]),
        .library(name: "SharedUI", targets: ["SharedUI"]),

        // Feature Modules
        .library(name: "CharacterFeature", targets: ["CharacterFeature"]),
        .library(name: "SkillsFeature", targets: ["SkillsFeature"]),
        .library(name: "GameSessionFeature", targets: ["GameSessionFeature"]),
        .library(name: "WeaponsFeature", targets: ["WeaponsFeature"]),
        .library(name: "SpawnDeckFeature", targets: ["SpawnDeckFeature"]),

        // App Shell
        .library(name: "AppShell", targets: ["AppShell"]),
    ],
    targets: [
        // MARK: - Foundation Layer (No Cross-Dependencies)

        /// Core domain models, enums, and utilities
        /// Dependencies: None (foundation layer)
        .target(
            name: "CoreDomain",
            dependencies: []
        ),

        /// Data repositories and seeding logic
        /// Dependencies: CoreDomain only
        .target(
            name: "DataLayer",
            dependencies: ["CoreDomain"],
            resources: [
                .copy("Resources/characters.json"),
                .copy("Resources/weapons.json")
            ]
        ),

        /// Reusable UI components and modifiers
        /// Dependencies: CoreDomain only
        .target(
            name: "SharedUI",
            dependencies: ["CoreDomain"]
        ),

        // MARK: - Feature Modules (Depend on Foundation Only)

        /// Character management screens
        /// Dependencies: CoreDomain, DataLayer, SharedUI
        .target(
            name: "CharacterFeature",
            dependencies: [
                "CoreDomain",
                "DataLayer",
                "SharedUI"
            ]
        ),

        /// Skills browsing and management screens
        /// Dependencies: CoreDomain, DataLayer, SharedUI
        .target(
            name: "SkillsFeature",
            dependencies: [
                "CoreDomain",
                "DataLayer",
                "SharedUI"
            ]
        ),

        /// Game session and actions screens
        /// Dependencies: CoreDomain, DataLayer, SharedUI, SpawnDeckFeature
        .target(
            name: "GameSessionFeature",
            dependencies: [
                "CoreDomain",
                "DataLayer",
                "SharedUI",
                "SpawnDeckFeature"
            ]
        ),

        /// Weapons deck management screens
        /// Dependencies: CoreDomain, DataLayer, SharedUI
        .target(
            name: "WeaponsFeature",
            dependencies: [
                "CoreDomain",
                "DataLayer",
                "SharedUI"
            ]
        ),

        /// Spawn deck screens
        /// Dependencies: CoreDomain, DataLayer, SharedUI
        .target(
            name: "SpawnDeckFeature",
            dependencies: [
                "CoreDomain",
                "DataLayer",
                "SharedUI"
            ]
        ),

        // MARK: - App Shell

        /// App coordination layer (tab navigation)
        /// Dependencies: All feature modules + foundation layers
        .target(
            name: "AppShell",
            dependencies: [
                "CoreDomain",
                "DataLayer",
                "SharedUI",
                "CharacterFeature",
                "SkillsFeature",
                "GameSessionFeature",
                "WeaponsFeature",
                "SpawnDeckFeature"
            ]
        ),

        // MARK: - Test Targets

        .testTarget(
            name: "CoreDomainTests",
            dependencies: ["CoreDomain"]
        ),

        .testTarget(
            name: "DataLayerTests",
            dependencies: ["DataLayer", "CoreDomain"]
        ),

        .testTarget(
            name: "SharedUITests",
            dependencies: ["SharedUI", "CoreDomain"]
        ),
    ]
)
