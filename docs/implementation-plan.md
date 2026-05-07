# deep-read-web 实施计划与当前状态

## 1. 项目目标

本项目提供一个可发布到 GitHub、可被 Agent 安装和调用的网页深度读取能力，满足以下核心场景：

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

状态：**已完成首版，并升级为双发布模型**

当前方案：

- `small`：最小下载，不内置 Chromium
- `full`：内置 Chromium，按需下载
- 默认优先 `small`
- 只有本机没有系统 Edge/Chrome 时，才需要 `full`

已完成内容：

- `tools/build_windows.ps1` 支持 `-Flavor small|full`
- `tools/install_release_binary.ps1` 支持 `-Flavor auto|small|full`
- `tools/run_deep_read.ps1` 优先 exe、回退 Python
- `tools/verify.ps1` 支持源码 / 二进制验证，并可指定浏览器
- 发布版默认不引入 Firefox
- 运行时对精简包缺少 Chromium 的错误提示已优化

### Phase 4：发布与验收

状态：**部分完成**

已完成内容：

- GitHub 仓库已发布
- CI 已存在
- 源码模式本地验证已通过
- 二进制本地构建与运行已通过
- release workflow 已升级为双发布

待继续收口：

- GitHub Release 远端双资产验收
- small / full 安装回装验收
- 真实登录站点人工验收

---

## 3. 当前统一方案

### 3.1 运行入口

统一能力入口仍然只有一组逻辑：

```text
deep_read.py --HTML_PAGE <url> [--browser ...] [--auth-timeout ...]
```

发布态提供等价 exe：

```text
deep_read.exe --HTML_PAGE <url> [--browser ...] [--auth-timeout ...]
```

### 3.2 运行优先级

当前统一规则：

1. 若存在 `skills/deep-read-web/bin/deep_read.exe`，优先调用 exe
2. 若 exe 不存在，则回退 Python 脚本
3. 若两者都不可用，则提示用户安装发布版或 Python

### 3.3 浏览器与下载策略

固定浏览器策略：

```text
auto -> msedge -> chrome -> chromium
```

下载策略：

```text
先 small -> 不够再 full
```

说明：

- Windows 默认不需要安装 Chromium / Firefox
- 有 Edge/Chrome 时直接使用系统浏览器
- 只有缺浏览器时才下载带 Chromium 的 full 包
- Firefox 仅在源码模式且用户显式需要时才安装

---

## 4. 当前文档统一标准

以下文档必须保持一致：

1. `README.md`
2. `skills/deep-read-web/SKILL.md`
3. `.cursor/rules/deep-read-web.mdc`

统一要点：

- 优先 exe，回退 Python
- 默认 small
- 缺浏览器时再切换 full
- 默认不要求 Firefox
- 登录后重定向处理一致
- `stdout/stderr` 语义一致

---

## 5. 当前开发与发布脚本

### 源码模式

- `tools/setup_windows.ps1`
- `tools/run_deep_read.ps1`
- `tools/verify.ps1`

### 二进制模式

- `tools/build_windows.ps1 -Flavor small|full`
- `tools/install_release_binary.ps1 -Flavor auto|small|full`
- `tools/run_deep_read.ps1`
- `tools/verify.ps1 -UseBinary`

### GitHub Actions

- `.github/workflows/ci.yml`：源码模式验证
- `.github/workflows/release.yml`：small/full 双发布

---

## 6. 下一步建议

1. 推送当前双发布修复
2. 用新 tag 触发 `release-binary`
3. 验证 Release 中是否同时出现：
   - `deep_read-windows-x64.zip`
   - `deep_read-windows-x64-with-chromium.zip`
4. 本地分别测试：
   - `install_release_binary.ps1 -Flavor small`
   - `install_release_binary.ps1 -Flavor full`
5. 最后补真实登录页人工验收
