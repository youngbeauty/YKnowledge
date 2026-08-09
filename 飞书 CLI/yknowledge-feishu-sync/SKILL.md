---
name: yknowledge-feishu-sync
description: 用 lark-cli 把本地「个人AI知识库」增量同步到已有的飞书知识库（Wiki）——只导入新增文档，跳过没变的，改动和删除只报告不擅自覆盖。带 sha256 状态文件、首次接管时按标题对账已同步的旧文档、目录镜像、串行导入、fresh read 验证。当用户说「同步知识库到飞书」「把新写的文档推到飞书」「更新飞书知识库」「feishu sync」时使用。
---

# YKnowledge → 飞书知识库 增量同步

## 定位

[feishu-cli-knowledge-sync](../feishu-cli-knowledge-sync/飞书%20CLI%20知识库同步%20Skill.md) 做的是**一次性全量搬运**；这个 skill 做的是**同一个库的第 N 次同步**：每次只把新加的文档送上去，不重复导入、不覆盖用户在飞书上的编辑。

## 固定参数

| 项 | 值 |
| --- | --- |
| `local_root` | `C:\Users\17767\Desktop\自媒体\个人AI知识库` |
| `wiki_url` | `https://my.feishu.cn/wiki/OpTQwKBclicamDkM8GccJYKYnce` |
| `identity` | `user`（个人知识库必须 `--as user`，bot 看不见） |
| `state_file` | `C:\Users\17767\.codex\skills\yknowledge-feishu-sync\state\sync-state.json` |
| 同步范围 | `*.md`，跳过 `.git/`、`README.md` 之外的仓库元文件按需保留 |

状态文件**故意放在仓库外**：`个人AI知识库` 是公开 GitHub 仓库，node token 不进公开库，也避免每次同步都产生 git diff。

## 状态文件结构

```json
{
  "version": 1,
  "wiki_url": "https://my.feishu.cn/wiki/...",
  "space_id": "7xxxxxxxxxxxxxxx",
  "root_node_token": "OpTQ...",
  "dirs": { "我觉得好用的skills 分享/网页图形与可视化": "<node_token>" },
  "files": {
    "我觉得好用的skills 分享/网页图形与可视化/tldraw.md": {
      "sha256": "…", "size": 3412, "title": "tldraw",
      "docx_token": "…", "wiki_node_token": "…", "synced_at": "2026-08-09"
    }
  },
  "last_run": "2026-08-09"
}
```

路径统一用**正斜杠相对路径**做 key，避免 Windows 反斜杠转义踩坑。

## 流程

### 1. 读状态 + 扫本地

状态文件不存在 → 走「首次接管」（第 2 步）；存在则直接进第 3 步。

扫描并算哈希：

```powershell
Get-ChildItem "C:\Users\17767\Desktop\自媒体\个人AI知识库" -Recurse -File -Filter *.md |
  Where-Object { $_.FullName -notmatch '\\\.git\\' } |
  ForEach-Object {
    [PSCustomObject]@{
      Path = (Resolve-Path -Relative $_.FullName) -replace '^\.\\','' -replace '\\','/'
      Size = $_.Length
      Sha  = if ($_.Length -gt 0) { (Get-FileHash $_.FullName -Algorithm SHA256).Hash } else { "EMPTY" }
    }
  }
```

### 2. 首次接管（只在无状态文件时做一次）

这个库在 2026-08-05 已经被全量同步过一次，之后本地目录**改过名、加过文件**。不做对账就会整库重复导入。

1. `wiki +node-get` 解析 `space_id` 和根节点 token。
2. 递归 `wiki +node-list` 拉出现有节点树（标题 + node_token + obj_token + 父节点）。
3. 按**标题**匹配本地文件名（去掉 `.md`）：匹配上的写进 `files`，`sha256` 记为 `"UNKNOWN"`（表示"远端已存在，本地哈希未对齐"），目录节点写进 `dirs`。
4. 匹配不上的本地文件才算新增。
5. 远端有、本地没有的节点（例如改名前的 `个人博客`/`提示词合计`）**只列出来报告，绝不删除**。

写入状态文件后再继续。

### 3. 分三桶

| 桶 | 判定 | 默认动作 |
| --- | --- | --- |
| **新增** | 路径不在 `files` | 导入并移入 Wiki |
| **已改** | 路径在，`sha256` 不同且不是 `UNKNOWN` | **不动**，列出来问用户一次 |
| **已删** | 路径在 `files`，本地没有 | **不动**，只报告 |

只有新增会自动写飞书。这是硬规则：飞书那边可能已被人工编辑过，覆盖是不可逆的。

已改文件用户确认要更新时，做法是**导入一份新 docx 并移到同一父节点**，标题加日期后缀，然后告诉用户去手动合并/删旧版——不要试图原地覆盖 docx 正文。

### 4. 确认身份

```powershell
lark-cli auth status --json --verify
```

user 未登录或缺 scope 时，按报错里的**最小 scope** 增量授权：

```powershell
lark-cli auth login --scope "<报错里的确切 scope>" --no-wait --json
```

展示返回的验证 URL / 二维码，**停下来**等用户确认，再 `lark-cli auth login --device-code <device_code>`。device code 和验证 URL 一次性，不写进任何文档、不跨流程复用。

这个库历史上用到的 scope：`wiki:wiki` `wiki:wiki:readonly` `wiki:node:read` `wiki:node:create` `wiki:space:read` `wiki:node:move`，加 `docs`/`drive` 域。

### 5. 补目录节点

新增文件所在目录如果不在 `dirs` 里，先建：

```powershell
lark-cli wiki +node-create --node-type origin --obj-type docx `
  --space-id "<space_id>" --parent-node-token "<parent>" --title "<目录名>" `
  --as user --format json
```

多层目录从上往下逐层建，每建一个立刻写进 `dirs`。

### 6. 串行导入

**一次一个，不并发**（同一 Drive 位置并发导入会冲突）：

```powershell
lark-cli drive +import --file "<relative-file>" --type docx --name "<文件名去掉.md>" `
  --as user --format json
```

返回 ticket 且超时 → 用 `drive +task_result` 继续查，别重发导入。

空文件（0 字节，如 `未命名.md`）导入会被拒 → 改成在对应父节点下建同名空白 Wiki 节点，状态里 `sha256` 记 `"EMPTY"`。

### 7. 移入 Wiki

```powershell
lark-cli wiki +move --obj-token "<docx_token>" --obj-type docx `
  --target-space-id "<space_id>" --target-parent-token "<parent_node_token>" `
  --as user --format json
```

### 8. 落状态

**每成功一个文件就写一次状态文件**，不要攒到最后——中途失败时已完成的部分不能丢，否则下次重复导入。

### 9. Fresh read 验证

对本次动过的每个父节点重新 `wiki +node-list`，核对标题、数量、父子关系。命令返回成功 ≠ 同步成功，必须重读确认。

## 硬规则

- 只读本地，**永不修改、永不删除**本地文件。
- **永不删除**飞书上任何节点，哪怕本地文件已删。
- 默认只写新增；改动文件必须先问。
- 导入串行；重复并发冲突就停下报告。
- token / device code / app secret 不写进状态文件之外的任何地方，也不写进公开仓库。
- 不把 Wiki URL 当 `space_id` 用，必须 `node-get` 解析。

## 完成报告

一次同步结束报这些，缺一不可：

1. 新增导入 N 个（列文件名）
2. 跳过未变 N 个
3. 已改待确认 N 个（列出来）
4. 本地已删但远端保留 N 个
5. 失败 N 个 + 失败原因
6. 验证结果（重读节点数 vs 预期）
7. 目标 Wiki URL

有失败就明说失败，不允许用"基本完成"糊过去。
