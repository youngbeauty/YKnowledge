#!/bin/bash
# 用法: render.sh <input.html> <output.pdf>
# 无头 Chrome 渲染 A4 PDF 并报告页数
set -e
IN="$1"; OUT="$2"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
[ -x "$CHROME" ] || CHROME="$(command -v chromium || command -v google-chrome)"
"$CHROME" --headless --disable-gpu --no-pdf-header-footer \
  --print-to-pdf="$OUT" "file://$(cd "$(dirname "$IN")" && pwd)/$(basename "$IN")" >/dev/null 2>&1
python3 - "$OUT" <<'EOF'
import re, sys
data = open(sys.argv[1], 'rb').read()
pat = rb'/Type\s*/Page[^s]'
pages = len(re.findall(pat, data))
print(f"OK {sys.argv[1]}  pages={pages}  bytes={len(data)}")
EOF
