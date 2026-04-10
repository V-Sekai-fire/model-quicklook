<div align="center">

# VRM QuickLook

<img src="logo.png" alt="VRMQuickLook Logo" width="200" />

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Apple Silicon + Intel](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey) 


![Claude Code](https://img.shields.io/badge/vibe%20coded-Claude%20Code-E67D22)

</div>

MacOS QuickLook plugin for `.vrm` 3D avatar files. Adds Finder thumbnails and interactive Space bar previews.

> **NOTE:** Tested on MacOS Tahoe 26.4

## Installing

### Prebuilt Application

1. Go to the [Releases](../../releases) page and download the latest `VRMQuickLook.app.zip`.
2. Unzip and move **VRMQuickLook.app** to your `/Applications` folder.
3. Open **Terminal** and run:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/VRMQuickLook.app
qlmanage -r && qlmanage -r cache
```

4. Open a folder containing `.vrm` files in Finder - thumbnails will appear. Press **Space** on any `.vrm` file for an interactive 3D preview.

> **First launch:** MacOS may show a "cannot be opened" Gatekeeper prompt. Right-click the app in Finder, choose **Open**, then click **Open** again to allow it or run:

```bash
xattr -dr com.apple.quarantine /Applications/VRMQuickLook.app
```

---

### Build from source

**Requirements:** macOS 13+, Xcode 15+, [xcodegen](https://github.com/yonaskolb/XcodeGen)

No Apple Developer account required — the project uses ad-hoc signing.

```bash
brew install xcodegen
git clone <THIS_REPO_URL>
cd vrm-quicklook
```

> **Note:** The `.xcodeproj` is not committed — generate it from `project.yml` first:

```bash
xcodegen generate
```

Build a universal binary (Apple Silicon + Intel):

```bash
xcodebuild -project VRMQuickLook.xcodeproj \
  -scheme VRMQuickLook \
  -configuration Release \
  -destination 'platform=macOS' \
  ARCHS="arm64 x86_64" \
  build
```

Install:

```bash
BUILT=$(find ~/Library/Developer/Xcode/DerivedData/VRMQuickLook-* \
  -name "VRMQuickLook.app" -path "*/Release/*" 2>/dev/null | head -1)

rm -rf /Applications/VRMQuickLook.app
ditto "$BUILT" /Applications/VRMQuickLook.app

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/VRMQuickLook.app
qlmanage -r && qlmanage -r cache
```

---

## Uninstalling

```bash
rm -rf /Applications/VRMQuickLook.app

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u /Applications/VRMQuickLook.app

qlmanage -r && qlmanage -r cache
```

Thumbnails already cached by Finder will disappear once you navigate away from and back to the folder.

---

## Usage

| Action | Result |
|---|---|
| Browse a folder with `.vrm` files | Thumbnails render automatically |
| Press **Space** on a `.vrm` file | Interactive 3D preview - drag to rotate, scroll to zoom |

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
pluginkit -m -v | grep vroid
```

If nothing appears, re-register manually:

```bash
pluginkit -a /Applications/VRMQuickLook.app/Contents/PlugIns/VRMPreviewExtension.appex
pluginkit -a /Applications/VRMQuickLook.app/Contents/PlugIns/VRMThumbnailExtension.appex
```

### Space bar preview shows nothing / spinner never disappears

The VRM file may use unsupported extensions. VRM QuickLook uses [GLTFKit2](https://github.com/warrenm/GLTFKit2) for loading, which renders using standard PBR materials (MToon cel-shading is not supported).

---

## Dependencies

- [GLTFKit2](https://github.com/warrenm/GLTFKit2): glTF/VRM loading via Swift Package Manager
