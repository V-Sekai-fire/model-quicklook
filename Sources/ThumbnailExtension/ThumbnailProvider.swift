import Cocoa
import QuickLookThumbnailing
import SceneKit
import GLTFKit2
import os

private let log = Logger(subsystem: "com.vsekai.ModelQuickLook", category: "thumbnail")

final class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let fileURL = request.fileURL
        log.notice("thumbnail request for \(fileURL.lastPathComponent, privacy: .public)")
        let side = min(request.maximumSize.width, request.maximumSize.height)
        let size = CGSize(width: side, height: side)
        let scale = request.scale

        // Start security-scoped access so the sandboxed extension can read the file.
        let accessing = fileURL.startAccessingSecurityScopedResource()

        GLTFAsset.load(with: fileURL, options: [:]) { _, status, asset, error, _ in
            autoreleasepool {
                // Skip intermediate progress callbacks — only act on final result.
                guard status == .complete || error != nil else { return }

                // Safe to stop security-scoped access now that loading is done.
                if accessing { fileURL.stopAccessingSecurityScopedResource() }

                if let error {
                    log.error("load failed for \(fileURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                    handler(nil, error)
                    return
                }
                guard let asset else {
                    log.error("no asset for \(fileURL.lastPathComponent, privacy: .public)")
                    handler(nil, ThumbnailError.assetLoadFailed)
                    return
                }

                let scene = SCNScene(gltfAsset: asset)

                let reply = QLThumbnailReply(contextSize: size) { [scene] context -> Bool in
                    autoreleasepool {
                        let renderer = SCNRenderer(device: nil, options: nil)
                        renderer.scene = scene
                        ThumbnailProvider.configureScene(scene, renderer: renderer)

                        let pixelSize = CGSize(
                            width: size.width * scale,
                            height: size.height * scale
                        )
                        let image = renderer.snapshot(
                            atTime: 0,
                            with: pixelSize,
                            antialiasingMode: .multisampling2X
                        )

                        renderer.scene = nil

                        // Draw into the CGContext directly via CGImage to avoid
                        // NSGraphicsContext state issues in an extension process.
                        guard let cgImage = image.cgImage(
                            forProposedRect: nil,
                            context: nil,
                            hints: nil
                        ) else {
                            log.error("snapshot produced no CGImage")
                            return false
                        }

                        context.draw(cgImage, in: CGRect(origin: .zero, size: pixelSize))
                        return true
                    }
                }

                handler(reply, nil)
            }
        }
    }

    // MARK: - Scene Configuration

    private static func configureScene(
        _ scene: SCNScene,
        renderer: SCNRenderer
    ) {
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 800
        keyLight.color = NSColor.white
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyNode)

        let fillLight = SCNLight()
        fillLight.type = .directional
        fillLight.intensity = 300
        fillLight.color = NSColor(white: 0.8, alpha: 1)
        let fillNode = SCNNode()
        fillNode.light = fillLight
        fillNode.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 3, 0)
        scene.rootNode.addChildNode(fillNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 150
        ambientLight.color = NSColor(white: 0.5, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        let (minBounds, maxBounds) = scene.rootNode.boundingBox
        let center = SCNVector3(
            (minBounds.x + maxBounds.x) / 2,
            (minBounds.y + maxBounds.y) / 2,
            (minBounds.z + maxBounds.z) / 2
        )
        let extents = SCNVector3(
            maxBounds.x - minBounds.x,
            maxBounds.y - minBounds.y,
            maxBounds.z - minBounds.z
        )
        // Fit by height for a square thumbnail so the avatar fills the frame
        // vertically. Use a tighter padding (1.1x) than the preview (1.4x).
        let rawDim: CGFloat = max(extents.y, extents.z)
        // Empty or degenerate bounds would give zNear = 0 and distance = 0.
        let maxDim: CGFloat = (rawDim.isFinite && rawDim > 0) ? rawDim : 1
        let fovRadians: CGFloat = 60.0 * CGFloat.pi / 180.0
        let halfFov: CGFloat = fovRadians / 2.0
        let distance: CGFloat = (maxDim / (2.0 * tan(halfFov))) * 1.1

        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = Double(maxDim) * 0.01
        camera.zFar  = Double(maxDim) * 20

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(center.x, center.y, center.z + distance)
        cameraNode.look(at: center)
        scene.rootNode.addChildNode(cameraNode)

        renderer.pointOfView = cameraNode
    }

    // MARK: - Errors

    private enum ThumbnailError: LocalizedError {
        case assetLoadFailed
        var errorDescription: String? { "Failed to load VRM asset for thumbnail." }
    }
}
