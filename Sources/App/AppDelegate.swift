import AppKit
import SceneKit
import GLTFKit2

@main
final class AppDelegate: NSObject, NSApplicationDelegate {

    // Retain viewer windows so they aren't released while open.
    private var viewerWindows: [NSWindow] = []
    private var fileOpenedOnLaunch = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Force NSDocumentController to initialize (and register its odoc handler) first,
        // then immediately replace its handler with ours. This ensures we win the race.
        _ = NSDocumentController.shared
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleOpenDocumentsEvent(_:withReplyEvent:)),
            forEventClass: AEEventClass(0x61657674), // kCoreEventClass 'aevt'
            andEventID:   AEEventID(0x6F646F63)      // kAEOpenDocuments 'odoc'
        )

        DispatchQueue.main.async {
            if !self.fileOpenedOnLaunch {
                self.showWelcomeWindow()
            }
        }
    }

    @objc func handleOpenDocumentsEvent(_ event: NSAppleEventDescriptor,
                                        withReplyEvent: NSAppleEventDescriptor) {
        guard let fileList = event.paramDescriptor(forKeyword: AEKeyword(0x2D2D2D2D))
        else { return }
        let count = fileList.numberOfItems
        for i in 1...max(1, count) {
            guard let item = (count > 0 ? fileList.atIndex(i) : fileList) else { continue }
            if let url = item.fileURLValue {
                fileOpenedOnLaunch = true
                openVRM(url: url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    // MARK: - Internal

    func openVRM(url: URL) {
        let window = makeViewerWindow(title: url.lastPathComponent)
        viewerWindows.append(window)
        window.makeKeyAndOrderFront(nil)

        let sceneView = window.contentView as! SCNView
        let spinner = sceneView.subviews.first as! NSProgressIndicator
        spinner.startAnimation(nil)

        GLTFAsset.load(with: url, options: [:]) { [weak self, weak window] _, status, asset, error, _ in
            guard status == .complete || error != nil else { return }
            DispatchQueue.main.async {
                guard let self, let window else { return }
                let sceneView = window.contentView as! SCNView
                let spinner = sceneView.subviews.first as! NSProgressIndicator
                spinner.stopAnimation(nil)
                spinner.isHidden = true

                if let error {
                    self.viewerWindows.removeAll { $0 === window }
                    let alert = NSAlert()
                    alert.messageText = "Could not open file"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .warning
                    alert.beginSheetModal(for: window)
                    return
                }

                guard let asset else { return }
                let scene = SCNScene(gltfAsset: asset)
                setupScene(scene, in: sceneView)
                sceneView.isHidden = false
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.viewerWindows.removeAll { $0 === window }
        }
    }

    private func makeViewerWindow(title: String) -> NSWindow {
        let sceneView = SCNView(frame: NSRect(x: 0, y: 0, width: 800, height: 600))
        sceneView.backgroundColor = NSColor(white: 0.12, alpha: 1)
        sceneView.antialiasingMode = .multisampling4X
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.isHidden = true

        let spinner = NSProgressIndicator()
        spinner.style = .spinning
        spinner.isIndeterminate = true
        spinner.translatesAutoresizingMaskIntoConstraints = false
        sceneView.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerXAnchor.constraint(equalTo: sceneView.centerXAnchor),
            spinner.centerYAnchor.constraint(equalTo: sceneView.centerYAnchor),
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.contentView = sceneView
        window.center()
        return window
    }

    private func showWelcomeWindow() {
        let label = NSTextField(wrappingLabelWithString:
            "VRM QuickLook is installed.\n" +
            "Double-click any .vrm file to open it, or select one in Finder and press Space."
        )
        label.alignment = .center
        label.isEditable = false
        label.isBordered = false
        label.drawsBackground = false
        label.frame = NSRect(x: 20, y: 60, width: 440, height: 80)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 200),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "VRM QuickLook"
        window.contentView?.addSubview(label)
        window.center()
        window.makeKeyAndOrderFront(nil)
        viewerWindows.append(window)
    }
}

private func setupScene(_ scene: SCNScene, in sceneView: SCNView) {
    let keyLight = SCNLight(); keyLight.type = .directional
    keyLight.intensity = 800; keyLight.color = NSColor.white; keyLight.castsShadow = true
    let keyNode = SCNNode(); keyNode.light = keyLight
    keyNode.eulerAngles = SCNVector3(-Float.pi / 4, Float.pi / 4, 0)
    scene.rootNode.addChildNode(keyNode)

    let fillLight = SCNLight(); fillLight.type = .directional
    fillLight.intensity = 300; fillLight.color = NSColor(white: 0.8, alpha: 1)
    let fillNode = SCNNode(); fillNode.light = fillLight
    fillNode.eulerAngles = SCNVector3(-Float.pi / 6, -Float.pi / 3, 0)
    scene.rootNode.addChildNode(fillNode)

    let rimLight = SCNLight(); rimLight.type = .directional
    rimLight.intensity = 200; rimLight.color = NSColor(calibratedRed: 0.6, green: 0.8, blue: 1.0, alpha: 1)
    let rimNode = SCNNode(); rimNode.light = rimLight
    rimNode.eulerAngles = SCNVector3(Float.pi / 6, Float.pi + Float.pi / 4, 0)
    scene.rootNode.addChildNode(rimNode)

    let ambientLight = SCNLight(); ambientLight.type = .ambient
    ambientLight.intensity = 150; ambientLight.color = NSColor(white: 0.5, alpha: 1)
    let ambientNode = SCNNode(); ambientNode.light = ambientLight
    scene.rootNode.addChildNode(ambientNode)

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
    let distance: CGFloat = (maxDim / (2.0 * tan(60.0 * CGFloat.pi / 180.0 / 2.0))) * 1.4

    let camera = SCNCamera()
    camera.fieldOfView = 60
    camera.zNear = Double(maxDim) * 0.01
    camera.zFar  = Double(maxDim) * 20
    let cameraNode = SCNNode(); cameraNode.camera = camera
    cameraNode.position = SCNVector3(0, center.y, center.z + distance)
    cameraNode.look(at: center)
    scene.rootNode.addChildNode(cameraNode)
    sceneView.pointOfView = cameraNode
    sceneView.defaultCameraController.target = center
}
