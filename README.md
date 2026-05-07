# deep-read-web

使用 Playwright 读取公开网页或登录后网页，并把最终页面的完整 HTML 输出到标准输出。

这个项目把“网页深度读取”做成一个可复用能力，供 Codex、Claude Code、Cursor 等 Agent 场景使用。

## 当前定位

本项目支持两种使用方式：

1. **只安装 skill**
   - 这是主路径
   - 不要求用户完整 clone 仓库
   - 无 Python 用户应优先使用二进制发布物

2. **完整仓库开发/调试**
   - 适合开发、构建、验证、发布
   - 可以使用 `tools/` 下的辅助脚本

## 当前发布策略

采用双发布模型：

### small（默认）

资产名：

```text
deep_read-windows-x64.zip
```

特点：

- 最小下载
- 不内置 Chromium
- 优先使用系统 Edge / Chrome
- 适合大多数 Windows 用户

### full（按需）

资产名：

```text
deep_read-windows-x64-with-chromium.zip
```

特点：

- 内置 Playwright Chromium
- 适合没有系统 Edge / Chrome 的环境
- 只在 small 不够用时再下载

## 运行逻辑

统一运行优先级：

1. 若存在 `bin/deep_read.exe`，优先运行 exe
2. 若没有 exe，再回退 Python 源码模式
3. 若没有 Python，也没有 exe，则先安装发布版

默认浏览器策略：

```text
auto -> msedge -> chrome -> chromium
```

说明：

- Windows 环境默认不要求安装 Chromium / Firefox
- 只有系统没有可用 Edge/Chrome 时，才需要 full 包
- Firefox 不作为默认发布依赖，仅在源码模式且用户显式需要时使用

## CLI 约定

源码入口：

```powershell
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>" [--browser ...] [--auth-timeout ...]
```

二进制入口：

```powershell
skills\deep-read-web\bin\deep_read.exe --HTML_PAGE "<url>" [--browser ...] [--auth-timeout ...]
```

参数：

- `--HTML_PAGE`：必填，必须是合法 `http/https` URL
- `--browser`：默认 `auto`
- `--auth-timeout`：默认 `60`

支持的浏览器值：

```text
auto | msedge | msedge-dev | msedge-beta | chrome | chrome-dev | chrome-beta | chromium | firefox
```

退出码：

- `0`：成功
- `1`：运行时错误、依赖缺失、浏览器启动失败、登录超时
- `2`：参数错误
- `130`：用户中断

输出约定：

- 成功时只把最终 HTML 输出到 `stdout`
- 状态和错误输出到 `stderr`

## 只安装 skill 的使用流程

### A. 有 Python 的用户

1. 安装 skill
2. 直接运行：

```powershell
py -3 scripts\deep_read.py --HTML_PAGE "https://example.com"
```

3. 如果缺少 Playwright：

```powershell
py -3 -m pip install playwright
```

4. 如果之后仍提示缺少 Chromium 回退浏览器，再按需安装：

```powershell
py -3 -m playwright install chromium
```

5. 只有显式需要 Firefox 时，再安装：

```powershell
py -3 -m playwright install firefox
```

### B. 没有 Python 的用户

这是主路径。

1. 安装 skill
2. 先运行 skill 内自带的无 Python 安装脚本：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_binary.ps1
```

3. 该脚本会自动判断：
   - 有系统 Edge/Chrome：下载 **small**
   - 没有系统 Edge/Chrome：下载 **full**
   - 默认直接从 GitHub Release 资产下载，不依赖 GitHub API 的 latest metadata 配额

4. 安装完成后，运行：

```powershell
bin\deep_read.exe --HTML_PAGE "https://example.com"
```

5. 如果 small 包运行时报缺少 Chromium 回退浏览器，则手动升级到 full：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_binary.ps1 -Flavor full
```

6. 如果你要指定某个发布 tag，也可以：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_binary.ps1 -Tag v1.0.0
```

## 完整仓库模式

完整仓库模式主要用于开发与发布。

### 常用脚本

安装源码依赖：

```powershell
.\tools\setup_windows.ps1
```

按需安装 Chromium：

```powershell
.\tools\setup_windows.ps1 -InstallChromium
```

按需安装 Firefox：

```powershell
.\tools\setup_windows.ps1 -InstallFirefox
```

下载发布版到 skill bin 目录：

```powershell
.\tools\install_release_binary.ps1
```

运行：

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com"
```

验证：

```powershell
.\tools\verify.ps1
.\tools\verify.ps1 -RunNetworkSmoke
.\tools\verify.ps1 -UseBinary -RunNetworkSmoke
.\tools\verify.ps1 -UseBinary -RunNetworkSmoke -Browser chromium
```

构建 small：

```powershell
.\tools\build_windows.ps1 -Flavor small
```

构建 full：

```powershell
.\tools\build_windows.ps1 -Flavor full
```

## 页面读取与登录行为

脚本固定采用两阶段流程：

1. 先用无头浏览器访问目标页
2. 若页面像正常内容页，直接输出 HTML
3. 若页面像登录页 / 鉴权页，切换到可视浏览器
4. 等待用户手动完成登录
5. 登录成功后输出最合适内容页的 HTML
6. 超时则返回错误

### 登录页判断

当前采用启发式规则：

- URL 是否包含 `login` / `signin` / `auth` / `sso` / `oauth` / `登录`
- 页面标题是否包含登录关键词
- 是否存在 `input[type=password]`
- 是否存在账号类输入框

### 登录后重定向处理

登录成功后：

- 不要求最终 URL 与原始 URL 完全相等
- 允许站点在登录后跳到新地址
- 最终页必须仍属于目标站点 host 范围
- 最终页不能继续像登录页

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
  .github/
    workflows/
      ci.yml
      release.yml
  skills/
    deep-read-web/
      SKILL.md
      bin/
        README.md
        deep_read.exe
      scripts/
        deep_read.py
        install_binary.ps1
  tools/
    build_windows.ps1
    install_release_binary.ps1
    run_deep_read.ps1
    setup_windows.ps1
    verify.ps1
```

## 三端接入说明

### Codex

- 优先使用 `bin/deep_read.exe`
- 没有 exe 时再回退 Python
- 没有 Python 时，优先运行 skill 内的 `scripts/install_binary.ps1`
- 默认 small，不够再 full

### Claude Code

同样建议：

- 优先 exe
- 回退 Python
- 没 Python 时优先运行 skill 内安装脚本
- 默认 small，不够再 full

### Cursor

Cursor 规则应遵循同样原则：

- 优先 exe
- 回退 Python
- 缺环境时优先提示运行 skill 内安装脚本
- 默认 small，必要时 full

## GitHub Actions

### `ci`

源码模式验证：

- 安装 Python
- 安装 Playwright
- 执行 `tools/verify.ps1 -RunNetworkSmoke`

### `release-binary`

双发布工作流：

- 构建并验证 small 包
- 构建并验证 full 包
- 上传两个构建产物
- tag 触发时创建 Release，并附带两个资产

## 常见失败场景

### 1. 没有 Python，也没有 exe

处理：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_binary.ps1
```

如果 GitHub 下载环境受限，可设置 `GITHUB_TOKEN` 或 `GH_TOKEN` 后重试。

### 2. small 包启动失败，提示缺少 Chromium 回退浏览器

处理：

```powershell
powershell -ExecutionPolicy Bypass -File scripts\install_binary.ps1 -Flavor full
```

### 3. 源码模式缺少 Playwright

处理：

```powershell
py -3 -m pip install playwright
```

若仍缺 Chromium 回退浏览器，再补：

```powershell
py -3 -m playwright install chromium
```

### 4. 显式指定 Firefox 失败

这是预期边界之一：

- 发布版默认不内置 Firefox
- 若确实需要 Firefox，请走源码模式并安装 Playwright Firefox
