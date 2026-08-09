# 用 Claude Code 定时任务做网页监控 + Outlook 自动告警

> 实操日期：2026-07-29
> 环境：Windows 11 / Claude Code 桌面版 / opencli v1.8.4 / Chrome + Browser Bridge 扩展 v1.0.22
> 需求：每 10 分钟巡检 `https://memories.ai/`，发现问题自动发邮件给 3 个人；同一个问题只发一次，不刷屏

---

## 一、最终跑通的架构

```
Claude Code scheduled task  (*/10 * * * *)
        │
        ├─ 巡检：应用内浏览器 mcp__Claude_Browser__*
        │     navigate / get_page_text / read_console_messages
        │     read_network_requests / 点击导航链接验证
        │
        ├─ 去重：state.json 存「问题指纹 → 首次发现时间」
        │     新指纹 → 发信；老指纹 → 静默；指纹消失 → 发 RESOLVED 后删除
        │
        └─ 告警：bash send-outlook.sh
              └─ opencli 驱动用户已登录的真实 Chrome
                    └─ Outlook Web 发信 + 到「已发送邮件」核实
```

关键分工：**巡检用应用内浏览器，发信用真实 Chrome**。

巡检每 10 分钟一次，不能去抢用户的浏览器窗口；发信频率低（去重后一天可能就几封），占用 60–90 秒可以接受。

---

## 二、选型过程：四条路死了三条

### 2.1 定时器：三种机制，只有一种能用

| 机制 | 持久性 | 能开浏览器吗 | 结论 |
|---|---|---|---|
| `CronCreate` | 会话内，7 天上限，关了就没 | 否 | ✗ 会话结束即失效 |
| 云端 routine（`/schedule`） | 持久，云端跑 | **否** | ✗ 需要点网页，云端没浏览器 |
| **scheduled-tasks MCP（本地）** | 持久，落盘 `~/.claude/scheduled-tasks/` | **是** | ✓ 采用 |

**决定性因素是「要能点网页」。** 一旦需求里有「去页面上点点看链接通不通」，云端方案直接出局，只能本地跑，代价是 Claude Code 应用必须开着。

如果只是纯 HTTP 探活（不需要点击、不需要渲染 JS），云端 routine 更好 —— 关机也在跑。

### 2.2 cron 表达式被静默曲解

原本想用 `3-59/10 * * * *`（每 10 分钟，但错开 :00 整点，减轻服务端同时段压力）。

**结果被解析成「每小时的第 9 分钟」，变成一小时一次。**

这个解析器不支持 `起始-结束/步长` 的写法。老实用 `*/10 * * * *`。

> 创建完一定要 `list_scheduled_tasks` 回读 `schedule` 字段确认。
> 我这次就是靠回读发现变成了 `At 9 minutes past the hour, every hour` 才抓到的 —— 它不报错，只是默默给你换了个语义。

顺带一提，这个调度器自己会加抖动（本次 `jitterSeconds: 372`），所以不用手动错峰。

### 2.3 邮件 Connector 发不了信

装了 Gmail Connector 之后，工具列表是：

```
create_draft / update_draft / list_drafts
get_message / get_thread / search_threads
create_label / label_message / unlabel_message
apply_sensitive_message_label / ...
```

**没有 send。写权限只到草稿层。**

这不是 Gmail 特有的限制，是官方 Connector 对邮件类的统一策略（防止 agent 自动发信）。换 Outlook Connector 大概率一样。

顺带一提：MCP 注册表搜索 `outlook` / `microsoft` / `email` 全返回空 —— 但搜 `slack` / `notion` 也返回空，说明是本机那个 registry 搜索接口查不出东西，**不能据此断言目录里没有 Outlook connector**。要确认得去 claude.ai → Settings → Connectors 页面自己翻。

> 这是个通用的判断纪律：一个查询接口返回空，先用一个「肯定存在」的关键词去验证接口本身是不是活的，再下结论。

### 2.4 备选方案排序

1. **Resend / SendGrid 等事务邮件 API** —— 最稳，一个 API key，不碰密码。缺点：要注册、要配 DNS 才能用自己域名的发件人。
2. **SMTP + 应用专用密码** —— Google Workspace / M365 管理员常禁用应用专用密码入口，可能一开始就走不通。
3. **opencli 驱动已登录浏览器**（最终选择）—— 零凭据，白嫖现成登录态。缺点：UI 自动化脆，界面改版就坏。
4. **飞书 / 企业微信 webhook** —— 告警场景其实比邮件更合适（更快、零凭据、天然支持群），但这次需求点名要邮件。

---

## 三、踩坑详录

### 坑 1：Chrome 里登录的是个人 Gmail，不是工作邮箱

一开始默认「用户 Chrome 登录的就是工作号」，直接开 `mail.google.com` 就想发。实际查下来：

```
u/0 => Inbox (488) - podmorepawelczyk@gmail.com - Gmail
u/1 => Inbox (488) - podmorepawelczyk@gmail.com - Gmail
u/2 => Inbox (488) - podmorepawelczyk@gmail.com - Gmail
```

三个账号位全是同一个个人 Gmail。用个人邮箱给同事发公司运维告警 → 进垃圾箱 + 看着像钓鱼。

**教训：动手前先确认登录的是哪个账号，别假设。** 一条 `get title` 就能看出来，成本几乎为零。

后来用户说工作邮箱是 Outlook，`outlook.office.com` 打开就是登录态的 `邮件 - Runze Yang - Outlook`，方向立刻就对了。

（注意 URL 会重定向到 `outlook.cloud.microsoft`，写校验逻辑时别对 host 做硬匹配。）

### 坑 2：Outlook deeplink 撰写页的「发送」按钮点了不生效 ★核心坑

Outlook Web 支持 deeplink 预填：

```
https://outlook.office.com/mail/deeplink/compose?to=<urlenc>&subject=<urlenc>&body=<urlenc>
```

**预填完全正常**，三个字段实测都对：

```json
{"subj": "[TEST] memories.ai site watch - link check",
 "bodyTxt": "This is a connectivity test from the memories.ai site watch task."}
```

收件人也正确（读 `#recipient-well-label-to` 所在容器的 innerText）：

```
收件人 抄送 密件抄送 runze.yang@memories.ai <runze.yang@memories.ai>
```

**但发送打死不生效。** 两种方式都试了：

| 方式 | 返回 | 实际结果 |
|---|---|---|
| `keys "Control+Enter"` | `Pressed: Control+Enter` | 撰写窗口纹丝不动 |
| `click '[data-testid="ComposeSendButton"] button[aria-label="发送"]'` | `{"clicked": true, "matches_n": 1, "match_level": "exact"}` | **依然没发出去** |

**这里是整件事最值得记的一条：`clicked: true` 只代表点击事件派发成功，不代表业务动作发生了。**

不去查「已发送邮件」根本发现不了 —— 工具返回全绿，邮件静静躺在草稿箱（21:33，草稿计数 `[2]`）。

**绕法**：让 deeplink 存成草稿 → 回草稿箱 → 用正常邮箱界面打开它 → 在正常界面上点发送。这次立刻成功，草稿数 `[2] → [1]`，已发送邮件出现 21:37 的记录。

推测原因：deeplink 页面是个 popout / detached 的撰写上下文（DOM 里有 `popoutCompose` 按钮），发送动作依赖主邮箱界面的某些上下文。没深究，绕过去就行。

### 坑 3：`opencli browser eval` 在 Outlook 上查不到 DOM ★核心坑

写脚本时用 `eval` 找草稿行，一直返回找不到：

```
FAIL: 草稿箱里找不到这封草稿 (NOROW)
```

但截图看得清清楚楚，草稿就在那儿。于是探测各种 role 的数量：

```json
{"counts": {"option": 0, "listitem": 0, "row": 0, "grid": 0, "convItem": 0},
 "hasSubj": false}
```

**全 0，连 `document.body.innerText` 都不包含主题文字。** 而同一时刻 `find` 却能正常返回：

```
ref 7  div  option
aria-label: "[草稿] Runze Yang [TEST2] site-watch script check 21:38 ..."
```

`frames` 返回 `[]`，所以不是 iframe 的问题 —— 是 `eval` 和 `find` 跑在不同的执行上下文里，`eval` 拿到的是个空壳 / 过期的 page handle。

**教训：opencli 上不要用 `eval` 查 DOM，用 `find` / `click` 配 CSS 选择器。** `eval` 只适合做纯计算，不适合当 DOM 查询工具。

这个坑特别阴 —— 因为 `eval` 不报错，它「成功地」返回了 0 个元素。

### 坑 4：草稿箱列表加载后不会自动刷新出新草稿

选择器验证过是对的（带方括号也没问题）：

```bash
# 两种写法都 matches_n: 1
opencli browser dbg click 'div[role="option"][aria-label*="[TEST3] site-watch autosend"]'
opencli browser dbg click 'div[role="option"][aria-label*="site-watch autosend"]'
```

但脚本里还是找不到。原因是时序：脚本导航到草稿箱时草稿还没同步出来，而**在同一个已加载的 SPA 页面上反复重试是没用的** —— 列表不会自己刷新。

**修法：重试循环里每轮重新 `open` 一次草稿箱**，而不是只重复 click。

```bash
for i in 1 2 3 4 5; do
  oc open "https://outlook.office.com/mail/drafts" >/dev/null
  sleep 12
  if oc click "$ROW_SEL" | grep -q '"clicked": true'; then opened=1; break; fi
done
```

改完一次通过。

> 通用结论：**重试要重建上下文，不是重复同一个动作。** 对 SPA 尤其如此。

### 坑 5：bash 字符串替换里的引号

```bash
SUBJECT="${SUBJECT//\"/'}"     # ✗ 单引号未闭合 → unexpected EOF while looking for matching `''
SUBJECT="${SUBJECT//\"/}"      # ✓ 直接删掉双引号
```

报错行号指向文件末尾，很容易误导你去看别的地方。

主题里的 `"` 会破坏 CSS 属性选择器（`[aria-label*="..."]`），必须处理掉。

### 坑 6：管道吃掉退出码

```bash
bash send-outlook.sh ... 2>&1 | tail -15; echo "EXIT=$?"   # ✗ 永远是 tail 的退出码 0
```

调试初期被这个骗过一次：脚本明明打印了 `FAIL:`，却显示 `EXIT=0`。要么别接管道，要么用 `${PIPESTATUS[0]}`。

**这个坑在告警场景特别危险** —— 发送失败被当成成功，指纹写进 state，之后这个问题永久静默。

### 坑 7：`--window` 选项不存在

```
opencli browser <session> open <url> --window background
→ error: unknown option '--window'
```

`--window` 是 `opencli browser` 这一层的选项，不是 `open` 子命令的。子命令的参数位置要看 `opencli browser --help`，别凭直觉猜。

---

## 四、验证过的选择器与时序

### 选择器

| 目标 | 选择器 | 备注 |
|---|---|---|
| 草稿行 | `div[role="option"][aria-label*="<主题>"]` | aria-label 形如 `[草稿] Runze Yang <主题> 21:38 <正文预览> 未选择任何项目` |
| 发送按钮 | `button[aria-label="发送"]` | 英文界面为 `Send`；**id 形如 `splitButton-r96__primaryActionButton`，每次渲染都变，绝对不能写死** |
| 丢弃按钮 | `#discardCompose` | 或 `button[aria-label="放弃"]` |
| 收件人栏 | `#recipient-well-label-to` | 读它父容器的 innerText 看解析结果 |

「已发送邮件」列表可能按会话折叠，aria-label 对不上草稿箱那套 —— **核实的时候按主题文本找（`find --text`），别按 aria-label 找**。

### 时序（实测下限，宁可多等）

| 步骤 | 等待 |
|---|---|
| deeplink 打开 → 自动存草稿 | 10 秒 |
| 草稿箱导航 → 列表渲染完 | 12 秒 |
| 点开草稿 → 撰写区就绪 | 8 秒 |
| 点发送 → 生效 | 10 秒 |
| 已发送邮件渲染 | 12 秒 |

单次发信全程约 60–90 秒。

### 多收件人

deeplink 的 `to=` 用**逗号分隔**，整串 URL 编码后传，Outlook 能正确拆成独立的收件人 pill。已验证：

```
shawn.shen@memories.ai <shawn.shen@memories.ai>
runze.yang@memories.ai <runze.yang@memories.ai>
xiangjing.zeng@memories.ai <xiangjing.zeng@memories.ai>
```

> 验证多收件人时**不要真发**给同事。开 deeplink 看收件人栏解析对不对，然后点 `#discardCompose` 丢弃，就完成验证了。

---

## 五、成果物

### 5.1 发信脚本

`C:\Users\17767\.claude\scripts\send-outlook.sh`

```bash
bash "C:/Users/17767/.claude/scripts/send-outlook.sh" \
     "a@x.com,b@x.com,c@x.com" \
     "主题（要独特，带时间戳）" \
     "正文"
```

流程：

1. 打开 deeplink 预填 → 等自动存草稿
2. 循环重新打开草稿箱直到能点开这封草稿（最多 5 轮，每轮重新导航）
3. 点发送（中文 `发送` / 英文 `Send` 双 fallback）
4. 打开「已发送邮件」按主题文本核实（最多 3 轮）
5. 关闭 session

**退出码 0 = 已在已发送邮件里核实到；非 0 = 没发出去。**

主题必须独特（带时间戳），脚本靠主题在草稿箱里定位这封信。

### 5.2 定时任务

`C:\Users\17767\.claude\scheduled-tasks\memories-site-watch\SKILL.md`，cron `*/10 * * * *`

**判定标准**（机械可判，不做 AI 主观判断 —— 每 10 分钟一次的主观判断，误报会逼你在三天内关掉整个告警）：

- **P0**：首页非 200 / 正文为空 / 出现 `Application error`、`Something went wrong`、`500`、`502`、`503`、`Internal Server Error`、`This page could not be found` / 首屏 hero 文案 `The multimodal memory infrastructure for AI` 消失 / 标题为空或含 error
- **P1**：`/app` 或 `/contact-sales` 404 或空白 / 网络请求 5xx / console 有 JS error（analytics、intercom、hotjar 等第三方域名除外）
- **忽略**：视频图片加载慢、第三方脚本报错、样式细微差异、单次超时（先重试一次，两次都失败才算 P0）

**去重机制**（`state.json`）：

```json
{"open_issues": {
  "P1:404:/contact-sales": {
    "first_seen": "2026-07-29T21:40:00+08:00",
    "detail": "contact-sales 页面返回 404",
    "severity": "P1"
  }
}}
```

指纹格式 `<severity>:<类别>:<关键标识>`，**不能含时间戳或随机 ID** —— 否则每轮生成新指纹，去重直接失效，变成每 10 分钟一封。

- 新指纹 → 发信 + 写入
- 老指纹 → 静默（哪怕已持续几小时）
- 指纹消失 → 发 RESOLVED + 从 state 删除

**发送失败时不写 state**，并在输出里打 `SEND FAILED`。

否则「发失败了却记成已通知」会导致这个问题永久静默 —— **这是整套机制里最危险的失效模式**：你以为有告警在守着，实际上它在第一次网络抖动之后就哑了，而且不会告诉你。

---

## 六、限制

1. **Claude Code 应用必须开着**，Chrome 也得开着且 Outlook 保持登录态。应用关闭期间任务不跑，下次启动补跑一次。
2. **发信会占用真实浏览器 60–90 秒**（切到 Outlook 标签页）。巡检本身走应用内浏览器，不影响。
3. **UI 自动化天然脆**。Outlook Web 改版、界面语言切换、aria-label 变更都会让它坏掉。选择器和时序都写进脚本注释了，坏了照着改。要稳还是上 Resend / SMTP。
4. **首次运行要手动 Run once 预授权**。第一次跑会弹权限确认（浏览器控制 + Bash），批准后记在任务上。不预授权的话，凌晨三点的告警会卡在权限弹窗上不动 —— 而这恰恰是你最需要它工作的时候。
5. 三人群发只验证了**预填**，没做真实群发（不想拿测试邮件打扰同事）。首次真实告警会是第一次端到端三人发送。

---

## 七、可复用的方法论

这七条脱离 Outlook / opencli 也成立，是这次真正的收获：

1. **`clicked: true` 不等于业务成功。** UI 自动化必须有独立的结果核验 —— 发信就去查已发送邮件，下单就去查订单列表，提交就去查列表里有没有新记录。只信工具返回值迟早翻车，而且翻的时候是静默的。
2. **别假设登录态。** 动手前一条 `get title` 确认账号，成本几乎为零。
3. **配置写完要回读。** cron 表达式方言不一致，`3-59/10` 这种写法可能被静默曲解成完全不同的语义。
4. **查询接口返回空，先验证接口本身是活的。** 用一个「肯定存在」的关键词试一下，再决定要不要下「不存在」的结论。
5. **告警的判定标准必须机械可判。** 状态码、关键字、DOM 元素在不在。写「看起来正常」等于给自己造一个必然在三天内被关掉的告警。
6. **去重状态只在动作确认成功后才写。** 失败也写 = 制造永久静默，比没有告警更糟 —— 因为你以为有。
7. **重试要重建上下文，不是重复同一个动作。** SPA 的列表不会自己刷新。
