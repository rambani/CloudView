import XCTest
@testable import CloudView

final class CombinationRulesTests: XCTestCase {

    func testStaticSubjectsCannotDoSports() {
        // Landmarks and nature elements don't move — sports actions are filtered out.
        XCTAssertFalse(CombinationRules.isCompatible(subject: .pyramid, action: .skateboarding))
        XCTAssertFalse(CombinationRules.isCompatible(subject: .eiffelTower, action: .running))
        XCTAssertFalse(CombinationRules.isCompatible(subject: .mountain, action: .swimming))
    }

    func testMagicalActionsRequireMagicalSubjects() {
        XCTAssertTrue(CombinationRules.isCompatible(subject: .dragon, action: .breathingFire))
        XCTAssertTrue(CombinationRules.isCompatible(subject: .unicorn, action: .castingSpells))
        XCTAssertTrue(CombinationRules.isCompatible(subject: .magicWand, action: .grantingWishes))

        XCTAssertFalse(CombinationRules.isCompatible(subject: .cat, action: .breathingFire))
        XCTAssertFalse(CombinationRules.isCompatible(subject: .car, action: .castingSpells))
    }

    func testWorkActionsOnlyForPeopleOrTech() {
        XCTAssertTrue(CombinationRules.isCompatible(subject: .doctor, action: .performingSurgery))
        XCTAssertTrue(CombinationRules.isCompatible(subject: .robot, action: .conductingExperiment))

        XCTAssertFalse(CombinationRules.isCompatible(subject: .cat, action: .performingSurgery))
        XCTAssertFalse(CombinationRules.isCompatible(subject: .dragon, action: .teachingClass))
    }

    func testCompatibilityListIsRespected() {
        // wildAnimal allows adventure / sports / playful (per the rules table).
        XCTAssertTrue(CombinationRules.isCompatible(subject: .lion, action: .climbing))
        XCTAssertTrue(CombinationRules.isCompatible(subject: .tiger, action: .swimming))

        // wildAnimal does NOT allow arts — verify the table actually filters.
        XCTAssertFalse(CombinationRules.isCompatible(subject: .lion, action: .painting))
    }

    func testEveryNonStaticSubjectHasAtLeastOneCompatibleAction() {
        // Regression guard: if the compatibility table goes empty for a subject,
        // the random concept generator will hit `randomElement() ?? .happy`
        // forever and quality of output collapses silently.
        for subject in DrawingSubject.allCases {
            if CombinationRules.staticSubjects.contains(subject.category) { continue }

            let anyMatch = DrawingAction.allCases.contains { action in
                CombinationRules.isCompatible(subject: subject, action: action)
            }
            XCTAssertTrue(
                anyMatch,
                "\(subject) has no compatible actions — combination table needs an entry for category \(subject.category)"
            )
        }
    }

    func testAccessorySuggestionsAreNonEmptyForSubjectsWithActions() {
        // Action-driven accessory list should always include at least the
        // category-specific defaults — no actions means no accessory hints from
        // the action branch, which is fine, but with an action we expect output.
        let accessories = CombinationRules.getAppropriateAccessories(
            for: .cat,
            action: .skateboarding
        )
        XCTAssertFalse(accessories.isEmpty)
    }
}
