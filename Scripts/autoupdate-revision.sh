#!/bin/sh
set -eu

build_number="$(git -C "$SRCROOT" rev-list --count HEAD)"

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleVersion $build_number" \
    "$TARGET_BUILD_DIR/$INFOPLIST_PATH"
