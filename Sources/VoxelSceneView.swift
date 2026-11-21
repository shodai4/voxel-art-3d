import SceneKit
import SwiftUI
import UIKit
import simd

/// 塗ったマスを SCNBox の集まりに変換する。
enum VoxelEngine {
    static let voxelSize: CGFloat = 0.1
    static let chamferRadius: CGFloat = 0.006
    /// カメラまでの距離。10x10 の全体が縦長の画面に収まる値。
    static let cameraDistance: Float = 3.6

    static func makeScene(grid: VoxelGrid) -> SCNScene {
        let scene = SCNScene()
        let rootNode = SCNNode()
        rootNode.name = "voxels"

        grid.forEachPainted { row, column, color in
            let box = SCNBox(
                width: voxelSize,
                height: voxelSize,
                length: voxelSize,
                chamferRadius: chamferRadius
            )
            let material = SCNMaterial()
            material.diffuse.contents = UIColor(color)
            material.roughness.contents = 0.85
            material.metalness.contents = 0.0
            box.materials = [material]

            let node = SCNNode(geometry: box)
            node.position = SCNVector3(
                Float(column) * Float(voxelSize),
                Float(-row) * Float(voxelSize),
                0
            )
            rootNode.addChildNode(node)
        }

        scene.rootNode.addChildNode(rootNode)
        return scene
    }

    /// 10x10 の中心。カメラの向きを決めるのに使う。
    static var gridCenter: SCNVector3 {
        let span = Float(voxelSize) * Float(VoxelGrid.size - 1)
        return SCNVector3(span / 2, -span / 2, 0)
    }
}

/// SceneKit のビュー。ドラッグで回転、ピンチで拡大縮小できる。
struct VoxelSceneView: UIViewRepresentable {
    let grid: VoxelGrid

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.scene = VoxelEngine.makeScene(grid: grid)
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = true
        view.backgroundColor = UIColor(white: 0.06, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.camera?.fieldOfView = 40
        cameraNode.camera?.zNear = 0.01
        cameraNode.camera?.zFar = 100

        let center = VoxelEngine.gridCenter
        let direction = simd_normalize(SIMD3<Float>(0.45, 0.52, 1.0))
        let eye = SIMD3<Float>(center.x, center.y, center.z) + direction * VoxelEngine.cameraDistance
        cameraNode.position = SCNVector3(eye.x, eye.y, eye.z)
        cameraNode.look(
            at: center,
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )

        view.scene?.rootNode.addChildNode(cameraNode)
        view.pointOfView = cameraNode
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // 表示中にマス目は変わらないので、カメラ操作の状態を保つためシーンは作り直さない。
    }
}
