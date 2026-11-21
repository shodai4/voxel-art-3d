import SwiftUI

struct PreviewScreen: View {
    @ObservedObject var document: VoxelDocument

    @State private var isRotating = true
    @State private var isExporting = false
    @State private var exportedVideo: ExportedVideo?
    @State private var showExportOptions = false
    @State private var showAdNotice = false
    @State private var showPaywall = false
    @State private var errorMessage: String?

    private var voxelCount: Int {
        VoxelEngine.cells(front: document.front, side: document.side, top: document.top).count
    }

    var body: some View {
        VStack(spacing: 0) {
            stage
            controls
        }
        .navigationTitle("3Dプレビュー")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .sheet(item: $exportedVideo) { video in
            ShareSheet(items: [video.url])
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
        .confirmationDialog("動画の保存", isPresented: $showExportOptions, titleVisibility: .visible) {
            Button("広告を見て保存") {
                showAdNotice = true
            }
            Button("Proで広告なしで保存") {
                showPaywall = true
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("無料版は広告の視聴後に保存できます。")
        }
        .alert("広告は準備中です", isPresented: $showAdNotice) {
            Button("このまま保存する") {
                startExport()
            }
            Button("やめる", role: .cancel) {}
        } message: {
            Text("広告SDKはまだ接続していません。今回は確認だけして、広告なしで保存します。")
        }
        .alert("動画を保存できませんでした", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var stage: some View {
        ZStack {
            VoxelSceneView(document: document, revision: document.revision, isRotating: isRotating)
                // エディタへ戻って描き足したあとの2回目も、必ず新しいシーンで開き直す。
                .id(document.revision)

            if voxelCount == 0 {
                VStack(spacing: 6) {
                    Text("まだ立体がありません")
                        .font(.subheadline.weight(.semibold))
                    Text("どれかの面に色を塗ると、その形が奥へ押し出されて立体になります。")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                }
                .foregroundStyle(Color.white.opacity(0.75))
                .padding(16)
            }

            if isExporting {
                ProgressView("回転動画を作っています")
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.055))
        .overlay(alignment: .bottomTrailing) {
            Text("ドラッグで回転・ピンチで拡大")
                .font(.caption2)
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(10)
        }
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Text(voxelCount == 0 ? "ボクセル 0個" : "ボクセル \(voxelCount)個")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("自動回転")
                    .font(.subheadline)
                Toggle("自動回転", isOn: $isRotating)
                    .labelsHidden()
            }

            Button {
                requestExport()
            } label: {
                Label(isExporting ? "書き出し中" : "動画を保存", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .foregroundStyle(Color.white)
                    .background(
                        Color.accentColor.opacity(voxelCount == 0 ? 0.4 : 1),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .disabled(isExporting || voxelCount == 0)

            Button {
                showPaywall = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "lock.fill")
                        .font(.caption)
                    Text(".usdzで書き出し")
                        .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(Color(uiColor: .systemBackground))
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { isPresented in
                if !isPresented { errorMessage = nil }
            }
        )
    }

    private func requestExport() {
        if document.isPro {
            startExport()
        } else {
            showExportOptions = true
        }
    }

    private func startExport() {
        guard !isExporting else { return }
        isExporting = true

        VideoExporter.exportMovie(
            front: document.front,
            side: document.side,
            top: document.top
        ) { result in
            isExporting = false
            switch result {
            case .success(let url):
                exportedVideo = ExportedVideo(url: url)
            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
    }
}
