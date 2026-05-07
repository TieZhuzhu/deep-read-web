# deep-read-web

使用 Playwright 读取公开网页或登录后网页，并把最终页面的完整 HTML 输出到标准输出。

这个项目的目标是把“网页深度读取”做成一个可复用的 Skill / Plugin / IDE 规则能力，供 Codex、Claude Code、Cursor 等 Agent 场景使用。

## 当前状态

当前仓库已经完成首版核心能力：

- 支持公开页面无头读取
- 支持疑似登录页切换到可视浏览器，等待用户手动登录
- 支持登录后重定向，再自动选择目标站点范围内的最佳内容页
- 支持通过 Skill / Codex Plugin / Cursor rule 接入
- 支持 Windows 二进制发布路径：**优先 `deep_read.exe`，回退 Python 源码模式**

## 能力边界

- 当前优先支持 Windows
- 核心实现语言仍然是 Python
- 运行时第三方 Python 依赖仅使用 `playwright`
- 默认浏览器策略为：`auto -> msedge -> chrome -> chromium`
- `firefox` 仅在显式指定 `--browser firefox` 时启用
- 无 Python 体验通过 **Windows 发布版 `deep_read.exe`** 提供

## 仓库结构

```text
deep-read-web/
  README.md
  docs/
    implementation-plan.md
  .codex-plugin/
    plugin.json
  .cursor/
    rules/
      deep-read-web.mdc
  skills/
    deep-read-web/
      SKILL.md
      bin/
        README.md
        deep_read.exe              # 发布物，默认不提交到仓库
      scripts/
        deep_read.py
  tools/
    build_windows.ps1
    install_release_binary.ps1
    run_deep_read.ps1
    setup_windows.ps1
    verify.ps1
```

## 运行模式

项目现在有两种运行模式。

### 1. 二进制模式（无 Python 用户优先）

如果存在下面这个文件：

```text
skills/deep-read-web/bin/deep_read.exe
```

则：

- `tools/run_deep_read.ps1` 会优先调用它
- Skill 文档和 Cursor 规则也应优先走 exe
- 用户本机**不需要安装 Python**

如果你已经在 GitHub Release 中发布了二进制包，可以直接下载到本地：

```powershell
.\tools\install_release_binary.ps1
```

这会从默认仓库 `TieZhuzhu/deep-read-web` 的最新 Release 下载：

- `deep_read-windows-x64.zip`

并解压安装到：

```text
skills/deep-read-web/bin/deep_read.exe
```

> 如果你要安装指定 tag 的发布物，也可以传 `-Tag`。

### 2. 源码模式（开发 / 调试 / 回退）

当 `deep_read.exe` 不存在时，回退到 Python 源码模式：

```powershell
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "https://example.com"
```

如果 `py -3` 不可用，再尝试：

```powershell
python skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "https://example.com"
```

## CLI 约定

统一入口：

```powershell
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>" [--browser ...] [--auth-timeout ...]
```

或二进制入口：

```powershell
skills\deep-read-web\bin\deep_read.exe --HTML_PAGE "<url>" [--browser ...] [--auth-timeout ...]
```

参数约定：

- `--HTML_PAGE`：必填，必须是合法 `http/https` URL
- `--browser`：可选，默认 `auto`
- `--auth-timeout`：可选，默认 `60`

支持的浏览器值：

```text
auto | msedge | msedge-dev | msedge-beta | chrome | chrome-dev | chrome-beta | chromium | firefox
```

退出码约定：

- `0`：成功
- `1`：依赖缺失、浏览器启动失败、读取失败、登录超时等运行时错误
- `2`：命令行参数错误
- `130`：用户中断

输出约定：

- 成功时：**只把最终 HTML 输出到 `stdout`**
- 状态信息与错误信息：输出到 `stderr`

## 页面读取与登录行为

脚本的行为是固定的两阶段流程：

1. 先用无头浏览器访问目标页
2. 若页面像正常内容页，直接输出 HTML，不弹窗口
3. 若页面像登录页 / 鉴权页，则切换为可视浏览器
4. 等待用户手动完成登录
5. 登录成功后，输出当前最合适的内容页 HTML
6. 超时则返回错误

### 登录页判断

当前使用启发式规则，不做站点定制：

- URL 是否包含 `login` / `signin` / `auth` / `sso` / `oauth` / `登录` 等关键词
- 页面标题是否包含登录关键词
- 页面中是否存在 `input[type=password]`
- 是否存在账号类输入框

### 登录后重定向处理

登录成功**不要求最终 URL 必须与原始 URL 完全一致**。

当前规则是：

- 最终页必须仍是 `http/https`
- 最终页不能仍然像登录页
- 最终页必须属于目标站点 host 范围内
  - 同 host
  - 或父子域名关系
- 会在多个页面中优先选择最像目标内容页的页面

这保证了下面这类场景可以正常工作：

- 原始页：`https://docs.example.com/a`
- 登录后：`https://docs.example.com/a?ticket=...`

或者：

- 原始页：`https://example.com/report/1`
- 登录后：`https://reader.example.com/report/1`

## 安装与准备

### 源码模式：安装 Python 与 Playwright

检查 Python：

```powershell
py -3 --version
```

或：

```powershell
python --version
```

安装依赖：

```powershell
.\tools\setup_windows.ps1
```

如需额外安装 Playwright Firefox 运行时：

```powershell
.\tools\setup_windows.ps1 -InstallFirefox
```

### 二进制模式：下载发布版

如果你不想安装 Python：

```powershell
.\tools\install_release_binary.ps1
```

下载完成后即可运行：

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com"
```

## 常用命令

### 读取页面

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com"
```

指定浏览器：

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com" -Browser firefox
```

自定义登录超时：

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com" -AuthTimeout 90
```

### 本地验证

源码模式验证：

```powershell
.\tools\verify.ps1
.\tools\verify.ps1 -RunNetworkSmoke
```

二进制模式验证：

```powershell
.\tools\verify.ps1 -UseBinary
.\tools\verify.ps1 -UseBinary -RunNetworkSmoke
```

### 构建 Windows 发布版

本地构建：

```powershell
.\tools\build_windows.ps1
```

如果你希望构建时把 Playwright Chromium 一并打包进发布物：

```powershell
.\tools\build_windows.ps1 -BundleChromium
```

构建结果：

- 可执行文件：`skills/deep-read-web/bin/deep_read.exe`
- 压缩包：`dist/deep_read-windows-x64.zip`

## 三端接入说明

### Codex

仓库已提供：

- `.codex-plugin/plugin.json`
- `skills/deep-read-web/SKILL.md`

建议调用优先级：

1. 若存在 `skills/deep-read-web/bin/deep_read.exe`，优先调用 exe
2. 否则调用 Python 脚本
3. 若两者都不可用，明确提示用户缺少运行环境

### Claude Code

可直接复用：

```text
skills/deep-read-web/
```

安装到：

```text
~/.claude/skills/deep-read-web/
```

或项目级：

```text
.claude/skills/deep-read-web/
```

同样建议：**优先 exe，回退 Python**。

### Cursor

仓库已提供：

```text
.cursor/rules/deep-read-web.mdc
```

该规则的职责是：

- 告诉 Cursor 在什么情况下调用 `deep-read-web`
- 优先消费 exe
- 若没有 exe 再退回 Python 脚本
- 将 `stdout` 作为最终 HTML 上下文

## GitHub Actions

当前提供两个工作流：

### 1. `ci`

用于源码模式验证：

- 安装 Python
- 安装 Playwright
- 运行 `tools/verify.ps1 -RunNetworkSmoke`

### 2. `release-binary`

用于构建 Windows 发布版：

- 构建 `deep_read.exe`
- 验证二进制可执行文件
- 上传 `deep_read-windows-x64.zip` 构建产物
- 在 tag 推送时创建 GitHub Release

## 常见失败场景

### 1. 没有 Python，也没有 exe

表现：

- `run_deep_read.ps1` 提示没有可用运行环境

处理：

- 运行 `install_release_binary.ps1` 下载发布版
- 或安装 Python 后使用源码模式

### 2. 缺少 Playwright

表现：

- 源码模式下脚本提示未检测到 `playwright`

处理：

```powershell
.\tools\setup_windows.ps1
```

### 3. 登录超时

表现：

- 浏览器窗口已打开，但在超时时间内仍未检测到回到目标内容页

处理：

- 确认站点已真正完成登录并跳转到内容页
- 适当增大 `-AuthTimeout` 或 `--auth-timeout`

### 4. 二进制模式下浏览器启动失败

表现：

- 没有系统 Edge / Chrome
- 且当前发布版未包含所需浏览器运行时

处理：

- 优先使用系统 Edge / Chrome
- 或使用 `-BundleChromium` 构建自己的发布版
- 或退回 Python 源码模式安装 Playwright 浏览器运行时

## 后续计划

下一阶段仍可继续增强：

- 更完整的跨平台发布（macOS / Linux）
- 可选 Firefox 打包发布
- 更细粒度的 Release 安装脚本
- 更完整的真实登录页回归验证
