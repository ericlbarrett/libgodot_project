#!/bin/bash

set -eux

# Build and install the editor
./build_libgodot_nanofoo.sh --editor-rebuild
./install_godot_macos.sh

# Create the export zip
./build_ios_export_zip.sh

# Build the embeddable .xcframework
./build_libgodot_xcframework.sh