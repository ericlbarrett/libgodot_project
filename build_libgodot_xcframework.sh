#!/bin/bash

set -eux
BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
GODOT_DIR="$BASE_DIR/godot"
BUILD_DIR=$BASE_DIR/build

lib_configuration=""
target="template_debug"

./build_libgodot_nanofoo.sh --lib-debug

# Create the .xcframework file
rm -rf $BUILD_DIR/libgodot.xcframework
tmp=/tmp/dir-$$
mkdir $tmp
cp $GODOT_DIR/core/extension/gdextension_interface.h $tmp/gdextension_interface.h
cp $GODOT_DIR/core/extension/libgodot.h $tmp/libgodot.h
cat > $tmp/module.modulemap << EOF
module libgodot {
    header "libgodot.h"
    export *
}
EOF

xcodebuild -create-xcframework \
    -library $GODOT_DIR/bin/libgodot.ios.$target$lib_configuration.arm64.a -headers $tmp \
    -library $GODOT_DIR/bin/libgodot.macos.$target$lib_configuration.arm64_x86_64.a -headers $tmp \
    -library $GODOT_DIR/bin/libgodot.ios.$target$lib_configuration.arm64_x86_64.simulator.a -headers $tmp \
    -output $BUILD_DIR/libgodot.xcframework
rm -rf /tmp/dir-$$