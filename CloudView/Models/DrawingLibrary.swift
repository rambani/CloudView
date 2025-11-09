import Foundation
import CoreGraphics

// MARK: - Modular Component System

enum DrawingSubject: String, CaseIterable {
    // ANIMALS - Domestic
    case cat, dog, hamster, rabbit, parrot, goldfish, turtle

    // ANIMALS - Farm
    case cow, pig, sheep, chicken, horse, duck, goat, llama

    // ANIMALS - Wild
    case lion, tiger, elephant, giraffe, zebra, monkey, panda, koala, kangaroo, sloth

    // ANIMALS - Forest
    case bear, deer, fox, owl, squirrel, raccoon, hedgehog, beaver, woodpecker

    // ANIMALS - Ocean/Sea
    case dolphin, whale, octopus, starfish, crab, seahorse, jellyfish, penguin, seal, otter

    // ANIMALS - Arctic
    case polarBear, arcticFox, walrus, reindeer, snowOwl

    // ANIMALS - Desert
    case camel, meerkat, snake, scorpion, lizard

    // ANIMALS - Jungle
    case parrot, toucan, gorilla, leopard, jaguar, chameleon, macaw

    // ANIMALS - Insects & Small Creatures
    case butterfly, ladybug, bee, caterpillar, snail, dragonfly

    // MYTHICAL CREATURES
    case unicorn, dragon, phoenix, pegasus, griffin, fairy, mermaid, yeti

    // DINOSAURS
    case tRex, triceratops, brontosaurus, stegosaurus, pterodactyl, velociraptor

    // PEOPLE/PROFESSIONS
    case astronaut, chef, artist, scientist, firefighter, teacher, doctor, musician, athlete, explorer

    // LANDMARKS (Simplified versions)
    case pyramid, eiffelTower, bigBen, statueOfLiberty, tajMahal, greatWall, colosseum, christRedeemer

    // VEHICLES
    case car, airplane, boat, submarine, hotAirBalloon, rocket, train, bicycle, scooter, helicopter

    // FOOD CHARACTERS (Anthropomorphized)
    case apple, banana, pizza, donut, cupcake, iceCream, cookie, watermelon, strawberry, taco

    // NATURE ELEMENTS
    case sun, moon, star, cloud, rainbow, tree, flower, mountain, volcano

    // FANTASY OBJECTS
    case castle, treasure, magicWand, crown, crystalBall, flyingCarpet

    // ROBOTS & TECH
    case robot, computer, satellite, drone

    var displayName: String {
        switch self {
        case .tRex: return "T-Rex"
        case .bigBen: return "Big Ben"
        case .eiffelTower: return "Eiffel Tower"
        case .statueOfLiberty: return "Statue of Liberty"
        case .tajMahal: return "Taj Mahal"
        case .greatWall: return "Great Wall"
        case .christRedeemer: return "Christ the Redeemer"
        case .hotAirBalloon: return "Hot Air Balloon"
        case .iceCream: return "Ice Cream"
        case .flyingCarpet: return "Flying Carpet"
        case .crystalBall: return "Crystal Ball"
        case .magicWand: return "Magic Wand"
        case .polarBear: return "Polar Bear"
        case .arcticFox: return "Arctic Fox"
        case .snowOwl: return "Snow Owl"
        default: return rawValue.capitalized
        }
    }

    var category: SubjectCategory {
        switch self {
        case .cat, .dog, .hamster, .rabbit, .parrot, .goldfish, .turtle:
            return .domesticAnimal
        case .cow, .pig, .sheep, .chicken, .horse, .duck, .goat, .llama:
            return .farmAnimal
        case .lion, .tiger, .elephant, .giraffe, .zebra, .monkey, .panda, .koala, .kangaroo, .sloth:
            return .wildAnimal
        case .bear, .deer, .fox, .owl, .squirrel, .raccoon, .hedgehog, .beaver, .woodpecker:
            return .forestAnimal
        case .dolphin, .whale, .octopus, .starfish, .crab, .seahorse, .jellyfish, .penguin, .seal, .otter:
            return .oceanAnimal
        case .polarBear, .arcticFox, .walrus, .reindeer, .snowOwl:
            return .arcticAnimal
        case .camel, .meerkat, .snake, .scorpion, .lizard:
            return .desertAnimal
        case .parrot, .toucan, .gorilla, .leopard, .jaguar, .chameleon, .macaw:
            return .jungleAnimal
        case .butterfly, .ladybug, .bee, .caterpillar, .snail, .dragonfly:
            return .insect
        case .unicorn, .dragon, .phoenix, .pegasus, .griffin, .fairy, .mermaid, .yeti:
            return .mythical
        case .tRex, .triceratops, .brontosaurus, .stegosaurus, .pterodactyl, .velociraptor:
            return .dinosaur
        case .astronaut, .chef, .artist, .scientist, .firefighter, .teacher, .doctor, .musician, .athlete, .explorer:
            return .person
        case .pyramid, .eiffelTower, .bigBen, .statueOfLiberty, .tajMahal, .greatWall, .colosseum, .christRedeemer:
            return .landmark
        case .car, .airplane, .boat, .submarine, .hotAirBalloon, .rocket, .train, .bicycle, .scooter, .helicopter:
            return .vehicle
        case .apple, .banana, .pizza, .donut, .cupcake, .iceCream, .cookie, .watermelon, .strawberry, .taco:
            return .food
        case .sun, .moon, .star, .cloud, .rainbow, .tree, .flower, .mountain, .volcano:
            return .nature
        case .castle, .treasure, .magicWand, .crown, .crystalBall, .flyingCarpet:
            return .fantasyObject
        case .robot, .computer, .satellite, .drone:
            return .tech
        }
    }
}

enum SubjectCategory {
    case domesticAnimal, farmAnimal, wildAnimal, forestAnimal, oceanAnimal, arcticAnimal, desertAnimal, jungleAnimal, insect
    case mythical, dinosaur, person, landmark, vehicle, food, nature, fantasyObject, tech
}

enum DrawingAction: String, CaseIterable {
    // SPORTS
    case skateboarding, surfing, skiing, snowboarding, rollerblading
    case playingBasketball, playingSoccer, playingTennis, playingBaseball, playingGolf
    case swimming, diving, sailing, kayaking, paddleboarding
    case cycling, running, jumping, dancing, gymnastics

    // ARTS & CREATIVITY
    case painting, drawing, playingGuitar, playingPiano, playingDrums, singing
    case sculpting, photography, writing, reading

    // EVERYDAY ACTIVITIES
    case cooking, baking, gardening, fishing, camping
    case flyingKite, blowingBubbles, playingChess, juggling
    case studying, teaching, building, inventing

    // ADVENTURE & EXPLORATION
    case exploring, climbing, hiking, treasure hunting
    case spaceExploring, deepSeaDiving, flying, soaring
    case paragliding, bungeeJumping, ziplining

    // MAGICAL & FANTASY
    case castingSpells, ridingBroomstick, grantingWishes, breathingFire

    // RELAXING
    case sleeping, meditating, sunbathing, stargazing, cloudWatching
    case drinkingTea, eatingSnacks, napping, relaxing

    // PLAYFUL
    case playingWithToys, hopscotch, hideAndSeek, tagPlaying
    case splashingInPuddles, makingSnowAngels, catchingFireflies

    // WORK & CAREER
    case savingTheDay, performingSurgery, conductingExperiment, designingBuilding
    case teachingClass, fightingFire, launchingRocket

    var displayName: String {
        switch self {
        case .playingBasketball: return "Playing Basketball"
        case .playingSoccer: return "Playing Soccer"
        case .playingTennis: return "Playing Tennis"
        case .playingBaseball: return "Playing Baseball"
        case .playingGolf: return "Playing Golf"
        case .playingGuitar: return "Playing Guitar"
        case .playingPiano: return "Playing Piano"
        case .playingDrums: return "Playing Drums"
        case .flyingKite: return "Flying a Kite"
        case .blowingBubbles: return "Blowing Bubbles"
        case .playingChess: return "Playing Chess"
        case .spaceExploring: return "Exploring Space"
        case .deepSeaDiving: return "Deep Sea Diving"
        case .castingSpells: return "Casting Spells"
        case .ridingBroomstick: return "Riding a Broomstick"
        case .grantingWishes: return "Granting Wishes"
        case .breathingFire: return "Breathing Fire"
        case .drinkingTea: return "Drinking Tea"
        case .eatingSnacks: return "Eating Snacks"
        case .playingWithToys: return "Playing with Toys"
        case .splashingInPuddles: return "Splashing in Puddles"
        case .makingSnowAngels: return "Making Snow Angels"
        case .catchingFireflies: return "Catching Fireflies"
        case .savingTheDay: return "Saving the Day"
        case .performingSurgery: return "Performing Surgery"
        case .conductingExperiment: return "Conducting an Experiment"
        case .designingBuilding: return "Designing a Building"
        case .teachingClass: return "Teaching a Class"
        case .fightingFire: return "Fighting a Fire"
        case .launchingRocket: return "Launching a Rocket"
        default: return rawValue.capitalized
        }
    }

    var actionCategory: ActionCategory {
        switch self {
        case .skateboarding, .surfing, .skiing, .snowboarding, .rollerblading,
             .playingBasketball, .playingSoccer, .playingTennis, .playingBaseball, .playingGolf,
             .swimming, .diving, .sailing, .kayaking, .paddleboarding,
             .cycling, .running, .jumping, .dancing, .gymnastics:
            return .sports
        case .painting, .drawing, .playingGuitar, .playingPiano, .playingDrums, .singing,
             .sculpting, .photography, .writing, .reading:
            return .arts
        case .cooking, .baking, .gardening, .fishing, .camping,
             .flyingKite, .blowingBubbles, .playingChess, .juggling,
             .studying, .teaching, .building, .inventing:
            return .everyday
        case .exploring, .climbing, .hiking, .treasure hunting,
             .spaceExploring, .deepSeaDiving, .flying, .soaring,
             .paragliding, .bungeeJumping, .ziplining:
            return .adventure
        case .castingSpells, .ridingBroomstick, .grantingWishes, .breathingFire:
            return .magical
        case .sleeping, .meditating, .sunbathing, .stargazing, .cloudWatching,
             .drinkingTea, .eatingSnacks, .napping, .relaxing:
            return .relaxing
        case .playingWithToys, .hopscotch, .hideAndSeek, .tagPlaying,
             .splashingInPuddles, .makingSnowAngels, .catchingFireflies:
            return .playful
        case .savingTheDay, .performingSurgery, .conductingExperiment, .designingBuilding,
             .teachingClass, .fightingFire, .launchingRocket:
            return .work
        }
    }
}

enum ActionCategory {
    case sports, arts, everyday, adventure, magical, relaxing, playful, work
}

enum DrawingAccessory: String, CaseIterable {
    // HEADWEAR
    case wizardHat, baseballCap, crown, cowboyHat, partyHat, chefHat, pirateHat, topHat, beret, beanie

    // EYEWEAR
    case sunglasses, glasses, goggles, monocle, 3DGlasses, heartGlasses

    // NECKWEAR
    case scarf, bowTie, necktie, cape, lei

    // HANDHELD ITEMS
    case umbrella, balloon, kite, telescope, magnifyingGlass, camera
    case paintbrush, microphone, book, map, compass, lantern
    case sword, shield, magicWand, scepter, flag, torch

    // BAGS & CARRIERS
    case backpack, suitcase, lunchbox, treasureChest, giftBox

    // SPORTS EQUIPMENT
    case skateboard, surfboard, skis, snowboard, bicycle
    case basketball, soccerBall, tennisRacket, baseballBat, golfClub

    // MUSICAL INSTRUMENTS
    case guitar, drums, piano, trumpet, violin, ukulele

    // TOOLS
    case hammer, wrench, paintbrush, telescope, microscope

    // MAGICAL ITEMS
    case crystalBall, spellBook, potionBottle, magicStaff, fairyDust

    // FUN ITEMS
    case bubbles, confetti, flowers, butterfly, sparkles, hearts, stars
    case rainbow, snowflakes, leaves, fireflies

    // FOOD & DRINK
    case coffee, tea, juice, smoothie, pizza, donut, iceCream, cookie

    var displayName: String {
        switch self {
        case .wizardHat: return "Wizard Hat"
        case .baseballCap: return "Baseball Cap"
        case .cowboyHat: return "Cowboy Hat"
        case .partyHat: return "Party Hat"
        case .chefHat: return "Chef Hat"
        case .pirateHat: return "Pirate Hat"
        case .topHat: return "Top Hat"
        case .heartGlasses: return "Heart-shaped Glasses"
        case ._3DGlasses: return "3D Glasses"
        case .bowTie: return "Bow Tie"
        case .magnifyingGlass: return "Magnifying Glass"
        case .treasureChest: return "Treasure Chest"
        case .giftBox: return "Gift Box"
        case .soccerBall: return "Soccer Ball"
        case .tennisRacket: return "Tennis Racket"
        case .baseballBat: return "Baseball Bat"
        case .golfClub: return "Golf Club"
        case .crystalBall: return "Crystal Ball"
        case .spellBook: return "Spell Book"
        case .potionBottle: return "Potion Bottle"
        case .magicStaff: return "Magic Staff"
        case .fairyDust: return "Fairy Dust"
        case .iceCream: return "Ice Cream"
        default: return rawValue.capitalized
        }
    }
}

// MARK: - Smart Combination Rules

struct CombinationRules {
    // Actions that work well with certain subject categories
    static let compatibleCombinations: [SubjectCategory: [ActionCategory]] = [
        .domesticAnimal: [.sports, .playful, .relaxing, .everyday],
        .farmAnimal: [.everyday, .playful, .relaxing],
        .wildAnimal: [.adventure, .sports, .playful],
        .forestAnimal: [.adventure, .playful, .everyday],
        .oceanAnimal: [.sports, .adventure, .playful],
        .arcticAnimal: [.sports, .adventure, .playful],
        .desertAnimal: [.adventure, .relaxing, .everyday],
        .jungleAnimal: [.adventure, .sports, .playful],
        .insect: [.playful, .everyday, .adventure],
        .mythical: [.magical, .adventure, .sports, .playful],
        .dinosaur: [.adventure, .sports, .playful],
        .person: [.sports, .arts, .everyday, .adventure, .work],
        .landmark: [.adventure, .relaxing], // Landmarks typically don't "do" much
        .vehicle: [.adventure, .sports],
        .food: [.playful, .sports, .relaxing],
        .nature: [.relaxing, .magical],
        .fantasyObject: [.magical, .adventure],
        .tech: [.work, .adventure, .everyday]
    ]

    // Some actions are incompatible with landmarks (they don't move)
    static let staticSubjects: Set<SubjectCategory> = [.landmark, .nature]

    // Magical actions only for magical subjects
    static let magicalSubjects: Set<SubjectCategory> = [.mythical, .fantasyObject]

    static func isCompatible(subject: DrawingSubject, action: DrawingAction) -> Bool {
        let subjectCat = subject.category
        let actionCat = action.actionCategory

        // Static subjects can only do stationary things
        if staticSubjects.contains(subjectCat) && actionCat == .sports {
            return false
        }

        // Magical actions only for magical subjects
        if actionCat == .magical && !magicalSubjects.contains(subjectCat) {
            return false
        }

        // Work actions only for people/robots
        if actionCat == .work && ![.person, .tech].contains(subjectCat) {
            return false
        }

        // Check compatibility list
        if let compatibleActions = compatibleCombinations[subjectCat] {
            return compatibleActions.contains(actionCat)
        }

        return true
    }

    // Get appropriate accessories for a subject+action combo
    static func getAppropriateAccessories(for subject: DrawingSubject, action: DrawingAction) -> [DrawingAccessory] {
        var accessories: [DrawingAccessory] = []

        // Add action-specific accessories
        switch action.actionCategory {
        case .sports:
            accessories += [.sunglasses, .baseballCap, .skateboard, .surfboard]
        case .arts:
            accessories += [.beret, .paintbrush, .camera, .book, .guitar]
        case .magical:
            accessories += [.wizardHat, .magicWand, .crystalBall, .cape, .magicStaff]
        case .adventure:
            accessories += [.backpack, .compass, .map, .telescope, .magnifyingGlass]
        case .work:
            accessories += [.glasses, .book, .microscope, .telescope]
        case .playful:
            accessories += [.partyHat, .balloon, .bubbles, .kite]
        case .relaxing:
            accessories += [.sunglasses, .tea, .coffee, .book]
        case .everyday:
            accessories += [.scarf, .glasses, .backpack, .umbrella]
        }

        // Add subject-specific accessories
        switch subject.category {
        case .mythical, .fantasyObject:
            accessories += [.crown, .magicWand, .sparkles, .fairyDust]
        case .person:
            accessories += [.glasses, .beret, .scarf]
        case .oceanAnimal:
            accessories += [.surfboard, .sunglasses, .umbrella]
        default:
            break
        }

        return Array(Set(accessories)) // Remove duplicates
    }
}

// MARK: - Modular Drawing Concept

struct ModularDrawingConcept {
    let subject: DrawingSubject
    let action: DrawingAction?
    let accessories: [DrawingAccessory]
    let expression: Expression

    enum Expression: String, CaseIterable {
        case happy, excited, silly, peaceful, determined, curious, sleepy, joyful, surprised, cool

        var displayName: String { rawValue.capitalized }
    }

    var description: String {
        var desc = "\(expression.displayName) \(subject.displayName)"

        if let action = action {
            desc += " \(action.displayName)"
        }

        if !accessories.isEmpty {
            let accessoryNames = accessories.prefix(2).map { $0.displayName }
            desc += " with \(accessoryNames.joined(separator: " and "))"
        }

        return desc
    }

    var shortName: String {
        if let action = action {
            return "\(subject.displayName) \(action.displayName)"
        }
        return "\(expression.displayName) \(subject.displayName)"
    }

    // Generate paths for this concept (procedurally generated based on components)
    func generatePaths() -> [DrawingConcept.DrawingPath] {
        // This will generate simple geometric representations
        // In a production app, you'd have more sophisticated path generation
        var paths: [DrawingConcept.DrawingPath] = []

        // Base subject body
        paths.append(contentsOf: generateSubjectPaths())

        // Add expression (eyes, mouth)
        paths.append(contentsOf: generateExpressionPaths())

        // Add accessories
        for (index, accessory) in accessories.prefix(2).enumerated() {
            paths.append(contentsOf: generateAccessoryPaths(accessory, position: index))
        }

        return paths
    }

    private func generateSubjectPaths() -> [DrawingConcept.DrawingPath] {
        // Generate basic shape based on subject category
        switch subject.category {
        case .domesticAnimal, .wildAnimal, .farmAnimal, .forestAnimal, .arcticAnimal, .desertAnimal, .jungleAnimal:
            return generateAnimalBody()
        case .oceanAnimal:
            return generateOceanCreatureBody()
        case .mythical:
            return generateMythicalCreatureBody()
        case .person:
            return generatePersonBody()
        case .vehicle:
            return generateVehicleBody()
        case .food:
            return generateFoodBody()
        default:
            return generateGenericBody()
        }
    }

    private func generateAnimalBody() -> [DrawingConcept.DrawingPath] {
        // Simple animal body shape
        [
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.4, y: 0.5),
                CGPoint(x: 0.6, y: 0.5),
                CGPoint(x: 0.62, y: 0.65),
                CGPoint(x: 0.38, y: 0.65)
            ], closed: true, order: 1),
            // Head
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.45, y: 0.5),
                CGPoint(x: 0.55, y: 0.5),
                CGPoint(x: 0.56, y: 0.4),
                CGPoint(x: 0.44, y: 0.4)
            ], closed: true, order: 2)
        ]
    }

    private func generateOceanCreatureBody() -> [DrawingConcept.DrawingPath] {
        // Ocean creature with flowing shape
        [
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.3, y: 0.5),
                CGPoint(x: 0.5, y: 0.45),
                CGPoint(x: 0.7, y: 0.5),
                CGPoint(x: 0.6, y: 0.6),
                CGPoint(x: 0.4, y: 0.6)
            ], closed: true, order: 1)
        ]
    }

    private func generateMythicalCreatureBody() -> [DrawingConcept.DrawingPath] {
        // Magical creature with extra flourishes
        [
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.4, y: 0.5),
                CGPoint(x: 0.6, y: 0.5),
                CGPoint(x: 0.62, y: 0.65),
                CGPoint(x: 0.38, y: 0.65)
            ], closed: true, order: 1),
            // Wings or horn
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.5, y: 0.4),
                CGPoint(x: 0.48, y: 0.3),
                CGPoint(x: 0.52, y: 0.3)
            ], closed: false, order: 2)
        ]
    }

    private func generatePersonBody() -> [DrawingConcept.DrawingPath] {
        // Simple humanoid shape
        [
            // Body
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.4, y: 0.5),
                CGPoint(x: 0.6, y: 0.5),
                CGPoint(x: 0.58, y: 0.7),
                CGPoint(x: 0.42, y: 0.7)
            ], closed: true, order: 1),
            // Head
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.45, y: 0.5),
                CGPoint(x: 0.55, y: 0.5),
                CGPoint(x: 0.55, y: 0.4),
                CGPoint(x: 0.45, y: 0.4)
            ], closed: true, order: 2)
        ]
    }

    private func generateVehicleBody() -> [DrawingConcept.DrawingPath] {
        // Simple vehicle shape
        [
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.3, y: 0.55),
                CGPoint(x: 0.7, y: 0.55),
                CGPoint(x: 0.68, y: 0.65),
                CGPoint(x: 0.32, y: 0.65)
            ], closed: true, order: 1)
        ]
    }

    private func generateFoodBody() -> [DrawingConcept.DrawingPath] {
        // Rounded food shape
        [
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.35, y: 0.5),
                CGPoint(x: 0.65, y: 0.5),
                CGPoint(x: 0.68, y: 0.6),
                CGPoint(x: 0.65, y: 0.7),
                CGPoint(x: 0.35, y: 0.7),
                CGPoint(x: 0.32, y: 0.6)
            ], closed: true, order: 1)
        ]
    }

    private func generateGenericBody() -> [DrawingConcept.DrawingPath] {
        // Generic rounded shape
        [
            DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.35, y: 0.45),
                CGPoint(x: 0.65, y: 0.45),
                CGPoint(x: 0.68, y: 0.55),
                CGPoint(x: 0.65, y: 0.65),
                CGPoint(x: 0.35, y: 0.65),
                CGPoint(x: 0.32, y: 0.55)
            ], closed: true, order: 1)
        ]
    }

    private func generateExpressionPaths() -> [DrawingConcept.DrawingPath] {
        var paths: [DrawingConcept.DrawingPath] = []

        // Eyes
        paths.append(DrawingConcept.DrawingPath(points: [
            CGPoint(x: 0.46, y: 0.45),
            CGPoint(x: 0.47, y: 0.45)
        ], closed: false, order: 10))

        paths.append(DrawingConcept.DrawingPath(points: [
            CGPoint(x: 0.53, y: 0.45),
            CGPoint(x: 0.54, y: 0.45)
        ], closed: false, order: 11))

        // Mouth based on expression
        switch expression {
        case .happy, .joyful, .excited:
            paths.append(DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.46, y: 0.50),
                CGPoint(x: 0.50, y: 0.52),
                CGPoint(x: 0.54, y: 0.50)
            ], closed: false, order: 12))
        case .silly:
            paths.append(DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.46, y: 0.50),
                CGPoint(x: 0.48, y: 0.52),
                CGPoint(x: 0.50, y: 0.50),
                CGPoint(x: 0.52, y: 0.52),
                CGPoint(x: 0.54, y: 0.50)
            ], closed: false, order: 12))
        case .sleepy, .peaceful:
            paths.append(DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.46, y: 0.50),
                CGPoint(x: 0.54, y: 0.50)
            ], closed: false, order: 12))
        default:
            paths.append(DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.46, y: 0.50),
                CGPoint(x: 0.50, y: 0.51),
                CGPoint(x: 0.54, y: 0.50)
            ], closed: false, order: 12))
        }

        return paths
    }

    private func generateAccessoryPaths(_ accessory: DrawingAccessory, position: Int) -> [DrawingConcept.DrawingPath] {
        let offset = CGFloat(position) * 0.1

        switch accessory {
        case .wizardHat, .baseballCap, .crown, .partyHat, .chefHat:
            // Hat on top
            return [DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.45, y: 0.38),
                CGPoint(x: 0.50, y: 0.30),
                CGPoint(x: 0.55, y: 0.38)
            ], closed: false, order: 20 + position)]

        case .sunglasses, .glasses:
            // Glasses
            return [DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.44, y: 0.45),
                CGPoint(x: 0.48, y: 0.45),
                CGPoint(x: 0.52, y: 0.45),
                CGPoint(x: 0.56, y: 0.45)
            ], closed: false, order: 20 + position)]

        case .scarf:
            // Scarf around neck
            return [DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.42, y: 0.52),
                CGPoint(x: 0.58, y: 0.52)
            ], closed: false, order: 20 + position)]

        case .balloon, .kite:
            // Floating above
            return [
                DrawingConcept.DrawingPath(points: [
                    CGPoint(x: 0.55 + offset, y: 0.35),
                    CGPoint(x: 0.55 + offset, y: 0.25)
                ], closed: false, order: 20 + position),
                DrawingConcept.DrawingPath(points: [
                    CGPoint(x: 0.53 + offset, y: 0.25),
                    CGPoint(x: 0.55 + offset, y: 0.23),
                    CGPoint(x: 0.57 + offset, y: 0.25)
                ], closed: true, order: 21 + position)
            ]

        case .umbrella:
            // Umbrella above
            return [DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.40, y: 0.35),
                CGPoint(x: 0.45, y: 0.30),
                CGPoint(x: 0.50, y: 0.28),
                CGPoint(x: 0.55, y: 0.30),
                CGPoint(x: 0.60, y: 0.35)
            ], closed: false, order: 20 + position)]

        default:
            // Generic small accessory
            return [DrawingConcept.DrawingPath(points: [
                CGPoint(x: 0.60 + offset, y: 0.55),
                CGPoint(x: 0.62 + offset, y: 0.55),
                CGPoint(x: 0.62 + offset, y: 0.57),
                CGPoint(x: 0.60 + offset, y: 0.57)
            ], closed: true, order: 20 + position)]
        }
    }
}

// MARK: - Modular Drawing Generator

class ModularDrawingGenerator {
    static let shared = ModularDrawingGenerator()

    private var usedCombinations: Set<String> = []
    private let maxHistorySize = 50

    func generateRandomConcept(for cloudShape: CloudShape) -> ModularDrawingConcept {
        var attempts = 0
        let maxAttempts = 10

        while attempts < maxAttempts {
            let concept = createRandomConcept(for: cloudShape)
            let key = "\(concept.subject.rawValue)-\(concept.action?.rawValue ?? "none")"

            // Try to avoid recent repeats
            if !usedCombinations.contains(key) || attempts == maxAttempts - 1 {
                usedCombinations.insert(key)

                // Keep history size manageable
                if usedCombinations.count > maxHistorySize {
                    usedCombinations.removeFirst()
                }

                return concept
            }

            attempts += 1
        }

        return createRandomConcept(for: cloudShape)
    }

    private func createRandomConcept(for cloudShape: CloudShape) -> ModularDrawingConcept {
        // Select subject based on cloud shape
        let subject = selectSubject(for: cloudShape)

        // Select compatible action
        let action = selectAction(for: subject)

        // Select appropriate accessories
        let accessories = selectAccessories(for: subject, action: action)

        // Select random expression
        let expression = ModularDrawingConcept.Expression.allCases.randomElement() ?? .happy

        return ModularDrawingConcept(
            subject: subject,
            action: action,
            accessories: accessories,
            expression: expression
        )
    }

    private func selectSubject(for cloudShape: CloudShape) -> DrawingSubject {
        // Filter subjects by cloud shape
        let allSubjects = DrawingSubject.allCases

        switch cloudShape.shapeCategory {
        case .round:
            // Prefer round, cute subjects
            let preferred: [DrawingSubject] = [
                .cat, .dog, .hamster, .rabbit, .panda, .koala, .owl, .penguin,
                .sun, .moon, .pizza, .donut, .cupcake, .hotAirBalloon
            ]
            return preferred.randomElement() ?? allSubjects.randomElement()!

        case .elongated:
            // Prefer long subjects
            let preferred: [DrawingSubject] = [
                .dragon, .snake, .giraffe, .train, .submarine, .banana
            ]
            return preferred.randomElement() ?? allSubjects.randomElement()!

        case .wide:
            // Prefer wide subjects
            let preferred: [DrawingSubject] = [
                .whale, .airplane, .car, .boat, .rainbow, .pyramid,
                .eiffelTower, .greatWall, .colosseum
            ]
            return preferred.randomElement() ?? allSubjects.randomElement()!

        case .tall:
            // Prefer tall subjects
            let preferred: [DrawingSubject] = [
                .giraffe, .rocket, .tree, .mountain, .volcano,
                .statueOfLiberty, .christRedeemer, .bigBen
            ]
            return preferred.randomElement() ?? allSubjects.randomElement()!
        }
    }

    private func selectAction(for subject: DrawingSubject) -> DrawingAction? {
        // Some subjects don't need actions (landmarks, nature elements)
        if CombinationRules.staticSubjects.contains(subject.category) {
            return nil
        }

        // 20% chance of no action (just the subject with accessories)
        if Int.random(in: 0..<10) < 2 {
            return nil
        }

        // Find compatible actions
        let compatibleActions = DrawingAction.allCases.filter { action in
            CombinationRules.isCompatible(subject: subject, action: action)
        }

        return compatibleActions.randomElement()
    }

    private func selectAccessories(for subject: DrawingSubject, action: DrawingAction?) -> [DrawingAccessory] {
        var accessories: [DrawingAccessory] = []

        // Get appropriate accessories
        if let action = action {
            accessories = CombinationRules.getAppropriateAccessories(for: subject, action: action)
        } else {
            // Random fun accessories if no action
            accessories = [.sunglasses, .crown, .scarf, .balloon, .sparkles, .hearts, .flowers].compactMap { $0 }
        }

        // Select 0-2 random accessories
        let count = Int.random(in: 0...min(2, accessories.count))
        return Array(accessories.shuffled().prefix(count))
    }
}

// MARK: - Legacy DrawingConcept (for compatibility)

struct DrawingConcept {
    let name: String
    let paths: [DrawingPath]
    let preferredShape: CloudShape.ShapeCategory?

    struct DrawingPath {
        let points: [CGPoint]
        let closed: Bool
        let order: Int
    }
}

// MARK: - Updated Drawing Library

class DrawingLibrary {
    private let generator = ModularDrawingGenerator.shared

    func selectDrawing(for cloudShape: CloudShape) -> DrawingConcept? {
        // Generate a modular concept
        let modularConcept = generator.generateRandomConcept(for: cloudShape)

        // Convert to DrawingConcept
        return DrawingConcept(
            name: modularConcept.description,
            paths: modularConcept.generatePaths(),
            preferredShape: nil // Now adaptive to all shapes
        )
    }

    // Method to get the modular concept directly (for UI display)
    func selectModularDrawing(for cloudShape: CloudShape) -> ModularDrawingConcept {
        return generator.generateRandomConcept(for: cloudShape)
    }
}
