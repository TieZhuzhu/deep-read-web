# deep-read-web 实施方案

## 1. 目标

本项目计划提供一个可发布到 GitHub 的网页深度读取能力，支持被 Codex、Claude Code 等 Agent 客户端复用，并尽量兼容 Cursor 这类 IDE Agent 工作流。

用户通过自然语言触发能力后，底层脚本负责：

1. 接收目标网页 URL。
2. 尝试无界面读取页面 HTML。
3. 如果页面需要登录，则拉起浏览器让用户手动完成鉴权。
4. 最长等待 1 分钟确认鉴权成功。
5. 成功后输出当前页面完整 HTML。

## 2. 当前假设

1. 第一版优先支持 Windows。
2. 第一版核心实现语言仍使用 Python。
3. Python 脚本运行时只依赖 `playwright`，不额外引入其他第三方 Python 包。
4. Skill 的主要使用方式是“自然语言触发”，而不是要求用户手工拼接复杂命令。

这些假设是为了先把方案做稳。如果后续你要把 Linux、macOS、无 Python 环境都一并拉满，我们可以在第二阶段继续扩展。

## 3. 关于“没有 Python 怎么办”

这是最关键的兼容性问题。只交付 `deep_read.py` 会让很多非开发者无法直接使用，因此建议把交付方式拆成“开发态”和“发布态”。

### 3.1 推荐方案

推荐采用双轨交付：

1. 源码交付：保留 `deep_read.py`，方便开发、调试、二次修改。
2. 发布交付：额外提供可直接运行的打包产物，优先是 Windows 单文件可执行程序。

这样做的好处是：

1. Agent/开发者环境可以直接跑 Python 脚本。
2. 普通用户即使没有安装 Python，也能直接运行发布产物。
3. Skill 在调用时可以优先探测本地是否有 Python，没有则自动走可执行文件。

### 3.2 具体落地建议

建议按下面顺序兼容：

1. 第一优先：`python + playwright` 源码方式。
2. 第二优先：Windows 预编译 `deep_read.exe`。
3. 第三优先：未来再补 macOS/Linux 发布物。

### 3.3 打包方式建议

运行时不要求用户安装 Python，但“打包阶段”仍然可以使用专门的构建工具来产出可执行文件。这类工具只出现在发布流水线中，不进入脚本运行时依赖。

建议：

1. 仓库保留纯 Python 源码实现。
2. 通过 GitHub Actions 生成 Release 附件。
3. Release 中上传 `deep_read-windows-x64.zip` 这类产物。

### 3.4 不推荐的方式

以下方案不建议作为第一版主方案：

1. 运行时自动帮用户安装 Python。
2. 运行时自动修改系统浏览器安装。
3. 首版就同时支持所有操作系统的免安装运行。

原因很简单：不稳定、不可控、失败路径多，且会让 Skill 的体验非常脆弱。

## 4. 关于自然语言交互与浏览器兼容

## 4.1 自然语言交互的实际工作方式

用户在 Codex、Claude Code、Cursor 中不会直接“理解 Python”，而是通过自然语言表达需求，例如：

1. “读取这个页面的 HTML：`https://example.com/private/doc`”
2. “打开这个登录后页面，把当前 HTML 给我”
3. “分析这个页面内容，如果需要登录我来手动登录”

Skill 的职责是把自然语言转换成一个明确的底层调用，例如：

```bash
python deep_read.py --HTML_PAGE "https://example.com/private/doc"
```

因此，Skill 层负责“理解用户意图”，脚本层负责“稳定执行浏览器动作”。

## 4.2 浏览器兼容策略

根据 Playwright 官方文档，第一版建议采用“分层兼容”。

### A. Chromium 系列

Chromium 系列是首选，兼容性最好，尤其适合登录跳转与页面 HTML 抓取。

优先兼容以下浏览器通道：

1. `msedge`
2. `msedge-dev`
3. `msedge-beta`
4. `chrome`
5. `chrome-dev`
6. `chrome-beta`
7. `chromium`

其中：

1. `msedge`、`chrome` 表示使用系统已安装的品牌浏览器。
2. `chromium` 表示回退到 Playwright 自带浏览器。

### B. Firefox

Firefox 可以兼容，但需要明确边界：

1. Playwright 支持 `firefox` 引擎。
2. 更稳妥的做法是使用 Playwright 自带的 Firefox。
3. 不建议第一版承诺“直接控制用户本机安装的 Firefox 品牌版本”。

因此建议：

1. 第一版允许 `--browser firefox`。
2. 但默认自动选择策略仍优先 Chromium 系列。

### C. Safari / WebKit

不建议第一版主打 Safari。

原因：

1. Windows 不存在原生 Safari 场景。
2. WebKit 更适合作为测试兼容层，不适合作为当前登录抓取主路径。

## 4.3 自动浏览器选择策略

建议脚本支持一个参数：

```bash
--browser auto|msedge|msedge-dev|chrome|chrome-dev|firefox|chromium
```

默认值：`auto`

`auto` 规则建议如下：

1. 如果用户明确指定浏览器，则按指定浏览器执行。
2. 如果未指定，则优先寻找系统已安装的 `msedge`。
3. 若无 `msedge`，则寻找 `chrome`。
4. 若都不存在，则回退到 Playwright 自带 `chromium`。
5. 如果用户显式要求 `firefox`，则使用 Playwright 的 `firefox`。

这样可以兼容“有人默认用 Edge，有人默认用 Chrome，有人只想用 Firefox”的场景。

## 5. 登录与无登录的处理策略

第一版建议保持简单，不做站点定制化适配，只做启发式判断。

### 5.1 无登录场景

流程：

1. 用无头浏览器打开目标页面。
2. 如果检测结果像正常内容页，则直接输出 HTML。
3. 此时不打开任何可见窗口。

### 5.2 需要登录场景

流程：

1. 用无头浏览器打开目标页面。
2. 如果像登录页，则关闭无头流程。
3. 拉起可见浏览器窗口。
4. 提示用户在 1 分钟内手动登录。
5. 持续检测是否已离开登录态并进入可读内容页。
6. 成功后输出 HTML。
7. 超过 1 分钟仍未成功，则报错并终止。

### 5.3 登录成功判定

第一版使用启发式规则：

1. URL 是否仍包含登录关键词。
2. 页面标题是否包含登录关键词。
3. 页面中是否仍存在密码输入框。
4. 是否跳回目标站点内容页。
5. 是否存在明显的正文内容页面结构。

注意：这个判定不能保证覆盖所有网站，但足够支撑第一版发布。

## 6. Skill 形态与仓库组织建议

建议仓库同时兼顾以下几种使用方式：

1. 作为通用 Skill 仓库被 GitHub 引用。
2. 作为 Codex Plugin 安装。
3. 作为 Claude Code 本地 Skill 安装。
4. 作为 Cursor 规则或辅助工具接入。

建议结构：

```text
deep-read-web/
  README.md
  docs/
    implementation-plan.md
  .codex-plugin/
    plugin.json
  skills/
    deep-read-web/
      SKILL.md
      scripts/
        deep_read.py
      bin/
        deep_read.exe
  .cursor/
    rules/
      deep-read-web.mdc
```

说明：

1. `skills/deep-read-web/SKILL.md` 用于 Agent 说明如何触发与调用。
2. `scripts/deep_read.py` 是源码实现。
3. `bin/deep_read.exe` 是发布态运行产物，可选。
4. `.codex-plugin/plugin.json` 用于 Codex 插件化安装。
5. `.cursor/rules/deep-read-web.mdc` 用于给 Cursor 提供规则与调用约定。

## 7. 面向不同客户端的兼容建议

## 7.1 Codex

Codex 当前更适合：

1. 直接安装 Skill。
2. 或安装 Plugin，再由 Plugin 暴露 Skill。

建议为 Codex 提供：

1. `SKILL.md`
2. `plugin.json`
3. 清晰的 README 安装说明

## 7.2 Claude Code

Claude Code 和 Codex 在 Skill 组织方式上比较接近，可以共用绝大多数 Skill 内容。

建议：

1. 复用同一份 `SKILL.md`
2. 复用同一份脚本
3. 只在安装路径说明上做区分

## 7.3 Cursor

Cursor 不建议假设它会原生按 `SKILL.md` 自动安装执行，因此要增加一层兼容说明。

建议：

1. 提供 `.cursor/rules/deep-read-web.mdc`
2. 在规则里告诉 Cursor 何时调用脚本
3. 在 README 中明确写出 Cursor 的接入方式

如果后续要把兼容性做得更强，可以再考虑 MCP Server 形式，但第一版没必要直接上。

## 8. 分阶段实施计划

## Phase 1：文档与结构搭建

目标：

1. 建立仓库目录结构。
2. 编写 `SKILL.md`。
3. 编写 `plugin.json`。
4. 编写 Cursor 规则文件。
5. 完善 README。

产出：

1. 项目可被外部理解和安装。
2. Skill 调用方式明确。

## Phase 2：实现 `deep_read.py`

目标：

1. 支持 `--HTML_PAGE` 参数。
2. 支持 `--browser` 参数。
3. 默认先走无头模式。
4. 检测到登录后再切换可见浏览器。
5. 登录成功后输出完整 HTML。
6. 超时 1 分钟失败退出。

产出：

1. 一个可独立运行的 Python 脚本。

## Phase 3：无 Python 环境支持

目标：

1. 补充 Windows 可执行产物构建方案。
2. Skill 增加“先找 Python，再找可执行文件”的运行逻辑。
3. README 补充“开发态”和“发布态”使用说明。

产出：

1. 无 Python 用户也能运行。

## Phase 4：发布与验证

目标：

1. 发布到 GitHub。
2. 增加 Release 产物。
3. 验证 Codex / Claude Code / Cursor 接入说明是否完整。
4. 测试公开页面与登录页面。

产出：

1. 一个可安装、可复用、可演示的技能仓库。

## 9. 建议的优先级决策

为了避免第一版过重，建议这样收敛范围：

1. 第一版主平台：Windows。
2. 第一版主浏览器：`auto -> msedge -> chrome -> chromium`。
3. 第一版保留 `firefox` 选项，但不作为默认路线。
4. 第一版先完成 Python 脚本。
5. 第二阶段再补可执行发布物。

这是当前性价比最高、最容易发布成功的路线。

## 10. 下一步建议

如果继续推进，下一步建议直接开始以下工作：

1. 创建 Skill 目录结构。
2. 编写第一版 `deep_read.py`。
3. 让脚本支持 `--browser auto`。
4. 再补 `SKILL.md` 和 `plugin.json`。
5. 最后再处理无 Python 用户的发布形态。

这能确保我们先把“能力可用”做出来，再做“安装更丝滑”。
