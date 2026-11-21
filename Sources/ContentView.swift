import SwiftUI

struct ContentView: View {
    @State private var grid = VoxelGrid()
    @State private var selectedID = "blue"

    private let palette = PaletteColor.defaults

    private var selected: PaletteColor {
        palette.first(where: { $0.id == selectedID }) ?? palette[0]
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                paletteBar
                gridBoard
                statusLine
                Spacer(minLength: 0)
                previewLink
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .padding(.bottom, 12)
            .navigationTitle("ボクセルアート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("全消し") {
                        grid.clear()
                    }
                    .disabled(grid.isEmpty)
                }
            }
        }
    }

    private var paletteBar: some View {
        HStack(spacing: 8) {
            ForEach(palette) { item in
                swatch(item)
            }
        }
    }

    private func swatch(_ item: PaletteColor) -> some View {
        let isSelected = item.id == selectedID
        return ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(item.isEraser ? Color(white: 0.16) : item.color)
            if item.isEraser {
                Image(systemName: "eraser.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    isSelected ? Color.primary : Color.primary.opacity(0.12),
                    lineWidth: isSelected ? 2.5 : 1
                )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            selectedID = item.id
        }
        .accessibilityLabel(item.isEraser ? "消しゴム" : colorName(item.id))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var gridBoard: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 2
            let cellSize = (geometry.size.width - spacing * CGFloat(VoxelGrid.size - 1))
                / CGFloat(VoxelGrid.size)

            VStack(spacing: spacing) {
                ForEach(0..<VoxelGrid.size, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<VoxelGrid.size, id: \.self) { column in
                            cell(row: row, column: column)
                                .frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func cell(row: Int, column: Int) -> some View {
        let color = grid[row, column]
        return RoundedRectangle(cornerRadius: 2)
            .fill(color ?? Color(white: 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.primary.opacity(color == nil ? 0.10 : 0.0), lineWidth: 0.5)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                paint(row: row, column: column)
            }
    }

    private var statusLine: some View {
        HStack {
            Text("塗ったマス \(grid.paintedCount) / \(VoxelGrid.size * VoxelGrid.size)")
            Spacer()
            Text("同じ色をもう一度タップで消えます")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }

    private var previewLink: some View {
        NavigationLink {
            VoxelSceneView(grid: grid)
                .overlay(alignment: .bottom) {
                    if grid.isEmpty {
                        Text("まだ色が塗られていません")
                            .font(.footnote)
                            .foregroundStyle(Color.white.opacity(0.7))
                            .padding(.bottom, 16)
                    }
                }
                .navigationTitle("3Dプレビュー")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Text("ドラッグで回転")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
        } label: {
            Text("3Dで見る")
                .font(.headline)
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func paint(row: Int, column: Int) {
        if selected.isEraser {
            grid[row, column] = nil
        } else if grid[row, column] == selected.color {
            grid[row, column] = nil
        } else {
            grid[row, column] = selected.color
        }
    }

    private func colorName(_ id: String) -> String {
        switch id {
        case "blue": return "青"
        case "red": return "赤"
        case "green": return "緑"
        case "yellow": return "黄"
        case "orange": return "オレンジ"
        default: return "色"
        }
    }
}

#Preview {
    ContentView()
}
