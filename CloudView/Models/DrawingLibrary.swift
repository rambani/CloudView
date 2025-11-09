import Foundation
import CoreGraphics

struct DrawingConcept {
    let name: String
    let paths: [DrawingPath]
    let preferredShape: CloudShape.ShapeCategory?

    struct DrawingPath {
        let points: [CGPoint]
        let closed: Bool
        let order: Int // Animation order
    }
}

class DrawingLibrary {
    private let drawings: [DrawingConcept]

    init() {
        // Initialize with a collection of cute and funny drawings
        self.drawings = [
            // Round shapes
            Self.createTurtleOnSkateboard(),
            Self.createHappySun(),
            Self.createSleepingCat(),
            Self.createBubbleTeaCup(),

            // Elongated shapes
            Self.createDragonEatingBurger(),
            Self.createDachshundInSweater(),
            Self.createSurfingPenguin(),

            // Wide shapes
            Self.createFlyingSaucer(),
            Self.createWhaleWithUmbrella(),
            Self.createCloudCastle(),

            // Tall shapes
            Self.createGiraffeInScarf(),
            Self.createRocketShip(),
            Self.createIceCreamCone()
        ]
    }

    func selectDrawing(for cloudShape: CloudShape) -> DrawingConcept? {
        // Filter drawings that match the cloud shape
        let matchingDrawings = drawings.filter { drawing in
            drawing.preferredShape == nil || drawing.preferredShape == cloudShape.shapeCategory
        }

        // Return a random matching drawing
        return matchingDrawings.randomElement()
    }

    // MARK: - Drawing Definitions

    static func createTurtleOnSkateboard() -> DrawingConcept {
        DrawingConcept(
            name: "Turtle on Skateboard",
            paths: [
                // Shell
                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.4),
                    CGPoint(x: 0.7, y: 0.35),
                    CGPoint(x: 0.8, y: 0.5),
                    CGPoint(x: 0.7, y: 0.65),
                    CGPoint(x: 0.5, y: 0.7),
                    CGPoint(x: 0.3, y: 0.65),
                    CGPoint(x: 0.2, y: 0.5),
                    CGPoint(x: 0.3, y: 0.35)
                ], closed: true, order: 1),

                // Head
                DrawingPath(points: [
                    CGPoint(x: 0.2, y: 0.5),
                    CGPoint(x: 0.1, y: 0.45),
                    CGPoint(x: 0.05, y: 0.4),
                    CGPoint(x: 0.08, y: 0.35)
                ], closed: false, order: 2),

                // Eye
                DrawingPath(points: [
                    CGPoint(x: 0.12, y: 0.38),
                    CGPoint(x: 0.13, y: 0.38),
                    CGPoint(x: 0.13, y: 0.37),
                    CGPoint(x: 0.12, y: 0.37)
                ], closed: true, order: 3),

                // Legs (front)
                DrawingPath(points: [
                    CGPoint(x: 0.35, y: 0.65),
                    CGPoint(x: 0.33, y: 0.75),
                    CGPoint(x: 0.32, y: 0.78)
                ], closed: false, order: 4),

                // Legs (back)
                DrawingPath(points: [
                    CGPoint(x: 0.65, y: 0.65),
                    CGPoint(x: 0.67, y: 0.75),
                    CGPoint(x: 0.68, y: 0.78)
                ], closed: false, order: 5),

                // Skateboard
                DrawingPath(points: [
                    CGPoint(x: 0.25, y: 0.8),
                    CGPoint(x: 0.75, y: 0.8),
                    CGPoint(x: 0.77, y: 0.82),
                    CGPoint(x: 0.75, y: 0.84),
                    CGPoint(x: 0.25, y: 0.84),
                    CGPoint(x: 0.23, y: 0.82)
                ], closed: true, order: 6),

                // Wheels
                DrawingPath(points: [
                    CGPoint(x: 0.3, y: 0.87),
                    CGPoint(x: 0.32, y: 0.87),
                    CGPoint(x: 0.32, y: 0.89),
                    CGPoint(x: 0.3, y: 0.89)
                ], closed: true, order: 7),

                DrawingPath(points: [
                    CGPoint(x: 0.68, y: 0.87),
                    CGPoint(x: 0.7, y: 0.87),
                    CGPoint(x: 0.7, y: 0.89),
                    CGPoint(x: 0.68, y: 0.89)
                ], closed: true, order: 8)
            ],
            preferredShape: .round
        )
    }

    static func createDragonEatingBurger() -> DrawingConcept {
        DrawingConcept(
            name: "Dragon Eating Burger",
            paths: [
                // Body
                DrawingPath(points: [
                    CGPoint(x: 0.3, y: 0.5),
                    CGPoint(x: 0.4, y: 0.45),
                    CGPoint(x: 0.5, y: 0.5),
                    CGPoint(x: 0.6, y: 0.48),
                    CGPoint(x: 0.7, y: 0.5),
                    CGPoint(x: 0.75, y: 0.55),
                    CGPoint(x: 0.7, y: 0.6),
                    CGPoint(x: 0.6, y: 0.58),
                    CGPoint(x: 0.5, y: 0.6),
                    CGPoint(x: 0.4, y: 0.58),
                    CGPoint(x: 0.3, y: 0.55)
                ], closed: true, order: 1),

                // Head
                DrawingPath(points: [
                    CGPoint(x: 0.2, y: 0.5),
                    CGPoint(x: 0.15, y: 0.45),
                    CGPoint(x: 0.12, y: 0.5),
                    CGPoint(x: 0.15, y: 0.55),
                    CGPoint(x: 0.2, y: 0.53)
                ], closed: true, order: 2),

                // Spikes on back
                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.45),
                    CGPoint(x: 0.38, y: 0.38)
                ], closed: false, order: 3),

                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.43),
                    CGPoint(x: 0.48, y: 0.35)
                ], closed: false, order: 4),

                DrawingPath(points: [
                    CGPoint(x: 0.6, y: 0.42),
                    CGPoint(x: 0.58, y: 0.34)
                ], closed: false, order: 5),

                // Burger (top bun)
                DrawingPath(points: [
                    CGPoint(x: 0.08, y: 0.45),
                    CGPoint(x: 0.05, y: 0.42),
                    CGPoint(x: 0.04, y: 0.38),
                    CGPoint(x: 0.06, y: 0.35),
                    CGPoint(x: 0.10, y: 0.35)
                ], closed: true, order: 6),

                // Burger (patty)
                DrawingPath(points: [
                    CGPoint(x: 0.04, y: 0.42),
                    CGPoint(x: 0.11, y: 0.42)
                ], closed: false, order: 7),

                // Burger (bottom bun)
                DrawingPath(points: [
                    CGPoint(x: 0.04, y: 0.45),
                    CGPoint(x: 0.11, y: 0.45)
                ], closed: false, order: 8),

                // Eye
                DrawingPath(points: [
                    CGPoint(x: 0.17, y: 0.48),
                    CGPoint(x: 0.18, y: 0.48)
                ], closed: false, order: 9)
            ],
            preferredShape: .elongated
        )
    }

    static func createHappySun() -> DrawingConcept {
        DrawingConcept(
            name: "Happy Sun",
            paths: [
                // Face circle
                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.3),
                    CGPoint(x: 0.6, y: 0.35),
                    CGPoint(x: 0.65, y: 0.45),
                    CGPoint(x: 0.65, y: 0.55),
                    CGPoint(x: 0.6, y: 0.65),
                    CGPoint(x: 0.5, y: 0.7),
                    CGPoint(x: 0.4, y: 0.65),
                    CGPoint(x: 0.35, y: 0.55),
                    CGPoint(x: 0.35, y: 0.45),
                    CGPoint(x: 0.4, y: 0.35)
                ], closed: true, order: 1),

                // Happy eyes (left)
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.45),
                    CGPoint(x: 0.44, y: 0.43),
                    CGPoint(x: 0.46, y: 0.45)
                ], closed: false, order: 2),

                // Happy eyes (right)
                DrawingPath(points: [
                    CGPoint(x: 0.54, y: 0.45),
                    CGPoint(x: 0.56, y: 0.43),
                    CGPoint(x: 0.58, y: 0.45)
                ], closed: false, order: 3),

                // Smile
                DrawingPath(points: [
                    CGPoint(x: 0.43, y: 0.55),
                    CGPoint(x: 0.45, y: 0.58),
                    CGPoint(x: 0.5, y: 0.6),
                    CGPoint(x: 0.55, y: 0.58),
                    CGPoint(x: 0.57, y: 0.55)
                ], closed: false, order: 4),

                // Sun rays
                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.3),
                    CGPoint(x: 0.5, y: 0.2)
                ], closed: false, order: 5),

                DrawingPath(points: [
                    CGPoint(x: 0.6, y: 0.35),
                    CGPoint(x: 0.68, y: 0.28)
                ], closed: false, order: 6),

                DrawingPath(points: [
                    CGPoint(x: 0.65, y: 0.45),
                    CGPoint(x: 0.75, y: 0.45)
                ], closed: false, order: 7),

                DrawingPath(points: [
                    CGPoint(x: 0.6, y: 0.65),
                    CGPoint(x: 0.68, y: 0.72)
                ], closed: false, order: 8),

                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.7),
                    CGPoint(x: 0.5, y: 0.8)
                ], closed: false, order: 9),

                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.65),
                    CGPoint(x: 0.32, y: 0.72)
                ], closed: false, order: 10),

                DrawingPath(points: [
                    CGPoint(x: 0.35, y: 0.45),
                    CGPoint(x: 0.25, y: 0.45)
                ], closed: false, order: 11),

                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.35),
                    CGPoint(x: 0.32, y: 0.28)
                ], closed: false, order: 12)
            ],
            preferredShape: .round
        )
    }

    static func createSleepingCat() -> DrawingConcept {
        DrawingConcept(
            name: "Sleeping Cat",
            paths: [
                // Body
                DrawingPath(points: [
                    CGPoint(x: 0.35, y: 0.5),
                    CGPoint(x: 0.65, y: 0.5),
                    CGPoint(x: 0.7, y: 0.6),
                    CGPoint(x: 0.65, y: 0.7),
                    CGPoint(x: 0.35, y: 0.7),
                    CGPoint(x: 0.3, y: 0.6)
                ], closed: true, order: 1),

                // Head
                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.5),
                    CGPoint(x: 0.38, y: 0.4),
                    CGPoint(x: 0.42, y: 0.32),
                    CGPoint(x: 0.5, y: 0.3),
                    CGPoint(x: 0.58, y: 0.32),
                    CGPoint(x: 0.62, y: 0.4),
                    CGPoint(x: 0.6, y: 0.5)
                ], closed: true, order: 2),

                // Left ear
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.32),
                    CGPoint(x: 0.38, y: 0.25),
                    CGPoint(x: 0.44, y: 0.28)
                ], closed: true, order: 3),

                // Right ear
                DrawingPath(points: [
                    CGPoint(x: 0.58, y: 0.32),
                    CGPoint(x: 0.62, y: 0.25),
                    CGPoint(x: 0.56, y: 0.28)
                ], closed: true, order: 4),

                // Sleeping eyes (left)
                DrawingPath(points: [
                    CGPoint(x: 0.43, y: 0.42),
                    CGPoint(x: 0.47, y: 0.42)
                ], closed: false, order: 5),

                // Sleeping eyes (right)
                DrawingPath(points: [
                    CGPoint(x: 0.53, y: 0.42),
                    CGPoint(x: 0.57, y: 0.42)
                ], closed: false, order: 6),

                // Nose
                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.46),
                    CGPoint(x: 0.48, y: 0.48),
                    CGPoint(x: 0.52, y: 0.48)
                ], closed: true, order: 7),

                // Tail
                DrawingPath(points: [
                    CGPoint(x: 0.65, y: 0.68),
                    CGPoint(x: 0.72, y: 0.65),
                    CGPoint(x: 0.75, y: 0.58),
                    CGPoint(x: 0.73, y: 0.5)
                ], closed: false, order: 8)
            ],
            preferredShape: .round
        )
    }

    static func createBubbleTeaCup() -> DrawingConcept {
        DrawingConcept(
            name: "Bubble Tea Cup",
            paths: [
                // Cup body
                DrawingPath(points: [
                    CGPoint(x: 0.35, y: 0.4),
                    CGPoint(x: 0.65, y: 0.4),
                    CGPoint(x: 0.62, y: 0.75),
                    CGPoint(x: 0.38, y: 0.75)
                ], closed: true, order: 1),

                // Cup lid
                DrawingPath(points: [
                    CGPoint(x: 0.33, y: 0.4),
                    CGPoint(x: 0.33, y: 0.35),
                    CGPoint(x: 0.67, y: 0.35),
                    CGPoint(x: 0.67, y: 0.4)
                ], closed: false, order: 2),

                // Straw
                DrawingPath(points: [
                    CGPoint(x: 0.55, y: 0.35),
                    CGPoint(x: 0.53, y: 0.25),
                    CGPoint(x: 0.52, y: 0.2)
                ], closed: false, order: 3),

                // Straw opening
                DrawingPath(points: [
                    CGPoint(x: 0.51, y: 0.2),
                    CGPoint(x: 0.53, y: 0.2)
                ], closed: false, order: 4),

                // Tea level
                DrawingPath(points: [
                    CGPoint(x: 0.37, y: 0.5),
                    CGPoint(x: 0.63, y: 0.5)
                ], closed: false, order: 5),

                // Boba pearls
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.68),
                    CGPoint(x: 0.44, y: 0.68),
                    CGPoint(x: 0.44, y: 0.7),
                    CGPoint(x: 0.42, y: 0.7)
                ], closed: true, order: 6),

                DrawingPath(points: [
                    CGPoint(x: 0.48, y: 0.66),
                    CGPoint(x: 0.5, y: 0.66),
                    CGPoint(x: 0.5, y: 0.68),
                    CGPoint(x: 0.48, y: 0.68)
                ], closed: true, order: 7),

                DrawingPath(points: [
                    CGPoint(x: 0.54, y: 0.69),
                    CGPoint(x: 0.56, y: 0.69),
                    CGPoint(x: 0.56, y: 0.71),
                    CGPoint(x: 0.54, y: 0.71)
                ], closed: true, order: 8),

                // Happy face
                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.55),
                    CGPoint(x: 0.46, y: 0.55)
                ], closed: false, order: 9),

                DrawingPath(points: [
                    CGPoint(x: 0.54, y: 0.55),
                    CGPoint(x: 0.55, y: 0.55)
                ], closed: false, order: 10),

                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.6),
                    CGPoint(x: 0.5, y: 0.62),
                    CGPoint(x: 0.55, y: 0.6)
                ], closed: false, order: 11)
            ],
            preferredShape: .round
        )
    }

    static func createDachshundInSweater() -> DrawingConcept {
        DrawingConcept(
            name: "Dachshund in Sweater",
            paths: [
                // Long body
                DrawingPath(points: [
                    CGPoint(x: 0.2, y: 0.5),
                    CGPoint(x: 0.8, y: 0.5),
                    CGPoint(x: 0.78, y: 0.6),
                    CGPoint(x: 0.22, y: 0.6)
                ], closed: true, order: 1),

                // Head
                DrawingPath(points: [
                    CGPoint(x: 0.15, y: 0.48),
                    CGPoint(x: 0.1, y: 0.45),
                    CGPoint(x: 0.08, y: 0.5),
                    CGPoint(x: 0.1, y: 0.55),
                    CGPoint(x: 0.15, y: 0.52)
                ], closed: true, order: 2),

                // Ear
                DrawingPath(points: [
                    CGPoint(x: 0.12, y: 0.45),
                    CGPoint(x: 0.1, y: 0.4),
                    CGPoint(x: 0.13, y: 0.47)
                ], closed: false, order: 3),

                // Eye
                DrawingPath(points: [
                    CGPoint(x: 0.11, y: 0.48),
                    CGPoint(x: 0.12, y: 0.48)
                ], closed: false, order: 4),

                // Sweater pattern (stripes)
                DrawingPath(points: [
                    CGPoint(x: 0.3, y: 0.5),
                    CGPoint(x: 0.3, y: 0.6)
                ], closed: false, order: 5),

                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.5),
                    CGPoint(x: 0.4, y: 0.6)
                ], closed: false, order: 6),

                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.5),
                    CGPoint(x: 0.5, y: 0.6)
                ], closed: false, order: 7),

                DrawingPath(points: [
                    CGPoint(x: 0.6, y: 0.5),
                    CGPoint(x: 0.6, y: 0.6)
                ], closed: false, order: 8),

                DrawingPath(points: [
                    CGPoint(x: 0.7, y: 0.5),
                    CGPoint(x: 0.7, y: 0.6)
                ], closed: false, order: 9),

                // Legs (stubby)
                DrawingPath(points: [
                    CGPoint(x: 0.3, y: 0.6),
                    CGPoint(x: 0.3, y: 0.65)
                ], closed: false, order: 10),

                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.6),
                    CGPoint(x: 0.45, y: 0.65)
                ], closed: false, order: 11),

                DrawingPath(points: [
                    CGPoint(x: 0.6, y: 0.6),
                    CGPoint(x: 0.6, y: 0.65)
                ], closed: false, order: 12),

                DrawingPath(points: [
                    CGPoint(x: 0.75, y: 0.6),
                    CGPoint(x: 0.75, y: 0.65)
                ], closed: false, order: 13),

                // Tail
                DrawingPath(points: [
                    CGPoint(x: 0.8, y: 0.52),
                    CGPoint(x: 0.85, y: 0.48),
                    CGPoint(x: 0.88, y: 0.42)
                ], closed: false, order: 14)
            ],
            preferredShape: .elongated
        )
    }

    static func createSurfingPenguin() -> DrawingConcept {
        DrawingConcept(
            name: "Surfing Penguin",
            paths: [
                // Surfboard
                DrawingPath(points: [
                    CGPoint(x: 0.25, y: 0.65),
                    CGPoint(x: 0.75, y: 0.65),
                    CGPoint(x: 0.78, y: 0.7),
                    CGPoint(x: 0.75, y: 0.75),
                    CGPoint(x: 0.25, y: 0.75),
                    CGPoint(x: 0.22, y: 0.7)
                ], closed: true, order: 1),

                // Penguin body
                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.35),
                    CGPoint(x: 0.55, y: 0.35),
                    CGPoint(x: 0.58, y: 0.45),
                    CGPoint(x: 0.56, y: 0.6),
                    CGPoint(x: 0.44, y: 0.6),
                    CGPoint(x: 0.42, y: 0.45)
                ], closed: true, order: 2),

                // White belly
                DrawingPath(points: [
                    CGPoint(x: 0.46, y: 0.42),
                    CGPoint(x: 0.54, y: 0.42),
                    CGPoint(x: 0.53, y: 0.55),
                    CGPoint(x: 0.47, y: 0.55)
                ], closed: true, order: 3),

                // Head
                DrawingPath(points: [
                    CGPoint(x: 0.46, y: 0.35),
                    CGPoint(x: 0.54, y: 0.35),
                    CGPoint(x: 0.55, y: 0.3),
                    CGPoint(x: 0.5, y: 0.25),
                    CGPoint(x: 0.45, y: 0.3)
                ], closed: true, order: 4),

                // Eyes
                DrawingPath(points: [
                    CGPoint(x: 0.47, y: 0.3),
                    CGPoint(x: 0.48, y: 0.3)
                ], closed: false, order: 5),

                DrawingPath(points: [
                    CGPoint(x: 0.52, y: 0.3),
                    CGPoint(x: 0.53, y: 0.3)
                ], closed: false, order: 6),

                // Beak
                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.32),
                    CGPoint(x: 0.48, y: 0.34),
                    CGPoint(x: 0.52, y: 0.34)
                ], closed: true, order: 7),

                // Flippers (wings)
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.48),
                    CGPoint(x: 0.35, y: 0.5),
                    CGPoint(x: 0.32, y: 0.48)
                ], closed: false, order: 8),

                DrawingPath(points: [
                    CGPoint(x: 0.58, y: 0.48),
                    CGPoint(x: 0.65, y: 0.5),
                    CGPoint(x: 0.68, y: 0.48)
                ], closed: false, order: 9),

                // Feet on board
                DrawingPath(points: [
                    CGPoint(x: 0.46, y: 0.6),
                    CGPoint(x: 0.45, y: 0.64)
                ], closed: false, order: 10),

                DrawingPath(points: [
                    CGPoint(x: 0.54, y: 0.6),
                    CGPoint(x: 0.55, y: 0.64)
                ], closed: false, order: 11),

                // Wave lines
                DrawingPath(points: [
                    CGPoint(x: 0.15, y: 0.75),
                    CGPoint(x: 0.18, y: 0.78),
                    CGPoint(x: 0.22, y: 0.75)
                ], closed: false, order: 12),

                DrawingPath(points: [
                    CGPoint(x: 0.78, y: 0.75),
                    CGPoint(x: 0.82, y: 0.78),
                    CGPoint(x: 0.85, y: 0.75)
                ], closed: false, order: 13)
            ],
            preferredShape: .elongated
        )
    }

    static func createFlyingSaucer() -> DrawingConcept {
        DrawingConcept(
            name: "Flying Saucer",
            paths: [
                // Bottom dish
                DrawingPath(points: [
                    CGPoint(x: 0.2, y: 0.55),
                    CGPoint(x: 0.8, y: 0.55),
                    CGPoint(x: 0.75, y: 0.62),
                    CGPoint(x: 0.25, y: 0.62)
                ], closed: true, order: 1),

                // Top dome
                DrawingPath(points: [
                    CGPoint(x: 0.35, y: 0.55),
                    CGPoint(x: 0.65, y: 0.55),
                    CGPoint(x: 0.6, y: 0.45),
                    CGPoint(x: 0.5, y: 0.4),
                    CGPoint(x: 0.4, y: 0.45)
                ], closed: true, order: 2),

                // Alien inside
                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.5),
                    CGPoint(x: 0.55, y: 0.5),
                    CGPoint(x: 0.54, y: 0.48),
                    CGPoint(x: 0.5, y: 0.46),
                    CGPoint(x: 0.46, y: 0.48)
                ], closed: true, order: 3),

                // Alien eyes
                DrawingPath(points: [
                    CGPoint(x: 0.48, y: 0.48),
                    CGPoint(x: 0.49, y: 0.48)
                ], closed: false, order: 4),

                DrawingPath(points: [
                    CGPoint(x: 0.51, y: 0.48),
                    CGPoint(x: 0.52, y: 0.48)
                ], closed: false, order: 5),

                // Lights on bottom
                DrawingPath(points: [
                    CGPoint(x: 0.3, y: 0.6),
                    CGPoint(x: 0.32, y: 0.6),
                    CGPoint(x: 0.32, y: 0.59),
                    CGPoint(x: 0.3, y: 0.59)
                ], closed: true, order: 6),

                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.6),
                    CGPoint(x: 0.47, y: 0.6),
                    CGPoint(x: 0.47, y: 0.59),
                    CGPoint(x: 0.45, y: 0.59)
                ], closed: true, order: 7),

                DrawingPath(points: [
                    CGPoint(x: 0.53, y: 0.6),
                    CGPoint(x: 0.55, y: 0.6),
                    CGPoint(x: 0.55, y: 0.59),
                    CGPoint(x: 0.53, y: 0.59)
                ], closed: true, order: 8),

                DrawingPath(points: [
                    CGPoint(x: 0.68, y: 0.6),
                    CGPoint(x: 0.7, y: 0.6),
                    CGPoint(x: 0.7, y: 0.59),
                    CGPoint(x: 0.68, y: 0.59)
                ], closed: true, order: 9),

                // Light beams
                DrawingPath(points: [
                    CGPoint(x: 0.31, y: 0.62),
                    CGPoint(x: 0.28, y: 0.7)
                ], closed: false, order: 10),

                DrawingPath(points: [
                    CGPoint(x: 0.46, y: 0.62),
                    CGPoint(x: 0.43, y: 0.7)
                ], closed: false, order: 11),

                DrawingPath(points: [
                    CGPoint(x: 0.54, y: 0.62),
                    CGPoint(x: 0.57, y: 0.7)
                ], closed: false, order: 12),

                DrawingPath(points: [
                    CGPoint(x: 0.69, y: 0.62),
                    CGPoint(x: 0.72, y: 0.7)
                ], closed: false, order: 13)
            ],
            preferredShape: .wide
        )
    }

    static func createWhaleWithUmbrella() -> DrawingConcept {
        DrawingConcept(
            name: "Whale with Umbrella",
            paths: [
                // Whale body
                DrawingPath(points: [
                    CGPoint(x: 0.3, y: 0.55),
                    CGPoint(x: 0.7, y: 0.55),
                    CGPoint(x: 0.75, y: 0.58),
                    CGPoint(x: 0.78, y: 0.65),
                    CGPoint(x: 0.75, y: 0.68),
                    CGPoint(x: 0.3, y: 0.68),
                    CGPoint(x: 0.25, y: 0.62)
                ], closed: true, order: 1),

                // Eye
                DrawingPath(points: [
                    CGPoint(x: 0.32, y: 0.6),
                    CGPoint(x: 0.33, y: 0.6)
                ], closed: false, order: 2),

                // Smile
                DrawingPath(points: [
                    CGPoint(x: 0.28, y: 0.63),
                    CGPoint(x: 0.3, y: 0.64),
                    CGPoint(x: 0.32, y: 0.63)
                ], closed: false, order: 3),

                // Tail
                DrawingPath(points: [
                    CGPoint(x: 0.75, y: 0.63),
                    CGPoint(x: 0.8, y: 0.6),
                    CGPoint(x: 0.82, y: 0.58)
                ], closed: false, order: 4),

                DrawingPath(points: [
                    CGPoint(x: 0.75, y: 0.63),
                    CGPoint(x: 0.8, y: 0.66),
                    CGPoint(x: 0.82, y: 0.68)
                ], closed: false, order: 5),

                // Umbrella handle
                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.55),
                    CGPoint(x: 0.5, y: 0.35)
                ], closed: false, order: 6),

                // Umbrella top
                DrawingPath(points: [
                    CGPoint(x: 0.35, y: 0.35),
                    CGPoint(x: 0.4, y: 0.3),
                    CGPoint(x: 0.45, y: 0.28),
                    CGPoint(x: 0.5, y: 0.27),
                    CGPoint(x: 0.55, y: 0.28),
                    CGPoint(x: 0.6, y: 0.3),
                    CGPoint(x: 0.65, y: 0.35)
                ], closed: false, order: 7),

                // Umbrella segments
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.29),
                    CGPoint(x: 0.44, y: 0.33)
                ], closed: false, order: 8),

                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.27),
                    CGPoint(x: 0.5, y: 0.32)
                ], closed: false, order: 9),

                DrawingPath(points: [
                    CGPoint(x: 0.58, y: 0.29),
                    CGPoint(x: 0.56, y: 0.33)
                ], closed: false, order: 10),

                // Water spout
                DrawingPath(points: [
                    CGPoint(x: 0.48, y: 0.55),
                    CGPoint(x: 0.47, y: 0.48),
                    CGPoint(x: 0.48, y: 0.42)
                ], closed: false, order: 11),

                DrawingPath(points: [
                    CGPoint(x: 0.52, y: 0.55),
                    CGPoint(x: 0.53, y: 0.48),
                    CGPoint(x: 0.52, y: 0.42)
                ], closed: false, order: 12)
            ],
            preferredShape: .wide
        )
    }

    static func createCloudCastle() -> DrawingConcept {
        DrawingConcept(
            name: "Cloud Castle",
            paths: [
                // Base
                DrawingPath(points: [
                    CGPoint(x: 0.25, y: 0.65),
                    CGPoint(x: 0.75, y: 0.65),
                    CGPoint(x: 0.75, y: 0.75),
                    CGPoint(x: 0.25, y: 0.75)
                ], closed: true, order: 1),

                // Left tower
                DrawingPath(points: [
                    CGPoint(x: 0.25, y: 0.65),
                    CGPoint(x: 0.35, y: 0.65),
                    CGPoint(x: 0.35, y: 0.45),
                    CGPoint(x: 0.25, y: 0.45)
                ], closed: true, order: 2),

                // Right tower
                DrawingPath(points: [
                    CGPoint(x: 0.65, y: 0.65),
                    CGPoint(x: 0.75, y: 0.65),
                    CGPoint(x: 0.75, y: 0.45),
                    CGPoint(x: 0.65, y: 0.45)
                ], closed: true, order: 3),

                // Center tower (taller)
                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.65),
                    CGPoint(x: 0.55, y: 0.65),
                    CGPoint(x: 0.55, y: 0.35),
                    CGPoint(x: 0.45, y: 0.35)
                ], closed: true, order: 4),

                // Left tower top
                DrawingPath(points: [
                    CGPoint(x: 0.23, y: 0.45),
                    CGPoint(x: 0.3, y: 0.38),
                    CGPoint(x: 0.37, y: 0.45)
                ], closed: true, order: 5),

                // Right tower top
                DrawingPath(points: [
                    CGPoint(x: 0.63, y: 0.45),
                    CGPoint(x: 0.7, y: 0.38),
                    CGPoint(x: 0.77, y: 0.45)
                ], closed: true, order: 6),

                // Center tower top
                DrawingPath(points: [
                    CGPoint(x: 0.43, y: 0.35),
                    CGPoint(x: 0.5, y: 0.28),
                    CGPoint(x: 0.57, y: 0.35)
                ], closed: true, order: 7),

                // Flags
                DrawingPath(points: [
                    CGPoint(x: 0.3, y: 0.38),
                    CGPoint(x: 0.3, y: 0.32),
                    CGPoint(x: 0.33, y: 0.34),
                    CGPoint(x: 0.3, y: 0.36)
                ], closed: false, order: 8),

                DrawingPath(points: [
                    CGPoint(x: 0.7, y: 0.38),
                    CGPoint(x: 0.7, y: 0.32),
                    CGPoint(x: 0.73, y: 0.34),
                    CGPoint(x: 0.7, y: 0.36)
                ], closed: false, order: 9),

                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.28),
                    CGPoint(x: 0.5, y: 0.22),
                    CGPoint(x: 0.53, y: 0.24),
                    CGPoint(x: 0.5, y: 0.26)
                ], closed: false, order: 10),

                // Windows
                DrawingPath(points: [
                    CGPoint(x: 0.28, y: 0.52),
                    CGPoint(x: 0.32, y: 0.52),
                    CGPoint(x: 0.32, y: 0.56),
                    CGPoint(x: 0.28, y: 0.56)
                ], closed: true, order: 11),

                DrawingPath(points: [
                    CGPoint(x: 0.68, y: 0.52),
                    CGPoint(x: 0.72, y: 0.52),
                    CGPoint(x: 0.72, y: 0.56),
                    CGPoint(x: 0.68, y: 0.56)
                ], closed: true, order: 12),

                DrawingPath(points: [
                    CGPoint(x: 0.48, y: 0.42),
                    CGPoint(x: 0.52, y: 0.42),
                    CGPoint(x: 0.52, y: 0.46),
                    CGPoint(x: 0.48, y: 0.46)
                ], closed: true, order: 13),

                // Door
                DrawingPath(points: [
                    CGPoint(x: 0.47, y: 0.65),
                    CGPoint(x: 0.53, y: 0.65),
                    CGPoint(x: 0.53, y: 0.72),
                    CGPoint(x: 0.47, y: 0.72)
                ], closed: true, order: 14)
            ],
            preferredShape: .wide
        )
    }

    static func createGiraffeInScarf() -> DrawingConcept {
        DrawingConcept(
            name: "Giraffe in Scarf",
            paths: [
                // Body
                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.6),
                    CGPoint(x: 0.6, y: 0.6),
                    CGPoint(x: 0.62, y: 0.75),
                    CGPoint(x: 0.38, y: 0.75)
                ], closed: true, order: 1),

                // Long neck
                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.6),
                    CGPoint(x: 0.55, y: 0.6),
                    CGPoint(x: 0.53, y: 0.3),
                    CGPoint(x: 0.47, y: 0.3)
                ], closed: true, order: 2),

                // Head
                DrawingPath(points: [
                    CGPoint(x: 0.44, y: 0.3),
                    CGPoint(x: 0.56, y: 0.3),
                    CGPoint(x: 0.57, y: 0.25),
                    CGPoint(x: 0.56, y: 0.2),
                    CGPoint(x: 0.44, y: 0.2),
                    CGPoint(x: 0.43, y: 0.25)
                ], closed: true, order: 3),

                // Ossicones (horns)
                DrawingPath(points: [
                    CGPoint(x: 0.46, y: 0.2),
                    CGPoint(x: 0.46, y: 0.15),
                    CGPoint(x: 0.48, y: 0.15)
                ], closed: false, order: 4),

                DrawingPath(points: [
                    CGPoint(x: 0.54, y: 0.2),
                    CGPoint(x: 0.54, y: 0.15),
                    CGPoint(x: 0.52, y: 0.15)
                ], closed: false, order: 5),

                // Eyes
                DrawingPath(points: [
                    CGPoint(x: 0.47, y: 0.24),
                    CGPoint(x: 0.48, y: 0.24)
                ], closed: false, order: 6),

                DrawingPath(points: [
                    CGPoint(x: 0.52, y: 0.24),
                    CGPoint(x: 0.53, y: 0.24)
                ], closed: false, order: 7),

                // Nose
                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.27),
                    CGPoint(x: 0.49, y: 0.28),
                    CGPoint(x: 0.51, y: 0.28)
                ], closed: true, order: 8),

                // Scarf wrapped around neck
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.45),
                    CGPoint(x: 0.58, y: 0.45),
                    CGPoint(x: 0.58, y: 0.5),
                    CGPoint(x: 0.42, y: 0.5)
                ], closed: true, order: 9),

                // Scarf stripes
                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.45),
                    CGPoint(x: 0.45, y: 0.5)
                ], closed: false, order: 10),

                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.45),
                    CGPoint(x: 0.5, y: 0.5)
                ], closed: false, order: 11),

                DrawingPath(points: [
                    CGPoint(x: 0.55, y: 0.45),
                    CGPoint(x: 0.55, y: 0.5)
                ], closed: false, order: 12),

                // Scarf ends hanging
                DrawingPath(points: [
                    CGPoint(x: 0.43, y: 0.5),
                    CGPoint(x: 0.4, y: 0.55),
                    CGPoint(x: 0.38, y: 0.58)
                ], closed: false, order: 13),

                DrawingPath(points: [
                    CGPoint(x: 0.57, y: 0.5),
                    CGPoint(x: 0.6, y: 0.55),
                    CGPoint(x: 0.62, y: 0.58)
                ], closed: false, order: 14),

                // Spots on body
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.65),
                    CGPoint(x: 0.44, y: 0.65),
                    CGPoint(x: 0.44, y: 0.67),
                    CGPoint(x: 0.42, y: 0.67)
                ], closed: true, order: 15),

                DrawingPath(points: [
                    CGPoint(x: 0.56, y: 0.68),
                    CGPoint(x: 0.58, y: 0.68),
                    CGPoint(x: 0.58, y: 0.7),
                    CGPoint(x: 0.56, y: 0.7)
                ], closed: true, order: 16),

                // Legs
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.75),
                    CGPoint(x: 0.42, y: 0.85)
                ], closed: false, order: 17),

                DrawingPath(points: [
                    CGPoint(x: 0.48, y: 0.75),
                    CGPoint(x: 0.48, y: 0.85)
                ], closed: false, order: 18),

                DrawingPath(points: [
                    CGPoint(x: 0.52, y: 0.75),
                    CGPoint(x: 0.52, y: 0.85)
                ], closed: false, order: 19),

                DrawingPath(points: [
                    CGPoint(x: 0.58, y: 0.75),
                    CGPoint(x: 0.58, y: 0.85)
                ], closed: false, order: 20)
            ],
            preferredShape: .tall
        )
    }

    static func createRocketShip() -> DrawingConcept {
        DrawingConcept(
            name: "Rocket Ship",
            paths: [
                // Main body
                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.7),
                    CGPoint(x: 0.6, y: 0.7),
                    CGPoint(x: 0.6, y: 0.35),
                    CGPoint(x: 0.4, y: 0.35)
                ], closed: true, order: 1),

                // Nose cone
                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.35),
                    CGPoint(x: 0.5, y: 0.2),
                    CGPoint(x: 0.6, y: 0.35)
                ], closed: true, order: 2),

                // Window (porthole)
                DrawingPath(points: [
                    CGPoint(x: 0.46, y: 0.42),
                    CGPoint(x: 0.54, y: 0.42),
                    CGPoint(x: 0.54, y: 0.5),
                    CGPoint(x: 0.46, y: 0.5)
                ], closed: true, order: 3),

                // Astronaut in window
                DrawingPath(points: [
                    CGPoint(x: 0.48, y: 0.44),
                    CGPoint(x: 0.52, y: 0.44),
                    CGPoint(x: 0.52, y: 0.47),
                    CGPoint(x: 0.48, y: 0.47)
                ], closed: true, order: 4),

                // Happy face
                DrawingPath(points: [
                    CGPoint(x: 0.49, y: 0.45),
                    CGPoint(x: 0.51, y: 0.45)
                ], closed: false, order: 5),

                DrawingPath(points: [
                    CGPoint(x: 0.49, y: 0.46),
                    CGPoint(x: 0.5, y: 0.465),
                    CGPoint(x: 0.51, y: 0.46)
                ], closed: false, order: 6),

                // Left fin
                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.7),
                    CGPoint(x: 0.3, y: 0.8),
                    CGPoint(x: 0.4, y: 0.75)
                ], closed: true, order: 7),

                // Right fin
                DrawingPath(points: [
                    CGPoint(x: 0.6, y: 0.7),
                    CGPoint(x: 0.7, y: 0.8),
                    CGPoint(x: 0.6, y: 0.75)
                ], closed: true, order: 8),

                // Flames
                DrawingPath(points: [
                    CGPoint(x: 0.42, y: 0.7),
                    CGPoint(x: 0.4, y: 0.75),
                    CGPoint(x: 0.42, y: 0.8),
                    CGPoint(x: 0.4, y: 0.85)
                ], closed: false, order: 9),

                DrawingPath(points: [
                    CGPoint(x: 0.48, y: 0.7),
                    CGPoint(x: 0.47, y: 0.76),
                    CGPoint(x: 0.48, y: 0.82),
                    CGPoint(x: 0.47, y: 0.88)
                ], closed: false, order: 10),

                DrawingPath(points: [
                    CGPoint(x: 0.52, y: 0.7),
                    CGPoint(x: 0.53, y: 0.76),
                    CGPoint(x: 0.52, y: 0.82),
                    CGPoint(x: 0.53, y: 0.88)
                ], closed: false, order: 11),

                DrawingPath(points: [
                    CGPoint(x: 0.58, y: 0.7),
                    CGPoint(x: 0.6, y: 0.75),
                    CGPoint(x: 0.58, y: 0.8),
                    CGPoint(x: 0.6, y: 0.85)
                ], closed: false, order: 12),

                // Stars around rocket
                DrawingPath(points: [
                    CGPoint(x: 0.25, y: 0.3),
                    CGPoint(x: 0.26, y: 0.32),
                    CGPoint(x: 0.24, y: 0.32)
                ], closed: false, order: 13),

                DrawingPath(points: [
                    CGPoint(x: 0.75, y: 0.4),
                    CGPoint(x: 0.76, y: 0.42),
                    CGPoint(x: 0.74, y: 0.42)
                ], closed: false, order: 14),

                DrawingPath(points: [
                    CGPoint(x: 0.72, y: 0.25),
                    CGPoint(x: 0.73, y: 0.27),
                    CGPoint(x: 0.71, y: 0.27)
                ], closed: false, order: 15)
            ],
            preferredShape: .tall
        )
    }

    static func createIceCreamCone() -> DrawingConcept {
        DrawingConcept(
            name: "Ice Cream Cone",
            paths: [
                // Cone
                DrawingPath(points: [
                    CGPoint(x: 0.35, y: 0.5),
                    CGPoint(x: 0.65, y: 0.5),
                    CGPoint(x: 0.5, y: 0.85)
                ], closed: true, order: 1),

                // Waffle pattern
                DrawingPath(points: [
                    CGPoint(x: 0.4, y: 0.55),
                    CGPoint(x: 0.6, y: 0.7)
                ], closed: false, order: 2),

                DrawingPath(points: [
                    CGPoint(x: 0.6, y: 0.55),
                    CGPoint(x: 0.4, y: 0.7)
                ], closed: false, order: 3),

                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.5),
                    CGPoint(x: 0.52, y: 0.77)
                ], closed: false, order: 4),

                DrawingPath(points: [
                    CGPoint(x: 0.55, y: 0.5),
                    CGPoint(x: 0.48, y: 0.77)
                ], closed: false, order: 5),

                // Ice cream scoops (bottom)
                DrawingPath(points: [
                    CGPoint(x: 0.35, y: 0.5),
                    CGPoint(x: 0.32, y: 0.45),
                    CGPoint(x: 0.35, y: 0.4),
                    CGPoint(x: 0.5, y: 0.38),
                    CGPoint(x: 0.65, y: 0.4),
                    CGPoint(x: 0.68, y: 0.45),
                    CGPoint(x: 0.65, y: 0.5)
                ], closed: true, order: 6),

                // Ice cream scoops (middle)
                DrawingPath(points: [
                    CGPoint(x: 0.37, y: 0.4),
                    CGPoint(x: 0.34, y: 0.35),
                    CGPoint(x: 0.37, y: 0.3),
                    CGPoint(x: 0.5, y: 0.28),
                    CGPoint(x: 0.63, y: 0.3),
                    CGPoint(x: 0.66, y: 0.35),
                    CGPoint(x: 0.63, y: 0.4)
                ], closed: true, order: 7),

                // Ice cream scoops (top)
                DrawingPath(points: [
                    CGPoint(x: 0.39, y: 0.3),
                    CGPoint(x: 0.36, y: 0.25),
                    CGPoint(x: 0.39, y: 0.2),
                    CGPoint(x: 0.5, y: 0.18),
                    CGPoint(x: 0.61, y: 0.2),
                    CGPoint(x: 0.64, y: 0.25),
                    CGPoint(x: 0.61, y: 0.3)
                ], closed: true, order: 8),

                // Happy face on ice cream
                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.43),
                    CGPoint(x: 0.46, y: 0.43)
                ], closed: false, order: 9),

                DrawingPath(points: [
                    CGPoint(x: 0.54, y: 0.43),
                    CGPoint(x: 0.55, y: 0.43)
                ], closed: false, order: 10),

                DrawingPath(points: [
                    CGPoint(x: 0.45, y: 0.46),
                    CGPoint(x: 0.5, y: 0.48),
                    CGPoint(x: 0.55, y: 0.46)
                ], closed: false, order: 11),

                // Cherry on top
                DrawingPath(points: [
                    CGPoint(x: 0.48, y: 0.18),
                    CGPoint(x: 0.52, y: 0.18),
                    CGPoint(x: 0.52, y: 0.15),
                    CGPoint(x: 0.48, y: 0.15)
                ], closed: true, order: 12),

                // Cherry stem
                DrawingPath(points: [
                    CGPoint(x: 0.5, y: 0.15),
                    CGPoint(x: 0.51, y: 0.12),
                    CGPoint(x: 0.52, y: 0.1)
                ], closed: false, order: 13)
            ],
            preferredShape: .tall
        )
    }
}
