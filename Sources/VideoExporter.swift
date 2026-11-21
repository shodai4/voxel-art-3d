import AVFoundation
import CoreVideo
import Metal
import SceneKit
import SwiftUI
import UIKit

/// 3面図から1周ぶんの回転MP4を作り、一時ファイルのURLを返す。
/// 外部SDKは使わず、SceneKit のオフスクリーンレンダリングと AVAssetWriter だけで完結させる。
enum VideoExporter {
    enum Failure: LocalizedError {
        case emptyModel
        case metalUnavailable
        case writerUnavailable
        case frameFailed
        case writingFailed(String)

        var errorDescription: String? {
            switch self {
            case .emptyModel:
                return "まだ立体がありません。どこかの面に色を塗ってください。"
            case .metalUnavailable:
                return "この端末では動画を作れませんでした。"
            case .writerUnavailable:
                return "動画の保存先を用意できませんでした。"
            case .frameFailed:
                return "動画のコマを作れませんでした。"
            case .writingFailed(let reason):
                return reason
            }
        }
    }

    static let frameRate: Int32 = 30
    static let pixelSize = 720

    /// 書き出しは重いのでバックグラウンドで回し、結果だけメインスレッドへ返す。
    static func exportMovie(
        front: VoxelGrid,
        side: VoxelGrid,
        top: VoxelGrid,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let result = Result { try renderMovie(front: front, side: side, top: top) }
            DispatchQueue.main.async {
                completion(result)
            }
        }
    }

    private static func renderMovie(front: VoxelGrid, side: VoxelGrid, top: VoxelGrid) throws -> URL {
        let built = VoxelEngine.makeScene(front: front, side: side, top: top, aspect: 1)
        guard !built.rotor.childNodes.isEmpty else { throw Failure.emptyModel }

        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            throw Failure.metalUnavailable
        }

        let renderer = SCNRenderer(device: device, options: nil)
        renderer.scene = built.scene
        renderer.pointOfView = built.camera
        renderer.autoenablesDefaultLighting = false

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voxel-rotation-\(Int(Date().timeIntervalSince1970)).mp4")
        try? FileManager.default.removeItem(at: url)

        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: pixelSize,
            AVVideoHeightKey: pixelSize,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 4_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: pixelSize,
                kCVPixelBufferHeightKey as String: pixelSize,
                kCVPixelBufferMetalCompatibilityKey as String: true
            ]
        )

        guard writer.canAdd(input) else { throw Failure.writerUnavailable }
        writer.add(input)

        guard writer.startWriting() else {
            throw Failure.writingFailed(writer.error?.localizedDescription ?? "動画を作れませんでした。")
        }
        writer.startSession(atSourceTime: .zero)

        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm,
            width: pixelSize,
            height: pixelSize,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw Failure.metalUnavailable
        }

        let frames = max(Int((VoxelEngine.rotationDuration * Double(frameRate)).rounded()), 1)

        for frame in 0..<frames {
            let angle = Float(frame) / Float(frames) * 2 * .pi
            built.rotor.eulerAngles = SCNVector3(0, angle, 0)

            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = texture
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .store
            pass.colorAttachments[0].clearColor = MTLClearColor(
                red: 0.055,
                green: 0.055,
                blue: 0.06,
                alpha: 1
            )

            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                throw Failure.frameFailed
            }
            renderer.render(
                atTime: CFTimeInterval(frame) / CFTimeInterval(frameRate),
                viewport: CGRect(x: 0, y: 0, width: pixelSize, height: pixelSize),
                commandBuffer: commandBuffer,
                passDescriptor: pass
            )
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()

            guard let pixelBuffer = makePixelBuffer(from: texture) else {
                throw Failure.frameFailed
            }

            while !input.isReadyForMoreMediaData {
                Thread.sleep(forTimeInterval: 0.005)
            }

            let time = CMTime(value: CMTimeValue(frame), timescale: frameRate)
            guard adaptor.append(pixelBuffer, withPresentationTime: time) else {
                throw Failure.writingFailed(writer.error?.localizedDescription ?? "動画に書き込めませんでした。")
            }
        }

        input.markAsFinished()
        let semaphore = DispatchSemaphore(value: 0)
        writer.finishWriting { semaphore.signal() }
        semaphore.wait()

        guard writer.status == .completed else {
            throw Failure.writingFailed(writer.error?.localizedDescription ?? "動画を仕上げられませんでした。")
        }
        return url
    }

    private static func makePixelBuffer(from texture: MTLTexture) -> CVPixelBuffer? {
        let bytesPerRow = pixelSize * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * pixelSize)
        bytes.withUnsafeMutableBytes { buffer in
            guard let base = buffer.baseAddress else { return }
            texture.getBytes(
                base,
                bytesPerRow: bytesPerRow,
                from: MTLRegionMake2D(0, 0, pixelSize, pixelSize),
                mipmapLevel: 0
            )
        }

        var pixelBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
            kCVPixelBufferMetalCompatibilityKey as String: true
        ]
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            pixelSize,
            pixelSize,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let destination = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let destinationBytesPerRow = CVPixelBufferGetBytesPerRow(buffer)

        bytes.withUnsafeBytes { source in
            guard let sourceBase = source.baseAddress else { return }
            for row in 0..<pixelSize {
                memcpy(
                    destination.advanced(by: row * destinationBytesPerRow),
                    sourceBase.advanced(by: row * bytesPerRow),
                    bytesPerRow
                )
            }
        }
        return buffer
    }
}

/// 書き出した動画。シェアシートに渡すために Identifiable にする。
struct ExportedVideo: Identifiable {
    let url: URL
    var id: URL { url }
}

/// UIActivityViewController。保存もSNS投稿もこれ1枚から選べる。
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
