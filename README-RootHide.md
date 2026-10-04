# Helium 的 RootHide 构建

此目录基于 [AsakuraFuuko/Helium](https://github.com/AsakuraFuuko/Helium) 主分支提交 `9714ad880a638f035e4cd7225b4ab9b37ae279e2`。目标产物是供 RootHide 包管理器安装的 `iphoneos-arm64e.deb`。包内的应用和守护进程路径按 RootHide 的 jbroot 视角保持为 `/Applications` 和 `/Library`，不写死 `/var/jb`。

## 从源码构建

需要 macOS、Xcode 及 [roothide/theos](https://github.com/roothide/theos)。Theos 的 `sdks` 目录应包含 iOS 16.5 SDK。设置 `THEOS` 指向 Theos 目录后，在此目录执行：

```sh
sh build-roothide.sh
```

输出文件位于 `packages/`，名称以 `_iphoneos-arm64e.deb` 结尾。也可以将此工程放入自己的 GitHub 仓库；启用 fork 的 Actions 后，推送到 `roothide-build` 分支会运行 **Build RootHide deb** 工作流。构建完成后下载 `Helium-RootHide-deb` 产物。若要使用手动运行按钮，工作流文件还需存在于仓库默认分支。

本适配将原来只用于 TrollStore `.tipa` 的暂存步骤排除在 RootHide `.deb` 构建之外，更新了包架构、签名权限及安装维护脚本。安装脚本会刷新应用注册并尝试加载 HUD 守护进程；卸载和升级时会停止守护进程。

## 已封装的 3.2.5 包

工作区 `dist/com.leemin.helium_3.2.5-roothide1_iphoneos-arm64e.deb` 由该仓库发布的 [v3.2.5 Helium.tipa](https://github.com/AsakuraFuuko/Helium/releases/tag/v3.2.5) 中的已编译程序重新签名和封装得到。它不包含主分支 3.2.6 的源码改动，也不等同于主分支重新编译产物。请优先在可用的 macOS 环境运行上面的源码构建以获得 3.2.6 包。

未在 RootHide 真机上验证运行。首次安装时，应检查 Helium 图标、HUD 显示、设置保存，以及守护进程是否启动。如果图标或 HUD 未出现，可重新启动用户空间后再检查。
