# Helium RootHide 版

此目录基于 [AsakuraFuuko/Helium](https://github.com/AsakuraFuuko/Helium) 3.2.6 源码，生成供 iOS 越狱环境下 Sileo 安装的 `iphoneos-arm64e.deb`。RootHide 安装包使用 `.deb` 后缀。

## 获取安装包

在 [ggb15075/Helium 的 Actions 页面](https://github.com/ggb15075/Helium/actions/workflows/roothide.yml) 打开最新的成功构建，下载 `Helium-RootHide-deb`，解压得到 `.deb` 文件，然后通过 Sileo 安装。

## 此版修复

- HUD 只由一个 launchd 服务启动。App 的开关直接控制该服务，避免多个悬浮层叠在一起。
- 关闭 HUD 的选择会保留，重启 SpringBoard 后不会自行重新开启；重新打开后仍由服务维持运行。
- iOS 16 上优先使用 `user/foreground` 域，避免安装脚本使用旧的 `system` 写法触发警告。升级时旧包的卸载脚本仍可能打印一次旧警告。
- 字体绘制参数与上游保持一致。请在设备上核对浅色、深色背景和切换 App 时的表现。

## 从源码编译

需要 macOS、Xcode 15.4 和 `roothide/theos`。设置 `THEOS` 指向 Theos 目录后，运行 `sh build-roothide.sh`。详细说明见 [ROOTHIDE_BUILD.md](ROOTHIDE_BUILD.md)。
