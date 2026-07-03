#!/bin/bash
###
 # @Author         : midoll@midoll.ai
 # @Date           : 2026-03-20 11:33:16
 # @LastEditors    : Midoll
 # @LastEditTime   : 2026-03-20 11:55:18
 # @FilePath       : /Users/midoll/scripts/move_multi.sh
 # @Description    : 
 # 
### 
# 批量移动目录到指定目标，创建软链接，保留原目录结构
# 主要是为了解决主硬盘空间不足的问题

set -e

DST_BASE="/Volumes/HD2/mirror"

if [ "$#" -lt 1 ]; then
  echo "用法: $0 <目录1> <目录2> ..."
  echo "示例: $0 ~/Library/Developer/Xcode/DerivedData ~/.gradle"
  exit 1
fi

# 检查目标磁盘
if [ ! -d "$DST_BASE" ]; then
  echo "❌ 目标路径不存在或未挂载: $DST_BASE"
  exit 1
fi

echo "📦 目标根目录: $DST_BASE"
echo "----------------------------------"

for SRC in "$@"; do
  echo ""
  echo "👉 处理: $SRC"

  # 转绝对路径
  SRC=$(realpath "$SRC")
  NAME=$(basename "$SRC")
  DST="$DST_BASE/$NAME"

  echo "源目录: $SRC"
  echo "目标目录: $DST"

  # 检查源目录
  if [ ! -d "$SRC" ]; then
    echo "⚠️ 跳过（不存在）"
    continue
  fi

  # 已是软链接
  if [ -L "$SRC" ]; then
    echo "⚠️ 已是软链接，跳过"
    continue
  fi

  # 防止目标已存在冲突
  if [ -e "$DST" ]; then
    echo "⚠️ 目标已存在，跳过: $DST"
    continue
  fi

  echo "🚚 rsync 迁移中..."
  rsync -avh --progress "$SRC/" "$DST/"

  # 备份原目录
  BACKUP="${SRC}_backup_$(date +%Y%m%d%H%M%S)"
  echo "📦 备份原目录 -> $BACKUP"
  mv "$SRC" "$BACKUP"

  # 创建软链接
  echo "🔗 创建软链接..."
  ln -s "$DST" "$SRC"

  # 验证
  if [ -L "$SRC" ]; then
    echo "✅ 完成: $SRC -> $DST"
    echo "🧹 可稍后删除备份: $BACKUP"
  else
    echo "❌ 失败，恢复中..."
    mv "$BACKUP" "$SRC"
  fi

  echo "----------------------------------"
done

echo ""
echo "🎉 所有任务处理完成！"
