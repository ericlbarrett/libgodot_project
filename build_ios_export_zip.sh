#!/bin/bash

set -eux
BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
GODOT_DIR="$BASE_DIR/godot"
BUILD_DIR=$BASE_DIR/build
EXPORT_ZIP="ios"
TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates/4.3.beta"

# Clean up old builds
rm -rf $BUILD_DIR/$EXPORT_ZIP
rm -f $BUILD_DIR/$EXPORT_ZIP.zip

# Build the libraries
./build_libgodot_nanofoo.sh --lib-release
./build_libgodot_nanofoo.sh --lib-debug

# Copy the sample
cp -r $GODOT_DIR/misc/dist/ios_xcode $BUILD_DIR/$EXPORT_ZIP

cp $GODOT_DIR/bin/libgodot.ios.template_debug.arm64.a $BUILD_DIR/$EXPORT_ZIP/libgodot.ios.debug.xcframework/ios-arm64/libgodot.a
lipo -create $GODOT_DIR/bin/libgodot.ios.template_debug.arm64.simulator.a $GODOT_DIR/bin/libgodot.ios.template_debug.x86_64.simulator.a -output $BUILD_DIR/$EXPORT_ZIP/libgodot.ios.debug.xcframework/ios-arm64_x86_64-simulator/libgodot.a

cp $GODOT_DIR/bin/libgodot.ios.template_release.arm64.a $BUILD_DIR/$EXPORT_ZIP/libgodot.ios.release.xcframework/ios-arm64/libgodot.a
lipo -create $GODOT_DIR/bin/libgodot.ios.template_release.arm64.simulator.a $GODOT_DIR/bin/libgodot.ios.template_release.x86_64.simulator.a -output $BUILD_DIR/$EXPORT_ZIP/libgodot.ios.release.xcframework/ios-arm64_x86_64-simulator/libgodot.a

cp -r ~/VulkanSDK/1.3.268.1/MoltenVK/MoltenVK.xcframework $BUILD_DIR/$EXPORT_ZIP

cd $BUILD_DIR/$EXPORT_ZIP
zip -q -9 -r $BUILD_DIR/$EXPORT_ZIP.zip *

rm -f "$TEMPLATE_DIR/$EXPORT_ZIP.zip"
cp $BUILD_DIR/$EXPORT_ZIP.zip "$TEMPLATE_DIR/"
