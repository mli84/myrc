#!/usr/bin/env bash

# ----------------------------------------
# 功能：
# - 统计指定目录下“第一层”文件/目录大小
# - 支持隐藏文件（.开头）
# - 按大小排序（从大到小）
# - 支持 Top N
# ----------------------------------------

set -euo pipefail

dir="${1:-.}"        # 默认当前目录
topn="${2:-0}"       # 默认不限制

echo "指定目录: $dir"

# 校验目录
if [[ ! -d "$dir" ]]; then
  echo "目录不存在"
  exit 1
fi

# macOS / Linux 兼容 du
if du -sb . >/dev/null 2>&1; then
  DU_CMD="du -sb"
else
  DU_CMD="du -sk"  # macOS fallback（单位KB）
fi

# 开启包含隐藏文件（但不包含 . 和 ..）
shopt -s dotglob nullglob

tmpfile=$(mktemp)

for path in "$dir"/*; do
  # basename
  name=$(basename "$path")

  # 获取大小（统一用字节/KB作为排序依据）
  size_bytes=$($DU_CMD "$path" | awk '{print $1}')

  # 人类可读
  size_human=$(du -sh "$path" 2>/dev/null | awk '{print $1}')

  printf "%s\t%s\t%s\n" "$size_bytes" "$size_human" "$name" >> "$tmpfile"
done

# 排序
if [[ "$topn" -gt 0 ]]; then
  sort -rn "$tmpfile" | head -n "$topn"
else
  sort -rn "$tmpfile"
fi | awk -F'\t' '{
  printf "%-10s %-10s %s\n", $2, $1 "B", $3
}'

rm -f "$tmpfile"
