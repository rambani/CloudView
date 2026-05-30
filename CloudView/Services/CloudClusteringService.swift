import Foundation
import CoreGraphics

/// Groups spatially-adjacent CloudShapes into CloudClusters so the
/// recognizer can see multi-cloud constellations as a single thing
/// ("those three clouds together look like a dragon") instead of always
/// treating clouds in isolation.
///
/// **Today**: returns one cluster per shape (no multi-cloud grouping
/// yet). The architecture is in place — the recognition pipeline,
/// rasterizer, and Hu-moments signature all already handle the cluster
/// type — so the upgrade is contained to this file.
///
/// **Next**: pair-distance union-find using screenPosition centers. The
/// threshold is best expressed relative to the larger cloud's
/// diameter; two clouds whose centers are within ~1.5× the larger
/// diameter merge into one cluster.
enum CloudClusteringService {

    /// Convert detected cloud shapes into clusters. Today: one cluster
    /// per shape. The signature on the cluster is the Hu signature of
    /// the (so far identical) combined contour.
    static func cluster(_ shapes: [CloudShape]) -> [CloudCluster] {
        shapes.map { shape in
            let normalized = shape.normalizedContour
            return CloudCluster(
                shapes: [shape],
                combinedContour: normalized,
                signature: CloudShapeSignature(contour: normalized)
            )
        }
    }
}
