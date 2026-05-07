---
name: deep-read-web
description: 使用 Playwright 读取公开网页或登录后网页的最终 HTML。适用于用户想要网页 HTML、需要在手动登录后继续读取页面，或希望分析登录后最终渲染内容的场景。
---

# Deep Read Web

## 何时使用

当满足以下任一情况时，使用这个 skill：

- 用户提供了 `http` 或 `https` URL，并希望获取页面 HTML
- 页面可能需要登录后才能阅读
- 页面会先跳转到登录页，登录后再重定向回目标内容页
- 用户希望你分析登录后的最终页面内容，而不是只看原始响应

## 调用优先级

### 1. 优先使用二进制发布物

如果下面这个文件存在：

```text
skills/deep-read-web/bin/deep_read.exe
```

优先调用：

```bash
skills/deep-read-web/bin/deep_read.exe --HTML_PAGE "<url>"
```

### 2. 二进制不存在时回退 Python 源码模式

Windows 下优先：

```bash
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>"
```

如果 `py -3` 不可用，再尝试：

```bash
python skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>"
```

### 3. 可选参数

指定浏览器：

```bash
skills/deep-read-web/bin/deep_read.exe --HTML_PAGE "<url>" --browser firefox
```

或：

```bash
py -3 skills/deep-read-web/scripts/deep_read.py --HTML_PAGE "<url>" --browser firefox
```

自定义登录超时：

```bash
skills/deep-read-web/bin/deep_read.exe --HTML_PAGE "<url>" --auth-timeout 90
```

支持的浏览器值：

```text
auto | msedge | msedge-dev | msedge-beta | chrome | chrome-dev | chrome-beta | chromium | firefox
```

默认浏览器策略：

1. `auto` 先尝试系统 `msedge`
2. 再尝试系统 `chrome`
3. 最后回退到 `chromium`
4. `firefox` 仅在显式指定时启用

## 预期行为

1. 先进行无头读取
2. 若页面像正常内容页，直接返回 HTML，不打开窗口
3. 若页面像登录页 / 鉴权页，打开可视浏览器让用户手动登录
4. 登录判断使用启发式规则：URL、标题、密码框、账号输入框等
5. 登录成功后，允许页面发生重定向
6. 不要求最终 URL 与原 URL 完全一致
7. 只要最终页仍属于目标站点 host 范围内、且不再像登录页，即认为可读
8. 从多个页面中选择最像目标内容页的页面，并输出其完整 HTML

## CLI 约定

- `--HTML_PAGE` 必填，必须是合法 `http/https` URL
- `--browser` 默认为 `auto`
- `--auth-timeout` 默认为 `60`
- 成功时只把最终 HTML 写到 `stdout`，退出码 `0`
- 参数错误退出 `2`
- 依赖缺失、浏览器启动失败、页面读取失败、登录超时退出 `1`
- 用户中断退出 `130`

## 依赖与安装提示

### 如果没有 Python

优先提示用户：

```powershell
.\tools\install_release_binary.ps1
```

下载并安装 `deep_read.exe`。

### 如果没有 Playwright

在源码模式下提示：

```bash
py -3 -m pip install playwright
py -3 -m playwright install chromium firefox
```

## 输出处理约定

- 把 `stdout` 当作最终页面 HTML
- 把 `stderr` 当作状态信息或错误信息
- 不要让用户把密码、cookie、token、session 等敏感信息贴到聊天里
- 如果需要登录，只让用户在浏览器窗口里自己完成鉴权
