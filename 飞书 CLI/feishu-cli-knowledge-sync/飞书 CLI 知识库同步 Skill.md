---
name: feishu-cli-knowledge-sync
description: Batch-sync a local document tree into an existing Feishu Wiki with lark-cli, including user authorization, incremental scope handling, mirrored Wiki nodes, serial Markdown import, empty-file handling, and fresh verification. Use when a user asks to move local notes or documents into a Feishu knowledge base or repeat this workflow.
---

# Feishu CLI Knowledge Sync

## Overview

Use this workflow to copy a local document tree into an existing Feishu Wiki while preserving its directory hierarchy as Wiki nodes. Convert supported Markdown files to Feishu cloud documents, move them into the target Wiki, and verify the resulting node tree.

## Inputs

- `local_root`: local directory containing documents.
- `wiki_url`: existing Wiki root URL or node token.
- `identity`: use `user` for personal libraries and user-owned Wiki spaces.
- `extensions`: map each extension to an import type before writing (for example, `.md` -> `docx`).

## Workflow

1. Inspect the local tree recursively. Count files by extension, record relative paths, sizes, and empty files. Do not modify the source tree.

2. Check identity explicitly:

   ```powershell
   lark-cli auth status --json --verify
   ```

   Use `--as user` on all Wiki and Drive commands. If user identity is missing, request the smallest needed domains with `lark-cli auth login --domain docs --domain drive --no-wait --json`; show the returned verification URL and QR code, stop, and resume only after the user confirms. For a missing scope, start a fresh `auth login --scope "<exact scopes>" --no-wait --json` flow. Never reuse device codes or verification URLs.

3. Resolve the Wiki root and space ID before writing:

   ```powershell
   lark-cli wiki +node-get --node-token "<wiki_url>" --as user --format json
   ```

4. Mirror non-empty local directories with `wiki +node-create --node-type origin --obj-type docx`. Keep a path-to-node-token map. Create only the nodes needed by the source tree.

5. Import documents serially when they share the same Drive mount. For Markdown, use:

   ```powershell
   lark-cli drive +import --file "<relative-file>" --type docx --name "<title>" --as user --format json
   ```

   Do not launch imports concurrently at the same target. Capture the resulting document token and ticket; if the task times out, continue with the returned `drive +task_result` command.

6. Move each imported document into its mapped Wiki parent:

   ```powershell
   lark-cli wiki +move --obj-token "<docx_token>" --obj-type docx `
     --target-space-id "<space_id>" --target-parent-token "<parent_node_token>" `
     --as user --format json
   ```

7. Handle zero-byte files explicitly. If import rejects an empty file, create a same-title blank Wiki node under the mapped parent and record that it is a representation of the source empty file.

8. Verify with fresh reads. List the root and every mirrored parent using `wiki +node-list`; compare expected titles, counts, and parent tokens. Report partial failures instead of claiming completion.

## Guardrails

- Preserve the local source files; this is a one-way copy unless the user separately asks for ongoing synchronization.
- Treat the user's explicit sync request as write authorization, but state the target scope and operation before starting a batch.
- Keep imports serial for one location and stop on repeated concurrency conflicts.
- Never write app secrets, access tokens, device codes, or raw authorization URLs into the skill, logs, or experience documents. Show an authorization URL only for the active authorization step.
- Do not silently switch from `user` to `bot`; bot identity does not see personal Wiki resources.
- Do not delete source files or existing Wiki nodes as part of this workflow.

## Completion report

Return the target Wiki URL, number of source files discovered, number imported, empty-file representations, mirrored directory nodes, any failures, and the verification result. State explicitly whether continuous synchronization was configured.
