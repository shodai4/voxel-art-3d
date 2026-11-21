# VoxelArt3D

10x10 のマス目に色を塗り、1タップでボクセル（3D）に変換して眺める iOS アプリ。
SwiftUI + SceneKit の MVP。

## いまできること

- 10x10 のマス目に青・赤・緑・黄・オレンジで塗る
- 同じ色をもう一度タップ、または消しゴムで消す
- 「3Dで見る」で 3D プレビューへ移動（ドラッグで回転、ピンチで拡大縮小）

## 構成

```
Sources/
  VoxelArt3DApp.swift    アプリの入口
  ContentView.swift      マス目エディタ
  VoxelModel.swift       マス目のデータとパレット
  VoxelSceneView.swift   ボクセル化と SceneKit のビュー
Resources/Info.plist
project.yml              XcodeGen の定義
```

## ビルド

XcodeGen でプロジェクトを生成してからビルドする。

```bash
brew install xcodegen
xcodegen generate
xcodebuild build -project VoxelArt3D.xcodeproj -scheme VoxelArt3D \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

`main` への push と pull request で GitHub Actions（`.github/workflows/ios-build.yml`）が同じビルドを回す。

## これから

- 回転するボクセルの動画・GIF 書き出し
- AR プレビュー
- 写真の取り込み
- STL 出力（3Dプリント用）
- 広告と Pro 版

Bundle ID: `com.shodai4.voxelart3d`
