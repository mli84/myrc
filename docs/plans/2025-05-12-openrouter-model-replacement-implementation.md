# OpenRouter 模型替换脚本 - 实现计划

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 创建 `update-openroute-models.sh` 脚本，从 `openrouter_models.txt` 读取候选模型，使用 `check-models.sh` 检测可用性，并替换 `AI-Models.txt` 中的 openroute 模型。

**Architecture:** 脚本分为三个阶段：读取候选模型、调用检测脚本解析可用性、替换目标文件。通过调用现有 `check-models.sh` 复用检测逻辑，确保行为一致。

**Tech Stack:** Bash, curl, 现有 check-models.sh 工具链

---

## Task 1: 创建脚本骨架和参数解析

**Files:**
- Create: `update-openroute-models.sh`

**Step 1: 编写脚本头部和参数解析**

```bash
#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_FILE="${1:-$SCRIPT_DIR/openrouter_models.txt}"
TARGET_FILE="${2:-$SCRIPT_DIR/AI-Models.txt}"
CHECK_SCRIPT="${3:-$SCRIPT_DIR/check-models.sh}"
```

**Step 2: 添加文件存在性检查**

```bash
# 检查必要文件是否存在
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
```

**Step 3: 赋权并提交**

Run: `chmod +x update-openroute-models.sh`

Commit:
```bash
git add update-openroute-models.sh
git commit -m "feat: add update-openroute-models.sh skeleton with argument parsing"
```

---

## Task 2: 实现候选模型读取逻辑

**Files:**
- Modify: `update-openroute-models.sh`

**Step 1: 添加读取候选模型的函数**

```bash
read_candidates() {
    local file="$1"
    local candidates=()
    
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [[ -z "$line" ]] && continue
        [[ "$line" == \#* ]] && continue
        candidates+=("$line")
    done < "$file"
    
    printf '%s\n' "${candidates[@]}"
}
```

**Step 2: 在主流程中调用并验证**

```bash
# 读取候选模型
echo "📋 读取候选模型..."
mapfile -t candidates < <(read_candidates "$SOURCE_FILE")

if [[ ${#candidates[@]} -eq 0 ]]; then
    echo "⚠️  源文件中没有找到候选模型"
    exit 0
fi

echo "   找到 ${#candidates[@]} 个候选模型"
```

**Step 3: 测试**

Run: `./update-openroute-models.sh`
Expected: 显示 "找到 N 个候选模型"（假设 openrouter_models.txt 存在且有内容）

**Step 4: 提交**

Commit:
```bash
git add update-openroute-models.sh
git commit -m "feat: read candidate models from source file"
```

---

## Task 3: 实现可用性检测和输出解析

**Files:**
- Modify: `update-openroute-models.sh`

**Step 1: 创建临时文件并调用检测脚本**

```bash
# 创建临时目录
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

# 生成候选模型文件
candidate_file="$tmpdir/candidates.txt"
printf '%s\n' "${candidates[@]}" > "$candidate_file"

# 调用检测脚本
echo ""
echo "🔍 开始检测模型可用性..."
```

**Step 2: 解析检测结果**

```bash
available_models=()

while IFS= read -r result; do
    # 解析结果行: OK|openroute/model|time 或 FAIL|... 或 SKIP|...
    if [[ "$result" =~ ^OK\|(.+)\|(.+)$ ]]; then
        model="${BASH_REMATCH[1]}"
        available_models+=("$model")
        echo "  ✅ ${model}"
    elif [[ "$result" =~ ^FAIL\|(.+)\|(.+)$ ]]; then
        model="${BASH_REMATCH[1]}"
        detail="${BASH_REMATCH[2]}"
        echo "  ❌ ${model} — ${detail}"
    elif [[ "$result" =~ ^SKIP\|(.+)\|(.+)$ ]]; then
        model="${BASH_REMATCH[1]}"
        detail="${BASH_REMATCH[2]}"
        echo "  ⚠️  ${model} — ${detail}"
    fi
done < <("$CHECK_SCRIPT" "$candidate_file" 2>/dev/null | grep -E '^(OK|FAIL|SKIP)\|')
```

**Step 3: 检测后处理**

```bash
echo ""
if [[ ${#available_models[@]} -eq 0 ]]; then
    echo "⚠️  没有检测到可用模型，不修改目标文件"
    exit 0
fi

echo "📊 检测结果: ${#available_models[@]} 个可用模型"
```

**Step 4: 测试**

Run: `CHECK_MODELS_TIMEOUT=10 ./update-openroute-models.sh`
Expected: 显示各模型的检测状态和汇总

**Step 5: 提交**

Commit:
```bash
git add update-openroute-models.sh
git commit -m "feat: integrate check-models.sh for availability detection"
```

---

## Task 4: 实现目标文件替换逻辑

**Files:**
- Modify: `update-openroute-models.sh`

**Step 1: 实现替换函数**

```bash
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
        
        # 检测是否是 openroute 模型行
        if [[ "$trimmed" =~ ^openroute/ ]]; then
            # 第一个 openroute 行，插入新模型
            if [[ "$in_openroute_block" == false ]]; then
                for model in "${new_models[@]}"; do
                    echo "$model" >> "$new_file"
                done
                in_openroute_block=true
            fi
            # 跳过现有 openroute 行
            continue
        fi
        
        echo "$line" >> "$new_file"
    done < "$target"
    
    # 如果文件中没有 openroute 行，在末尾追加
    if [[ "$in_openroute_block" == false ]]; then
        echo "" >> "$new_file"
        for model in "${new_models[@]}"; do
            echo "$model" >> "$new_file"
        done
    fi
    
    echo "$new_file"
}
```

**Step 2: 在主流程中调用**

```bash
# 替换目标文件
echo "📝 更新目标文件: $TARGET_FILE"
new_file="$(replace_models "$TARGET_FILE" "$tmpdir" "${available_models[@]}")"
mv "$new_file" "$TARGET_FILE"

echo ""
echo "✅ 完成！已替换为 ${#available_models[@]} 个可用模型"
```

**Step 3: 测试**

先备份 AI-Models.txt：
Run: `cp AI-Models.txt AI-Models.txt.bak`

执行脚本：
Run: `./update-openroute-models.sh`

验证结果：
Run: `diff AI-Models.txt.bak AI-Models.txt`
Expected: 显示 openroute 行被替换为可用模型

恢复备份：
Run: `mv AI-Models.txt.bak AI-Models.txt`

**Step 4: 提交**

Commit:
```bash
git add update-openroute-models.sh
git commit -m "feat: implement target file replacement logic"
```

---

## Task 5: 添加使用说明和最终验证

**Files:**
- Modify: `update-openroute-models.sh`
- Modify: `README.md` (如果存在)

**Step 1: 添加帮助信息**

在脚本开头添加 usage 函数：

```bash
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

# 如果传入 -h 或 --help，显示帮助
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi
```

**Step 2: 最终集成测试**

1. 检查脚本是否能处理空源文件
2. 检查脚本在无可用模型时是否不修改目标文件
3. 检查脚本是否正确保留注释和其他提供商模型

**Step 3: 提交**

Commit:
```bash
git add update-openroute-models.sh
git commit -m "feat: add usage help and finalize update-openroute-models.sh"
```

---

## 验证清单

- [ ] 脚本可执行 (`chmod +x`)
- [ ] 能正确读取候选模型
- [ ] 能正确调用 `check-models.sh` 并解析输出
- [ ] 能正确替换 `AI-Models.txt` 中的 openroute 模型
- [ ] 保留文件中的注释和空行
- [ ] 处理无可用模型的边界情况
- [ ] 处理目标文件无 openroute 行的边界情况
