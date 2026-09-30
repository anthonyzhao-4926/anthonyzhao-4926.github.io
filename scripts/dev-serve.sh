#!/usr/bin/env bash
# 本地预览：若 4000 已被占用则先结束旧 Jekyll，再启动 serve + livereload
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${JEKYLL_PORT:-4000}"
HOST="${JEKYLL_HOST:-127.0.0.1}"

cd "$ROOT"

if command -v lsof >/dev/null 2>&1; then
  old_pids=$(lsof -ti ":$PORT" 2>/dev/null || true)
  if [[ -n "${old_pids:-}" ]]; then
    echo "端口 $PORT 已被占用，正在结束旧进程: $old_pids"
    # shellcheck disable=SC2086
    kill $old_pids 2>/dev/null || true
    sleep 1
  fi
fi

exec bundle exec jekyll serve --host "$HOST" --port "$PORT" --livereload
