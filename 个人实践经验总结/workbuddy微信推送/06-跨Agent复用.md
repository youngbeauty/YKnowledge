# 06 · 跨 Agent 复用

> 让本机其他 AI Agent（Codex CLI、Claude Code 等）也能调用微信推送。

---

## 1. 为什么能复用

`send_wechat.py` 是一个**完全独立的 Python 程序**：

- 不依赖 WorkBuddy 进程运行
- 不依赖任何 WorkBuddy 内部 API
- 凭据从磁盘上的 `settings.json` 读取
- 零第三方依赖

所以任何能执行 shell 命令的东西都能调它 —— 其他 Agent、cron、任务计划程序、CI 脚本、甚至你手动敲。

---

## 2. Agent Skill 格式通用性

Codex 和 Claude Code 的 skill 格式是兼容的：

```
<skills 根目录>/
└── wechat-push/
    ├── SKILL.md       ← frontmatter (name + description) + 正文
    └── send_wechat.py
```

`SKILL.md` 的 frontmatter：

```yaml
---
name: wechat-push
description: 通过 WorkBuddy 已绑定的微信 ClawBot 通道向用户微信主动推送文本消息。当任务完成后需要通知用户、或用户要求"发消息到微信/微信提醒我/推送到微信"时使用。
---
```

`description` 写得越具体，Agent 越容易在正确时机想起用它。要把用户可能说的原话（"发我微信"、"微信提醒我"、"推送到微信"）都塞进去。

---

## 3. 各 Agent 的 skills 目录

| Agent | 目录 |
|---|---|
| WorkBuddy | `C:/Users/<用户名>/.workbuddy/skills/` |
| Codex CLI | `C:/Users/<用户名>/.codex/skills/` |
| Claude Code | `C:/Users/<用户名>/.claude/skills/` |

---

## 4. 安装步骤

### 4.1 Windows

```bash
# Codex
mkdir -p "C:/Users/<用户名>/.codex/skills/wechat-push"
cp "C:/Users/<用户名>/.workbuddy/skills/wechat-push/"* \
   "C:/Users/<用户名>/.codex/skills/wechat-push/"

# Claude Code
mkdir -p "C:/Users/<用户名>/.claude/skills/wechat-push"
cp "C:/Users/<用户名>/.workbuddy/skills/wechat-push/"* \
   "C:/Users/<用户名>/.claude/skills/wechat-push/"
```

### 4.2 用符号链接代替复制（推荐）

复制会导致多份副本，改一处要同步多次。用 junction / symlink 更好：

**Windows（管理员 PowerShell）**：

```powershell
New-Item -ItemType Junction `
  -Path "C:\Users\<用户名>\.codex\skills\wechat-push" `
  -Target "C:\Users\<用户名>\.workbuddy\skills\wechat-push"

New-Item -ItemType Junction `
  -Path "C:\Users\<用户名>\.claude\skills\wechat-push" `
  -Target "C:\Users\<用户名>\.workbuddy\skills\wechat-push"
```

**macOS / Linux**：

```bash
ln -s ~/.workbuddy/skills/wechat-push ~/.codex/skills/wechat-push
ln -s ~/.workbuddy/skills/wechat-push ~/.claude/skills/wechat-push
```

这样只维护一份源文件。

---

## 5. 验证

### 5.1 Codex

```
你: 发条微信告诉我 codex 也能用了
```

Codex 应该自动找到 wechat-push 技能并执行命令。

### 5.2 Claude Code

```
你: 把这次构建结果推送到我微信
```

### 5.3 如果 Agent 没识别到

- 确认 `SKILL.md` 有正确的 frontmatter（`---` 包裹的 name/description）
- 确认目录名和 `name` 字段一致
- 重启 Agent（部分 Agent 只在启动时扫描 skills 目录）
- 直接告诉它路径：「用 `~/.workbuddy/skills/wechat-push/send_wechat.py` 发条微信」

---

## 6. 非 Agent 场景

### 6.1 Windows 任务计划程序

程序：

```
C:\Users\<用户名>\.workbuddy\binaries\python\versions\3.13.12\python.exe
```

参数：

```
"C:\Users\<用户名>\.workbuddy\skills\wechat-push\send_wechat.py" "定时提醒内容"
```

### 6.2 Linux/macOS cron

```cron
0 9 * * 1-5 /usr/bin/python3 ~/.workbuddy/skills/wechat-push/send_wechat.py "该开始工作了"
```

### 6.3 CI / 构建脚本

```bash
# GitHub Actions / 本地构建
if npm run build; then
  python send_wechat.py "✅ 构建成功"
else
  python send_wechat.py "❌ 构建失败，请检查日志"
  exit 1
fi
```

### 6.4 Python 内嵌调用

```python
import sys
sys.path.insert(0, os.path.expanduser("~/.workbuddy/skills/wechat-push"))
from send_wechat import load_config, send_text

cfg = load_config()
send_text(cfg, "从 Python 代码直接调用")
```

### 6.5 监控脚本

```bash
#!/bin/bash
USAGE=$(df -h / | awk 'NR==2 {print $5}' | tr -d '%')
if [ "$USAGE" -gt 85 ]; then
  python ~/.workbuddy/skills/wechat-push/send_wechat.py "⚠️ 磁盘告警：根分区已用 ${USAGE}%"
fi
```

---

## 7. 跨机器使用

脚本本身可以放到任何机器，但**凭据是绑定的**：

- 方案一：把目标机器也用 WorkBuddy 绑定同一个微信 → 生成各自的 token
- 方案二：把 `settings.json` 里的 `weixinClawBot` 节点复制到目标机器的同路径下

⚠️ 方案二涉及凭据跨机传输，注意传输安全，且多机共用同一 token 的行为未经充分验证。

---

## 8. 注意事项

无论哪个 Agent、哪种调用方式，**都受同一个会话时效限制**：

- 微信会话失效后，所有调用方都会同时返回 `ret=-2`
- 用户在微信发一条消息，所有调用方同时恢复
- 这是服务端状态，与调用方无关

所以给每个 Agent 的 SKILL.md 里都要写清楚 `ret=-2` 的处理方式（不重试、提示用户刷新）。

---

## 下一步

出问题了 → [07-故障排查.md](07-故障排查.md)
