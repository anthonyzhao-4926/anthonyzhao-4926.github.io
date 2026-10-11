#!/usr/bin/env bash
# ==========================================================
# 从多个笔记仓库拉取内容,生成到 _posts/notes/<仓库名>/
# 笔记不带日期与 front matter,按 git 提交日期生成日期。
# 仓库列表见 scripts/notes-repos.txt(名称 地址 每行一个)。
# 各仓库根目录 config.yml(旧版 columns.yml 自动兼容)提供:
#   columns: 本仓库专栏配置,聚合到站点 _data/columns.yml;
#   exclude: 不发布的 md/html 文件/文件夹(相对仓库根目录),遍历时跳过。
# 除 .md 外也支持 .html/.htm 笔记(自带样式/脚本的完整 HTML 文档):
#   原样拷贝到 assets/notes/<仓库名>/ 下作为静态资源,各列表入口直接链接到该页面,
#   文档作为完整页面独立渲染;元数据写在文件头部的 <!-- ... --> 注释块(DOCTYPE 之后、
#   <body> 之前均可),语法同 YAML front matter(title/column/order/viewable),
#   title 缺省时回退 <title> 标签,column 缺省时按同目录/上级目录的 .md 笔记推断。
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

# 从 HTML 文件头部的 <!-- ... --> 注释块提取元数据(用法: html_meta <key> <文件>);
# 块内写法同 YAML front matter,如:
#   <!--
#   title: 事件生命周期
#   column: dsh-plugin
#   -->
# 注释块可放在 DOCTYPE 之后、<body> 之前的任意位置(不必独占首行),也可以是
# 单行写法 <!-- title: x -->;只看首个注释块,避免把正文里的注释当元数据。
html_meta() {
  awk -v key="$1" '
    function val(s, k) {
      sub("^[[:space:]]*" k ":[[:space:]]*", "", s)
      sub(/[[:space:]]+$/, "", s)
      gsub(/^["'\'']+|["'\'']+$/, "", s)
      return s
    }
    NR > 60 { exit }
    !inm && /<!--/ {
      line = $0
      sub(/^.*<!--/, "", line)
      if (line ~ /-->/) {                       # 单行注释: <!-- title: x, column: y -->
        sub(/-->.*$/, "", line)
        n = split(line, parts, /,[[:space:]]*/)
        for (i = 1; i <= n; i++) {
          if (parts[i] ~ "^[[:space:]]*" key ":[[:space:]]*") { print val(parts[i], key); exit }
        }
        next
      }
      inm = 1
      next
    }
    inm && /-->/ { exit }
    inm && $0 ~ "^[[:space:]]*" key ":[[:space:]]*" { print val($0, key); exit }
  ' "$2"
}

# HTML 文档未声明 column 时,从同目录(再退到上级目录)的 .md 笔记推断所属专栏:
# 参考卡片这类 HTML 文档常与同专栏的 md 放在一起,靠目录关系即可自动归档。
# 用法: infer_column <起始目录> <仓库根目录>
infer_column() {
  local dir="$1" root="$2" depth=0 f col
  while [ -n "$dir" ] && [ "$depth" -lt 2 ]; do
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      col=$(awk '
        NR==1 && $0 ~ /^---[[:space:]]*$/ { fm=1; next }
        fm==1 && $0 ~ /^---[[:space:]]*$/ { exit }
        fm==1 && $0 ~ /^column:[[:space:]]*/ {
          sub(/^column:[[:space:]]*/, "")
          gsub(/^["'\'']+|["'\'']+$/, "")
          print
          exit
        }
      ' "$f")
      if [ -n "$col" ]; then printf '%s\n' "$col"; return 0; fi
    done < <(find "$dir" -maxdepth 1 -type f -iname '*.md' 2>/dev/null | sort)
    if [ "$dir" = "$root" ]; then break; fi
    dir=$(dirname "$dir")
    depth=$((depth + 1))
  done
  return 0
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

  # clone;已有 clone 则同步到远端最新
  # (以前是「已存在就跳过」,导致本地预览一直用第一次 clone 的旧笔记——
  #  新加的 HTML 文档/md 在本地怎么跑都不出现,必须手动删掉 _notes-src 才行)
  if [ ! -d "$src/.git" ]; then
    git clone "$url" "$src" 2>&1 | sed 's/^/    /'
  else
    echo "  ↻ 更新已有 clone 到远端最新"
    git -C "$src" fetch --quiet origin 2>&1 | sed 's/^/    /' || true
    remote_head=$(git -C "$src" symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || echo origin/main)
    git -C "$src" reset --hard --quiet "$remote_head" 2>&1 | sed 's/^/    /' \
      || git -C "$src" reset --hard --quiet origin/main 2>&1 | sed 's/^/    /' || true
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

  # 递归遍历仓库内所有 .md/.html/.htm(跳过 exclude 命中的文件/文件夹与 README 索引文件,保留子目录结构以免同名冲突)
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

    ext_lc=$(printf '%s' "${base##*.}" | tr '[:upper:]' '[:lower:]')
    slug="${base%.*}"
    if [ "$ext_lc" = "md" ]; then
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
    else
      # HTML 文档:元数据取文件头部 <!-- ... --> 注释块(见 html_meta);
      # title 缺省回退 <title> 标签,再回退文件名;
      # column 缺省时按同目录/上级目录的 .md 笔记推断(见 infer_column),
      # 这样「整理好的一份 HTML 参考材料」扔进专栏目录就能自动归档,不必手写元数据
      src_title=$(html_meta title "$f")
      [ -z "$src_title" ] && src_title=$(sed -n 's/.*<title[^>]*>\([^<]*\)<\/title>.*/\1/p' "$f" | head -1)
      src_column=$(html_meta column "$f")
      src_order=$(html_meta order "$f")
      src_viewable=$(html_meta viewable "$f")
      if [ -z "$src_column" ]; then
        src_column=$(infer_column "$(dirname "$f")" "$src")
        if [ -n "$src_column" ]; then
          echo "  · $rel 未声明 column,按同目录笔记推断为 $src_column"
        fi
      fi
      if [ -z "$src_title$src_column" ]; then
        echo "  ℹ $rel 没有元数据注释块:标题回退 <title>,专栏按目录推断;要指定 order/viewable 可在文件头部加 <!-- ... -->"
      fi
    fi
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
    # 同目录同名不同扩展名(如 foo.md 与 foo.html)会生成同一文章文件,属于配置错误,直接失败
    if [ -e "$out_file" ]; then
      echo "  ❌ 输出冲突: $rel 与另一同名笔记生成同一文件 $out_file" >&2
      exit 1
    fi

    # 资源目录:该文件所在目录的 assets 按相对结构拷贝(md 引用改写为对应绝对路径;
    # HTML 原样部署,相对引用随目录结构保留即可解析);
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
    if [ "$ext_lc" = "md" ]; then
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
        # 笔记正文常含 Go/Vue 等 {{ }} 模板；Jekyll 默认当 Liquid 执行，
        # 会把整站页面互相套进正文，构建时内存暴涨、专栏页大到打不开。
        echo "render_with_liquid: false"
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
    else
      # HTML 文档:原样拷贝为静态资源(保留相对目录结构,文档内 assets/ 等相对引用可直接解析);
      # 各列表入口通过 html_url 直接链接到该静态页,文档作为完整页面独立渲染;
      # 文章 URL 本身生成跳转页(layout: html-redirect),兜底直接访问场景
      mkdir -p "$ASSETS_BASE/$name/$rel_dir"
      cp "$f" "$ASSETS_BASE/$name/$rel"
      html_url="/assets/notes/$name/$rel"
      {
        echo "---"
        echo "title: \"$yaml_title\""
        echo "date: $date"
        [ -n "$src_column" ] && echo "column: $src_column"
        [ -n "$src_order" ] && echo "order: $src_order"
        [ -n "$src_viewable" ] && echo "viewable: $src_viewable"
        echo "layout: html-redirect"
        echo "html_url: \"$html_url\""
        echo "---"
        echo ""
        # 正文只作兜底说明与列表摘要:跳转与「打开完整页面」链接由 html-redirect 布局渲染,
        # 这里不写裸空格 URL,免得摘要里出现 /assets/.../%20 这类噪声
        echo "这是一份独立的 HTML 参考文档，本页会自动打开它；若未跳转，请用页面上的链接打开。"
      } > "$out_file"
    fi

    count=$((count + 1))
    echo "  ✓ $out_file (提交日期 $date)"
  done < <(find "$src" -type f \( -iname '*.md' -o -iname '*.html' -o -iname '*.htm' \) ! -path '*/.git/*' -print0)

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
