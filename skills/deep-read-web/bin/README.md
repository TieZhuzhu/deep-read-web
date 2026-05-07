# deep-read-web binary

该目录用于放置本地构建或从 GitHub Release 安装得到的 Windows 发布物。

当前采用双发布模型：

1. `deep_read-windows-x64.zip`
   - small 包
   - 不内置 Chromium
   - 优先使用系统 Edge/Chrome
   - 默认推荐

2. `deep_read-windows-x64-with-chromium.zip`
   - full 包
   - 内置 Playwright Chromium
   - 只有本机没有 Edge/Chrome，或 small 包不够用时再下载

解压或安装后，本目录下统一放置：

- `deep_read.exe`

典型来源：

- 本地构建：`E:\workspace\project\deep-read-web\tools\build_windows.ps1 -Flavor small|full`
- 发布版安装：`E:\workspace\project\deep-read-web\tools\install_release_binary.ps1 -Flavor auto|small|full`

运行优先级：

- `tools/run_deep_read.ps1` 会优先使用这里的 `deep_read.exe`
- 若没有 exe，再回退到 Python 源码模式
