import Cocoa
import QuickLookThumbnailing
import SceneKit
import GLTFKit2

final class ThumbnailProvider: QLThumbnailProvider {

    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, Error?) -> Void
    ) {
        let fileURL = request.fileURL
        let side = min(request.maximumSize.width, request.maximumSize.height)
        let size = CGSize(width: side, height: side)
        let scale = request.scale

        // Start security-scoped access so the sandboxed extension can read the file.
        let accessing = fileURL.startAccessingSecurityScopedResource()

        GLTFAsset.load(with: fileURL, options: [:]) { _, status, asset, error, _ in
            // Skip intermediate progress callbacks — only act on final result.
            guard status == .complete || error != nil else { return }

            // Safe to stop security-scoped access now that loading is done.
            if accessing { fileURL.stopAccessingSecurityScopedResource() }

            if let error {
                handler(nil, error)
                return
            }
            guard let asset else {
                handler(nil, ThumbnailError.assetLoadFailed)
                return
            }

            let scene = SCNScene(gltfAsset: asset)

            let reply = QLThumbnailReply(contextSize: size) { [scene] context -> Bool in
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
                    antialiasingMode: .multisampling4X
                )

                // Draw into the CGContext directly via CGImage to avoid
                // NSGraphicsContext state issues in an extension process.
                guard let cgImage = image.cgImage(
                    forProposedRect: nil,
                    context: nil,
                    hints: nil
                ) else { return false }

                context.draw(cgImage, in: CGRect(origin: .zero, size: size))
                return true
            }

            handler(reply, nil)
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
        let keyNode = SCNNode()
        keyNode.light = keyLight
        keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
        scene.rootNode.addChildNode(keyNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 250
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
        let maxDim: CGFloat = max(max(extents.x, extents.y), extents.z)
        let fovRadians: CGFloat = 60.0 * CGFloat.pi / 180.0
        let halfFov: CGFloat = fovRadians / 2.0
        let distance: CGFloat = (maxDim / (2.0 * tan(halfFov))) * 1.4

        let camera = SCNCamera()
        camera.fieldOfView = 60
        camera.zNear = Double(maxDim) * 0.01
        camera.zFar  = Double(maxDim) * 20

        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, center.y, center.z + distance)
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
