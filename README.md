# VoxelArt3D

正面・横・上 の3面図に色を塗り、3面が交わる場所を立体にする iOS アプリ。
SwiftUI + SceneKit。自動回転と回転動画の書き出しまで入っている。

## いまできること

- 「正面」「横」「上」の3タブで10×10のマス目に青・赤・緑・黄・オレンジで塗る
- 同じ色をもう一度タップ、または消しゴムで消す。全消しは面ごと／3面まとめて選べる
- 「3Dで見る」で視体積交差（3面すべてに色がある座標だけ立体）した3Dプレビューへ
- 自動回転のオン／オフ（指でのドラッグ回転・ピンチ拡大と併用できる）
- 1周ぶんの回転MP4を書き出してシェアシートから保存・投稿

## Pro の導線（未接続）

- 16×16のマス目、動画の広告なし保存、.usdz 書き出しはロック表示の案内だけを置いている
- StoreKit と広告SDKはまだ入れていないので、課金処理そのものは動かない

## 構成

```
Sources/
  VoxelArt3DApp.swift    アプリの入口
  VoxelModel.swift       3面のマス目・パレット・ドキュメント
  ContentView.swift      3面図エディタ
  VoxelSceneView.swift   視体積交差と SceneKit のビュー・自動回転
  PreviewScreen.swift    3Dプレビューと保存の導線
  VideoExporter.swift    回転MP4の書き出しとシェアシート
  PaywallSheet.swift     Pro の案内
Resources/Info.plist
project.yml              XcodeGen の定義
```

## 3面の向き

- 正面：正面から見た図（上が上）
- 横：左から見た図（右が正面、左が奥）
- 上：真上から見た図（下が正面、上が奥）

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

- StoreKit の課金と AdMob のリワード広告を接続
- .usdz / .obj の書き出し
- 写真の取り込み（輪郭と色を10×10へ落とす）
- AR プレビュー

Bundle ID: `com.shodai4.voxelart3d`
