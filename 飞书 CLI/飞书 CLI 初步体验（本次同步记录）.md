# 飞书 CLI 初步体验：本地 AI 知识库同步

> 记录时间：2026-08-05  
> 本地来源：`C:\Users\17767\Desktop\自媒体\个人AI知识库`  
> 目标知识库：[首页](https://my.feishu.cn/wiki/OpTQwKBclicamDkM8GccJYKYnce?fromScene=spaceOverview)

## 一、这次做了什么

把本地目录中的 7 个 Markdown 文件同步到目标飞书知识库，并把本地目录映射成 Wiki 节点：

- `个人博客`（含 `cloudFactory`）
- `外网文章摘录`（含 `CC开发者`）
- `提示词合计`

6 个非空 Markdown 被导入为飞书云文档；空文件 `未命名.md` 用同名空白 Wiki 页面表示。原始本地文件没有被修改。

## 二、授权过程记录

本次使用的是用户身份（`--as user`），没有用 bot 代替用户访问个人知识库。授权采用“发起授权—展示 URL/二维码—用户确认—Agent 继续轮询”的分步方式。

1. 初始 `auth status --json --verify` 显示 bot 可用、user 未登录。
2. 首次授权申请文档和云盘域：

   ```powershell
   lark-cli auth login --domain docs --domain drive --no-wait --json
   ```

3. 读取目标 Wiki 节点时，飞书提示缺少知识库读取权限，于是增量申请：

   ```powershell
   lark-cli auth login --scope "wiki:wiki wiki:wiki:readonly wiki:node:read" --no-wait --json
   ```

4. 创建目录节点时，继续补充：

   ```powershell
   lark-cli auth login --scope "wiki:node:create wiki:space:read" --no-wait --json
   ```

5. 把导入后的云文档移动到 Wiki 时，最后补充：

   ```powershell
   lark-cli auth login --scope "wiki:node:move" --no-wait --json
   ```

每次授权都由用户在飞书页面确认，再由 Agent 执行 `lark-cli auth login --device-code <device_code>` 完成绑定。真实 device code、一次性 verification URL、access token 和 app secret 不写入这份记录。

## 三、实际执行链路

### 1. 解析目标

用 `wiki +node-get` 从 Wiki URL 解析出真实的 `space_id` 和根节点 token；不要把 Wiki URL 直接当成 `space_id`。

### 2. 创建目录节点

使用 `wiki +node-create --node-type origin --obj-type docx` 创建与本地目录对应的节点，并保存“本地相对路径 → Wiki node token”的映射。

### 3. 串行导入 Markdown

每个文件使用：

```powershell
lark-cli drive +import --file "<relative-file>" --type docx --name "<title>" --as user --format json
```

导入结果返回 docx token；同一 Drive 位置的导入必须串行，避免飞书导入任务并发冲突。

### 4. 移入 Wiki

使用 `wiki +move` 的 docs-to-wiki 模式，把 docx token 移到对应的 Wiki 父节点：

```powershell
lark-cli wiki +move --obj-token "<docx_token>" --obj-type docx `
  --target-space-id "<space_id>" --target-parent-token "<parent_node_token>" `
  --as user --format json
```

### 5. 验证

用 `wiki +node-list` 重新读取根节点、各目录节点和文档节点，核对标题、数量及父节点关系。最终树形数量与预期一致。

## 四、这次得到的经验

1. 个人知识库优先用 `--as user`；bot 身份看不到用户个人资源。
2. `docs` / `drive` 授权不等于 Wiki 授权；Wiki 读取、建节点、移动节点是分开的 scope。
3. 遇到 `missing_scope` 时，按报错中的最小 scope 增量授权，不要盲目申请全部权限。
4. 授权链接和 device code 是一次性的，不能写进长期文档，也不能跨流程复用。
5. Markdown 导入成 docx，再移动到 Wiki，适合把本地笔记变成可搜索、可协作的飞书页面。
6. 同一位置的导入应串行；长任务返回 ticket 时按 `drive +task_result` 继续查询。
7. 空 Markdown 文件不适合作为有内容的导入任务，可用同名空白 Wiki 页面保留其位置语义。
8. 写入结束必须 fresh read 验证，不能只凭命令返回成功就宣称完成。

## 五、当前边界与下一步

这次是一次性同步，不包含文件监听、增量 diff、定时任务或双向同步。下一步可以在这个 Skill 基础上增加：按文件哈希做增量同步、失败重试清单、重复标题检测，以及可选的定时执行。
