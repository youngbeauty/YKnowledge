# pi 使用技巧：web fetch/search + computer use

> 来源推文：[@dillon_mulroy](https://x.com/dillon_mulroy/status/2074491669508976835)（Cloudflare 首席工程师）
> 整理日期：2026-07-14 · 已在本机（Windows 11 / pi 0.80.3）实测跑通

## 背景：pi 为什么要"自己装"

pi 是 Mario Zechner（@badlogicgames）和 Armin Ronacher（@mitsuhiko）做的极简 coding agent，
设计哲学是**核心只带最少工具，其余全靠扩展按需装**。默认只有 8 个工具
（read / write / edit / bash / grep / find / ls + 一个 mcp 代理），
起始 context 约 5.7K token——对比 Claude Code 的 69 工具 / 65K token，少了 91%。

代价就是：想要 web 访问、想要操作电脑，都得自己装扩展。下面两个是作者本人在用的方案。

---

## 技巧一：web fetch / search

给 pi 加两个工具：

- **webfetch** — 抓一个公开 URL，转成 markdown / text / html（HTML 自动转 markdown）
- **websearch** — 公网搜索，返回候选 URL（底层走 Exa）

### 安装

来源是作者 dotfiles 里的 `web-tools` 扩展（TypeScript）。装法：

```bash
# 1. 把扩展拷进 pi 的扩展目录
#    源：https://github.com/dmmulroy/.dotfiles/tree/main/home/.pi/agent/extensions/web-tools
#    落点：~/.pi/agent/extensions/web-tools/

# 2. 装它的 4 个运行时依赖
cd ~/.pi/agent/extensions/web-tools
npm install --omit=dev
#    依赖：html-to-text / linkedom / turndown / turndown-plugin-gfm
```

pi 会**自动发现** `~/.pi/agent/extensions/` 下的扩展，无需在 settings.json 登记。

### 用法

正常开 `pi`，直接说人话即可：

- "fetch https://xxx 这个页面，总结要点"
- "搜一下 xxx 最新进展"

### ⚠️ 关键注意：websearch 的搜索端点

`web-tools/settings.ts` 里把搜索端点**硬编码**成了作者的私人 Exa 代理：

```
searchEndpoint: "https://m.mulroy.dev/m/e"
```

- 这是 Dillon 自建的 Exa MCP 代理，**他的服务器替你付 Exa 的费用**。
- 实测该端点对外开放、可直接用——所以 websearch **零配置就能搜**。
- 但这是借他的基础设施，哪天关掉或限流就失效。
- 想独立：去 [exa.ai](https://exa.ai) 注册拿 API key，把端点改成官方托管的：
  ```
  searchEndpoint: "https://mcp.exa.ai/mcp?exaApiKey=<你的KEY>"
  ```
  （代码不发鉴权头，key 直接放在 URL 里）

---

## 技巧二：computer / browser use（通过 MCP）

让 pi 能操作你的电脑——列出运行中的应用、截图、点击、按键、读窗口的无障碍树。

作者原话：**"Codex 桌面版的 computer use 本质就是一个 MCP server，把 pi 指过去就行。"**
但 pi 故意不内置 MCP，所以要三段拼起来。

### 三个组件

| 组件 | 作用 | 装法 |
|------|------|------|
| `open-computer-use`（`ocu`） | 开源 computer-use MCP server，跨平台（自带 Windows Go 运行时） | `npm i -g open-computer-use` |
| `pi-mcp-adapter` | pi 的 MCP 客户端扩展，把任意 MCP server 收敛成**一个 ~200 token 的 `mcp` 代理工具**，按需搜索/调用 | `pi install npm:pi-mcp-adapter` |
| `~/.pi/agent/mcp.json` | 注册 MCP server | 见下方 |

> `pi-mcp-adapter` 的机制正是 Dillon 截图里那个 `mcp` 工具的原理：
> 不把 MCP 的一堆工具定义塞进 context（那会瞬间吃掉几万 token），
> 而是只暴露一个代理工具，agent 用 `mcp({search:"..."})` 按需发现、`mcp({tool,args})` 调用。
> 一个服务器接进来只多花 ~200 token，而不是几十个工具定义。

### mcp.json 配置（Windows）

`~/.pi/agent/mcp.json`：

```json
{
  "mcpServers": {
    "open-computer-use": {
      "command": "cmd",
      "args": ["/c", "open-computer-use", "mcp"],
      "lifecycle": "lazy"
    }
  }
}
```

- **Windows 上必须用 `cmd /c` 形式**拉起 .cmd shim。直接写 `"command": "open-computer-use"`
  可能因 MCP SDK 对 Windows `.cmd` 的 spawn 处理而失败。
- macOS / Linux 上简化为 `"command": "open-computer-use", "args": ["mcp"]`。
- `lazy` = server 只在第一次调用工具时才启动。
- macOS 首次运行需授权 Accessibility + Screen Recording（`ocu doctor` 引导）；Windows / Linux 不需要。

### 用法

正常开 `pi`，说：

- "看看我现在开了哪些应用"
- "截图 Chrome 窗口，然后点某个按钮 / 填某个表单"

pi 会经 `mcp` 代理调用 open-computer-use 操作桌面。

### ⚠️ 安全

computer use 是**真的会操作你的电脑**（点击、按键、切窗口）。第一次让它动手时盯着点，
别在有敏感操作的界面上放手让它跑。

---

## 快速参考

### 一次装齐（Windows）

```bash
# web 工具（拷扩展 + 装依赖，见技巧一）
cd ~/.pi/agent/extensions/web-tools && npm install --omit=dev

# computer use
npm i -g open-computer-use
pi install npm:pi-mcp-adapter
# 然后写 ~/.pi/agent/mcp.json（见上）
```

### 验证命令

```bash
# webfetch
pi -p --tools webfetch "fetch https://example.com 并给我 H1"

# websearch
pi -p --tools websearch "搜索 'pi coding agent' 列出前 3 个结果"

# computer use 引擎本身
ocu list-apps

# pi 经 MCP 代理发现 + 调用
pi -p --tools mcp "用 mcp 工具 {search:'app'} 列出可用的 MCP 工具"
pi -p --tools mcp "调用 open_computer_use_list_apps，报前 5 个 app"
```

### 文件落点

| 路径 | 内容 |
|------|------|
| `~/.pi/agent/extensions/web-tools/` | web-tools 扩展 + node_modules |
| `~/.pi/agent/npm/node_modules/pi-mcp-adapter` | MCP 适配器（`pi list` 可见） |
| `~/.pi/agent/mcp.json` | MCP server 注册 |
| `~/.pi/agent/settings.json` | pi 全局设置（默认 provider/model 等） |

### 相关命令

```bash
pi list                 # 看已装扩展
pi install <source>     # 装扩展（npm: / git: / 本地路径）
pi remove <source>      # 卸载
pi config               # TUI 里开关各扩展的资源
```

---

## 来源链接

- 推文：https://x.com/dillon_mulroy/status/2074491669508976835
- web-tools 扩展：https://github.com/dmmulroy/.dotfiles/tree/main/home/.pi/agent/extensions/web-tools
- open-computer-use：https://github.com/iFurySt/open-codex-computer-use
- pi-mcp-adapter：https://www.npmjs.com/package/pi-mcp-adapter
- pi 本体：https://github.com/badlogic/pi-mono · https://pi.dev
- （被引用的对比文章）Matt Pocock《Kill The Bloat In Claude Code's System Prompt》：https://www.aihero.dev/how-to-kill-the-bloat-in-claude-codes-system-prompt
