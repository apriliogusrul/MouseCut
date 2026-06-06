#!/bin/bash
set -e

echo "=== Building MouseCut ==="

# 1. Clean previous build if exists
rm -rf MouseCut.app
rm -f MouseCut

# 2. Create bundle directories
mkdir -p MouseCut.app/Contents/MacOS
mkdir -p MouseCut.app/Contents/Resources

# 3. Find MacOS SDK path
SDK_PATH=$(xcrun --show-sdk-path)
echo "Using SDK: $SDK_PATH"

# 4. Compile Swift sources
echo "Compiling Swift files..."
swiftc -sdk "$SDK_PATH" Sources/*.swift -o MouseCut.app/Contents/MacOS/MouseCut

# 5. Copy Info.plist
echo "Copying Info.plist..."
cp Resources/Info.plist MouseCut.app/Contents/Info.plist

# 6. Ad-hoc sign the bundle
echo "Ad-hoc codesigning MouseCut.app..."
codesign --force --deep --sign - MouseCut.app

echo "=== Build Successful! MouseCut.app is ready ==="
