import Cocoa
import Quartz
import SceneKit
import GLTFKit2

final class PreviewViewController: NSViewController, QLPreviewingController {

    // MARK: - UI

    private var sceneView: SCNView?
    private var spinner: NSProgressIndicator!

    // MARK: - Lifecycle

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        container.wantsLayer = true
        container.layer?.backgroundColor = NSColor(white: 0.12, alpha: 1).cgColor

        spinner = NSProgressIndicator(frame: NSRect(x: 0, y: 0, width: 32, height: 32))
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: container.centerYAnchor),
        ])

        self.view = container
    }

    deinit {
        sceneView?.scene = nil
        sceneView = nil
    }

    // MARK: - QLPreviewingController

    func preparePreviewOfFile(
        at url: URL,
        completionHandler handler: @escaping (Error?) -> Void
    ) {
        spinner.startAnimation(nil)

        // Create SCNView lazily here so Metal doesn't initialize until actually needed.
        if sceneView == nil {
            let sv = SCNView(frame: view.bounds)
            sv.autoresizingMask = [.width, .height]
            sv.backgroundColor = NSColor(white: 0.12, alpha: 1)
            sv.antialiasingMode = .multisampling4X
            sv.allowsCameraControl = true
            sv.autoenablesDefaultLighting = false
            sv.isHidden = true
            view.addSubview(sv, positioned: .below, relativeTo: spinner)
            sceneView = sv
        }

        // Start security-scoped access so the sandboxed extension can read the file.
        let accessing = url.startAccessingSecurityScopedResource()

        GLTFAsset.load(with: url, options: [:]) { [weak self] _, status, asset, error, _ in
            // Skip intermediate progress callbacks — only act on final result.
            guard status == .complete || error != nil else { return }

            // Safe to stop security-scoped access now that loading is done.
            if accessing { url.stopAccessingSecurityScopedResource() }

            DispatchQueue.main.async {
                guard let self else { return }

                self.spinner.stopAnimation(nil)
                self.spinner.isHidden = true

                if let error {
                    handler(error)
                    return
                }

                guard let asset else {
                    handler(PreviewError.assetLoadFailed)
                    return
                }

                let scene = SCNScene(gltfAsset: asset)
                self.setupScene(scene)
                self.sceneView?.isHidden = false
                handler(nil)
            }
        }
    }

    // MARK: - Scene Setup

    private func setupScene(_ scene: SCNScene) {
        guard let sceneView else { return }
        sceneView.scene = scene

        // Three-point lighting: key, fill, rim + ambient
        let keyLight = SCNLight()
        keyLight.type = .directional
        keyLight.intensity = 800
        keyLight.color = NSColor.white
        keyLight.castsShadow = true
        keyLight.shadowRadius = 3
        keyLight.shadowSampleCount = 8
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

        let rimLight = SCNLight()
        rimLight.type = .directional
        rimLight.intensity = 200
        rimLight.color = NSColor(calibratedRed: 0.6, green: 0.8, blue: 1.0, alpha: 1)
        let rimNode = SCNNode()
        rimNode.light = rimLight
        rimNode.eulerAngles = SCNVector3(Float.pi / 6, Float.pi + Float.pi / 4, 0)
        scene.rootNode.addChildNode(rimNode)

        let ambientLight = SCNLight()
        ambientLight.type = .ambient
        ambientLight.intensity = 150
        ambientLight.color = NSColor(white: 0.5, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambientLight
        scene.rootNode.addChildNode(ambientNode)

        // Camera fitted to bounding box
        let (minBounds, maxBounds) = scene.rootNode.boundingBox
        let center = SCNVector3(
            (minBounds.x + maxBounds.x) / 2,
            (minBounds.y + maxBounds.y) / 2,
            (minBounds.z + maxBounds.z) / 2
        )
        let size = SCNVector3(
            maxBounds.x - minBounds.x,
            maxBounds.y - minBounds.y,
            maxBounds.z - minBounds.z
        )
        let maxDim: CGFloat = max(max(size.x, size.y), size.z)
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
        sceneView.pointOfView = cameraNode
        sceneView.defaultCameraController.target = center
    }

    // MARK: - Errors

    private enum PreviewError: LocalizedError {
        case assetLoadFailed
        var errorDescription: String? {
            "Failed to load VRM asset."
        }
    }
}
