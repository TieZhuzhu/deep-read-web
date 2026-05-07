# deep-read-web binary

该目录用于放置 Windows 发布产物：

- `deep_read.exe`

典型来源有两种：

1. 运行 `E:\workspace\project\deep-read-web\tools\build_windows.ps1`
2. 运行 `E:\workspace\project\deep-read-web\tools\install_release_binary.ps1` 从 GitHub Release 下载

当 `deep_read.exe` 存在时：

- `E:\workspace\project\deep-read-web\tools\run_deep_read.ps1` 会优先使用它
- `SKILL.md` / Cursor 规则也应优先按二进制模式调用

如果该目录下没有 `deep_read.exe`，则回退到 Python 源码模式。
