#!/usr/bin/env bash
# ==========================================================
# 从多个笔记仓库拉取内容,生成到 _posts/notes/<仓库名>/
# 笔记不带日期与 front matter,按 git 提交日期生成日期。
# 仓库列表见 scripts/notes-repos.txt(名称 地址 每行一个)。
# 各仓库根目录 config.yml(旧版 columns.yml 自动兼容)提供:
#   columns: 本仓库专栏配置,聚合到站点 _data/columns.yml;
#   exclude: 不发布的 md 文件/文件夹(相对仓库根目录),遍历时跳过。
# 由 GitHub Actions 构建前运行;本地手动运行时也会临时 clone。
# ==========================================================
set -euo pipefail

REPOS_FILE="${NOTES_REPOS_FILE:-scripts/notes-repos.txt}"  # 仓库列表
SRC_BASE="_notes-src"          # 临时 clone 根目录(不入库,见 .gitignore)
OUT_BASE="_posts/notes"        # Jekyll 输出根目录(_posts 子目录,自动进入主时间线)
ASSETS_BASE="assets/notes"     # 图片拷贝根目录
COLUMNS_OUT="_data/columns.yml" # 专栏配置输出:由各仓库根 config.yml 的 columns 段合并(不入库)
COLS_TMP="$(mktemp)"            # columns 聚合临时文件
COLS_IDS=""                     # 已收集的专栏 id(换行分隔,用于查重)
EXCLUDES=()                     # 当前仓库的 exclude 清单(相对仓库根目录的 md 路径)

# 命中排除清单返回 0:以 / 结尾的条目按目录前缀匹配;不带 / 的条目精确匹配文件,命中同名目录时按目录前缀匹配
is_excluded() {
  local rel="$1" p
  for p in "${EXCLUDES[@]:-}"; do
    case "$p" in
      */) [[ "$rel" == "$p"* ]] && return 0 ;;
      *)  [[ "$rel" == "$p" || "$rel" == "$p"/* ]] && return 0 ;;
    esac
  done
  return 1
}

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
  EXCLUDES=()

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

  # 仓库根配置:优先 config.yml,兼容旧版 columns.yml
  src_cfg="$src/config.yml"
  [ -f "$src_cfg" ] || src_cfg="$src/columns.yml"
  if [ -f "$src_cfg" ]; then
    echo "  📋 配置: $name ($(basename "$src_cfg"))"

    # 解析 exclude 清单(条目为相对仓库根目录的 md 路径,支持引号/注释/空行)
    EXCLUDES=()
    while IFS= read -r p; do
      EXCLUDES+=("$p")
    done < <(awk '
      /^exclude:[[:space:]]*$/ { cap = 1; next }
      cap && /^[A-Za-z0-9_.-]+:[[:space:]]*$/ { exit }
      cap && /^[[:space:]]*#/ { next }
      cap && /^[[:space:]]*-[[:space:]]*/ {
        line = $0
        sub(/^[[:space:]]*-[[:space:]]*/, "", line)
        sub(/[[:space:]]*$/, "", line)
        gsub(/^["'\'']+|["'\'']+$/, "", line)
        sub(/^\.\//, "", line)
        if (line != "") print line
      }
    ' "$src_cfg")

    # columns 段聚合:同 id 跨仓库重复属于配置错误,直接失败(强制人工调整);
    # 聚合格式新旧兼容:顶层有 columns: 键时抽取该段(去掉列表项缩进),旧版纯列表则整文件合并
    while IFS= read -r cid; do
      if [ -z "$cid" ]; then
        echo "  ❌ $name 的 $(basename "$src_cfg") 存在缺少 id 的条目" >&2
        exit 1
      fi
      if grep -qxF "$cid" <<<"$COLS_IDS"; then
        echo "  ❌ 专栏 id 重复: '$cid' ($name 的 $(basename "$src_cfg") 与已收集的配置冲突)" >&2
        exit 1
      fi
      COLS_IDS="${COLS_IDS}${cid}"$'\n'
    done < <(awk '
      /^[[:space:]]*#/ { next }
      /^[[:space:]]*-[[:space:]]*id:[[:space:]]*/ {
        line = $0
        sub(/^[[:space:]]*-[[:space:]]*id:[[:space:]]*/, "", line)
        print line
      }
    ' "$src_cfg")
    if grep -qE '^columns:[[:space:]]*$' "$src_cfg"; then
      awk '
        /^columns:[[:space:]]*$/ { cap = 1; next }
        cap && /^[A-Za-z0-9_.-]+:[[:space:]]*$/ { exit }
        cap && /^[[:space:]]{2}/ { sub(/^  /, "") }
        cap { print }
      ' "$src_cfg" >> "$COLS_TMP"
    else
      cat "$src_cfg" >> "$COLS_TMP"
    fi
  fi

  # 递归遍历仓库内所有 .md(跳过 exclude 命中的文件/文件夹与 README 索引文件,保留子目录结构以免同名冲突)
  count=0
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    if is_excluded "$rel"; then
      echo "  ⊘ 排除 $rel"
      continue
    fi
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
    root_img_prefix="/assets/notes/$name"
    if [ "$rel_dir" != "." ] && [ -d "$md_assets" ]; then
      assets_out="$ASSETS_BASE/$name/$rel_dir/assets"
      mkdir -p "$assets_out"
      cp -R "$md_assets"/. "$assets_out"/
      img_prefix="/assets/notes/$name/$rel_dir/assets"
    else
      img_prefix="$root_img_prefix"
    fi
    # 仓库根 assets 场景:md 里的引用写作 ../assets/ 或 ../../assets/(../ 个数=md 所在目录的层数),需按层数改写为根 assets 的部署绝对路径,
    # 否则相对链接会残留到页面里解析失败
    rel_sed=""
    if [ "$rel_dir" != "." ]; then
      depth=$(awk -F/ '{ print NF }' <<<"$rel_dir")
      ups=""
      i=0
      while [ "$i" -lt "$depth" ]; do ups="${ups}\\.\\./"; i=$((i + 1)); done
      rel_sed="s|](${ups}assets/|]($root_img_prefix/|g"
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
      ' "$f" | sed "s|\](assets/|]($img_prefix/|g" | sed "$rel_sed"
    } > "$out_file"

    count=$((count + 1))
    echo "  ✓ $out_file (提交日期 $date)"
  done < <(find "$src" -type f -name '*.md' ! -path '*/.git/*' -print0)

  echo "  ✅ $name: $count 篇"
  total=$((total + count))
done < "$REPOS_FILE"

# 聚合各仓库 columns 段 → _data/columns.yml;没有任何仓库提供时清除旧产物
if [ -s "$COLS_TMP" ]; then
  mkdir -p "$(dirname "$COLUMNS_OUT")"
  cat > "$COLUMNS_OUT" <<'EOF'
# 自动生成:由 scripts/pull-notes.sh 从各笔记仓库根目录 config.yml 的 columns 段合并而来(不入库)。
# 维护入口:各笔记仓库根目录的 config.yml,勿直接编辑本文件。
EOF
  cat "$COLS_TMP" >> "$COLUMNS_OUT"
  rm -f "$COLS_TMP"
  echo "✅ 专栏配置已合并 → $COLUMNS_OUT"
else
  rm -f "$COLUMNS_OUT" "$COLS_TMP"
fi

echo "✅ 共生成 $total 篇笔记到 $OUT_BASE"
