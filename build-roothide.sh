#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Helium uses xcrun and Swift; build on macOS with Xcode installed." >&2
    exit 1
fi

if [ -z "${THEOS:-}" ] || [ ! -f "$THEOS/makefiles/common.mk" ]; then
    echo "Set THEOS to an installed roothide/theos checkout." >&2
    exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
    echo "Xcode command-line tools are unavailable." >&2
    exit 1
fi

chmod 0755 layout/DEBIAN/postinst layout/DEBIAN/prerm layout/DEBIAN/postrm
make clean THEOS_PACKAGE_SCHEME=roothide
make package FINALPACKAGE=1 THEOS_PACKAGE_SCHEME=roothide

echo "RootHide package:"
find packages -maxdepth 1 -name '*_iphoneos-arm64e.deb' -print
