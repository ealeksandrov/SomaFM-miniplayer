#!/bin/sh
set -eu

build_number="$(git -C "$SRCROOT" rev-list --count HEAD 2>/dev/null)" ||
    build_number="${CURRENT_PROJECT_VERSION:-1}"

/usr/libexec/PlistBuddy \
    -c "Set :CFBundleVersion $build_number" \
    "$TARGET_BUILD_DIR/$INFOPLIST_PATH"
