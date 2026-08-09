

> 2026-07-29。场景：我把"按 ADHD 方式输出"这条规则塞在 `~/.claude/CLAUDE.md` 的硬规则第一条，抄了 6 行摘要。结果模型每轮都"遵守了一半"——列表超 5 项、末尾带支线。折腾一圈才发现：**这类规则放错地方了。** Claude Code 有个专门的机制叫 output style，它改的是系统提示本身。

## 改造前：具体是什么设置

原始 skill 是 `i-have-adhd`（143 行 = 10 条规则 + 6 条破例条件 + 5 条 pre-send 自检），通过 plugin marketplace 装的，实际路径：

```
~/.claude/plugins/marketplaces/i-have-adhd/skills/i-have-adhd/SKILL.md
```

它的 frontmatter 里有一行关键设置：

```yaml
disable-model-invocation: true
```

**含义：模型不能自己调用这个 skill。** 只有用户手打 `/i-have-adhd` 才会加载。

于是我做了个看起来合理的妥协 —— 把规则压成摘要抄进全局 CLAUDE.md，让它每轮都在 context 里。改造前的三处设置逐字如下。

**① `~/.claude/CLAUDE.md` 硬规则第 1 条（6 行）**

```markdown
1. **输出风格**：每一轮都按 `i-have-adhd` skill 的规则输出 —— 第一行就是可执行动作
   （命令/路径/代码），多步走编号列表，每轮重述当前状态（"第 3/5 步完成，下一步 X"），
   无开场白、无收尾寒暄、无 by-the-way 支线，时间估算给具体单位，列表最多 5 项。
   完整规则：`~/.claude/plugins/marketplaces/i-have-adhd/skills/i-have-adhd/SKILL.md`
   （该 skill 标了 `disable-model-invocation`，我无法自己 Skill 调用，所以规则常驻在此）。
   用户说 "stop adhd mode" / "normal mode" 才关闭。
```

**② `~/.claude/settings.json` —— 10 个 key，没有 `outputStyle`**

```json
["permissions","model","hooks","enabledPlugins","extraKnownMarketplaces",
 "effortLevel","tui","skipDangerousModePermissionPrompt",
 "skipWorkflowUsageWarning","theme"]
```

**③ `~/.claude/output-styles/` —— 目录不存在**

也就是说：这台机器上 output style 机制**从没被启用过**，风格规则 100% 靠 CLAUDE.md 的自觉遵守。项目级（`<repo>/CLAUDE.md`）当时**完全没有**风格相关规则，只有 5 条技术约定。

## 触发了没有：分三层看

这是我一开始判断错的地方。我当时的原话是"全局有为什么不触发"，其实"触发"这个词把三件事混成了一件：

| 层 | 触发了吗 | 依据 |
|---|---|---|
| **Skill 加载**（`/i-have-adhd`） | ❌ 全程没有 | 整个会话零次 Skill 工具调用；`disable-model-invocation: true` 挡着模型自调，用户也没手打 |
| **CLAUDE.md 注入** | ✅ 每轮都注入 | 摘要内容确实出现在系统提示的 claudeMd 段里 |
| **实际遵守** | ⚠️ 只做到一半 | 见下表 |

**"只做到一半"是可验证的**，对着摘要逐条核：

| 摘要里的规则 | 实际输出 |
|---|---|
| 第一行即可执行动作/结论 | ✅ 做到 |
| 无开场白、无收尾寒暄 | ✅ 做到 |
| 列表最多 5 项 | ❌ 输出了 6 行表格 |
| 无 by-the-way 支线 | ❌ 末尾带了句"要我实际跑一遍吗 + 路径提醒" |

**所以结论不是"加载失败"，而是"信息量不够 + 位置不对"。**

病根在"压成摘要"这个动作本身：

| 原文有 | 6 行摘要有 |
|---|---|
| 10 条规则细则 | ❌ 只剩关键词 |
| 每条的正/反例（Bad/Good） | ❌ |
| 6 条"什么时候该破例" | ❌ |
| 5 条发送前自检清单 | ❌ |

摘要里明明写着"列表最多 5 项"，照样输出 6 行表格。**关键词不产生行为，例子才产生行为。** 再加上 CLAUDE.md 属于"上下文里的用户指令"，对话越长越被后面的内容稀释。

**可复用的排查方法**：怀疑一条规则没生效，先分清是「没加载」还是「加载了没遵守」。前者查路径 / 目录位置 / frontmatter（尤其 `disable-model-invocation`），后者查规则本身够不够具体、有没有例子。这两种病的药完全不同，别一上来就怀疑加载机制。

## 四个机制，别选错

| 机制 | 每轮生效 | 谁强制 | 每轮 token | 适合 |
|---|---|---|---|---|
| **Output Style** | 是，进系统提示 | harness | 0（不占对话） | 输出风格、人格、语气 |
| CLAUDE.md | 是，注入上下文 | 模型自觉 | 有，正比于长度 | 项目事实、路径、约定 |
| `UserPromptSubmit` hook | 是，注入文本 | harness | 有 | 必须不可绕过的硬约束 |
| Skill | 否，仅调用时 | 用户手动 | 0（未调用时） | 临时切换、一次性流程 |

**选择依据一句话**：规则是"怎么说话"→ output style；规则是"这个项目的事实"→ CLAUDE.md；规则是"绝不允许违反"→ hook；规则是"偶尔用一下"→ skill。

## 改造后：具体是什么设置

四处改动，逐字如下。

**① 新建 `~/.claude/output-styles/adhd.md`（执行源，143 行原文）**

```markdown
---
name: adhd
description: 为 ADHD 读者塑形输出：第一行即可执行动作、编号步骤、每轮重述状态、
             压制支线、具体时间估算、可见的完成项
keep-coding-instructions: true
---

# Output shape: the reader has ADHD
<以下是 SKILL.md 全文照搬：10 条规则含 Bad/Good 例子、6 条破例条件、pre-send 自检>
```

**② `~/.claude/settings.json` —— 加第 11 个 key**

```json
{
  "...": "原有 10 个 key 不动",
  "outputStyle": "adhd"
}
```

改之前先 `cp settings.json settings.json.bak-<日期>`。

**③ `~/.claude/CLAUDE.md` 第 1 条：6 行 → 4 行，规则正文删干净**

```markdown
1. **输出风格**：由 output style `adhd` 强制（`~/.claude/output-styles/adhd.md`，
   已在 `settings.json` 设为默认）。规则不再抄在此处 —— 它在系统提示里。
   **派 subagent / executor 时要把 `<repo>/docs/output-style-adhd.md` 路径写进 prompt**，
   因为 output style 不会传给子 agent。
```

**④ 项目侧新增两处（为了 subagent）**

```
<repo>/docs/output-style-adhd.md   ← 新建，SKILL.md 原文副本 + 抄录日期 + 上游路径
<repo>/CLAUDE.md 硬规则 6          ← 新增 3 行指针，明写"subagent 不继承，派单时带上路径"
```

```markdown
6. **输出风格（ADHD 模式）**：全文规则见
   [`docs/output-style-adhd.md`](docs/output-style-adhd.md) —— 主循环由 output style
   `adhd` 强制，**subagent / executor 不继承，派单时把该路径写进 prompt**。
```

### 前后对照表

| | 改造前 | 改造后 |
|---|---|---|
| 执行源 | CLAUDE.md 里的 6 行摘要 | `output-styles/adhd.md` 143 行原文 |
| 注入位置 | 上下文（用户指令层） | 系统提示 |
| 谁强制 | 模型自觉 | harness |
| 有 Bad/Good 例子 | ❌ | ✅ |
| 有破例条件 | ❌ | ✅ 6 条 |
| 有 pre-send 自检 | ❌ | ✅ 5 条 |
| 常驻占用行数 | 6 行（全局） | 7 行（全局 4 + 项目 3） |
| subagent 能读到 | ❌ 两边都读不到 | ✅ repo `docs/` 副本 |
| 一键开关 | 手动注释 CLAUDE.md | `/config` → Output style |

**净效果**：执行源从「6 行摘要 + 自觉」变成「143 行原文 + harness 强制」，常驻行数几乎不变（6 → 7）。

⚠️ 这里纠正我自己第一版写的一个数字：当时说"每轮 context 少占 9 行"，是拿改造后跟**中途的一个过渡版本**比的（我先在项目 CLAUDE.md 里加过一份 6 行摘要，后来才压成 3 行）。跟**真正的改造前**比，常驻行数是 6 → 7，微增 1 行。多出来的那 3 行项目侧指针买到的是 subagent 可读性，不是省 token。**省 token 不是这次改造的收益，别拿它当卖点。**

## 怎么做（4 步，约 10 分钟）

### 第 1 步：写 `~/.claude/output-styles/<名字>.md`

```markdown
---
name: adhd
description: 选择器里显示的说明
keep-coding-instructions: true
---

<规则正文，直接就是要注入系统提示的内容>
```

frontmatter 三个字段（从 `claude.exe` 里挖出来验证的，非文档记忆）：

- `name` —— 可省，默认用文件名
- `description` —— 可省，`/config` 的 Output style 选择器里显示
- `keep-coding-instructions` —— **最重要的一个，见下节**

### 第 2 步：设为默认

```jsonc
// ~/.claude/settings.json
{ "outputStyle": "adhd" }
```

改前先备份。或者走 UI：`/config` → Output style（老命令 `/output-style` 已并入 `/config`）。

### 第 3 步：把 CLAUDE.md 里的旧抄本删干净

只留一行指针。留着摘要 = 双份维护，改一处漏一处。

### 第 4 步：重启 session 验证

**系统提示是启动时定的，改完当轮不生效。** 这一步别省。

## 最大的坑：默认会吃掉你的 coding instructions

`keep-coding-instructions` 不写就是 false，含义是 output style 的正文**替换**掉默认那套软件工程系统提示。

- 想做"换个人格"（比如讲解模式、教学模式）→ 不加，让它替换
- 想做"在原有能力上改说话方式"→ **必须 `keep-coding-instructions: true`**，否则你的编码 agent 会变成一个只会按你风格说话、但不懂工程纪律的东西

我第一版差点漏了这个。挖二进制字符串时看到 `"If true, the default coding instructions st..."` 才反应过来。

## 好处 / 坏处权衡

**好处**

1. **优先级更高**：系统提示 > 上下文里的用户指令。风格规则不再随对话变长而衰减。
2. **不挤占 CLAUDE.md 的篇幅预算**：CLAUDE.md 讲究"只放索引 + 硬规则"，风格规则搬走后那份自律压力就没了。注意：**这不等于省 token** —— 系统提示同样每轮都在，只是走 prompt cache、且不跟你的项目说明书抢版面。
3. **能放全文**：CLAUDE.md 有"超过 5 行就写进 docs"的自律压力，output style 没有 —— 143 行原文可以整份放，例子全留。
4. **可切换**：`/config` 里一键换风格/关掉，比注释掉 CLAUDE.md 干净。
5. **能随 plugin 分发**：插件 manifest 支持 `outputStyles` 字段，可以把风格打包给别人装。

**坏处**

1. **全局，不分项目**：user 级 output style 对所有项目生效。项目专属规则不该放这儿（项目级 `.claude/output-styles/` 存在，但一个仓库强制一种说话风格通常太重）。
2. **subagent 不继承**：子 agent 有自己的系统提示。派单时得手动把规则路径写进 prompt —— 这也是我为什么在仓库里另留一份 `docs/` 副本。*（这条我未逐字验证到二进制层面，是按 subagent 系统提示独立构造推断的，实际派单时留意一下。）*
3. **隐形，难 debug**：它不出现在对话里。"模型为什么这么说话"以后要多查一个地方，新人接手你的配置会懵。
4. **safe mode 会禁用**：二进制里有 `disabled in safe mode` 的分支。安全模式下风格会静默失效。
5. **和 CLAUDE.md 容易双份漂移**：迁移时必须真的删掉旧抄本，不能"先留着以防万一"。

## 什么时候别用

- 规则是**项目事实**（路径、依赖、命名约定）→ 留在 CLAUDE.md，这是它的正职
- 规则**必须机械强制**、一次都不能漏 → 用 `UserPromptSubmit` hook，output style 仍然只是"很强的建议"
- 规则**只偶尔想用** → 保持 skill 形态，手动 `/xxx` 调用
- 规则**只对 subagent 有意义** → 写进 agent 定义或派单 prompt，output style 到不了那儿

## 一句话总结

CLAUDE.md 是"给模型看的项目说明书"，output style 是"给模型换个脑子"。**我把换脑子的事写进了说明书，所以它每轮都在读、每轮都只做到一半。**
