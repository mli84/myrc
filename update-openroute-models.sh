#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${1:-$SCRIPT_DIR/openrouter_models.txt}"
TARGET_FILE="${2:-$SCRIPT_DIR/AI-Models.txt}"
CHECK_SCRIPT="${3:-$SCRIPT_DIR/check-models.sh}"

usage() {
    cat << EOF
用法: $(basename "$0") [源文件] [目标文件] [检测脚本]

参数:
  源文件      包含候选模型的文件 (默认: ./openrouter_models.txt)
  目标文件    要更新的模型列表文件 (默认: ./AI-Models.txt)
  检测脚本    模型可用性检测脚本路径 (默认: ./check-models.sh)

说明:
  从源文件读取候选模型，使用检测脚本验证可用性，
  然后用可用模型替换目标文件中的所有 openroute/ 模型。

示例:
  $(basename "$0")
  $(basename "$0") openrouter_models.txt AI-Models.txt
  $(basename "$0") models.txt AI-Models.txt ./scripts/check-models.sh
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

check_files() {
    local missing=0
    for file in "$SOURCE_FILE" "$TARGET_FILE" "$CHECK_SCRIPT"; do
        if [[ ! -f "$file" ]]; then
            echo "❌ 文件不存在: $file"
            missing=1
        fi
    done
    return $missing
}

check_files || exit 1

read_candidates() {
    local file="$1"
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        echo "$line"
    done < "$file"
}

replace_models() {
    local target="$1"
    local tmpdir="$2"
    shift 2
    local new_models=("$@")
    
    local new_file="$tmpdir/new_models.txt"
    local in_openroute_block=false
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        local trimmed
        trimmed="$(echo "$line" | sed 's/^[[:space:]]*//')"
        
        if [[ "$trimmed" =~ ^openroute/ ]]; then
            if [[ "$in_openroute_block" == false ]]; then
                for model in "${new_models[@]}"; do
                    echo "$model" >> "$new_file"
                done
                in_openroute_block=true
            fi
            continue
        fi
        
        echo "$line" >> "$new_file"
    done < "$target"
    
    if [[ "$in_openroute_block" == false ]]; then
        echo "" >> "$new_file"
        for model in "${new_models[@]}"; do
            echo "$model" >> "$new_file"
        done
    fi
    
    echo "$new_file"
}

echo "📋 读取候选模型..."
candidates=()
while IFS= read -r line; do
    candidates+=("$line")
done < <(read_candidates "$SOURCE_FILE")

if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "⚠️  源文件中没有找到候选模型"
    exit 0
fi

echo "   找到 ${#candidates[@]} 个候选模型"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

candidate_file="$tmpdir/candidates.txt"
printf '%s\n' "${candidates[@]}" > "$candidate_file"

echo ""
echo "🔍 开始检测模型可用性..."

available_models=()

contains_model() {
    local needle="$1"
    local item
    if [[ ${#available_models[@]} -eq 0 ]]; then
        return 1
    fi
    for item in "${available_models[@]}"; do
        [[ "$item" == "$needle" ]] && return 0
    done
    return 1
}

while IFS= read -r result; do
    if [[ "$result" =~ ^OK\|(.+)\|(.+)$ ]]; then
        model="${BASH_REMATCH[1]}"
        detail="${BASH_REMATCH[2]}"
        if ! contains_model "$model"; then
            available_models+=("$model")
        fi
        echo "  ✅ ${model} — ${detail}"
    elif [[ "$result" =~ ^FAIL\|(.+)\|(.+)$ ]]; then
        model="${BASH_REMATCH[1]}"
        detail="${BASH_REMATCH[2]}"
        echo "  ❌ ${model} — ${detail}"
    elif [[ "$result" =~ ^SKIP\|(.+)\|(.+)$ ]]; then
        model="${BASH_REMATCH[1]}"
        detail="${BASH_REMATCH[2]}"
        echo "  ⚠️  ${model} — ${detail}"
    fi
done < <(CHECK_MODELS_RAW_OUTPUT=1 "$CHECK_SCRIPT" "$candidate_file" 2>/dev/null | grep -E '^(OK|FAIL|SKIP)\|')

echo ""
if [[ ${#available_models[@]} -eq 0 ]]; then
    echo "⚠️  没有检测到可用模型，不修改目标文件"
    exit 0
fi

echo "📊 检测结果: ${#available_models[@]} 个可用模型"

echo "📝 更新目标文件: $TARGET_FILE"
new_file="$(replace_models "$TARGET_FILE" "$tmpdir" "${available_models[@]}")"
mv "$new_file" "$TARGET_FILE"

echo ""
echo "✅ 完成！已替换为 ${#available_models[@]} 个可用模型"
