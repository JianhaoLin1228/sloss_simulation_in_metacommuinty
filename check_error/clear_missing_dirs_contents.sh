#!/bin/bash
# 方案 A：按 missing_dirs.txt 清空目录内容，但保留目录本身
#
# 用法：
#   bash clear_missing_dirs_contents.sh
#   bash clear_missing_dirs_contents.sh missing_dirs.txt
#
# 说明：
#   - 默认读取当前目录下的 missing_dirs.txt
#   - 对文件中列出的每个目录：删除其下所有文件和子目录，但保留该目录本身
#   - 如果目录不存在，则跳过
#
# 强烈建议：先查看 missing_dirs.txt 内容确认无误后再执行

set -euo pipefail

INPUT="${1:-missing_dirs.txt}"

if [ ! -f "$INPUT" ]; then
    echo "错误：输入文件不存在：$INPUT" >&2
    exit 1
fi

COUNT_TOTAL=0
COUNT_CLEARED=0
COUNT_SKIPPED=0

while IFS= read -r d || [ -n "$d" ]; do
    # 跳过空行
    [ -z "${d// }" ] && continue

    COUNT_TOTAL=$((COUNT_TOTAL + 1))

    if [ -d "$d" ]; then
        echo "清空目录内容: $d"
        find "$d" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
        COUNT_CLEARED=$((COUNT_CLEARED + 1))
    else
        echo "跳过（目录不存在）: $d"
        COUNT_SKIPPED=$((COUNT_SKIPPED + 1))
    fi
done < "$INPUT"

echo "完成：已按 $INPUT 清空目录内容（目录本身保留）"
echo "总目录条目数: $COUNT_TOTAL"
echo "已清空目录数: $COUNT_CLEARED"
echo "跳过目录数: $COUNT_SKIPPED"
