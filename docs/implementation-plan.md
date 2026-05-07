# deep-read-web 实施计划与当前状态

## 1. 项目目标

本项目要提供一个可发布到 GitHub、可被 Agent 安装和调用的网页深度读取能力，满足以下核心场景：

1. 输入目标网页 URL
2. 先尝试无头读取最终页面 HTML
3. 如果遇到登录页，则切换到可视浏览器
4. 让用户手动完成鉴权
5. 登录完成后输出最终内容页的完整 HTML
6. 这个能力可被 Codex、Claude Code、Cursor 等使用

---

## 2. 当前阶段判断

### Phase 1：结构与接入文档

状态：**已完成**

已完成内容：

- 仓库结构已建立
- Codex plugin 已存在
- `SKILL.md` 已存在
- Cursor rule 已存在
- README 已存在
- PowerShell 辅助脚本已存在

### Phase 2：核心脚本 `deep_read.py`

状态：**已完成**

已完成内容：

- `--HTML_PAGE` 参数
- `--browser` 参数
- `--auth-timeout` 参数
- 公开页面无头读取
- 登录页切换到可视浏览器
- 手动登录超时处理
- `stdout/stderr/exit code` 约定
- 登录后重定向处理
- 目标站点范围内最佳内容页选择

### Phase 3：无 Python 环境支持

状态：**已进入开发并已完成首版落地**

已完成内容：

- 增加 `tools/build_windows.ps1`
- 增加 `tools/install_release_binary.ps1`
- 增加 `skills/deep-read-web/bin/README.md`
- `tools/run_deep_read.ps1` 改为：**优先 exe，回退 Python**
- `tools/verify.ps1` 支持源码模式和二进制模式双验证
- 新增 `release-binary` GitHub Actions 工作流

当前边界：

- 首版优先 Windows
- 二进制发布物为 `deep_read.exe`
- `firefox` 打包支持暂不作为默认发布目标
- 是否把 Chromium 浏览器一并打包，由构建参数 `-BundleChromium` 控制

### Phase 4：发布与验收

状态：**部分完成**

已完成内容：

- GitHub 仓库已发布
- CI 已存在
- 本地源码模式验证已跑通
- 本地二进制打包与基础运行已验证通过

待继续收口：

- GitHub Release 发布物验收
- 二进制发布链路完整跑通
- 真实登录站点的人工验收

---

## 3. 当前统一方案

### 3.1 运行入口

统一能力入口仍然只有一组：

```text
deep_read.py --HTML_PAGE <url> [--browser ...] [--auth-timeout ...]
```

二进制发布时提供等价入口：

```text
deep_read.exe --HTML_PAGE <url> [--browser ...] [--auth-timeout ...]
```

### 3.2 运行优先级

当前统一规则：

1. 若存在 `skills/deep-read-web/bin/deep_read.exe`，优先调用 exe
2. 若 exe 不存在，则回退 Python 脚本
3. 若两者都不可用，则提示用户缺少运行环境

### 3.3 浏览器策略

固定策略：

```text
auto -> msedge -> chrome -> chromium
```

补充说明：

- `firefox` 仅在显式指定时启用
- 登录成功后允许发生重定向
- 不要求最终 URL 与原始 URL 完全相等
- 最终页必须仍属于目标站点 host 范围，且不再像登录页

---

## 4. 当前文档统一标准

以下三份文档必须保持同一套行为说明：

1. `README.md`
2. `skills/deep-read-web/SKILL.md`
3. `.cursor/rules/deep-read-web.mdc`

统一要点：

- 优先 exe，回退 Python
- 默认浏览器策略一致
- 登录后重定向处理一致
- `stdout/stderr` 语义一致
- 缺少 Python 时优先建议下载发布版

---

## 5. 当前开发与发布脚本

### 源码模式

- `tools/setup_windows.ps1`
- `tools/run_deep_read.ps1`
- `tools/verify.ps1`

### 二进制模式

- `tools/build_windows.ps1`
- `tools/install_release_binary.ps1`
- `tools/run_deep_read.ps1`
- `tools/verify.ps1 -UseBinary`

### GitHub Actions

- `.github/workflows/ci.yml`：源码模式验证
- `.github/workflows/release.yml`：Windows 二进制构建与发布

---

## 6. 下一步建议

接下来建议按这个顺序继续推进：

1. 将 README / SKILL / Cursor rule 同步后的变更提交到 GitHub
2. 在 GitHub 上触发一次 `release-binary` 工作流
3. 检查 `deep_read-windows-x64.zip` 是否成功产出
4. 用 `tools/install_release_binary.ps1` 回装验证一次发布物
5. 再补一轮真实登录站点人工验收
