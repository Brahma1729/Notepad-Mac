#!/bin/bash
# Builds NotepadMac.app into build/ — a standalone, launchable macOS app bundle.
set -euo pipefail

cd "$(dirname "$0")"          # always run from the repo root, no matter where called from
APP_NAME="NotepadMac"
BUNDLE="${APP_NAME}.app"
BUILD_DIR="build"
CONTENTS="$BUILD_DIR/$BUNDLE/Contents"
MACOS_DIR="$CONTENTS/MacOS"

echo "==> Building release binary..."
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/$APP_NAME"
[ -x "$BIN_PATH" ] || { echo "ERROR: binary not found at $BIN_PATH"; exit 1; }

echo "==> Assembling app bundle at $BUILD_DIR/$BUNDLE ..."
rm -rf "$CONTENTS"
mkdir -p "$MACOS_DIR"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"

# Info.plist — required for Finder double-click launch, menu bar name, and file associations.
cat > "$CONTENTS/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>            <string>NotepadMac</string>
    <key>CFBundleDisplayName</key>     <string>NotepadMac</string>
    <key>CFBundleExecutable</key>      <string>NotepadMac</string>
    <key>CFBundleIdentifier</key>      <string>com.example.notepadmack</string>
    <key>CFBundleVersion</key>         <string>1.0.0</string>
    <key>CFBundleShortVersionString</key> <string>1.0</string>
    <key>CFBundlePackageType</key>     <string>APPL</string>
    <key>LSMinimumSystemVersion</key>  <string>13.0</string>
    <key>NSHighResolutionCapable</key> <true/>
    <key>NSPrincipalClass</key>        <string>NSApplication</string>
    <!-- Generic text documents open in the app from Finder -->
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key>      <string>Text Document</string>
            <key>LSItemContentTypes</key>
            <array>
                <string>public.plain-text</string>
            </array>
            <key>CFBundleTypeRole</key>      <string>Editor</string>
        </dict>
    </array>
</dict>
</plist>
PLIST

# PkgInfo — standard bundle signature.
printf 'APPL????' > "$CONTENTS/PkgInfo"

echo "==> Ad-hoc code signing..."
codesign --force --sign - "$BUILD_DIR/$BUNDLE" 2>/dev/null || echo "(codesign skipped)"

echo ""
echo "✅ Done: $BUILD_DIR/$BUNDLE"
echo "   Launch with:  open $BUILD_DIR/$BUNDLE"
