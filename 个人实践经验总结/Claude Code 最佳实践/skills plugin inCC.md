# Claude Code:把散装 skills 迁移到 Plugin 的通用步骤与收益

> 2026-07-29。场景:很多人(包括我)最早是把别人的 skills 整个文件夹拷进项目 `.claude/skills/` 用的。现在作者们纷纷把 skills 打包成官方 plugin,这篇讲**怎么从"手动拷贝的散装 skills"迁移到"插件托管"**,以及为什么值得迁。

## 为什么要迁(收益)

1. **可升级**:散装副本是死的,拷进来那天就开始过时;插件一句 `claude plugins update` 跟上游最新版。我这次 diff 发现本地副本和上游已经漂移了两个月——措辞、触发条件、甚至整个 skill 的名字都变了。
2. **省 context**:不迁的话两份并存,每个 skill 的 description 都会在每次会话的 context 里出现两遍。二三十个 skill 就是几千 token 的纯浪费,还会让模型在自动触发时二选一犹豫。
3. **跨项目复用**:插件装在 user 级(`~/.claude/plugins/`),所有项目共享一份;散装副本每个项目拷一遍,改一处漏三处。
4. **来源可追溯**:插件有版本号、有 marketplace 来源;散装文件夹半年后没人记得从哪拷的、改没改过。
5. **命名空间隔离**:插件 skill 叫 `插件名:skill名`,永远不会和你项目自己的 skill 撞名。

## 通用迁移步骤(5 步)

### 第 1 步:装插件

```bash
# 直接装大概率报 not found —— 插件没有全局注册表
claude plugins install <插件名>

# 正确姿势:先把作者的 GitHub 仓库加成 marketplace
claude plugins marketplace add <owner>/<repo>
claude plugins install <插件名>
claude plugins list        # 验证版本和 scope
```

### 第 2 步:列出插件实际 ship 的 skill 清单

装好后去 `~/.claude/plugins/cache/<marketplace>/<插件>/<版本>/` 看实际内容。

**关键:不要假设插件清单 == 你本地副本清单。** 上游可能已经改名、合并、废弃了一些 skill。对照后分三类:

| 类别 | 处理 |
|---|---|
| 两边都有的 | 候选删除(进第 3 步验证) |
| 本地有、插件已删/改名的 | 保留(删了就彻底没了),或改用上游新名字 |
| 项目自有、和插件无关的 | 不动 |

### 第 3 步:验证本地副本没被自己定制过

删除前必须排除"我当年改过这份"的可能。diff 会全是差异(上游一直在更新),**diff 说明不了是谁改的,要靠 git 历史裁决**:

```bash
git log --oneline -- .claude/skills     # 拷入后有没有后续提交?
git status .claude/skills               # 工作区干净吗?
```

一次性拷入 + 之后零改动 = 差异全来自上游更新 → 放心删。
有自己的定制 → 要么不删保留本地版(裸名优先生效),要么把定制合并进别的地方再删。

### 第 4 步:删除重复副本

坑:`.claude/`、`.agents/` 常整个在 `.gitignore` 里,`git rm` 会静默无效果。先查再删:

```bash
git check-ignore -v .claude/skills/<name>/SKILL.md   # 被忽略?
rm -rf .claude/skills/<name>                          # 被忽略就直接 rm
```

注意有些项目 skills 存了**两处**(`.claude/skills/` 和 `.agents/skills/`),两边都要删。

### 第 5 步:重启验证

重启 Claude Code session,确认:

- skill 列表里裸名重复项消失,只剩 `插件名:xxx`
- `/插件名:某skill` 能正常调用
- 以后升级:`claude plugins update <插件名>`

## 机制备忘:同名到底会怎样

- 插件 skill 带命名空间前缀(`mattpocock-skills:tdd`),项目 skill 是裸名(`tdd`)
- **互不覆盖**,装插件不会动你项目里的任何文件
- 裸名调用优先解析到项目版;插件版永远带前缀调用
- 所以"冲突"其实不存在,存在的是**重复**——这正是要迁移清理的原因

## 什么时候不迁

- 你对本地副本做过深度定制,且不想跟上游 → 保留本地版,**别装插件**(装了纯多占 context)
- 插件把你在用的 skill 废弃了 → 那几个保留本地,其余照迁
