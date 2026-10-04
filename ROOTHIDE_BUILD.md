# RootHide / Sileo build

This source tree is based on `AsakuraFuuko/Helium` main commit
`9714ad880a638f035e4cd7225b4ab9b37ae279e2` (version 3.2.6).

## Build with GitHub Actions

1. Push this tree to a branch named `roothide-build` in a fork you control.
2. Enable GitHub Actions for the fork if GitHub asks you to do so.
3. The push starts **Build RootHide deb**. Once it succeeds, download the
   `Helium-RootHide-deb` artifact from the workflow run. It contains an
   `iphoneos-arm64e.deb` package for Sileo.

The workflow uses the RootHide Theos scheme, the patched iOS 16.5 SDK,
macOS 14 and Xcode 15.4. GitHub has announced retirement of the macOS 14
runner on November 2, 2026. A later migration to macOS 15 will need a
different Xcode version and a new build check.

The package structure and entitlements can be checked in CI. Installation,
the app icon, the HUD and launch daemon still need a RootHide device test.

## HUD lifecycle in the RootHide package

The package starts one launchd job for the HUD. The RootHide app controls that
job when the user turns the HUD on or off; it must not spawn a second `-hud`
process. On iOS 16 and later, installation targets `user/foreground` when that
domain is available. Older systems retain the `system` fallback. The package
stores the user's off choice in `/var/lib/helium/hud.disabled` inside jbroot.

After upgrading from `3.2.6-1`, verify on a RootHide device that turning the
HUD off leaves it off, turning it on shows one clean overlay, switching apps
remains smooth, and a SpringBoard restart restores one HUD while enabled. Also
check white and dark backgrounds. The old package's uninstall script may print
its one-time `system` domain warning during the upgrade.

## Build on a Mac

With Xcode 15.4 and `roothide/theos` installed, set `THEOS` to its directory
and run `sh build-roothide.sh`. The resulting package is in `packages/`.
