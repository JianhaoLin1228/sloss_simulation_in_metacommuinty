#!/bin/bash
# 合并版：同时检查 sexual / asexual 两种情景中哪些参数目录缺少最终图片，
# 并自动把缺失目录反解成参数列表，方便补跑。
#
# 适配目录结构：
#   /scratch/project_2018377/ljianhao/SLOSS_GRFE/
#     rep=<rep>/<sexual|asexual>/patch_num=<NNN>/is_same_heterogeneity=<True|False>/disp_among=<...>-disp_within=<...>/patch_dist_rate=<...>/
#
# 用法：
#   bash check_and_extract_missing_jobs.sh
#
# 可选环境变量：
#   ROOT=/scratch/project_2018377/ljianhao/SLOSS_GRFE
#   MODE=all3      # all3: 三张最终图都存在才算完成（默认）
#   MODE=any       # any: 任意一张最终图存在就算完成
#   TIME_STEP=4999
#
# 输出：
#   missing_dirs.txt          缺失图片的参数目录（sexual + asexual）
#   completed_dirs.txt        已完成的参数目录（sexual + asexual）
#   missing_jobs.txt          每行一个参数元组
#   missing_jobs.py           Python 可直接导入的 missing_jobs = [...]
#   missing_jobs_sexual.txt   仅 sexual 的参数元组
#   missing_jobs_asexual.txt  仅 asexual 的参数元组

set -euo pipefail

ROOT="${ROOT:-/scratch/project_2018377/ljianhao/SLOSS_GRFE}"
MODE="${MODE:-all3}"
TIME_STEP="${TIME_STEP:-4999}"

MISSING_DIRS="missing_dirs.txt"
COMPLETED_DIRS="completed_dirs.txt"
MISSING_JOBS_TXT="missing_jobs.txt"
MISSING_JOBS_PY="missing_jobs.py"
MISSING_JOBS_SEXUAL_TXT="missing_jobs_sexual.txt"
MISSING_JOBS_ASEXUAL_TXT="missing_jobs_asexual.txt"

if [ ! -d "$ROOT" ]; then
    echo "错误：ROOT 目录不存在：$ROOT" >&2
    exit 1
fi

if [ "$MODE" != "all3" ] && [ "$MODE" != "any" ]; then
    echo "错误：MODE 只能是 all3 或 any，当前是：$MODE" >&2
    exit 2
fi

TMPDIR_WORK=$(mktemp -d)
trap 'rm -rf "$TMPDIR_WORK"' EXIT

ALL_DIRS="$TMPDIR_WORK/all_dirs.txt"
IMG_MAP="$TMPDIR_WORK/img_map.tsv"
COUNTS="$TMPDIR_WORK/counts.txt"

# 1) 列出所有 sexual / asexual 参数目录
find "$ROOT" -type d \( -path '*/sexual/*' -o -path '*/asexual/*' \) -name 'patch_dist_rate=*' | sort > "$ALL_DIRS"

# 2) 一次性列出所有最终图片（非空文件）
find "$ROOT" -type f \( -path '*/sexual/*' -o -path '*/asexual/*' \) -size +0c \
    \( -name "rep=*-time_step=${TIME_STEP}-metacommunity_sp_dis.jpg" \
       -o -name "rep=*-time_step=${TIME_STEP}-metacommunity_sp_x_axis_phenotype_dis.jpg" \
       -o -name "rep=*-time_step=${TIME_STEP}-metacommunity_sp_y_axis_phenotype_dis.jpg" \) \
    -printf '%h\t%f\n' | sort > "$IMG_MAP"

# 3) 依据 MODE 汇总完成/缺失目录（只做两次 find，避免逐目录反复 find）
awk -F '\t' -v mode="$MODE" \
    -v missing_out="$MISSING_DIRS" \
    -v completed_out="$COMPLETED_DIRS" '
BEGIN {
    system(": > \"" missing_out "\"")
    system(": > \"" completed_out "\"")
}
FNR==NR {
    all_dirs[++n] = $0
    next
}
{
    dir = $1
    file = $2
    if (file ~ /-metacommunity_sp_dis\.jpg$/) sp[dir] = 1
    if (file ~ /-metacommunity_sp_x_axis_phenotype_dis\.jpg$/) xp[dir] = 1
    if (file ~ /-metacommunity_sp_y_axis_phenotype_dis\.jpg$/) yp[dir] = 1
}
END {
    for (i = 1; i <= n; i++) {
        d = all_dirs[i]
        has_sp = (d in sp)
        has_xp = (d in xp)
        has_yp = (d in yp)

        completed = 0
        if (mode == "all3") {
            completed = has_sp && has_xp && has_yp
        } else if (mode == "any") {
            completed = has_sp || has_xp || has_yp
        }

        if (completed) {
            print d >> completed_out
        } else {
            print d >> missing_out
        }
    }
}
' "$ALL_DIRS" "$IMG_MAP"

# 清除可能的空行
sed -i '/^$/d' "$MISSING_DIRS" "$COMPLETED_DIRS"

TOTAL=$(wc -l < "$ALL_DIRS")
DONE=$(wc -l < "$COMPLETED_DIRS")
MISS=$(wc -l < "$MISSING_DIRS")

# 4) 反解 missing_dirs.txt -> missing_jobs*.txt / .py
: > "$MISSING_JOBS_TXT"
: > "$MISSING_JOBS_SEXUAL_TXT"
: > "$MISSING_JOBS_ASEXUAL_TXT"

while IFS= read -r line || [ -n "$line" ]; do
    [ -z "${line// }" ] && continue

    dir="${line%/}"

    if [[ "$dir" == */sexual/* ]]; then
        reproduce_mode="sexual"
    elif [[ "$dir" == */asexual/* ]]; then
        reproduce_mode="asexual"
    else
        echo "警告：无法识别 reproduce_mode，跳过：$dir" >&2
        continue
    fi

    # 用 sed 精确解析，避免 bash 参数展开在重复键名路径上出错
    rep_seg=$(printf '%s\n' "$dir" | sed -n 's#^.*/rep=\([^/]*\)/.*#\1#p')
    patch_seg=$(printf '%s\n' "$dir" | sed -n 's#^.*/patch_num=\([^/]*\)/.*#\1#p')
    hetero_seg=$(printf '%s\n' "$dir" | sed -n 's#^.*/is_same_heterogeneity=\([^/]*\)/.*#\1#p')
    disp_seg=$(printf '%s\n' "$dir" | sed -n 's#^.*/disp_among=\([^/]*\)/patch_dist_rate=.*#\1#p')
    patch_dist_seg=$(printf '%s\n' "$dir" | sed -n 's#^.*/patch_dist_rate=\([^/]*\)$#\1#p')

    if [ -z "$rep_seg" ] || [ -z "$patch_seg" ] || [ -z "$hetero_seg" ] || [ -z "$disp_seg" ] || [ -z "$patch_dist_seg" ]; then
        echo "警告：无法完整解析目录，跳过：$dir" >&2
        continue
    fi

    if [[ "$disp_seg" =~ ^([^/]+)-disp_within=([^/]+)$ ]]; then
        disp_among="${BASH_REMATCH[1]}"
        disp_within="${BASH_REMATCH[2]}"
    else
        echo "警告：无法解析 disp_among/disp_within，跳过：$dir" >&2
        continue
    fi

    # 这里必须用算术展开，不能用 printf '%d' '10#004'
    rep=$((10#$rep_seg))
    patch_num=$((10#$patch_seg))

    if [ "$hetero_seg" != "True" ] && [ "$hetero_seg" != "False" ]; then
        echo "警告：is_same_heterogeneity 不是 True/False，跳过：$dir" >&2
        continue
    fi

    tuple=$(printf '(%s, %s, %s, "%s", (%s, %s), %s)' \
        "$rep" "$patch_num" "$hetero_seg" "$reproduce_mode" "$disp_among" "$disp_within" "$patch_dist_seg")

    echo "$tuple" >> "$MISSING_JOBS_TXT"
    if [ "$reproduce_mode" = "sexual" ]; then
        echo "$tuple" >> "$MISSING_JOBS_SEXUAL_TXT"
    else
        echo "$tuple" >> "$MISSING_JOBS_ASEXUAL_TXT"
    fi

done < "$MISSING_DIRS"

# 去重排序
sort -u "$MISSING_JOBS_TXT" -o "$MISSING_JOBS_TXT"
sort -u "$MISSING_JOBS_SEXUAL_TXT" -o "$MISSING_JOBS_SEXUAL_TXT"
sort -u "$MISSING_JOBS_ASEXUAL_TXT" -o "$MISSING_JOBS_ASEXUAL_TXT"

# 生成 Python 列表文件
{
    echo 'missing_jobs = ['
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "${line// }" ] && continue
        echo "    $line,"
    done < "$MISSING_JOBS_TXT"
    echo ']'
} > "$MISSING_JOBS_PY"

COUNT_ALL=$(wc -l < "$MISSING_JOBS_TXT")
COUNT_SEX=$(wc -l < "$MISSING_JOBS_SEXUAL_TXT")
COUNT_ASEX=$(wc -l < "$MISSING_JOBS_ASEXUAL_TXT")

echo "检查并反解完成（sexual + asexual）"
echo "ROOT: $ROOT"
echo "MODE: $MODE"
echo "TIME_STEP: $TIME_STEP"
echo "总参数目录数: $TOTAL"
echo "已完成目录数: $DONE"
echo "缺失目录数: $MISS"
echo "输出文件:"
echo "  - $MISSING_DIRS"
echo "  - $COMPLETED_DIRS"
echo "  - $MISSING_JOBS_TXT"
echo "  - $MISSING_JOBS_PY"
echo "  - $MISSING_JOBS_SEXUAL_TXT"
echo "  - $MISSING_JOBS_ASEXUAL_TXT"
echo "缺失参数组数量（全部）: $COUNT_ALL"
echo "缺失参数组数量（sexual）: $COUNT_SEX"
echo "缺失参数组数量（asexual）: $COUNT_ASEX"
