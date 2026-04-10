# VRM QuickLook

macOS QuickLook plugin for `.vrm` 3D avatar files. Adds Finder thumbnails and interactive Space bar previews.

![macOS 13+](https://img.shields.io/badge/macOS-13%2B-blue) ![Apple Silicon + Intel](https://img.shields.io/badge/arch-Apple%20Silicon%20%7C%20Intel-lightgrey)

## Installing

### Option 1 — Download (recommended)

1. Go to the [Releases](../../releases) page and download the latest `VRMQuickLook.app.zip`.
2. Unzip and move **VRMQuickLook.app** to your `/Applications` folder.
3. Open **Terminal** and run:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/VRMQuickLook.app
qlmanage -r && qlmanage -r cache
```

4. Open a folder containing `.vrm` files in Finder — thumbnails will appear. Press **Space** on any `.vrm` file for an interactive 3D preview.

> **First launch:** macOS may show a "cannot be opened" Gatekeeper prompt. Right-click the app in Finder, choose **Open**, then click **Open** again to allow it.

---

### Option 2 — Build from source

**Requirements:** macOS 13+, Xcode 15+, [xcodegen](https://github.com/yonaskolb/XcodeGen)

```bash
brew install xcodegen
git clone https://github.com/YOUR_USERNAME/vrm-quicklook
cd vrm-quicklook
xcodegen generate
```

Open `VRMQuickLook.xcodeproj` in Xcode, set your **Team** under *Signing & Capabilities* for all three targets, then build (⌘B).

```bash
BUILT=$(find ~/Library/Developer/Xcode/DerivedData/VRMQuickLook-* \
  -name "VRMQuickLook.app" -path "*/Debug/*" 2>/dev/null | head -1)

cp -R "$BUILT" /Applications/VRMQuickLook.app

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
| Press **Space** on a `.vrm` file | Interactive 3D preview — drag to rotate, scroll to zoom |

The plugin runs silently in the background — there is no app window or Dock icon.

---

## Troubleshooting

**Thumbnails not showing after install**

Touch the files to bust the Finder cache, then re-open the folder:

```bash
find /path/to/your/vrm/files -name "*.vrm" -exec touch {} \;
killall Finder
```

**Extension not listed in QuickLook**

```bash
pluginkit -m -v | grep vroid
```

If nothing appears, re-register manually:

```bash
pluginkit -a /Applications/VRMQuickLook.app/Contents/PlugIns/VRMPreviewExtension.appex
pluginkit -a /Applications/VRMQuickLook.app/Contents/PlugIns/VRMThumbnailExtension.appex
```

**Space bar preview shows nothing / spinner never disappears**

The VRM file may use unsupported extensions. VRM QuickLook uses [GLTFKit2](https://github.com/warrenm/GLTFKit2) for loading, which renders using standard PBR materials (MToon cel-shading is not supported).

---

## Project Structure

```
Sources/
  App/                    Silent host app — registers the com.vroid.vrm UTI
  PreviewExtension/       Space bar interactive 3D preview
  ThumbnailExtension/     Finder thumbnail generation
project.yml               xcodegen project definition
```

## Dependencies

- [GLTFKit2](https://github.com/warrenm/GLTFKit2) — glTF/VRM loading via Swift Package Manager
