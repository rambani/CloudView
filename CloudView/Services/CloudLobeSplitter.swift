import Foundation
import CoreGraphics

/// A small grayscale grid (0…1), row-major, top row first.
struct GrayGrid {
    let width: Int
    let height: Int
    var pixels: [Float]

    init(width: Int, height: Int, pixels: [Float]) {
        self.width = width
        self.height = height
        self.pixels = pixels
    }

    var count: Int { width * height }
}

/// Splits one big cloud blob into the lobes the eye sees — a bulbous
/// head-puff, a tower, a long body — using the brightness field itself.
/// Twin of `tools/cloud_lobes.py`; keep the constants in sync.
///
///   1. smooth the whiteness map (box blur twice ≈ gaussian)
///   2. peaks: local maxima inside the blob, non-max suppressed over a radius
///   3. marker watershed: flood from the peaks by decreasing brightness
///   4. merge lobes whose shared valley is shallow
///   5. fold tiny lobes into their largest neighbor; trace each outline
///
/// Pure Swift on a ~256-px grid (~50k pixels), well under a frame.
enum CloudLobeSplitter {
    static let smoothRadiusFraction: Float = 0.025
    static let peakMinDistanceFraction: Float = 0.09
    /// The saddle between two peaks must sit at least this far (as a
    /// fraction) below the dimmer peak, or the two lobes are one.
    static let minValleyDepth: Float = 0.10
    /// Lobes smaller than this fraction of the blob fold into a neighbor.
    static let minLobeAreaFraction: Float = 0.12
    static let maxOutlinePoints = 100

    struct Lobe {
        /// Ordered outline in grid pixel coordinates (y-down).
        let outline: [CGPoint]
        let area: Int
        let peakValue: Float
        /// Top of the bright mass: straight up from the brightest pixel
        /// while brightness stays within `summitFalloff` of the peak. A
        /// thin wisp attached above the mass is dimmer, so the climb stops
        /// below it — the right place to stand a companion.
        let summit: CGPoint
    }

    /// Climb stops when the field drops below this fraction of the peak.
    static let summitFalloff: Float = 0.8

    static func summit(_ field: [Float], width w: Int, height h: Int, labels: [Int], label: Int) -> CGPoint {
        var best = -1, bestValue: Float = -1
        for i in 0..<labels.count where labels[i] == label && field[i] > bestValue {
            best = i; bestValue = field[i]
        }
        guard best >= 0 else { return .zero }
        let x = best % w
        var y = best / w
        let floor = bestValue * summitFalloff
        while y > 0, labels[(y - 1) * w + x] == label, field[(y - 1) * w + x] >= floor {
            y -= 1
        }
        return CGPoint(x: x, y: y)
    }

    struct Peak {
        let value: Float
        let x: Int
        let y: Int
    }

    // MARK: - Smoothing

    static func boxBlur(_ img: [Float], width w: Int, height h: Int, radius r: Int) -> [Float] {
        guard r >= 1, w > 0, h > 0 else { return img }
        var tmp = [Float](repeating: 0, count: w * h)
        var out = [Float](repeating: 0, count: w * h)
        for y in 0..<h {
            let row = y * w
            var acc: Float = 0
            for x in -r..<w {
                if x + r < w { acc += img[row + x + r] }
                if x - r - 1 >= 0 { acc -= img[row + x - r - 1] }
                if x >= 0 {
                    let lo = max(0, x - r), hi = min(w - 1, x + r)
                    tmp[row + x] = acc / Float(hi - lo + 1)
                }
            }
        }
        for x in 0..<w {
            var acc: Float = 0
            for y in -r..<h {
                if y + r < h { acc += tmp[(y + r) * w + x] }
                if y - r - 1 >= 0 { acc -= tmp[(y - r - 1) * w + x] }
                if y >= 0 {
                    let lo = max(0, y - r), hi = min(h - 1, y + r)
                    out[y * w + x] = acc / Float(hi - lo + 1)
                }
            }
        }
        return out
    }

    static func smooth(_ grid: GrayGrid) -> [Float] {
        let r = max(1, Int((Float(grid.width) * smoothRadiusFraction).rounded()))
        return boxBlur(boxBlur(grid.pixels, width: grid.width, height: grid.height, radius: r),
                       width: grid.width, height: grid.height, radius: r)
    }

    // MARK: - Peaks

    static func findPeaks(_ field: [Float], width w: Int, height h: Int, mask: [Bool], minDistance: Float) -> [Peak] {
        var candidates: [Peak] = []
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                guard mask[i] else { continue }
                let v = field[i]
                var isMax = true
                outer: for dy in -1...1 {
                    for dx in -1...1 where !(dx == 0 && dy == 0) {
                        let nx = x + dx, ny = y + dy
                        if nx >= 0, nx < w, ny >= 0, ny < h, field[ny * w + nx] > v {
                            isMax = false
                            break outer
                        }
                    }
                }
                if isMax { candidates.append(Peak(value: v, x: x, y: y)) }
            }
        }
        candidates.sort { $0.value > $1.value }
        var peaks: [Peak] = []
        for c in candidates {
            let farEnough = peaks.allSatisfy { p in
                let dx = Float(c.x - p.x), dy = Float(c.y - p.y)
                return (dx * dx + dy * dy).squareRoot() >= minDistance
            }
            if farEnough { peaks.append(c) }
        }
        return peaks
    }

    // MARK: - Watershed

    private struct MaxHeap {
        private var items: [(value: Float, index: Int)] = []
        var isEmpty: Bool { items.isEmpty }

        mutating func push(_ value: Float, _ index: Int) {
            items.append((value, index))
            var i = items.count - 1
            while i > 0 {
                let p = (i - 1) / 2
                if items[p].value >= items[i].value { break }
                items.swapAt(p, i)
                i = p
            }
        }

        mutating func pop() -> (value: Float, index: Int)? {
            guard let top = items.first else { return nil }
            let last = items.removeLast()
            if !items.isEmpty {
                items[0] = last
                var i = 0
                while true {
                    let l = 2 * i + 1, r = l + 1
                    var m = i
                    if l < items.count, items[l].value > items[m].value { m = l }
                    if r < items.count, items[r].value > items[m].value { m = r }
                    if m == i { break }
                    items.swapAt(m, i)
                    i = m
                }
            }
            return top
        }
    }

    /// Labels (0 = outside the mask), flooding from the peaks by decreasing
    /// brightness so every pixel joins the lobe that reaches it first.
    static func watershed(_ field: [Float], width w: Int, height h: Int, mask: [Bool], peaks: [Peak]) -> [Int] {
        var labels = [Int](repeating: 0, count: w * h)
        var heap = MaxHeap()
        for (k, p) in peaks.enumerated() {
            let i = p.y * w + p.x
            labels[i] = k + 1
            heap.push(p.value, i)
        }
        while let (_, i) = heap.pop() {
            let lab = labels[i]
            let x = i % w, y = i / w
            for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                let j = ny * w + nx
                if mask[j] && labels[j] == 0 {
                    labels[j] = lab
                    heap.push(field[j], j)
                }
            }
        }
        return labels
    }

    // MARK: - Merging

    /// Union lobes whose saddle is nearly as bright as the dimmer peak.
    static func mergeShallow(_ field: [Float], width w: Int, height h: Int, labels: [Int], peaks: [Peak]) -> [Int] {
        let n = peaks.count
        var saddle: [Int: Float] = [:] // key: a * (n+1) + b with a < b
        for y in 0..<h {
            for x in 0..<w {
                let i = y * w + x
                let a = labels[i]
                guard a != 0 else { continue }
                for (nx, ny) in [(x + 1, y), (x, y + 1)] where nx < w && ny < h {
                    let j = ny * w + nx
                    let b = labels[j]
                    guard b != 0, b != a else { continue }
                    let key = min(a, b) * (n + 1) + max(a, b)
                    let s = min(field[i], field[j])
                    if s > (saddle[key] ?? -1) { saddle[key] = s }
                }
            }
        }
        var parent = Array(0...n)
        func find(_ u: Int) -> Int {
            var u = u
            while parent[u] != u { parent[u] = parent[parent[u]]; u = parent[u] }
            return u
        }
        for (key, s) in saddle.sorted(by: { $0.value > $1.value }) {
            let a = key / (n + 1), b = key % (n + 1)
            let ra = find(a), rb = find(b)
            guard ra != rb else { continue }
            let dimmer = min(peaks[a - 1].value, peaks[b - 1].value)
            if s >= dimmer * (1 - minValleyDepth) { parent[rb] = ra }
        }
        return labels.map { $0 == 0 ? 0 : find($0) }
    }

    /// Fold lobes below `minArea` into the neighbor they touch most.
    static func mergeSmall(_ labels: [Int], width w: Int, height h: Int, minArea: Int) -> [Int] {
        var labels = labels
        while true {
            var areas: [Int: Int] = [:]
            for l in labels where l != 0 { areas[l, default: 0] += 1 }
            let small = areas.filter { $0.value < minArea }
            guard !small.isEmpty, areas.count > 1 else { return labels }
            let l = small.min { $0.value < $1.value }!.key
            var touch: [Int: Int] = [:]
            for y in 0..<h {
                for x in 0..<w where labels[y * w + x] == l {
                    for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)] {
                        guard nx >= 0, nx < w, ny >= 0, ny < h else { continue }
                        let b = labels[ny * w + nx]
                        if b != 0 && b != l { touch[b, default: 0] += 1 }
                    }
                }
            }
            if let target = touch.max(by: { $0.value < $1.value })?.key {
                labels = labels.map { $0 == l ? target : $0 }
            } else {
                labels = labels.map { $0 == l ? 0 : $0 } // isolated speck: drop
            }
        }
    }

    // MARK: - Outline

    /// Moore-neighbour boundary trace of one label, subsampled.
    static func traceOutline(_ labels: [Int], width w: Int, height h: Int, label: Int) -> [CGPoint] {
        var cells = Set<Int>()
        var start: (x: Int, y: Int)? = nil
        for y in 0..<h {
            for x in 0..<w where labels[y * w + x] == label {
                cells.insert(y * w + x)
                if start == nil { start = (x, y) } // first in row-major order = topmost-leftmost
            }
        }
        guard let s = start else { return [] }
        let nbrs = [(-1, 0), (-1, -1), (0, -1), (1, -1), (1, 0), (1, 1), (0, 1), (-1, 1)]
        var outline: [(Int, Int)] = [(s.x, s.y)]
        var cur = (s.x, s.y)
        var back = 0
        for _ in 0..<(cells.count * 4 + 8) {
            var found = false
            for k in 0..<8 {
                let idx = (back + k) % 8
                let nxt = (cur.0 + nbrs[idx].0, cur.1 + nbrs[idx].1)
                if nxt.0 >= 0, nxt.0 < w, nxt.1 >= 0, nxt.1 < h, cells.contains(nxt.1 * w + nxt.0) {
                    cur = nxt
                    back = (idx + 5) % 8
                    found = true
                    break
                }
            }
            if !found || (cur.0 == s.x && cur.1 == s.y) { break }
            outline.append(cur)
        }
        if outline.count > maxOutlinePoints {
            let step = Double(outline.count) / Double(maxOutlinePoints)
            outline = (0..<maxOutlinePoints).map { outline[Int(Double($0) * step)] }
        }
        return outline.map { CGPoint(x: $0.0, y: $0.1) }
    }

    // MARK: - Entry point

    /// Split the blob under `mask` (same size as the grid) into lobes,
    /// biggest first. One lobe (the whole mask) when it doesn't split.
    static func split(_ grid: GrayGrid, mask: [Bool]) -> [Lobe] {
        let w = grid.width, h = grid.height
        guard mask.count == grid.count else { return [] }
        let area = mask.reduce(0) { $0 + ($1 ? 1 : 0) }
        guard area > 0 else { return [] }
        let field = smooth(grid)
        let minDist = max(2, (Float(w) * peakMinDistanceFraction).rounded())
        let peaks = findPeaks(field, width: w, height: h, mask: mask, minDistance: minDist)

        if peaks.count <= 1 {
            let labels = mask.map { $0 ? 1 : 0 }
            let outline = traceOutline(labels, width: w, height: h, label: 1)
            guard outline.count >= 3 else { return [] }
            return [Lobe(outline: outline, area: area, peakValue: peaks.first?.value ?? 0,
                         summit: summit(field, width: w, height: h, labels: labels, label: 1))]
        }

        var labels = watershed(field, width: w, height: h, mask: mask, peaks: peaks)
        labels = mergeShallow(field, width: w, height: h, labels: labels, peaks: peaks)
        labels = mergeSmall(labels, width: w, height: h, minArea: Int(minLobeAreaFraction * Float(area)))

        var lobes: [Lobe] = []
        for l in Set(labels).subtracting([0]).sorted() {
            let outline = traceOutline(labels, width: w, height: h, label: l)
            guard outline.count >= 3 else { continue }
            var a = 0
            var peak: Float = 0
            for i in 0..<labels.count where labels[i] == l {
                a += 1
                peak = max(peak, field[i])
            }
            lobes.append(Lobe(outline: outline, area: a, peakValue: peak,
                              summit: summit(field, width: w, height: h, labels: labels, label: l)))
        }
        return lobes.sorted { $0.area > $1.area }
    }
}
