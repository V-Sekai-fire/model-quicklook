<div align="center">

# Model QuickLook

<img src="logo.png" alt="ModelQuickLook Logo" width="200" />

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Apple Silicon + Intel](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey) 


![Claude Code](https://img.shields.io/badge/vibe%20coded-Claude%20Code-E67D22)

</div>

MacOS QuickLook plugin for `.vrm`, `.glb` and `.gltf` 3D files. Adds Finder thumbnails and interactive Space bar previews.

> This repository is the public distribution copy of the project.
> The canonical development repository is private.
> Changes made here may be overwritten by the automated publish pipeline.

## Installing

> **NOTE:** Tested on MacOS Tahoe 26.4

### Prebuilt Application

1. Go to the [Releases](../../releases) page and download the latest `ModelQuickLook.app.zip`.
2. Unzip and move **ModelQuickLook.app** to your `/Applications` folder.
3. Open **Terminal** and run:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/ModelQuickLook.app
qlmanage -r && qlmanage -r cache
```

4. Open a folder containing `.vrm` files in Finder - thumbnails will appear. Press **Space** on any `.vrm` file for an interactive 3D preview.

> **First launch:** MacOS may show a "cannot be opened" Gatekeeper prompt. Right-click the app in Finder, choose **Open**, then click **Open** again to allow it or run:

```bash
xattr -dr com.apple.quarantine /Applications/ModelQuickLook.app
```

---

### Build from source

**Requirements:** macOS 13+, Xcode 15+, [xcodegen](https://github.com/yonaskolb/XcodeGen)

No Apple Developer account required — the project uses ad-hoc signing.

```bash
brew install xcodegen
git clone <THIS_REPO_URL>
cd model-quicklook

xcodegen generate
```

Build a universal binary (Apple Silicon + Intel):

```bash
xcodebuild -project ModelQuickLook.xcodeproj \
  -scheme ModelQuickLook \
  -configuration Release \
  -destination 'platform=macOS' \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build
```

Install:

```bash
BUILT=$(find ~/Library/Developer/Xcode/DerivedData/ModelQuickLook-* \
  -name "ModelQuickLook.app" -path "*/Release/*" 2>/dev/null | head -1)

rm -rf /Applications/ModelQuickLook.app
ditto "$BUILT" /Applications/ModelQuickLook.app

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/ModelQuickLook.app
qlmanage -r && qlmanage -r cache
```

---

## Uninstalling

```bash
rm -rf /Applications/ModelQuickLook.app

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u /Applications/ModelQuickLook.app

qlmanage -r && qlmanage -r cache
```

Thumbnails already cached by Finder will disappear once you navigate away from and back to the folder.

---

## Usage

| Action | Result |
|---|---|
| Browse a folder with `.vrm`, `.glb` or `.gltf` files | Thumbnails render automatically |
| Press **Space** on a `.vrm`, `.glb` or `.gltf` file | Interactive 3D preview - drag to rotate, scroll to zoom |

The plugin runs silently in the background - there is no app window or Dock icon.

---

## Troubleshooting

### Thumbnails not showing after install

Touch the files to bust the Finder cache, then re-open the folder:

```bash
find /path/to/your/vrm/files -name "*.vrm" -exec touch {} \;
killall Finder
```

### Extension not listed in QuickLook

```bash
pluginkit -m -v | grep vsekai
```

If nothing appears, re-register manually:

```bash
pluginkit -a /Applications/ModelQuickLook.app/Contents/PlugIns/ModelPreviewExtension.appex
pluginkit -a /Applications/ModelQuickLook.app/Contents/PlugIns/ModelThumbnailExtension.appex
```

### `.glb` files use the macOS built-in generator

macOS ships its own Quick Look generator for `.glb` (`org.khronos.glb`) and it takes priority over third-party extensions, so this app cannot replace it. `.vrm` and `.gltf` are handled by this app. Tested on macOS 26: `.vrm` and `.gltf` thumbnails render through this app; a `.glb` thumbnail did not render, most likely because of that system generator.

### A `.gltf` file previews blank

The preview extension can only read the file itself. A `.gltf` that points at external `.bin` or texture files will not load them; use a `.glb` or a `.gltf` with embedded data.

### Space bar preview shows nothing / spinner never disappears

The VRM file may use unsupported extensions. Model QuickLook uses [GLTFKit2](https://github.com/warrenm/GLTFKit2) for loading, which renders using standard PBR materials (MToon cel-shading is not supported).

---

## Dependencies

- [GLTFKit2](https://github.com/warrenm/GLTFKit2): glTF/VRM loading via Swift Package Manager

---

## Creating a release

```bash
xcodegen generate

xcodebuild -project ModelQuickLook.xcodeproj \
  -scheme ModelQuickLook \
  -configuration Release \
  -destination 'platform=macOS' \
  ARCHS="arm64 x86_64" \
  ONLY_ACTIVE_ARCH=NO \
  build

BUILT=$(find ~/Library/Developer/Xcode/DerivedData/ModelQuickLook-* \
  -name "ModelQuickLook.app" -path "*/Release/*" 2>/dev/null | head -1)

ditto -c -k --keepParent "$BUILT" ModelQuickLook.zip
```

---

## License

Apache License 2.0. See [LICENSE](LICENSE).

This project was previously released under the Do What The F*ck You Want To Public License (WTFPL). It is now licensed under Apache-2.0.
