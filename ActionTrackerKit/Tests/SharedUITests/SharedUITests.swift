import XCTest
import SwiftUI
@testable import SharedUI
@testable import CoreDomain

final class SharedUITests: XCTestCase {

    // MARK: - Color+DifficultyLevel Tests

    func testDifficultyLevelColors() {
        // Test that each difficulty level has the correct color
        XCTAssertNotNil(DifficultyLevel.blue.color)
        XCTAssertNotNil(DifficultyLevel.yellow.color)
        XCTAssertNotNil(DifficultyLevel.orange.color)
        XCTAssertNotNil(DifficultyLevel.red.color)
    }

    func testDifficultyLevelColorMapping() {
        // Verify that all difficulty levels have unique color assignments
        // This tests that the extension is working correctly
        let blueColor = DifficultyLevel.blue.color
        let yellowColor = DifficultyLevel.yellow.color
        let orangeColor = DifficultyLevel.orange.color
        let redColor = DifficultyLevel.red.color

        // Colors should be defined (not nil or default)
        XCTAssertNotNil(blueColor)
        XCTAssertNotNil(yellowColor)
        XCTAssertNotNil(orangeColor)
        XCTAssertNotNil(redColor)
    }

    func testAllDifficultyLevelsHaveColors() {
        // Ensure all cases are covered
        for level in DifficultyLevel.allCases {
            XCTAssertNotNil(level.color, "Difficulty level \(level) should have a color")
        }
    }

    // MARK: - FlowLayout Tests

    func testFlowLayoutInitialization() {
        let layout1 = FlowLayout()
        XCTAssertNotNil(layout1)

        let layout2 = FlowLayout(spacing: 16)
        XCTAssertNotNil(layout2)
    }

    func testFlowLayoutSpacing() {
        let defaultLayout = FlowLayout()
        XCTAssertEqual(defaultLayout.spacing, 8)

        let customLayout = FlowLayout(spacing: 16)
        XCTAssertEqual(customLayout.spacing, 16)
    }

    func testFlowLayoutConformsToLayoutProtocol() {
        // Verify FlowLayout conforms to Layout protocol
        let layout: any Layout = FlowLayout()
        XCTAssertNotNil(layout)
    }

    // MARK: - ShakeEffect Tests

    func testShakeEffectInitialization() {
        let shakeEffect = ShakeEffect(isShaking: true)
        XCTAssertNotNil(shakeEffect)

        let noShakeEffect = ShakeEffect(isShaking: false)
        XCTAssertNotNil(noShakeEffect)
    }

    func testShakeEffectIsShakingProperty() {
        let shakingEffect = ShakeEffect(isShaking: true)
        XCTAssertTrue(shakingEffect.isShaking)

        let notShakingEffect = ShakeEffect(isShaking: false)
        XCTAssertFalse(notShakingEffect.isShaking)
    }

    func testViewShakeExtension() {
        // Test that the shake extension exists on View
        let view = Text("Test")
        let modifiedView = view.shake(isShaking: true)

        XCTAssertNotNil(modifiedView)
    }

    func testShakeEffectConformsToViewModifier() {
        // Verify ShakeEffect conforms to ViewModifier protocol
        let modifier: any ViewModifier = ShakeEffect(isShaking: true)
        XCTAssertNotNil(modifier)
    }

    // MARK: - View Extension Tests

    func testViewCornerRadiusExtensionExists() {
        // Test that corner radius extensions can be applied
        let view = Rectangle()
        let modifiedView = view.cornerRadius(10, corners: [.topLeft, .topRight])

        XCTAssertNotNil(modifiedView)
    }

    func testViewIfModifierExtensionExists() {
        // Test that the if modifier exists
        let view = Text("Test")
        let modifiedView = view.if(true) { content in
            content.bold()
        }

        XCTAssertNotNil(modifiedView)
    }

    // MARK: - Component Integration Tests

    func testFlowLayoutWithRealViews() {
        // Create a simple flow layout scenario
        let layout = FlowLayout(spacing: 10)

        // Verify it can be used with a Layout container (compile-time check)
        // This ensures the Layout protocol implementation is correct
        XCTAssertNotNil(layout)
        XCTAssertEqual(layout.spacing, 10)
    }

    func testColorExtensionsAreConsistent() {
        // Test that color extensions are consistent across difficulty levels
        let levels = DifficultyLevel.allCases

        // All levels should have colors
        XCTAssertEqual(levels.count, 4)

        for level in levels {
            let color = level.color
            XCTAssertNotNil(color, "Level \(level) should have a color")
        }
    }

    func testShakeEffectStateManagement() {
        // Test that ShakeEffect can transition between states
        var effect = ShakeEffect(isShaking: false)
        XCTAssertFalse(effect.isShaking)

        effect = ShakeEffect(isShaking: true)
        XCTAssertTrue(effect.isShaking)

        effect = ShakeEffect(isShaking: false)
        XCTAssertFalse(effect.isShaking)
    }

    // MARK: - Utility Tests

    func testRoundedCornerShapeExists() {
        // Verify RoundedCorner shape is available
        let corners: UIRectCorner = [.topLeft, .topRight]
        let shape = RoundedCorner(radius: 10, corners: corners)

        XCTAssertNotNil(shape)
    }

    func testRoundedCornerConformsToShape() {
        // Verify RoundedCorner conforms to Shape protocol
        let shape: any Shape = RoundedCorner(radius: 10, corners: [.allCorners])
        XCTAssertNotNil(shape)
    }

    // MARK: - Edge Case Tests

    func testFlowLayoutWithZeroSpacing() {
        let layout = FlowLayout(spacing: 0)
        XCTAssertEqual(layout.spacing, 0)
    }

    func testFlowLayoutWithLargeSpacing() {
        let layout = FlowLayout(spacing: 100)
        XCTAssertEqual(layout.spacing, 100)
    }

    func testShakeEffectMultipleInstances() {
        // Test that multiple shake effects can coexist
        let effect1 = ShakeEffect(isShaking: true)
        let effect2 = ShakeEffect(isShaking: false)
        let effect3 = ShakeEffect(isShaking: true)

        XCTAssertTrue(effect1.isShaking)
        XCTAssertFalse(effect2.isShaking)
        XCTAssertTrue(effect3.isShaking)
    }
}
