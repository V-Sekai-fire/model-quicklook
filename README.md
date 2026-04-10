# VRM QuickLook

macOS QuickLook plugin for `.vrm` and `.glb` 3D avatar files. Provides Finder thumbnails and interactive Space bar previews using SceneKit.

## Requirements

- macOS 13.0 or later (Apple Silicon or Intel)
- Xcode 15 or later
- [xcodegen](https://github.com/yonaskolb/XcodeGen)

## Building

**1. Install xcodegen** (if not already installed):

```bash
brew install xcodegen
```

**2. Generate the Xcode project:**

```bash
xcodegen generate
```

This only needs to be re-run when `project.yml` changes.

**3. Build the app:**

```bash
xcodebuild -project VRMQuickLook.xcodeproj \
  -scheme VRMQuickLook \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

The built app will be in `~/Library/Developer/Xcode/DerivedData/VRMQuickLook-*/Build/Products/Debug/VRMQuickLook.app`.

## Installing

Copy the app to `/Applications` and register it with Launch Services:

```bash
BUILT_APP=$(find ~/Library/Developer/Xcode/DerivedData/VRMQuickLook-* \
  -name "VRMQuickLook.app" -path "*/Debug/*" 2>/dev/null | head -1)

rm -rf /Applications/VRMQuickLook.app
cp -R "$BUILT_APP" /Applications/VRMQuickLook.app

/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -f /Applications/VRMQuickLook.app

qlmanage -r
qlmanage -r cache
```

After installing, **re-index your VRM files** so Spotlight assigns them the correct UTI:

```bash
mdimport /path/to/your/vrm/folder/
```

Then navigate away from the folder in Finder and back — thumbnails will regenerate.

## Uninstalling

```bash
rm -rf /Applications/VRMQuickLook.app
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
  -u /Applications/VRMQuickLook.app
qlmanage -r
```

## Usage

Once installed, `.vrm` and `.glb` files in Finder will show 3D avatar thumbnails automatically. Press **Space** on any such file to open an interactive QuickLook preview where you can rotate and zoom the avatar with the mouse.

Double-clicking a `.vrm` or `.glb` file opens it in macOS Preview (which handles `org.khronos.glb`, the GLB format that VRM is based on).

## Project Structure

```
Sources/
  App/                        Host application (registers the UTI and extensions)
    AppDelegate.swift
    Info.plist                Declares com.vroid.vrm UTI (UTExportedTypeDeclarations)
    VRMQuickLook.entitlements
  PreviewExtension/           QuickLook preview extension (Space bar)
    PreviewViewController.swift
    Info.plist
    VRMPreviewExtension.entitlements
  ThumbnailExtension/         QuickLook thumbnail extension (Finder icons)
    ThumbnailProvider.swift
    Info.plist
    VRMThumbnailExtension.entitlements
project.yml                   xcodegen project definition
```

## Troubleshooting

**Thumbnails still show the old look after updating**

Touch the VRM files to invalidate the Finder cache, then re-open the folder:

```bash
find /path/to/vrm/files -name "*.vrm" -o -name "*.glb" -exec touch {} \;
```

**ThumbnailsAgent stopped responding**

```bash
launchctl start com.apple.quicklook.ThumbnailsAgent
```

**Extension not appearing in QuickLook**

```bash
pluginkit -m -v | grep vroid
```

If missing, re-register:

```bash
pluginkit -a /Applications/VRMQuickLook.app/Contents/PlugIns/VRMThumbnailExtension.appex
pluginkit -a /Applications/VRMQuickLook.app/Contents/PlugIns/VRMPreviewExtension.appex
```

## Dependencies

- [GLTFKit2](https://github.com/warrenm/GLTFKit2) — glTF/VRM loading (fetched automatically via Swift Package Manager)
