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

  # 递归遍历仓库内所有 .md(跳过 README 索引文件,保留子目录结构以免同名冲突)
  count=0
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    base=$(basename "$rel")
    [ "$base" = "README.md" ] && continue

    # 取该文件最后提交日期(YYYY-MM-DD),取不到则回退到仓库 HEAD 提交日期
    date=$(git -C "$src" log -1 --format=%cs -- "$rel" 2>/dev/null || true)
    [ -z "$date" ] && date=$(git -C "$src" log -1 --format=%cs 2>/dev/null || true)

    slug="${base%.md}"
    # 源文件若已有 YAML front matter,取其 title/column/order/viewable,正文不再展示这段元数据
    src_title=$(awk '
      NR==1 && $0 ~ /^---[[:space:]]*$/ { fm=1; next }
      fm==1 && $0 ~ /^---[[:space:]]*$/ { exit }
      fm==1 && $0 ~ /^title:[[:space:]]*/ {
        sub(/^title:[[:space:]]*/, "")
        gsub(/^["'\'']+|["'\'']+$/, "")
        print
        exit
      }
    ' "$f")
    src_column=$(awk '
      NR==1 && $0 ~ /^---[[:space:]]*$/ { fm=1; next }
      fm==1 && $0 ~ /^---[[:space:]]*$/ { exit }
      fm==1 && $0 ~ /^column:[[:space:]]*/ {
        sub(/^column:[[:space:]]*/, "")
        gsub(/^["'\'']+|["'\'']+$/, "")
        print
        exit
      }
    ' "$f")
    src_order=$(awk '
      NR==1 && $0 ~ /^---[[:space:]]*$/ { fm=1; next }
      fm==1 && $0 ~ /^---[[:space:]]*$/ { exit }
      fm==1 && $0 ~ /^order:[[:space:]]*/ {
        sub(/^order:[[:space:]]*/, "")
        gsub(/^["'\'']+|["'\'']+$/, "")
        print
        exit
      }
    ' "$f")
    src_viewable=$(awk '
      NR==1 && $0 ~ /^---[[:space:]]*$/ { fm=1; next }
      fm==1 && $0 ~ /^---[[:space:]]*$/ { exit }
      fm==1 && $0 ~ /^viewable:[[:space:]]*/ {
        sub(/^viewable:[[:space:]]*/, "")
        gsub(/^["'\'']+|["'\'']+$/, "")
        print
        exit
      }
    ' "$f")
    title="${src_title:-$slug}"
    yaml_title=${title//\\/\\\\}
    yaml_title=${yaml_title//\"/\\\"}

    rel_dir=$(dirname "$rel")
    if [ "$rel_dir" = "." ]; then
      out_file="$out/${date}-${slug}.md"
    else
      mkdir -p "$out/$rel_dir"
      out_file="$out/$rel_dir/${date}-${slug}.md"
    fi

    # 图片资源:优先拷贝该 md 所在目录的 assets(保持相对结构),引用改写为对应绝对路径;
    # 无本地 assets 时回退到仓库根 assets(循环外已平铺拷贝到 /assets/notes/<name>/)
    md_assets="$(dirname "$f")/assets"
    if [ "$rel_dir" != "." ] && [ -d "$md_assets" ]; then
      assets_out="$ASSETS_BASE/$name/$rel_dir/assets"
      mkdir -p "$assets_out"
      cp -R "$md_assets"/. "$assets_out"/
      img_prefix="/assets/notes/$name/$rel_dir/assets"
    else
      img_prefix="/assets/notes/$name"
    fi

    {
      echo "---"
      echo "title: \"$yaml_title\""
      echo "date: $date"
      [ -n "$src_column" ] && echo "column: $src_column"
      [ -n "$src_order" ] && echo "order: $src_order"
      [ -n "$src_viewable" ] && echo "viewable: $src_viewable"
      echo "---"
      echo ""
      # 去掉源文件 front matter,再改写相对图片引用
      awk '
        function flush_buf() {
          for (i = 1; i <= n; i++) print buf[i]
        }
        NR==1 && $0 ~ /^---[[:space:]]*$/ { in_fm=1; n=0; buf[++n]=$0; next }
        in_fm {
          buf[++n]=$0
          if ($0 ~ /^---[[:space:]]*$/) { in_fm=0; n=0; next }
          next
        }
        { print }
        END { if (in_fm) flush_buf() }
      ' "$f" | sed "s|\](assets/|]($img_prefix/|g"
    } > "$out_file"

    count=$((count + 1))
    echo "  ✓ $out_file (提交日期 $date)"
  done < <(find "$src" -type f -name '*.md' ! -path '*/.git/*' -print0)

  echo "  ✅ $name: $count 篇"
  total=$((total + count))
done < "$REPOS_FILE"

echo "✅ 共生成 $total 篇笔记到 $OUT_BASE"
