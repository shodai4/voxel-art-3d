import SceneKit
import SwiftUI
import UIKit
import simd

/// 3面図からボクセルを作り、SceneKit のシーンに組み立てる。
enum VoxelEngine {
    static let voxelSize: CGFloat = 0.1
    static let chamferRadius: CGFloat = 0.006
    static let fieldOfView: CGFloat = 40
    /// 自動回転1周の秒数。書き出す動画の長さもこれに合わせる。
    static let rotationDuration: TimeInterval = 6
    static let cameraMargin: Float = 1.35

    /// 立体にする1マス。x は右、y は上、z は手前が大きい。
    struct Cell {
        let x: Int
        let y: Int
        let z: Int
        let color: VoxelColor
    }

    struct BuiltScene {
        let scene: SCNScene
        let rotor: SCNNode
        let camera: SCNNode
    }

    /// 3面の視体積交差。
    /// 正面は「上から row 行目・左から column 列目」、横は「上から row 行目・奥から depth 列目」、
    /// 上は「奥から depth 行目・左から column 列目」で、3面すべてに色がある座標だけを立体にする。
    static func cells(front: VoxelGrid, side: VoxelGrid, top: VoxelGrid) -> [Cell] {
        let size = front.size
        guard size > 0, side.size == size, top.size == size else { return [] }

        var result: [Cell] = []
        for depth in 0..<size {
            for column in 0..<size {
                guard top[depth, column] != nil else { continue }
                for row in 0..<size {
                    guard let frontColor = front[row, column], side[row, depth] != nil else { continue }
                    result.append(
                        Cell(x: column, y: size - 1 - row, z: depth, color: frontColor)
                    )
                }
            }
        }
        return result
    }

    static func makeScene(front: VoxelGrid, side: VoxelGrid, top: VoxelGrid) -> BuiltScene {
        let scene = SCNScene()
        scene.background.contents = UIColor(white: 0.055, alpha: 1)

        let rotor = SCNNode()
        rotor.name = "rotor"

        let cells = cells(front: front, side: side, top: top)
        var boxes: [String: SCNBox] = [:]
        var span: CGFloat = voxelSize * CGFloat(max(front.size, 1))

        if let bounds = bounds(of: cells) {
            let centerX = Float(bounds.minX + bounds.maxX) / 2
            let centerY = Float(bounds.minY + bounds.maxY) / 2
            let centerZ = Float(bounds.minZ + bounds.maxZ) / 2
            let voxel = Float(voxelSize)

            for cell in cells {
                let box = boxes[cell.color.id] ?? makeBox(for: cell.color)
                boxes[cell.color.id] = box

                let node = SCNNode(geometry: box)
                node.position = SCNVector3(
                    (Float(cell.x) - centerX) * voxel,
                    (Float(cell.y) - centerY) * voxel,
                    (Float(cell.z) - centerZ) * voxel
                )
                rotor.addChildNode(node)
            }

            let width = Float(bounds.maxX - bounds.minX + 1) * voxel
            let height = Float(bounds.maxY - bounds.minY + 1) * voxel
            let depth = Float(bounds.maxZ - bounds.minZ + 1) * voxel
            span = CGFloat(sqrt(width * width + height * height + depth * depth) / 2)
        }

        scene.rootNode.addChildNode(rotor)
        scene.rootNode.addChildNode(makeKeyLight())
        scene.rootNode.addChildNode(makeAmbientLight())

        let camera = makeCamera(distance: cameraDistance(forRadius: Float(span)))
        scene.rootNode.addChildNode(camera)

        return BuiltScene(scene: scene, rotor: rotor, camera: camera)
    }

    /// 立体全体が余白付きで収まるカメラ距離。
    static func cameraDistance(forRadius radius: Float) -> Float {
        let halfFOV = Float(fieldOfView) / 2 * .pi / 180
        let fitted = radius / tan(halfFOV) * cameraMargin
        return max(fitted, 1.0)
    }

    private static func makeBox(for color: VoxelColor) -> SCNBox {
        let box = SCNBox(
            width: voxelSize,
            height: voxelSize,
            length: voxelSize,
            chamferRadius: chamferRadius
        )
        let material = SCNMaterial()
        material.diffuse.contents = color.uiColor
        material.roughness.contents = 0.85
        material.metalness.contents = 0.0
        material.lightingModel = .physicallyBased
        box.materials = [material]
        return box
    }

    private static func makeCamera(distance: Float) -> SCNNode {
        let node = SCNNode()
        let camera = SCNCamera()
        camera.fieldOfView = fieldOfView
        camera.zNear = 0.01
        camera.zFar = 200
        node.camera = camera

        let direction = simd_normalize(SIMD3<Float>(0.55, 0.45, 1.0))
        let eye = direction * distance
        node.position = SCNVector3(eye.x, eye.y, eye.z)
        node.look(
            at: SCNVector3Zero,
            up: SCNVector3(0, 1, 0),
            localFront: SCNVector3(0, 0, -1)
        )
        return node
    }

    private static func makeKeyLight() -> SCNNode {
        let node = SCNNode()
        let light = SCNLight()
        light.type = .directional
        light.intensity = 1000
        light.castsShadow = false
        node.light = light
        node.eulerAngles = SCNVector3(-Float.pi / 3, Float.pi / 6, 0)
        return node
    }

    private static func makeAmbientLight() -> SCNNode {
        let node = SCNNode()
        let light = SCNLight()
        light.type = .ambient
        light.intensity = 420
        light.color = UIColor(white: 0.92, alpha: 1)
        node.light = light
        return node
    }

    private struct Bounds {
        let minX: Int
        let maxX: Int
        let minY: Int
        let maxY: Int
        let minZ: Int
        let maxZ: Int
    }

    private static func bounds(of cells: [Cell]) -> Bounds? {
        var minX = Int.max
        var maxX = Int.min
        var minY = Int.max
        var maxY = Int.min
        var minZ = Int.max
        var maxZ = Int.min

        for cell in cells {
            minX = min(minX, cell.x)
            maxX = max(maxX, cell.x)
            minY = min(minY, cell.y)
            maxY = max(maxY, cell.y)
            minZ = min(minZ, cell.z)
            maxZ = max(maxZ, cell.z)
        }

        guard minX <= maxX, minY <= maxY, minZ <= maxZ else { return nil }
        return Bounds(minX: minX, maxX: maxX, minY: minY, maxY: maxY, minZ: minZ, maxZ: maxZ)
    }
}

/// 自動回転の付け外し。指でのカメラ操作と両立させるため、カメラではなくボクセルの親ノードを回す。
enum SceneRotation {
    static let actionKey = "auto-rotation"

    static func apply(_ isRotating: Bool, to node: SCNNode?) {
        guard let node else { return }

        if isRotating {
            guard node.action(forKey: actionKey) == nil else { return }
            let spin = SCNAction.repeatForever(
                SCNAction.rotateBy(x: 0, y: .pi * 2, z: 0, duration: VoxelEngine.rotationDuration)
            )
            node.runAction(spin, forKey: actionKey)
        } else if node.action(forKey: actionKey) != nil {
            // 止めた角度のまま残す。止めるたびに正面へ戻ると目が疲れるため。
            let current = node.presentation.rotation
            node.removeAction(forKey: actionKey)
            node.rotation = current
        }
    }
}

/// SceneKit のビュー。ドラッグで回転、ピンチで拡大縮小できる。
struct VoxelSceneView: UIViewRepresentable {
    @ObservedObject var document: VoxelDocument
    var isRotating: Bool

    final class Coordinator {
        var rotor: SCNNode?
        var front = VoxelGrid(size: VoxelDocument.freeSize)
        var side = VoxelGrid(size: VoxelDocument.freeSize)
        var top = VoxelGrid(size: VoxelDocument.freeSize)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView()
        view.allowsCameraControl = true
        view.autoenablesDefaultLighting = false
        view.backgroundColor = UIColor(white: 0.055, alpha: 1)
        view.antialiasingMode = .multisampling4X
        view.preferredFramesPerSecond = 60

        applyScene(to: view, coordinator: context.coordinator)
        return view
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        let coordinator = context.coordinator
        if coordinator.front != document.front
            || coordinator.side != document.side
            || coordinator.top != document.top {
            applyScene(to: uiView, coordinator: coordinator)
        } else {
            SceneRotation.apply(isRotating, to: coordinator.rotor)
        }
    }

    private func applyScene(to view: SCNView, coordinator: Coordinator) {
        let built = VoxelEngine.makeScene(
            front: document.front,
            side: document.side,
            top: document.top
        )
        view.scene = built.scene
        view.pointOfView = built.camera

        coordinator.rotor = built.rotor
        coordinator.front = document.front
        coordinator.side = document.side
        coordinator.top = document.top

        SceneRotation.apply(isRotating, to: built.rotor)
    }
}
