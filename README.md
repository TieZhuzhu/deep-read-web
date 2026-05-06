# deep-read-web

利用 Playwright 读取公开网页或需要手动登录后才能访问的网页，并输出最终页面的完整 HTML。

首版目标是先把“可用核心”交付出来：

- 公开页面直接读取，不打开窗口。
- 登录页面自动切换到可见浏览器，等待用户手动鉴权。
- 鉴权成功后输出最终页面 HTML。
- 同时兼容 Codex、Claude Code、Cursor 三种使用方式。

## 当前能力边界

- 首版优先支持 Windows。
- 脚本运行时依赖 Python 和 `playwright`。
- 默认浏览器策略为 `auto -> msedge -> chrome -> chromium`。
- `firefox` 仅在显式指定 `--browser firefox` 时启用。
- 暂不提供无 Python 的可执行发布物；这是第二阶段工作。

## 仓库结构

```text
deep-read-web/
  .codex-plugin/
    plugin.json
  .cursor/
    rules/
      deep-read-web.mdc
  docs/
    implementation-plan.md
  skills/
    deep-read-web/
      SKILL.md
      scripts/
        deep_read.py
```

## 运行前准备

### 1. 安装 Python

Windows 推荐直接验证：

```powershell
py -3 --version
```

如果没有 `py`，可以改用：

```powershell
python --version
```

首版仍然需要 Python，因为当前只交付源码脚本，没有提供 `deep_read.exe` 之类的打包产物。

### 2. 安装 Playwright

安装 Python 包：

```powershell
py -3 -m pip install playwright
```

安装 Playwright 浏览器运行时：

```powershell
py -3 -m playwright install chromium firefox
```

说明：

- 使用系统 Edge 或 Chrome 时，通常不依赖 Playwright 下载品牌浏览器本体。
- 但 `chromium` 回退路径和显式 `firefox` 路径仍建议提前执行安装命令。

## 命令行使用

基础命令：

```powershell
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "https://example.com"
```

显式指定浏览器：

```powershell
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "https://example.com" --browser firefox
```

自定义登录超时：

```powershell
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "https://example.com" --auth-timeout 90
```

支持的浏览器参数：

```text
auto | msedge | msedge-dev | msedge-beta | chrome | chrome-dev | chrome-beta | chromium | firefox
```

脚本行为：

1. 先用无头浏览器读取页面。
2. 如果页面可直接访问，则直接输出完整 HTML 到标准输出。
3. 如果页面像登录页，则打开可见浏览器窗口等待用户手动登录。
4. 登录成功后输出最终页面 HTML。
5. 超时或失败时输出错误到标准错误，并返回非 0 退出码。

退出码约定：

- `0`：成功。
- `1`：依赖缺失、浏览器启动失败、鉴权超时或页面读取失败。
- `2`：命令行参数错误。
- `130`：用户中断执行。

## Windows 辅助脚本

为了减少手工输入，仓库提供了两个 PowerShell 辅助脚本：

### 安装依赖

```powershell
.\tools\setup_windows.ps1
```

如果你还想顺手安装 Playwright Firefox 运行时：

```powershell
.\tools\setup_windows.ps1 -InstallFirefox
```

### 运行读取脚本

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com"
```

指定浏览器与登录超时：

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com" -Browser firefox -AuthTimeout 90
```

### 运行仓库验证

```powershell
.\tools\verify.ps1
```

如果你已经安装好了 Playwright，希望顺带跑一次公开页面的真实 smoke test：

```powershell
.\tools\verify.ps1 -RunNetworkSmoke
```

## Codex 使用方式

本仓库提供了 `.codex-plugin/plugin.json` 和 `skills/deep-read-web/SKILL.md`。

Skill 约定：

- 当用户要求读取某个网页 HTML，或分析一个可能需要登录的页面时，Agent 应调用：

```powershell
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>"
```

- 如果 `py -3` 不可用，再尝试：

```powershell
python skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>"
```

- 如果 Python 不可用，则明确告知当前首版需要 Python 环境。

## Claude Code 使用方式

Claude Code 的 Skill 目录通常是：

- 个人级：`~/.claude/skills/`
- 项目级：`.claude/skills/`

本仓库可以直接复用 `skills/deep-read-web/` 目录内容。常见做法是把该目录复制到：

```text
~/.claude/skills/deep-read-web/
```

或项目内：

```text
.claude/skills/deep-read-web/
```

触发方式仍是自然语言，不需要额外的命令前缀。

## Cursor 使用方式

本仓库提供了 `.cursor/rules/deep-read-web.mdc`。

定位：

- 这是 Cursor Project Rule 兼容层。
- 它不是原生的 `SKILL.md` 安装体验替代品。
- 它的职责是告诉 Cursor Agent 在什么场景下运行 `deep_read.py`。

如果你在 Cursor 中使用本仓库，确保项目规则已启用，并让 Agent 在读取网页时使用该规则文件中的命令格式。

## 常见失败场景

### Python 不存在

表现：

- `py -3` 或 `python` 无法执行。

处理：

- 先安装 Python。
- 当前首版没有提供免 Python 的打包产物。

### Playwright 未安装

表现：

- 脚本提示未检测到 `playwright`。

处理：

```powershell
py -3 -m pip install playwright
py -3 -m playwright install chromium firefox
```

### 页面需要登录但一直没有成功

表现：

- 浏览器窗口已打开，但在超时时间内仍未检测到离开登录态。

处理：

- 确认页面确实已经完成登录并跳转到内容页。
- 如果站点登录流程较慢，可适当提高 `--auth-timeout`。

### 指定浏览器无法启动

表现：

- 脚本提示指定浏览器不可用或启动失败。

处理：

- 检查该浏览器是否已安装。
- 若使用 `firefox`，确认已经执行 `py -3 -m playwright install firefox`。
- 如果只是想读取页面，可先回退到默认 `auto`。

## 后续计划

第二阶段预留项：

- 提供 Windows 单文件可执行产物。
- 提供 GitHub Release 附件。
- 在 Skill 中实现“优先可执行文件，回退 Python”的无 Python 体验。

## CI

仓库已提供 GitHub Actions 基础验证流程：

- 在 Windows 环境安装 Python。
- 安装 `playwright` 与浏览器运行时。
- 执行 `tools/verify.ps1 -RunNetworkSmoke`。

这能保证公开页面读取路径在持续集成里有基础回归保护。
