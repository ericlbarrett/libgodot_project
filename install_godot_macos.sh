#!/bin/bash

set -eux
BASE_DIR="$( cd "$(dirname "$0")" ; pwd -P )"
BUILD_DIR=$BASE_DIR/build

cp -R $BUILD_DIR/Godot.app /Applications/GodotNanoFoo.app