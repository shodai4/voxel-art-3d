import SwiftUI

/// Pro の案内。課金の接続前なので、できることの紹介だけを出す。
struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    feature(
                        symbol: "square.grid.3x3.fill",
                        title: "16×16のマス目",
                        detail: "こまかい絵を描けます"
                    )
                    feature(
                        symbol: "video.fill",
                        title: "動画を広告なしで保存",
                        detail: "回転動画をすぐ書き出せます"
                    )
                    feature(
                        symbol: "cube.transparent",
                        title: ".usdzで書き出し",
                        detail: "3Dモデルとして他のアプリへ渡せます"
                    )
                } footer: {
                    Text("課金（StoreKit）と広告はまだ接続していません。準備中の画面です。")
                }
            }
            .navigationTitle("Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func feature(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .frame(width: 26)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
