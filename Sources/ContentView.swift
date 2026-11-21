import SwiftUI

struct ContentView: View {
    @StateObject private var document = VoxelDocument()
    @State private var brush: Brush = .color(VoxelColor.palette[0])
    @State private var face: VoxelFace = .front
    @State private var showPaywall = false
    @State private var showClearOptions = false

    private enum Brush: Equatable {
        case color(VoxelColor)
        case eraser
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                facePicker
                hintLine
                paletteBar
                gridBoard
                statusLine
                Spacer(minLength: 0)
                previewLink
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .navigationTitle("ボクセルアート")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    sizeMenu
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("全消し") {
                        showClearOptions = true
                    }
                    .disabled(document.isEmpty)
                }
            }
            .confirmationDialog("消す範囲を選ぶ", isPresented: $showClearOptions, titleVisibility: .visible) {
                Button("\(face.title)の面を消す", role: .destructive) {
                    document.clear(face)
                }
                Button("3面すべて消す", role: .destructive) {
                    document.clearAll()
                }
                Button("キャンセル", role: .cancel) {}
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
        }
    }

    private var facePicker: some View {
        Picker("面", selection: $face) {
            ForEach(VoxelFace.allCases) { item in
                Text(item.title).tag(item)
            }
        }
        .pickerStyle(.segmented)
    }

    private var hintLine: some View {
        HStack(spacing: 6) {
            Text(face.hint)
            Spacer()
            Text("\(document.size)×\(document.size)")
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var paletteBar: some View {
        HStack(spacing: 8) {
            ForEach(VoxelColor.palette) { item in
                swatch(for: .color(item), label: item.name) {
                    RoundedRectangle(cornerRadius: 8).fill(item.color)
                }
            }
            swatch(for: .eraser, label: "消しゴム") {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(white: 0.16))
                    Image(systemName: "eraser.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
            }
        }
    }

    private func swatch<Content: View>(
        for value: Brush,
        label: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        let isSelected = brush == value
        return content()
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        isSelected ? Color.primary : Color.primary.opacity(0.12),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            )
            .frame(maxWidth: .infinity)
            .frame(height: 36)
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                brush = value
            }
            .accessibilityLabel(label)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var gridBoard: some View {
        GeometryReader { geometry in
            let spacing: CGFloat = 2
            let cellSize = (geometry.size.width - spacing * CGFloat(document.size - 1))
                / CGFloat(document.size)

            VStack(spacing: spacing) {
                ForEach(0..<document.size, id: \.self) { row in
                    HStack(spacing: spacing) {
                        ForEach(0..<document.size, id: \.self) { column in
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
        let color = document.color(face, row: row, column: column)
        return RoundedRectangle(cornerRadius: 2)
            .fill(color?.color ?? Color(white: 0.12))
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(
                        Color.primary.opacity(color == nil ? 0.10 : 0.0),
                        lineWidth: 0.5
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                paint(row: row, column: column)
            }
    }

    private var statusLine: some View {
        HStack {
            Text("塗ったマス \(document.grid(for: face).paintedCount) / \(document.size * document.size)")
            Spacer()
            Text("同じ色をもう一度タップで消えます")
                .foregroundStyle(.secondary)
        }
        .font(.footnote)
    }

    private var sizeMenu: some View {
        Menu {
            Section("マス目") {
                Button {
                    document.resize(to: VoxelDocument.freeSize)
                } label: {
                    if document.size == VoxelDocument.freeSize {
                        Label("10×10", systemImage: "checkmark")
                    } else {
                        Text("10×10")
                    }
                }
                Button {
                    if document.isPro {
                        document.resize(to: VoxelDocument.proSize)
                    } else {
                        showPaywall = true
                    }
                } label: {
                    if document.isPro {
                        Text("16×16")
                    } else {
                        Label("16×16（Pro）", systemImage: "lock.fill")
                    }
                }
            }
        } label: {
            Text("\(document.size)×\(document.size)")
                .font(.footnote.weight(.semibold))
        }
    }

    private var previewLink: some View {
        NavigationLink {
            PreviewScreen(document: document)
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
        let current = document.color(face, row: row, column: column)
        switch brush {
        case .eraser:
            document.paint(nil, face: face, row: row, column: column)
        case .color(let color):
            if current == color {
                document.paint(nil, face: face, row: row, column: column)
            } else {
                document.paint(color, face: face, row: row, column: column)
            }
        }
    }
}

#Preview {
    ContentView()
}
