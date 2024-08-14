#!/bin/bash

set -eux

BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

GODOT_DIR="$BASE_DIR/godot"
GODOT_CPP_DIR="$BASE_DIR/godot-cpp"
SWIFT_GODOT_DIR="$BASE_DIR/SwiftGodot"
BUILD_DIR=$BASE_DIR/build

editor_build_options=""
editor_configuration="macos.editor"
lib_build_options=""
lib_configuration=""
lib_debug=1
force_editor_rebuild=0
update_api=0
dev_build=0
target="template_debug"

while [ "${1:-}" != "" ]
do
    case "$1" in
        --editor-rebuild)
            force_editor_rebuild=1
        ;;
        --update-api)
            update_api=1
            force_editor_rebuild=1
        ;;
        --lib-debug)
            lib_debug=1
        ;;
        --lib-release)
            lib_debug=0
        ;;
        --dev-build)
            dev_build=1
        ;;
        *)
            echo "Usage: $0 [--editor-rebuild] [--lib-debug] [--lib-release] [--dev-build] [--update-api] [--target <target platform>]"
            exit 1
        ;;
    esac
    shift
done

if [ $lib_debug -eq 0 ]
then
    target="template_release"
fi

if [ $dev_build -eq 1 ]
then
    lib_build_options="$lib_build_options dev_build=yes"
    lib_configuration="$editor_configuration.dev"

    editor_build_options="$editor_build_options dev_build=yes"
    editor_configuration="$editor_configuration.dev"
fi

arm64_godot="$GODOT_DIR/bin/godot.$editor_configuration.arm64"
x86_64_godot="$GODOT_DIR/bin/godot.$editor_configuration.x86_64"
godot_app="$BUILD_DIR/Godot.app"

mkdir -p $BUILD_DIR

if [ ! -x $godot_app ] || [ $force_editor_rebuild -eq 1 ]
then
    echo "Building Godot editor for host"
    rm -rf $godot_app
    rm -f $arm64_godot $x86_64_godot
    cd $GODOT_DIR
    scons p=macos target=editor arch=x86_64 $editor_build_options
    scons p=macos target=editor arch=arm64 $editor_build_options

    lipo -create $x86_64_godot \
                 $arm64_godot \
         -output bin/godot.$editor_configuration.universal

    cp -r $GODOT_DIR/misc/dist/macos_tools.app $godot_app
    mkdir -p $godot_app/Contents/MacOS
    cp bin/godot.$editor_configuration.universal $godot_app/Contents/MacOS/Godot
    chmod +x $godot_app/Contents/MacOS/Godot
    codesign --force --timestamp --options=runtime --entitlements $GODOT_DIR/misc/dist/macos/editor.entitlements -s - $godot_app
fi

if [ $update_api -eq 1 ]
then
    cd $BUILD_DIR
    $godot_app/Contents/MacOS/Godot --dump-extension-api
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
scons p=macos target=$target $lib_build_options arch=x86_64 library_type=static_library
scons p=macos target=$target $lib_build_options arch=arm64 library_type=static_library

lipo -create $GODOT_DIR/bin/libgodot.macos.$target$lib_configuration.x86_64.a \
             $GODOT_DIR/bin/libgodot.macos.$target$lib_configuration.arm64.a \
     -output $GODOT_DIR/bin/libgodot.macos.$target$lib_configuration.arm64_x86_64.a

# Build for iOS devices
scons p=ios target=$target $lib_build_options arch=arm64 library_type=shared_library

# Build for iOS Simulators
scons p=ios target=$target $lib_build_options ios_simulator=yes arch=x86_64 library_type=shared_library
scons p=ios target=$target $lib_build_options ios_simulator=yes arch=arm64 library_type=shared_library

lipo -create $GODOT_DIR/bin/libgodot.ios.$target$lib_configuration.x86_64.simulator.a \
             $GODOT_DIR/bin/libgodot.ios.$target$lib_configuration.arm64.simulator.a \
     -output $GODOT_DIR/bin/libgodot.ios.$target$lib_configuration.arm64_x86_64.simulator.a