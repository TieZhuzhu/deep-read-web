# deep-read-web binary

该目录用于放置 `deep-read-web` 的 Windows 二进制运行文件。

当前发布采用双资产模型：

1. `deep_read-windows-x64.zip`
   - small 包
   - 不内置 Chromium
   - 优先使用系统 Edge / Chrome
   - 适合大多数 Windows 环境

2. `deep_read-windows-x64-with-chromium.zip`
   - full 包
   - 内置 Playwright Chromium
   - 适合没有系统 Edge / Chrome，或需要完整回退浏览器的环境

安装或解压后，本目录下应放置：

- `deep_read.exe`

使用约定：

- 如果本目录下存在 `deep_read.exe`，运行入口应优先使用它
- 如果本目录下不存在 `deep_read.exe`，则回退到 Python 源码模式

典型来源：

- skill 内安装：`scripts/install_binary.ps1`
- 仓库级安装：`tools/install_release_binary.ps1`
- 本地构建：`tools/build_windows.ps1 -Flavor small|full`

说明：

- 本目录只负责承载二进制运行文件
- 只安装 skill 的场景，优先使用 `scripts/install_binary.ps1`
- 仓库级的构建、发布、下载与安装说明，以项目根目录的 `README.md` 为准
