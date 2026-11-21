import SwiftUI

/// 10x10 のマス目に色を塗るためのデータ。
/// 未塗りのマスは `nil` で持つので、色と「塗っていない状態」を取り違えない。
struct VoxelGrid {
    static let size = 10

    private var cells: [Color?]

    init() {
        cells = Array(repeating: nil, count: VoxelGrid.size * VoxelGrid.size)
    }

    subscript(row: Int, column: Int) -> Color? {
        get {
            let i = index(row, column)
            guard cells.indices.contains(i) else { return nil }
            return cells[i]
        }
        set {
            let i = index(row, column)
            guard cells.indices.contains(i) else { return }
            cells[i] = newValue
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
        cells = Array(repeating: nil, count: VoxelGrid.size * VoxelGrid.size)
    }

    func forEachPainted(_ body: (_ row: Int, _ column: Int, _ color: Color) -> Void) {
        for row in 0..<VoxelGrid.size {
            for column in 0..<VoxelGrid.size {
                if let color = cells[index(row, column)] {
                    body(row, column, color)
                }
            }
        }
    }

    private func index(_ row: Int, _ column: Int) -> Int {
        row * VoxelGrid.size + column
    }
}

/// パレットの1色。消しゴムも同じ並びに入れて、選択状態を1つで扱う。
struct PaletteColor: Identifiable {
    let id: String
    let color: Color
    var isEraser: Bool = false

    static let defaults: [PaletteColor] = [
        PaletteColor(id: "blue", color: .blue),
        PaletteColor(id: "red", color: .red),
        PaletteColor(id: "green", color: .green),
        PaletteColor(id: "yellow", color: .yellow),
        PaletteColor(id: "orange", color: .orange),
        PaletteColor(id: "eraser", color: .clear, isEraser: true)
    ]
}
