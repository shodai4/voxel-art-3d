import SwiftUI
import UIKit

/// 3面のどれを編集しているか。
enum VoxelFace: String, CaseIterable, Identifiable {
    case front
    case side
    case top

    var id: String { rawValue }

    var title: String {
        switch self {
        case .front: return "正面"
        case .side: return "横"
        case .top: return "上"
        }
    }

    /// 図の向きの説明。描いた形と立体の向きがずれないように出す。
    var hint: String {
        switch self {
        case .front: return "正面から見た図"
        case .side: return "左から見た図（右が正面）"
        case .top: return "真上から見た図（下が正面）"
        }
    }
}

/// 塗れる色。
/// SwiftUI の Color をそのまま持つと、明暗の設定で同じ色の比較がぶれるので数値で持つ。
struct VoxelColor: Equatable, Hashable, Identifiable {
    let id: String
    let red: Double
    let green: Double
    let blue: Double

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }

    var uiColor: UIColor {
        UIColor(red: CGFloat(red), green: CGFloat(green), blue: CGFloat(blue), alpha: 1)
    }

    var name: String {
        switch id {
        case "blue": return "青"
        case "red": return "赤"
        case "green": return "緑"
        case "yellow": return "黄"
        case "orange": return "オレンジ"
        default: return "色"
        }
    }

    static let palette: [VoxelColor] = [
        VoxelColor(id: "blue", red: 0.16, green: 0.42, blue: 0.94),
        VoxelColor(id: "red", red: 0.90, green: 0.24, blue: 0.24),
        VoxelColor(id: "green", red: 0.20, green: 0.66, blue: 0.38),
        VoxelColor(id: "yellow", red: 0.96, green: 0.79, blue: 0.18),
        VoxelColor(id: "orange", red: 0.95, green: 0.52, blue: 0.14)
    ]
}

/// 1面ぶんのマス目。未塗りのマスは `nil` で持つので、色と「塗っていない状態」を取り違えない。
struct VoxelGrid: Equatable {
    let size: Int
    private var cells: [VoxelColor?]

    init(size: Int) {
        self.size = size
        self.cells = Array(repeating: nil, count: size * size)
    }

    subscript(row: Int, column: Int) -> VoxelColor? {
        get {
            guard let index = index(row, column) else { return nil }
            return cells[index]
        }
        set {
            guard let index = index(row, column) else { return }
            cells[index] = newValue
        }
    }

    var isEmpty: Bool {
        cells.allSatisfy { $0 == nil }
    }

    var paintedCount: Int {
        cells.reduce(into: 0) { count, color in
            if color != nil { count += 1 }
        }
    }

    mutating func clear() {
        cells = Array(repeating: nil, count: size * size)
    }

    /// 左上をそろえてサイズを変える。広げた分は未塗り、狭めた分は切り落とす。
    func resized(to newSize: Int) -> VoxelGrid {
        guard newSize != size else { return self }
        var result = VoxelGrid(size: newSize)
        let limit = min(size, newSize)
        for row in 0..<limit {
            for column in 0..<limit {
                result[row, column] = self[row, column]
            }
        }
        return result
    }

    private func index(_ row: Int, _ column: Int) -> Int? {
        guard (0..<size).contains(row), (0..<size).contains(column) else { return nil }
        return row * size + column
    }
}

/// 3面ぶんのマス目と、Pro の状態を持つ。
final class VoxelDocument: ObservableObject {
    static let freeSize = 10
    static let proSize = 16

    @Published var front: VoxelGrid
    @Published var side: VoxelGrid
    @Published var top: VoxelGrid
    @Published var isPro: Bool = false

    init(size: Int = VoxelDocument.freeSize) {
        front = VoxelGrid(size: size)
        side = VoxelGrid(size: size)
        top = VoxelGrid(size: size)
    }

    var size: Int { front.size }

    var isEmpty: Bool {
        front.isEmpty && side.isEmpty && top.isEmpty
    }

    var totalPainted: Int {
        front.paintedCount + side.paintedCount + top.paintedCount
    }

    func grid(for face: VoxelFace) -> VoxelGrid {
        switch face {
        case .front: return front
        case .side: return side
        case .top: return top
        }
    }

    func color(_ face: VoxelFace, row: Int, column: Int) -> VoxelColor? {
        grid(for: face)[row, column]
    }

    func paint(_ color: VoxelColor?, face: VoxelFace, row: Int, column: Int) {
        switch face {
        case .front: front[row, column] = color
        case .side: side[row, column] = color
        case .top: top[row, column] = color
        }
    }

    func clear(_ face: VoxelFace) {
        switch face {
        case .front: front.clear()
        case .side: side.clear()
        case .top: top.clear()
        }
    }

    func clearAll() {
        front.clear()
        side.clear()
        top.clear()
    }

    func resize(to size: Int) {
        guard size != self.size else { return }
        front = front.resized(to: size)
        side = side.resized(to: size)
        top = top.resized(to: size)
    }
}
