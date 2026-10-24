#!/bin/bash

cd "$(dirname "$0")"
set -eo pipefail
trap 'echo; echo "❌ FAILED. Scroll up and look for the line with \"error\" in it."; read -n 1 -s -r -p "Press any key to close"; exit 1' ERR

echo "▶ 1/7 Finding Homebrew…"
for p in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$p" ] && eval "$($p shellenv)" && break
done
command -v brew >/dev/null || { echo "Homebrew not found. Install it from https://brew.sh first."; false; }

echo "▶ 2/7 Making sure xcodegen and ldid are installed…"
command -v xcodegen >/dev/null || brew install xcodegen
command -v ldid     >/dev/null || brew install ldid

echo "▶ 3/7 Finding Xcode…"
if ! xcode-select -p 2>/dev/null | grep -q "Xcode"; then
  APP="$(mdfind "kMDItemCFBundleIdentifier == 'com.apple.dt.Xcode'" | head -1)"
  [ -n "$APP" ] || { echo "Couldn't find Xcode.app anywhere on this Mac."; false; }
  export DEVELOPER_DIR="$APP/Contents/Developer"
fi
echo "   using: ${DEVELOPER_DIR:-$(xcode-select -p)}"

echo "▶ 4/7 Generating the Xcode project…"
xcodegen

echo "▶ 5/7 Compiling (first run downloads ZIPFoundation, takes a few minutes)…"
xcodebuild -project Bai.xcodeproj -scheme Bai -configuration Release \
  -sdk iphoneos -derivedDataPath build CODE_SIGNING_ALLOWED=NO clean build -quiet

echo "▶ 6/7 Stripping debug symbols and signing…"
APPDIR="build/Build/Products/Release-iphoneos/Bai.app"
strip -Sx "$APPDIR/Bai" || true
rm -rf "$APPDIR.dSYM"
ldid -SBai/Bai.entitlements "$APPDIR/Bai"
ldid -e "$APPDIR/Bai" | grep -q "platform-application" || { echo "Entitlements didn't attach!"; false; }
xattr -cr "$APPDIR"

echo "▶ 7/7 Packaging…"
rm -rf Payload Bai.tipa && mkdir Payload && cp -R "$APPDIR" Payload/
find Payload -name ".DS_Store" -delete
COPYFILE_DISABLE=1 zip -qr -X Bai.tipa Payload && rm -rf Payload

if unzip -p Bai.tipa "Payload/Bai.app/Bai" | strings | grep -q "/Users/"; then
  echo "⚠️  Found a /Users/ path still in the binary — check OTHER_SWIFT_FLAGS in project.yml."
fi

echo
echo "✅ Done: $(pwd)/Bai.tipa  ($(du -h Bai.tipa | cut -f1))"
open -R Bai.tipa
trap - ERR
read -n 1 -s -r -p "Press any key to close"
