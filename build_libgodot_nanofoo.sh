#!/bin/bash

set -eux

BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

GODOT_DIR="$BASE_DIR/godot"
GODOT_CPP_DIR="$BASE_DIR/godot-cpp"
SWIFT_GODOT_DIR="$BASE_DIR/SwiftGodot"
BUILD_DIR=$BASE_DIR/build

host_build_options=""
host_debug=1
debug=1
force_host_rebuild=0
update_api=0
target="template_debug"

while [ "${1:-}" != "" ]
do
    case "$1" in
        --host-rebuild)
            force_host_rebuild=1
        ;;
        --host-debug)
            host_debug=1
        ;;        
        --host-release)
            host_debug=0
        ;;
        --update-api)
            update_api=1
            force_host_rebuild=1
        ;;
        --debug)
            debug=1
        ;;
        --release)
            debug=0
        ;;
        *)
            echo "Usage: $0 [--host-debug] [--host-rebuild] [--host-debug] [--host-release] [--debug] [--release] [--update-api] [--target <target platform>]"
            exit 1
        ;;
    esac
    shift
done

if [ $debug -eq 0 ]
then
    target="template_release"
fi

godot_configuration="macos.editor"
if [ $host_debug -eq 1 ]
then
    host_build_options="$host_build_options dev_build=yes"
    godot_configuration="$godot_configuration.dev"
fi

arm64_godot="$GODOT_DIR/bin/godot.$godot_configuration.arm64"
x86_64_godot="$GODOT_DIR/bin/godot.$godot_configuration.x86_64"
godot_app="$BUILD_DIR/Godot.app"

mkdir -p $BUILD_DIR

if [ ! -x $godot_app ] || [ $force_host_rebuild -eq 1 ]
then
    echo "Building Godot editor for host"
    rm -f $arm64_godot $x86_64_godot $godot_app
    cd $GODOT_DIR
    scons p=macos target=editor arch=x86_64 $host_build_options
    scons p=macos target=editor arch=arm64 $host_build_options

    lipo -create $x86_64_godot \
                 $arm64_godot \
         -output bin/godot.$godot_configuration.universal

    cp -r $GODOT_DIR/misc/dist/macos_tools.app $godot_app
    mkdir -p $godot_app/Contents/MacOS
    cp bin/godot.$godot_configuration.universal $godot_app/Contents/MacOS/Godot
    chmod +x $godot_app/Contents/MacOS/Godot
    codesign --force --timestamp --options=runtime --entitlements $GODOT_DIR/misc/dist/macos/editor.entitlements -s - $godot_app
fi

if [ $update_api -eq 1 ]
then
    cd $BUILD_DIR
    $host_godot --dump-extension-api
    cp -v $BUILD_DIR/extension_api.json $GODOT_CPP_DIR/gdextension/
    cp -v $GODOT_DIR/core/extension/gdextension_interface.h $GODOT_CPP_DIR/gdextension/
    cp -v $GODOT_DIR/core/extension/libgodot.h $GODOT_CPP_DIR/gdextension/
    cp -v $BUILD_DIR/extension_api.json $SWIFT_GODOT_DIR/Sources/ExtensionApi/
    cp -v $GODOT_DIR/core/extension/gdextension_interface.h $SWIFT_GODOT_DIR/Sources/GDExtension/include/
    cp -v $GODOT_DIR/core/extension/libgodot.h $SWIFT_GODOT_DIR/Sources/GDExtension/include/

    echo "Successfully updated the GDExtension API."
    exit 0
fi

cd $GODOT_DIR

# Build for Mac OS
scons p=macos target=$target dev_build=yes arch=x86_64 library_type=static_library
scons p=macos target=$target dev_build=yes arch=arm64 library_type=static_library

lipo -create $GODOT_DIR/bin/libgodot.macos.$target.dev.x86_64.a \
             $GODOT_DIR/bin/libgodot.macos.$target.dev.arm64.a \
     -output $GODOT_DIR/bin/libgodot.macos.$target.dev.arm64_x86_64.a

# Build for iOS devices
scons p=ios target=$target dev_build=yes arch=arm64 library_type=static_library

# Build for iOS Simulators
scons p=ios target=$target dev_build=yes ios_simulator=yes arch=x86_64 library_type=shared_library
scons p=ios target=$target dev_build=yes ios_simulator=yes arch=arm64 library_type=shared_library

lipo -create $GODOT_DIR/bin/libgodot.ios.$target.dev.x86_64.simulator.a \
             $GODOT_DIR/bin/libgodot.ios.$target.dev.arm64.simulator.a \
     -output $GODOT_DIR/bin/libgodot.ios.$target.dev.arm64_x86_64.simulator.a

# Create the .xcframework file
rm -rf $BUILD_DIR/libgodot.xcframework
tmp=/tmp/dir-$$
mkdir $tmp
cp $GODOT_DIR/core/extension/libgodot.h $tmp/libgodot.h
cat > $tmp/module.modulemap << EOF
module libgodot {
    header "libgodot.h"
    export *
}
EOF

xcodebuild -create-xcframework \
    -library $GODOT_DIR/bin/libgodot.ios.$target.dev.arm64.a -headers $tmp \
    -library $GODOT_DIR/bin/libgodot.macos.$target.dev.arm64_x86_64.a -headers $tmp \
    -library $GODOT_DIR/bin/libgodot.ios.$target.dev.arm64_x86_64.simulator.a -headers $tmp \
    -output $BUILD_DIR/libgodot.xcframework
rm -rf /tmp/dir-$$