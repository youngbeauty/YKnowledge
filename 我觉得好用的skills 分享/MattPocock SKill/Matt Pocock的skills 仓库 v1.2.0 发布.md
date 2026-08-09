这是 Matt Pocock的 **skills 仓库 v1.2.0 发布视频**口播稿。他自己录屏走了一遍这版的每项改动。逐段拆：

## 0. 开场：项目现状

- 仓库到了 **20.4k stars**（他说是 GitHub 史上第 24 高 star 的仓库 —— 这个数字明显吹了/口误，20.4k 排不到第 24；但原话如此）
- 定位从「一堆 skill」升级成「成熟项目」，所以这版重点是**文档 + 分发渠道**，不只是加功能

## 1. 正式文档站：`ahero.dev/skills`

他推荐的看法是从 `/skills` 主页进，结构是：

- **主流程图** —— 他的推荐工作流顺序：`grill`（拷问需求）→ `suspect`（定位嫌疑）→ `ticket`（写工单）→ `implement`（实现）→ `code review`
- **左侧全量参考面板** —— 每个 skill 干什么，一条一条列
- **常见问题页** —— 来源是他自己维护的私人 wiki，记录所有人反复问他的问题
- **AI coding 词典** —— skill 文档里的术语（比如「ticket」）都链到词典条目，写着**他本人**对这个词的定义

他提了一句：写文档本来就是他的前一份全职工作，所以这次做文档挺开心。

**言外之意**：这套文档不只是 skill 说明书，他当成「学 AI coding 的教材」在做。

## 2. 进了 Claude Code 官方插件市场

以前要手动 clone / 拷目录，现在：

```bash
claude
```

`/plugin` → 搜 `Matt Pocock skills` → 装。

好处两条：

- 得到一个 **只读 bundle**，没有额外配置步骤
- 他改了 skill，**自动拉更新**

## 3. 给 codex 用户的 `openai.yaml` sidecar

这段是全片最技术的一节，讲的是他踩的一个坑：

他的 skill 分两类 ——

- **model-invoked**（模型自己判断要不要用）
- **user-invoked**（只有你打 `/xxx` 才触发）

user-invoked 的关键价值是**在你没调用之前，它对 agent 的上下文窗口是隐身的**，不占 context、不干扰模型。这个靠的是 `allow_implicit_invocation: false`。

问题：这个字段 **Claude Code 认、pi 认、还有几个 harness 认，但 codex 不认**。他之前没意识到，所以 codex 用户实际上是所有 skill 全量灌进上下文。

修法：**每个 skill 都附带一个 `openai.yaml` sidecar 文件**。效果是

- codex 开箱即用
- `allow_implicit_invocation: false` 的语义能传过去
- 顺带让 codex UI 之类的 UI 正确识别

## 4. 新 skill：`wait what`（治 Opus 废话）

他吐槽的痛点很具体：**Opus（尤其 Opus 5）现在说话像垃圾**。

他的原话大意：不知道怎么回事，可能就是新模型的毛病 —— 每次跟 Opus 交互，内容全在他头顶飞过去，极其啰嗦，用一堆怪异的 LLM 腔，读起来非常费劲。他说很多人有同感。

> 稿子这里插了一段明显是语音转写崩掉的句子（"the honest options are to accept it and reword the AC or to persist the digest along the export... it is genuinely load bearing though so that's how you know it matters"）—— 这其实**正是他在现场念的一段 Opus 输出样本**，用来演示「你根本不知道它在说什么」。所以这段读不懂是故意的。

他试过的失败方案：output styles、往 AGENTS.md 里加规则。都不够。

最终答案就是一个 skill，语义是「等等，你刚说什么？」。做两件事：

1. **强制 ASD-STE100**（Simplified Technical English，航空业的简化技术英语标准）。他明说这是个「引导词」—— 目的是让模型用清晰的陈述句、简单词汇
2. **强制模型落回你的 ubiquitous language**，也就是 `CONTEXT.md` 里你在 grilling 阶段自己定义的那套领域词汇

**他强调的核心洞见**：治啰嗦的真正解法不是「让它说简单点」（那只是辅料），而是**让它说你的话** —— 用你自己产出的术语体系。

用法：agent 吐出一堆你看不懂的东西，你就回一句 `wait what`，它会给一个好得多的版本。

## 5. 改造 `grill me`（他最热门的 skill，改动最大）

**旧行为**：一轮一个问题。问 → 你答 → 再问 → 你答。

**旧行为的失败模式**（他讲得很细）：一场 grilling 到后半段，硬骨头都啃完了，剩下一堆简单问题，还得一问一答，你只能不停 "yeah that sounds good"、"yeah that sounds good too"。极其烦躁，慢得要死。

**想改成多问题一轮，但有个难题**：如果 Q3 的答案依赖 Q1 的答案怎么办？旧模式天然没这问题（问到 Q3 时 Q1 早答完了）。批量问岂不是会让你答到无效问题、或者顺序错乱的问题？

**解法**：把问题当成一张**图（graph / DAG）**。

- 开头可能只有 **1 个关键问题**，它必须先答
- 答完它，**解锁一大批**后续问题
- 那批答完，又解锁下一层
- skill 的职责是**只问「当前可答」的问题，按轮次（rounds）推进，永远把你往问题前沿（frontier）推**

**界面细节**（他特意提的）：

- 显示 `Round 1`，下面 Q1、Q2、Q3…
- 每题带一个 **emoji 标记的推荐答案**。他自己说「我知道你们可能不喜欢 emoji，但我喜欢」—— 目的是给一点颜色，让眼睛能快速定位「这是 Q1，这是它的推荐答案」
- 他用**语音输入**，所以可以一路突突：「Q1 同意，Q2 同意，Q3 这里要改，Q4 这里要改」
- 答完 Round 1，Round 2 进来，同样的排版，继续往前推

## 6. `writing great skills` → 改名 `writing for agents`

**改名原因**：他发现自己拿这个 skill 干的事早就超出「写 skill」了 —— 任何**给 agent 读的文档**他都用它，为了让 agent 表现更好、文档更精炼、输出更可预测。

**改动**：

- 适用面扩到 `AGENTS.md`、`CLAUDE.md`、以及创建/编辑 skill
- skill 专属的机制（那部分细节）**挪进一个单独的 reference 文件**，主文件保持通用

**他最看重的用法**：把臃肿的 `AGENTS.md` 拆解成独立 skill —— 解决他说的 "horrible front loading"（所有规则一股脑前置塞满上下文）。

这个 skill 是 **model-invoked**，description 写得很干净，所以你一改 `AGENTS.md` 它就会自动被拉进来。

## 7. 新 skill：`wizard`（他自己雪藏了几个月）

**起因**：他最近要开一堆基础设施、手动过一遍 AWS 流程，烦透了。

**为什么不让 agent 直接干**：他说他本来可以让 agent 用 computer use 去 AWS 里点，但那**感觉很恶心（icky）** —— 他要对全流程有控制权，只是希望尽可能省事。

**做法**：这个 skill **生成一个交互式 bash 向导**，带着人走「只有人能做」的步骤。

他演示的是一个「迁移到远程开发机」的向导，实际体验：

1. 启动 → 问 "ready to start?" → yes
2. 脚本**自动打开**他要去的那个页面（他不用自己找）
3. 引导他登录
4. 引导他改需要改的那一项
5. 他把 API key 贴进来 —— **注意：这是确定性脚本，不经过 agent，不会发给 Anthropic**
6. 脚本把 key 存进该存的文件，需要的话**还写进 GitHub secrets**
7. 带着一个漂亮的小 UI 一段一段往下走，直到拿到想要的结果

**他的评价**：这让「开服务」从极度痛苦变成「诡异地愉快」，因为他清楚以前要花多久。已经成为他工具集里必需的一环，攒了几个月觉得可以放出来了。

## 8. 新 skill：`to questionnaire`（他自称名字最无聊）

**起因**（真事）：他在做一个 wayfinder session，想在后院盖个花园办公室。agent 在 grill 他，但他意识到**真正该被 grill 的人是他老婆** —— 那空间她也要用，得两个人一起设计。

**做法**：把 grilling session 里的决策，导成一份 markdown 文档，可以拿去跟别人一起走一遍。

他的实际流程：

1. 让 agent 把「原本要在 grilling 里问的问题」转成 markdown
2. 丢进 Google Doc
3. 发给老婆，两人一起过一遍
4. 答案再拉回给 agent

**他对这个 skill 的态度很有意思**：他**希望有一天能删掉它**。因为它本质是个补丁，补的是「现在的 agent 很难协作」这个缺陷。

他认为的理想状态：agent 在 Slack 里，团队在频道里讨论、随手 @ agent、和 stakeholder 一起答问题，然后 agent 直接照着去实现。但**很多人不在那个世界里** —— 不是 AI native，可能连 Slack / Teams 都没有。所以「能导出一份文档、给别人、别人在 Google Doc 上批注」在当下真的有用。

## 9. 收尾 + 他在卖什么

- 还有一些改动太小没在视频里讲，**完整 changelog 看 GitHub releases 的 v1.2.0**
- 他最期待大家对 `wait what` 的反应，觉得「Opus 抽风的时候它能救你几次」
- **他在做一门 AI coding crash course**，和以前的付费课不同：
    - 以前是 cohort 制（一群人几周内一起上）
    - 这次是**更便宜、全年可买、自定进度**
    - 他敢这么做的判断依据：**「AI coding 正在稳定下来，从去年 12 月到现在其实没变多少」**，所以自定进度的课不会很快过期
    - 目标是给一个稳定的基础，让你在此之上真正 ship 东西
    - 链接在视频下方，现在可以进 waitlist，大概几周后上线

## 一句话概括这版的性格

v1.2.0 不是「加功能」版，是**「让别人能真正用起来」版** —— 文档站 + 官方市场分发 + codex 兼容占了一半篇幅；剩下的新 skill 全在补「人机协作」的缺口：让模型说人话（`wait what`）、让提问不浪费人的时间（`grill me` 图化）、让人手动操作不痛苦（`wizard`）、让第三个人能参与进来（`to questionnaire`）。

下一步：想验证他讲的 `grill me` 分轮效果，直接在这个仓库里跑一次 `mattpocock-skills:grilling`。