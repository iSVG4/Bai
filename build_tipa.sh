#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")"
xcodegen
xcodebuild -project Bai.xcodeproj -scheme Bai -configuration Release \
  -sdk iphoneos -derivedDataPath build CODE_SIGNING_ALLOWED=NO clean build
APP="build/Build/Products/Release-iphoneos/Bai.app"

strip -Sx "$APP/Bai" || true
rm -rf "$APP.dSYM" "build/Build/Products/Release-iphoneos/Bai.app.dSYM"

ldid -SBai/Bai.entitlements "$APP/Bai"

xattr -cr "$APP"

rm -rf Payload Bai.tipa && mkdir Payload && cp -R "$APP" Payload/
find Payload -name ".DS_Store" -delete

COPYFILE_DISABLE=1 zip -qr -X Bai.tipa Payload && rm -rf Payload

echo "Checking for leftover absolute paths in the binary..."
if unzip -p Bai.tipa "Payload/Bai.app/Bai" | strings | grep -q "/Users/"; then
  echo "⚠️  Found a /Users/ path still in the binary — check OTHER_SWIFT_FLAGS."
else
  echo "✅ No /Users/ paths found in the binary."
fi

echo "Done: Bai.tipa -> open it with TrollStore"
