# deep-read-web

使用 Playwright 读取公开网页或登录后网页，并把最终页面的完整 HTML 输出到标准输出。

这个项目把“网页深度读取”做成一个可复用能力，供 Codex、Claude Code、Cursor 等 Agent 场景使用。

## 当前设计结论

当前发布策略已经调整为：

- **small 包**：最小下载，优先使用系统 Edge/Chrome，不内置 Chromium
- **full 包**：按需下载，内置 Playwright Chromium 回退浏览器
- **默认推荐 small**：Windows 机器通常已经有 Edge 或 Chrome，不必为大多数用户预装 Chromium / Firefox
- **Firefox 不做发布版默认依赖**：只有源码模式且用户显式需要时才安装

这意味着：

1. 能用系统浏览器时，尽量走最小下载
2. 只有本机没有可用 Chromium 系浏览器时，再下载 full 包
3. Skill 本身保持精简，不把大体积浏览器运行时直接塞进 skill 仓库

## 核心能力

- 公开页面无头读取
- 登录页自动切换到可视浏览器，等待用户手动登录
- 登录后允许重定向
- 自动选择目标站点范围内的最佳内容页
- 输出最终完整 HTML 到 `stdout`

## 能力边界

- 当前优先支持 Windows
- 核心实现语言仍然是 Python
- Python 运行时第三方依赖仅使用 `playwright`
- 默认浏览器策略为：`auto -> msedge -> chrome -> chromium`
- `firefox` 仅在显式指定 `--browser firefox` 时启用
- 发布版默认不内置 Firefox

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
        deep_read.exe                 # 本地构建或发布版安装后生成，不提交
      scripts/
        deep_read.py
  tools/
    build_windows.ps1
    install_release_binary.ps1
    run_deep_read.ps1
    setup_windows.ps1
    verify.ps1
```

## 两类发布物

### 1. small 包（默认）

资产名：

```text
deep_read-windows-x64.zip
```

特点：

- 最小下载
- 不内置 Chromium
- 优先使用系统 `msedge` / `chrome`
- 最适合大多数 Windows 用户

适用场景：

- Windows 已安装 Edge 或 Chrome
- 希望下载体积尽量小
- 愿意把浏览器依赖交给系统环境

### 2. full 包（按需）

资产名：

```text
deep_read-windows-x64-with-chromium.zip
```

特点：

- 下载更大
- 内置 Playwright Chromium 回退浏览器
- 没有系统 Edge / Chrome 时也能运行

适用场景：

- 极简系统
- 没有 Edge/Chrome
- 需要更强的“开箱即用”保证

## 最小运行方案

这是当前推荐的最小运行策略：

1. Skill 保持精简
2. 默认只安装 small 包
3. 运行时优先用系统 Edge / Chrome
4. 如果 small 包启动失败且提示缺少 Chromium 回退浏览器，再安装 full 包

也就是：

- **先最小下载**
- **不够再按需升级**

## 安装方式

### 1. 无 Python 用户：优先安装发布版

默认自动判断：

```powershell
.\tools\install_release_binary.ps1
```

脚本会按下面的策略选择下载哪个包：

- 如果检测到系统 Edge/Chrome：下载 **small**
- 如果没检测到：下载 **full**

也可以手动指定：

```powershell
.\tools\install_release_binary.ps1 -Flavor small
.\tools\install_release_binary.ps1 -Flavor full
```

### 2. 开发 / 调试用户：源码模式

检查 Python：

```powershell
py -3 --version
```

安装依赖：

```powershell
.\tools\setup_windows.ps1
```

如果你需要源码模式的 Chromium 运行时：

```powershell
.\tools\setup_windows.ps1 -InstallChromium
```

如果你显式需要 Firefox 运行时：

```powershell
.\tools\setup_windows.ps1 -InstallFirefox
```

> 注意：Windows 常规场景下，不需要默认安装 Chromium / Firefox。`setup_windows.ps1` 默认只安装 Python 包，不默认下载浏览器运行时；只有你显式传 `-InstallChromium` 或 `-InstallFirefox` 时才下载。

## 运行优先级

统一规则：

1. 若存在 `skills/deep-read-web/bin/deep_read.exe`，优先使用 exe
2. 若 exe 不存在，则回退 Python 源码模式
3. 若两者都不可用，则提示用户安装发布版或 Python

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

退出码约定：

- `0`：成功
- `1`：依赖缺失、浏览器启动失败、读取失败、登录超时等运行时错误
- `2`：命令行参数错误
- `130`：用户中断

输出约定：

- 成功时只把最终 HTML 输出到 `stdout`
- 状态和错误输出到 `stderr`

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

## 常用命令

### 运行

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com"
```

指定浏览器：

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com" -Browser firefox
```

自定义超时：

```powershell
.\tools\run_deep_read.ps1 -HtmlPage "https://example.com" -AuthTimeout 90
```

### 本地验证

源码模式：

```powershell
.\tools\verify.ps1
.\tools\verify.ps1 -RunNetworkSmoke
```

二进制模式：

```powershell
.\tools\verify.ps1 -UseBinary
.\tools\verify.ps1 -UseBinary -RunNetworkSmoke
```

如果你想验证 full 包里的 Chromium 回退浏览器：

```powershell
.\tools\verify.ps1 -UseBinary -RunNetworkSmoke -Browser chromium
```

### 本地构建

构建 small 包：

```powershell
.\tools\build_windows.ps1 -Flavor small
```

构建 full 包：

```powershell
.\tools\build_windows.ps1 -Flavor full
```

构建结果：

- `skills/deep-read-web/bin/deep_read.exe`
- `dist/deep_read-windows-x64.zip`
- `dist/deep_read-windows-x64-with-chromium.zip`

## 三端接入说明

### Codex

仓库提供：

- `.codex-plugin/plugin.json`
- `skills/deep-read-web/SKILL.md`

建议调用顺序：

1. 有 exe 就优先用 exe
2. 没 exe 再回退 Python
3. 没 Python 时优先提示用户安装发布版
4. 默认优先 small 包，只有缺浏览器时再建议 full 包

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

推荐规则同样是：

- 优先 exe
- 回退 Python
- 先 small，必要时 full

### Cursor

仓库提供：

```text
.cursor/rules/deep-read-web.mdc
```

该规则会指导 Cursor：

- 遇到网页深读需求时调用 deep-read-web
- 优先使用 exe
- 若没有 exe 再回退 Python
- 缺环境时优先指向 small 包安装
- 只有 small 包不满足时再切换 full 包

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

### 1. small 包启动失败，提示缺少 Chromium 回退浏览器

这说明：

- 本机没有可用系统 Edge/Chrome
- 当前又在使用不内置 Chromium 的 small 包

处理：

```powershell
.\tools\install_release_binary.ps1 -Flavor full
```

### 2. 源码模式缺少 Playwright

处理：

```powershell
.\tools\setup_windows.ps1
```

如果仍缺少 Chromium 回退浏览器，再执行：

```powershell
.\tools\setup_windows.ps1 -InstallChromium
```

### 3. 登录超时

处理：

- 确认登录后确实进入内容页
- 适当增大 `--auth-timeout` 或 `-AuthTimeout`

### 4. 显式指定 Firefox 失败

这是预期边界之一：

- 发布版默认不内置 Firefox
- 若确实需要 Firefox，请走源码模式并安装 Playwright Firefox

## 后续计划

下一阶段仍可继续优化：

- macOS / Linux 发布
- 更细粒度的浏览器按需下载机制
- 自动升级 small -> full 的辅助脚本
- 更完整的真实登录页验收
