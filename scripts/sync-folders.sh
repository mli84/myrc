#!/bin/bash

# sync-folders.sh - 同步两个文件夹内容的脚本
# 支持配置文件夹，文件夹内部的文件夹名过滤，手动指定需要同步的目录，同步方向等

# 默认配置
SOURCE_DIR=""
DEST_DIR=""
SYNC_MODE="one-way"  # one-way 或 two-way
EXCLUDE_DIRS=()
INCLUDE_DIRS=()
CONFIG_FILE=""
DRY_RUN=false
VERBOSE=false
DELETE=false  # 新增删除选项

# 显示帮助信息
show_help() {
    echo "用法: $(basename $0) [选项]"
    echo ""
    echo "选项:"
    echo "  -s, --source DIR       指定源文件夹路径"
    echo "  -d, --dest DIR         指定目标文件夹路径"
    echo "  -m, --mode MODE        同步模式: one-way(单向,默认) 或 two-way(双向)"
    echo "  -e, --exclude PATTERN  排除的文件夹名称模式 (可多次使用)"
    echo "  -i, --include DIR      指定需要同步的子目录 (可多次使用)"
    echo "  -c, --config FILE      指定配置文件"
    echo "  -n, --dry-run          模拟运行，不实际修改文件"
    echo "  -v, --verbose          显示详细信息"
    echo "  --delete               同步时删除目标目录中源目录没有的文件"
    echo "  -h, --help             显示此帮助信息"
    echo ""
    echo "示例:"
    echo "  $(basename $0) -s ~/Documents -d /Volumes/Backup/Documents -m one-way"
    echo "  $(basename $0) -s ~/Projects -d /Volumes/Backup/Projects -e node_modules -e .git"
    echo "  $(basename $0) -c sync-config.conf"
    exit 0
}

# 检查rsync是否安装
check_rsync() {
    if ! command -v rsync &> /dev/null; then
        echo "错误: 未找到rsync命令。请安装rsync后再运行此脚本。"
        echo "可以使用Homebrew安装: brew install rsync"
        exit 1
    fi
}

# 解析配置文件
parse_config_file() {
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "错误: 配置文件 '$CONFIG_FILE' 不存在"
        exit 1
    fi
    
    while IFS='=' read -r key value || [ -n "$key" ]; do
        # 跳过注释和空行
        [[ $key =~ ^\s*# ]] && continue
        [[ -z $key ]] && continue
        
        # 去除前后空格
        key=$(echo $key | xargs)
        value=$(echo $value | xargs)
        
        case "$key" in
            SOURCE_DIR) SOURCE_DIR="$value" ;;
            DEST_DIR) DEST_DIR="$value" ;;
            SYNC_MODE) SYNC_MODE="$value" ;;
            EXCLUDE_DIRS) 
                # 解析数组格式 "dir1 dir2 dir3"
                IFS=' ' read -r -a EXCLUDE_DIRS <<< "$value"
                ;;
            INCLUDE_DIRS)
                # 解析数组格式 "dir1 dir2 dir3"
                IFS=' ' read -r -a INCLUDE_DIRS <<< "$value"
                ;;
            DRY_RUN)
                if [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]; then
                    DRY_RUN=true
                else
                    DRY_RUN=false
                fi
                ;;
            VERBOSE)
                if [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]; then
                    VERBOSE=true
                else
                    VERBOSE=false
                fi
                ;;
            DELETE)
                if [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]; then
                    DELETE=true
                else
                    DELETE=false
                fi
                ;;
        esac
    done < "$CONFIG_FILE"
}

# 验证必要参数
validate_params() {
    if [ -z "$SOURCE_DIR" ]; then
        echo "错误: 未指定源文件夹"
        show_help
        exit 1
    fi
    
    if [ -z "$DEST_DIR" ]; then
        echo "错误: 未指定目标文件夹"
        show_help
        exit 1
    fi
    
    if [ ! -d "$SOURCE_DIR" ]; then
        echo "错误: 源文件夹 '$SOURCE_DIR' 不存在"
        exit 1
    fi
    
    # 确保目标文件夹存在
    if [ ! -d "$DEST_DIR" ]; then
        echo "目标文件夹 '$DEST_DIR' 不存在，是否创建? (y/n)"
        read -r answer
        if [[ "$answer" =~ ^[Yy]$ ]]; then
            mkdir -p "$DEST_DIR"
            if [ $? -ne 0 ]; then
                echo "错误: 无法创建目标文件夹 '$DEST_DIR'"
                exit 1
            fi
        else
            echo "操作已取消"
            exit 0
        fi
    fi
    
    # 验证同步模式
    if [[ "$SYNC_MODE" != "one-way" && "$SYNC_MODE" != "two-way" ]]; then
        echo "错误: 无效的同步模式 '$SYNC_MODE'，必须是 'one-way' 或 'two-way'"
        exit 1
    fi
}

# 执行同步
perform_sync() {
    local src=$1
    local dst=$2
    local direction=$3  # source-to-dest 或 dest-to-source
    
    echo "正在同步: $src -> $dst"
    
    # 构建rsync命令
    local rsync_cmd="rsync -a"
    
    # 添加删除选项
    if [ "$DELETE" = true ]; then
        rsync_cmd="$rsync_cmd --delete"
    fi
    
    # 添加其他选项
    if [ "$DRY_RUN" = true ]; then
        rsync_cmd="$rsync_cmd --dry-run"
    fi
    
    if [ "$VERBOSE" = true ]; then
        rsync_cmd="$rsync_cmd --verbose"
    else
        rsync_cmd="$rsync_cmd --info=progress2"
    fi
    
    # 添加排除选项
    for dir in "${EXCLUDE_DIRS[@]}"; do
        rsync_cmd="$rsync_cmd --exclude='$dir'"
    done
    
    # 如果指定了包含目录，则只同步这些目录
    if [ ${#INCLUDE_DIRS[@]} -gt 0 ]; then
        for dir in "${INCLUDE_DIRS[@]}"; do
            # 确保源路径中存在此目录
            local include_path="$src/$dir"
            if [ -d "$include_path" ]; then
                echo "同步指定目录: $dir"
                local target_dir="$dst/"
                
                # 执行rsync命令
                eval "$rsync_cmd \"$include_path\" \"$target_dir\""
            else
                echo "警告: 指定的目录 '$dir' 在源路径中不存在，已跳过"
            fi
        done
    else
        # 同步整个目录
        # 确保源路径以/结尾，这样rsync会复制目录内容而不是目录本身
        if [[ "$src" != */ ]]; then
            src="$src/"
        fi
        
        # 执行rsync命令
        eval "$rsync_cmd \"$src\" \"$dst\""
    fi
}

# 主函数
main() {

    # 解析命令行参数
    while [[ $# -gt 0 ]]; do
        case $1 in
            -s|--source)
                SOURCE_DIR="$2"
                shift 2
                ;;
            -d|--dest)
                DEST_DIR="$2"
                shift 2
                ;;
            -m|--mode)
                SYNC_MODE="$2"
                shift 2
                ;;
            -e|--exclude)
                EXCLUDE_DIRS+=("$2")
                shift 2
                ;;
            -i|--include)
                INCLUDE_DIRS+=("$2")
                shift 2
                ;;
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            --delete)
                DELETE=true
                shift
                ;;
            -h|--help)
                show_help
                ;;
            *)
                echo "未知选项: $1"
                show_help
                ;;
        esac
    done

    # 如果指定了配置文件，则解析配置文件
    if [ -n "$CONFIG_FILE" ]; then
        parse_config_file
    fi
    
    # 验证参数
    validate_params
    
    # 检查rsync是否安装
    check_rsync
    
    # 执行同步
    if [ "$SYNC_MODE" = "one-way" ]; then
        # 单向同步: 源 -> 目标
        perform_sync "$SOURCE_DIR" "$DEST_DIR" "source-to-dest"
    else
        # 双向同步: 先源 -> 目标，再目标 -> 源
        echo "执行双向同步..."
        perform_sync "$SOURCE_DIR" "$DEST_DIR" "source-to-dest"
        echo ""
        perform_sync "$DEST_DIR" "$SOURCE_DIR" "dest-to-source"
    fi
    
    echo "同步完成!"
}

# 执行主函数
main "$@"
