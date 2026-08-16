# 接 VibeProxy 与配思考强度

用已有的 Claude / ChatGPT 订阅喂 dsh，不另外买 API key。顺带解决「模型选了但没有思考强度选项」。

只适用 macOS 13+。VibeProxy 是 [automazeio/vibeproxy](https://github.com/automazeio/vibeproxy)，菜单栏小程序，把订阅包装成 OpenAI 兼容接口；内核是 [CLIProxyAPIPlus](https://github.com/router-for-me/CLIProxyAPIPlus)。

> 这是个人实践笔记，2026-08-15 实测。VibeProxy 和 dsh 都在快速迭代，模型名和端口以你机器上实际看到的为准。

## 这套组合解决什么

| | 没有代理 | 有 VibeProxy |
|---|---|---|
| 付费 | 订阅 + 另买 API key | 只用订阅 |
| 能用的模型 | 你买了 key 的那家 | Claude / Codex / Gemini / Copilot / GLM / Kimi 混着用 |
| dsh 怎么看它 | 各家提供方 | 一个 OpenAI 兼容的自定义提供方 |

代价：订阅额度按对话计费，跑 agent 消耗比手动聊天快得多；出问题时多一层要排查。

## 1. 装 VibeProxy 并登录

从 [Releases](https://github.com/automazeio/vibeproxy/releases) 下对应架构的 zip（Apple Silicon 选 arm64），拖进「应用程序」，启动。已签名公证，不会被 Gatekeeper 拦。

菜单栏图标 → Open Settings → 给要用的服务点 **Connect**，浏览器里走完 OAuth。凭据落在 `~/.cli-proxy-api/`。状态显示 Running 就绪。

## 2. 找到你的端口和模型名

**别照抄别人的端口。** VibeProxy 会开两个：菜单栏 App 一个，真正的 API 一个。自己查：

```bash
lsof -iTCP -sTCP:LISTEN -n -P | grep -i proxy
```

`cli-proxy-api-plus` 那行的端口才是 API 口（本文示例用 8318，你的可能不同）。也可以直接看配置：

```bash
grep -E '^(host|port)' ~/.cli-proxy-api/merged-config.yaml
```

然后列出实际可用的模型 —— 这一步不能跳过，模型名是 VibeProxy 自己定的，和各家官方名字不一样：

```bash
curl -s http://127.0.0.1:8318/v1/models | python3 -m json.tool | grep '"id"'
```

## 3. 接进 dsh

编辑 `$DSH_HOME/settings.yaml`（默认 `~/.dsh/settings.yaml`）：

```yaml
llm-pi-ai:
  providers:
    vibeproxy:                              # 提供方 ID，小写，定了别改
      displayName: VibeProxy
      api: openai-completions
      baseURL: http://127.0.0.1:8318/v1     # 换成你查到的端口
      apiKeyEnv: VIBEPROXY_API_KEY
      models:
        - id: claude-opus-5                 # 换成你 /v1/models 里看到的
        - id: claude-sonnet-5

agent-default-model:
  provider: vibeproxy
  model: claude-opus-5
```

`apiKeyEnv` 指向的环境变量必须存在，但值随便填 —— 本地代理认订阅不认 key，dsh 那边不给会报 `MISSING_CREDENTIAL`：

```bash
echo 'export VIBEPROXY_API_KEY=not-used' >> ~/.zshrc && source ~/.zshrc
```

重开 dsh，设置 → 模型里应该能选到了。

## 4. 为什么没有思考强度选项

配完你会发现：模型能选，但**没有思考强度（reasoning effort）选择器**。

不是 bug，是配置缺一项。dsh 判断一个模型会不会思考，只认两个来源：

1. 内置 catalog（`pi-ai` 自带的模型库）里同名条目的能力；
2. 你在 `settings.yaml` 里用 `reasoningEfforts` 自己声明。

VibeProxy 的模型名是它自己拼的，内置 catalog 里根本没有，所以第 1 条继承不到任何东西。而**手工声明的模型默认不推理** —— dsh 于是完全不显示这个控件。

这是刻意设计。这类模型如果硬报成「只支持 off 一档」，而 off 的实现就是省略参数，那和不选任何档位发出的请求完全一样：选它关不掉任何东西，界面却显示「已关闭」。宁可不给控件，也不给一个骗人的开关。

## 5. 查出模型真实支持的档位

**不要猜，也不要照抄本文。** 每个模型支持的档位不一样。VibeProxy 二进制里内嵌了一份模型注册表，直接读它：

```bash
B=/Applications/VibeProxy.app/Contents/Resources/cli-proxy-api-plus
M=claude-opus-5                              # 换成你要查的模型

strings -a -n 4 "$B" | grep -A 25 "\"id\": \"$M\"" \
  | sed -n '/"levels"/,/]/p' | grep -oE '"[a-z]+"' | tr -d '"' \
  | grep -v '^levels$' | awk '!seen[$0]++' | paste -sd, -
```

实测输出（同一台机器，同一份二进制）：

```
claude-opus-5   -> low,medium,high,xhigh,max
claude-sonnet-5 -> low,medium,high,xhigh,max
gpt-5.6-luna    -> low,medium,high,xhigh,max
grok-4.3        -> none,low,medium,high        ← 档位不同！
gpt-image-2     -> 空（没有 thinking 块，图像模型不推理）
```

差异是真的：全表 83 个模型里，只有 33 个有 `xhigh`，23 个有 `minimal`，只有 1 个有 `none`。**照抄别人的配置就会配错。**

顺带能查到容量，一起填进配置省得用兜底值：

```bash
strings -a -n 4 "$B" | grep -A 12 "\"id\": \"$M\"" \
  | grep -E '"(context_length|max_completion_tokens)"'
```

## 6. 写进配置

给每个会思考的模型加 `reasoningEfforts`。键是 dsh 界面显示的档位，值是发给代理的字符串：

```yaml
      models:
        - id: claude-opus-5
          contextWindow: 1000000
          maxTokens: 128000
          reasoningEfforts: &efforts        # YAML 锚点，下面复用
            off: none
            low: low
            medium: medium
            high: high
            xhigh: xhigh
            max: max
        - id: claude-sonnet-5
          contextWindow: 1000000
          maxTokens: 128000
          reasoningEfforts: *efforts        # 档位相同才能复用
        - id: gpt-image-2                    # 不推理的模型不要加
```

几个坑：

- **只给档位相同的模型复用锚点。** `grok-4.3` 只有 `none,low,medium,high`，套上面那份会把 `xhigh` / `max` 也报给界面，选了就报错。
- **`off` 要给真实值。** 上面写 `off: none` 是因为实测 VibeProxy 认 `none` 且真的关闭思考。留空（`off:`）的语义是「支持，但什么都不发」，那就退化成第 4 节说的假开关了。
- `off` 在 YAML 1.2 里是字符串，不会被当成布尔 `false`，dsh 用的正是 1.2 解析器，可以放心写。
- **别声明注册表里没有的档位。** 代理会把它「向上夹紧」到最近的合法档 —— 比如给 opus-5 发 `minimal`，实际按 `low` 跑，界面上却是两个重复选项。

改完重开 dsh，选择器就出来了。

## 7. 验证档位真的有效

配上了不等于有用。代理可能把几档映射到同一个值。用同一个难题跑几轮，比较返回的思考长度：

```bash
for E in none low medium high xhigh max; do
  printf "%-7s " "$E"
  curl -s http://127.0.0.1:8318/v1/chat/completions \
    -H 'Content-Type: application/json' -H 'Authorization: Bearer x' \
    -d "{\"model\":\"claude-opus-5\",
         \"messages\":[{\"role\":\"user\",\"content\":\"证明素数有无穷多个，并给出两种不同证法\"}],
         \"reasoning_effort\":\"$E\",\"max_tokens\":8192}" \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);m=d["choices"][0]["message"];print("思考字符",len(m.get("reasoning") or ""),"tokens",d["usage"]["completion_tokens"])'
done
```

某次实测（claude-opus-5，每档 5 次取均值）：

| 档位 | 思考字符 | completion_tokens | 耗时 |
|---|---|---|---|
| 不发参数 | 0 | 2508 | 27s |
| `none` | 0 | 1619 | 18s |
| `low` | 783 | 1418 | 18s |
| `medium` | 1179 | 2079 | 24s |
| `high` | 1617 | 2758 | 31s |
| `xhigh` | 2331 | 3790 | 41s |
| `max` | 2994 | 5008 | 54s |

结论：档位是真的，`low → max` 思考量涨约 4 倍，耗时从 18s 到 54s，不是别名。

两个值得注意的点：

- **`none` 和「不发参数」不等价。** 两者都不思考，但 token 数差很多（1619 vs 2508）。不发参数走的是代理的透传默认，发 `none` 是显式关闭。所以 `off: none` 是个真开关。
- **`minimal` 测出来和 `low` 无法区分**（873 vs 783，在噪声范围内），因为它不在 opus-5 的合法档位里，被夹紧到了 `low`。这就是「别声明注册表里没有的档位」的实证。

如果你测出来某几档没有区别，就把它们从 `reasoningEfforts` 里删掉 —— 少几个选项，好过几个假选项。

## 排错

| 现象 | 原因 |
|---|---|
| 没有思考强度选择器 | `reasoningEfforts` 没配，见第 4 节 |
| `UNSUPPORTED_REASONING_EFFORT` | 声明了模型不支持的档位，回第 5 节重查 |
| `MISSING_CREDENTIAL` | `apiKeyEnv` 指的环境变量不存在，值可以是假的但必须有 |
| `UNKNOWN_MODEL` | 模型名没写进 `models`，或和 `/v1/models` 对不上 |
| 连不上 / 超时 | 端口抄错了，或 VibeProxy 停了（菜单栏看 Running） |
| 选了档位但明显没思考 | 该模型本来就不推理，查注册表有没有 `thinking` 块 |

代理侧的错误日志在 `~/.cli-proxy-api/logs/`。

## 别怎么用

- 别把 `baseURL` 写成 `0.0.0.0` 或对外暴露 —— 那等于把你的订阅开放给同网段。
- 别在 agent 上无限跑 `max`。订阅额度按用量扣，思考 5000 token 一轮很快就见底。
- 别指望这套稳定。VibeProxy 靠逆向订阅接口工作，上游一改就可能全挂，重要的活留条后路。
- 别把注册表当承诺。那是 VibeProxy 单方面的声明，它内部怎么把 `max` 翻译成各家真实参数（Anthropic 用的是 `budget_tokens`，根本没有 `reasoning_effort`）没有对外保证。第 7 节的实测才是你能握住的证据。
