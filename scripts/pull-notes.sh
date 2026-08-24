#!/usr/bin/env bash
# ==========================================================
# 从多个笔记仓库拉取内容,生成到 _posts/notes/<仓库名>/
# 笔记不带日期与 front matter,按 git 提交日期生成日期。
# 仓库列表见 scripts/notes-repos.txt(名称 地址 每行一个)。
# 由 GitHub Actions 构建前运行;本地手动运行时也会临时 clone。
# ==========================================================
set -euo pipefail

REPOS_FILE="${NOTES_REPOS_FILE:-scripts/notes-repos.txt}"  # 仓库列表
SRC_BASE="_notes-src"          # 临时 clone 根目录(不入库,见 .gitignore)
OUT_BASE="_posts/notes"        # Jekyll 输出根目录(_posts 子目录,自动进入主时间线)
ASSETS_BASE="assets/notes"     # 图片拷贝根目录

[ -f "$REPOS_FILE" ] || { echo "❌ 未找到仓库列表 $REPOS_FILE"; exit 1; }

# 清空旧输出,重新生成(保证已删除的仓库/笔记不会残留)
rm -rf "$OUT_BASE" "$ASSETS_BASE"
mkdir -p "$OUT_BASE"

# 逐仓库处理
total=0
while read -r name url; do
  [ -z "$name" ] && continue
  [[ "$name" == \#* ]] && continue

  src="$SRC_BASE/$name"
  out="$OUT_BASE/$name"
  assets_src="$src/assets"

  echo "▶ 仓库: $name"
  echo "▶ 仓库url: $url"

  # clone(已存在则静默跳过,避免覆盖本地改动)
  if [ ! -d "$src/.git" ]; then
    git clone "$url" "$src" 2>&1 | sed 's/^/    /'
  fi
  [ -d "$src" ] || { echo "  ⚠️ clone 失败,跳过"; continue; }

  mkdir -p "$out"

  # 同步该仓库 assets 图片,并把 markdown 里的相对引用改写为绝对路径
  if [ -d "$assets_src" ]; then
    mkdir -p "$ASSETS_BASE/$name"
    cp -R "$assets_src"/. "$ASSETS_BASE/$name"/
  fi

  # 遍历仓库根目录下所有 .md(跳过 README 索引文件)
  count=0
  for f in "$src"/*.md; do
    [ -f "$f" ] || continue
    base=$(basename "$f")
    [ "$base" = "README.md" ] && continue

    # 取该文件最后提交日期(YYYY-MM-DD),取不到则回退到仓库 HEAD 提交日期
    date=$(git -C "$src" log -1 --format=%cs -- "$base" 2>/dev/null || true)
    [ -z "$date" ] && date=$(git -C "$src" log -1 --format=%cs 2>/dev/null || true)

    slug="${base%.md}"
    # 输出文件名带仓库名前缀,避免不同仓库的同名文件互相覆盖
    out_file="$out/${date}-${slug}.md"

    {
      echo "---"
      echo "title: \"$slug\""
      echo "date: $date"
      echo "---"
      echo ""
      # 改写相对图片引用: ](assets/xx.png -> ](/assets/notes/<name>/xx.png
      sed "s|\](assets/|](/assets/notes/$name/|g" "$f"
    } > "$out_file"

    count=$((count + 1))
    echo "  ✓ $out_file (提交日期 $date)"
  done

  echo "  ✅ $name: $count 篇"
  total=$((total + count))
done < "$REPOS_FILE"

echo "✅ 共生成 $total 篇笔记到 $OUT_BASE"
