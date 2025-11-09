import Foundation
import RealityKit
import MetalKit
import simd

class AnimatedDrawing {
    let concept: DrawingConcept
    let size: CGSize
    let duration: TimeInterval

    private var animationProgress: Float = 0.0
    private var isAnimating = false

    init(concept: DrawingConcept, size: CGSize, duration: TimeInterval) {
        self.concept = concept
        self.size = size
        self.duration = duration
    }

    func generateMesh() -> MeshResource {
        // Generate a mesh from the drawing paths
        // For now, we'll create a simple plane that will hold our line drawing

        let width = Float(size.width) * 0.01 // Scale to meters
        let height = Float(size.height) * 0.01

        // Create mesh descriptor
        var meshDescriptor = MeshDescriptor(name: concept.name)

        // Define vertices for a quad
        let positions: [simd_float3] = [
            [-width/2, -height/2, 0],  // Bottom-left
            [width/2, -height/2, 0],   // Bottom-right
            [width/2, height/2, 0],    // Top-right
            [-width/2, height/2, 0]    // Top-left
        ]

        let normals: [simd_float3] = [
            [0, 0, 1],
            [0, 0, 1],
            [0, 0, 1],
            [0, 0, 1]
        ]

        let uvs: [simd_float2] = [
            [0, 1],  // Bottom-left
            [1, 1],  // Bottom-right
            [1, 0],  // Top-right
            [0, 0]   // Top-left
        ]

        // Define triangle indices
        let indices: [UInt32] = [
            0, 1, 2,  // First triangle
            0, 2, 3   // Second triangle
        ]

        meshDescriptor.positions = MeshBuffer(positions)
        meshDescriptor.normals = MeshBuffer(normals)
        meshDescriptor.textureCoordinates = MeshBuffer(uvs)
        meshDescriptor.primitives = .triangles(indices)

        do {
            return try MeshResource.generate(from: [meshDescriptor])
        } catch {
            print("Failed to generate mesh: \(error)")
            return MeshResource.generateBox(size: [width, height, 0.01])
        }
    }

    func animate(entity: ModelEntity) {
        // Create animated line drawing effect
        isAnimating = true

        // Sort paths by order
        let sortedPaths = concept.paths.sorted { $0.order < $1.order }

        // Calculate time per path
        let timePerPath = duration / Double(sortedPaths.count)

        // Animate each path sequentially
        for (index, path) in sortedPaths.enumerated() {
            let delay = timePerPath * Double(index)
            animatePath(path, on: entity, delay: delay, duration: timePerPath)
        }
    }

    private func animatePath(_ path: DrawingConcept.DrawingPath, on entity: ModelEntity, delay: TimeInterval, duration: TimeInterval) {
        // Create line entities for this path
        let pathEntity = createPathEntity(path)

        // Position relative to parent
        pathEntity.position = [0, 0, 0.001] // Slightly in front

        // Add to entity after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            entity.addChild(pathEntity)

            // Animate the line drawing
            self.animateLineDrawing(pathEntity, path: path, duration: duration)
        }
    }

    private func createPathEntity(_ path: DrawingConcept.DrawingPath) -> ModelEntity {
        let entity = ModelEntity()

        // Create line mesh from path points
        let lineMesh = createLineMesh(from: path.points, closed: path.closed)

        // Create white material with slight glow
        var material = UnlitMaterial(color: .white)
        material.blending = .transparent(opacity: .init(floatLiteral: 0.95))

        entity.model = ModelComponent(mesh: lineMesh, materials: [material])

        // Start invisible (for animation)
        entity.scale = [0, 0, 0]

        return entity
    }

    private func createLineMesh(from points: [CGPoint], closed: Bool) -> MeshResource {
        guard points.count >= 2 else {
            return MeshResource.generateBox(size: 0.001)
        }

        var meshDescriptor = MeshDescriptor(name: "line")

        let lineWidth: Float = 0.003 // 3mm thick lines

        // Convert normalized points to 3D positions
        var positions: [simd_float3] = []
        var indices: [UInt32] = []

        // Create line segments
        for i in 0..<points.count - 1 {
            let p1 = points[i]
            let p2 = points[i + 1]

            // Convert normalized coordinates (0-1) to mesh space (-0.5 to 0.5)
            let pos1 = simd_float3(
                Float(p1.x - 0.5) * Float(size.width) * 0.01,
                Float(0.5 - p1.y) * Float(size.height) * 0.01,  // Flip Y
                0
            )
            let pos2 = simd_float3(
                Float(p2.x - 0.5) * Float(size.width) * 0.01,
                Float(0.5 - p2.y) * Float(size.height) * 0.01,  // Flip Y
                0
            )

            // Create a quad for this line segment
            let direction = normalize(pos2 - pos1)
            let perpendicular = simd_float3(-direction.y, direction.x, 0) * lineWidth / 2

            let baseIndex = UInt32(positions.count)

            // Four corners of the line quad
            positions.append(pos1 - perpendicular)
            positions.append(pos1 + perpendicular)
            positions.append(pos2 + perpendicular)
            positions.append(pos2 - perpendicular)

            // Two triangles for this segment
            indices.append(contentsOf: [
                baseIndex, baseIndex + 1, baseIndex + 2,
                baseIndex, baseIndex + 2, baseIndex + 3
            ])
        }

        // Close the path if needed
        if closed && points.count > 2 {
            let p1 = points[points.count - 1]
            let p2 = points[0]

            let pos1 = simd_float3(
                Float(p1.x - 0.5) * Float(size.width) * 0.01,
                Float(0.5 - p1.y) * Float(size.height) * 0.01,
                0
            )
            let pos2 = simd_float3(
                Float(p2.x - 0.5) * Float(size.width) * 0.01,
                Float(0.5 - p2.y) * Float(size.height) * 0.01,
                0
            )

            let direction = normalize(pos2 - pos1)
            let perpendicular = simd_float3(-direction.y, direction.x, 0) * lineWidth / 2

            let baseIndex = UInt32(positions.count)

            positions.append(pos1 - perpendicular)
            positions.append(pos1 + perpendicular)
            positions.append(pos2 + perpendicular)
            positions.append(pos2 - perpendicular)

            indices.append(contentsOf: [
                baseIndex, baseIndex + 1, baseIndex + 2,
                baseIndex, baseIndex + 2, baseIndex + 3
            ])
        }

        // Create normals (all pointing forward)
        let normals = positions.map { _ in simd_float3(0, 0, 1) }

        meshDescriptor.positions = MeshBuffer(positions)
        meshDescriptor.normals = MeshBuffer(normals)
        meshDescriptor.primitives = .triangles(indices)

        do {
            return try MeshResource.generate(from: [meshDescriptor])
        } catch {
            print("Failed to generate line mesh: \(error)")
            return MeshResource.generateBox(size: 0.001)
        }
    }

    private func animateLineDrawing(_ entity: ModelEntity, path: DrawingConcept.DrawingPath, duration: TimeInterval) {
        // Animate the line drawing from start to finish

        // Start: scale from 0 to 1
        let scaleAnimation = FromToByAnimation(
            name: "scaleIn",
            from: Transform(scale: [0, 0, 0]),
            to: Transform(scale: [1, 1, 1]),
            duration: duration * 0.3,
            timing: .easeOut,
            bindTarget: .transform
        )

        // Create animation resource
        if let animationResource = try? AnimationResource.generate(with: scaleAnimation) {
            entity.playAnimation(animationResource)
        }

        // Progressive reveal effect (simulated)
        // In a production app, you'd use custom shaders for true line-drawing effect
        let steps = 10
        let stepDuration = duration / Double(steps)

        for i in 0..<steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                let progress = Float(i + 1) / Float(steps)
                // Gradually increase opacity to simulate drawing
                if var material = entity.model?.materials.first as? UnlitMaterial {
                    material.blending = .transparent(opacity: .init(floatLiteral: Double(progress)))
                    entity.model?.materials = [material]
                }
            }
        }
    }

    // Alternative: Create a single combined mesh for all paths
    func generateCombinedMesh() -> MeshResource {
        var allPositions: [simd_float3] = []
        var allNormals: [simd_float3] = []
        var allIndices: [UInt32] = []

        let lineWidth: Float = 0.003

        for path in concept.paths {
            let points = path.points
            guard points.count >= 2 else { continue }

            for i in 0..<points.count - 1 {
                let p1 = points[i]
                let p2 = points[i + 1]

                let pos1 = simd_float3(
                    Float(p1.x - 0.5) * Float(size.width) * 0.01,
                    Float(0.5 - p1.y) * Float(size.height) * 0.01,
                    0
                )
                let pos2 = simd_float3(
                    Float(p2.x - 0.5) * Float(size.width) * 0.01,
                    Float(0.5 - p2.y) * Float(size.height) * 0.01,
                    0
                )

                let direction = normalize(pos2 - pos1)
                let perpendicular = simd_float3(-direction.y, direction.x, 0) * lineWidth / 2

                let baseIndex = UInt32(allPositions.count)

                allPositions.append(pos1 - perpendicular)
                allPositions.append(pos1 + perpendicular)
                allPositions.append(pos2 + perpendicular)
                allPositions.append(pos2 - perpendicular)

                allNormals.append(contentsOf: [
                    simd_float3(0, 0, 1),
                    simd_float3(0, 0, 1),
                    simd_float3(0, 0, 1),
                    simd_float3(0, 0, 1)
                ])

                allIndices.append(contentsOf: [
                    baseIndex, baseIndex + 1, baseIndex + 2,
                    baseIndex, baseIndex + 2, baseIndex + 3
                ])
            }

            // Close path if needed
            if path.closed && points.count > 2 {
                let p1 = points[points.count - 1]
                let p2 = points[0]

                let pos1 = simd_float3(
                    Float(p1.x - 0.5) * Float(size.width) * 0.01,
                    Float(0.5 - p1.y) * Float(size.height) * 0.01,
                    0
                )
                let pos2 = simd_float3(
                    Float(p2.x - 0.5) * Float(size.width) * 0.01,
                    Float(0.5 - p2.y) * Float(size.height) * 0.01,
                    0
                )

                let direction = normalize(pos2 - pos1)
                let perpendicular = simd_float3(-direction.y, direction.x, 0) * lineWidth / 2

                let baseIndex = UInt32(allPositions.count)

                allPositions.append(pos1 - perpendicular)
                allPositions.append(pos1 + perpendicular)
                allPositions.append(pos2 + perpendicular)
                allPositions.append(pos2 - perpendicular)

                allNormals.append(contentsOf: [
                    simd_float3(0, 0, 1),
                    simd_float3(0, 0, 1),
                    simd_float3(0, 0, 1),
                    simd_float3(0, 0, 1)
                ])

                allIndices.append(contentsOf: [
                    baseIndex, baseIndex + 1, baseIndex + 2,
                    baseIndex, baseIndex + 2, baseIndex + 3
                ])
            }
        }

        var meshDescriptor = MeshDescriptor(name: concept.name)
        meshDescriptor.positions = MeshBuffer(allPositions)
        meshDescriptor.normals = MeshBuffer(allNormals)
        meshDescriptor.primitives = .triangles(allIndices)

        do {
            return try MeshResource.generate(from: [meshDescriptor])
        } catch {
            print("Failed to generate combined mesh: \(error)")
            return MeshResource.generateBox(size: 0.001)
        }
    }
}
