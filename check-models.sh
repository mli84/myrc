#!/usr/bin/env zsh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODELS_FILE="${1:-$SCRIPT_DIR/AI-Models.txt}"
ENV_FILE="${2:-$SCRIPT_DIR/.env}"
PROVIDERS_FILE="${3:-$SCRIPT_DIR/providers.conf}"
TIMEOUT="${CHECK_MODELS_TIMEOUT:-30}"

load_env() {
  local env_file="$1"
  if [[ ! -f "$env_file" ]]; then
    return
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue
    local key="${line%%=*}"
    local val="${line#*=}"
    val="$(echo "$val" | sed 's/^["'"'"']//;s/["'"'"']$//')"
    eval "export ${key}=\"\${val}\""
  done < "$env_file"
}

load_env "$ENV_FILE"

typeset -A PROVIDER_BASE_URL
typeset -A PROVIDER_KEY_ENV
typeset -A PROVIDER_EXTRA_HEADER

load_providers() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "❌ 提供商配置文件不存在: $file" >&2
    exit 1
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    IFS='|' read -r name base_url key_env extra_header <<< "$line"
    [[ -z "$name" || -z "$base_url" || -z "$key_env" ]] && continue

    PROVIDER_BASE_URL[$name]="$base_url"
    PROVIDER_KEY_ENV[$name]="$key_env"
    PROVIDER_EXTRA_HEADER[$name]="${extra_header:-}"
  done < "$file"
}

load_providers "$PROVIDERS_FILE"

get_base_url() {
  echo "${PROVIDER_BASE_URL[$1]:-}"
}

get_key_env() {
  echo "${PROVIDER_KEY_ENV[$1]:-}"
}

get_extra_header() {
  echo "${PROVIDER_EXTRA_HEADER[$1]:-}"
}

is_known_provider() {
  [[ -n "${PROVIDER_BASE_URL[$1]:-}" ]]
}

available=0
unavailable=0
skipped=0
missing_providers=""

check_model() {
  local provider="$1" model="$2" variant="$3"
  local base_url key_env api_key

  base_url="$(get_base_url "$provider")"
  key_env="$(get_key_env "$provider")"
  eval "api_key=\${$key_env:-}"

  if [[ -z "$api_key" ]]; then
    echo "SKIP|${provider}/${model}|缺少 ${key_env}"
    return
  fi

  local request_body
  if [[ -n "$variant" ]]; then
    request_body="{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1,\"thinkingLevel\":\"${variant}\"}"
  else
    request_body="{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"hi\"}],\"max_tokens\":1}"
  fi

  local extra_header
  extra_header="$(get_extra_header "$provider")"

  local start_time end_time elapsed
  start_time=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo "0")

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --max-time "$TIMEOUT" \
    -X POST \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer ${api_key}" \
    ${extra_header:+-H "$extra_header"} \
    -d "$request_body" \
    "${base_url}/chat/completions" 2>/dev/null) || http_code="000"

  end_time=$(python3 -c 'import time; print(int(time.time()*1000))' 2>/dev/null || echo "0")
  elapsed=$((end_time - start_time))
  [[ "$elapsed" -lt 0 ]] && elapsed=0

  if [[ "$http_code" == "200" ]]; then
    echo "OK|${provider}/${model}${variant:+ [$variant]}|${elapsed}ms"
  else
    local error_msg
    case "$http_code" in
      000) error_msg="超时或连接失败" ;;
      401) error_msg="API Key 无效" ;;
      403) error_msg="无权限" ;;
      404) error_msg="模型不存在" ;;
      429) error_msg="频率超限" ;;
      500|502|503) error_msg="服务器错误" ;;
      *) error_msg="HTTP $http_code" ;;
    esac
    echo "FAIL|${provider}/${model}${variant:+ [$variant]}|${error_msg}"
  fi
}

print_result() {
  local result="$1"

  if [[ "${CHECK_MODELS_RAW_OUTPUT:-}" == "1" ]]; then
    echo "$result"
    local _st="${result%%|*}"
    case "$_st" in
      OK) available=$((available + 1)) ;;
      FAIL) unavailable=$((unavailable + 1)) ;;
      SKIP) skipped=$((skipped + 1)) ;;
    esac
    return
  fi

  local _st="${result%%|*}"
  local rest="${result#*|}"
  local name="${rest%%|*}"
  local detail="${rest#*|}"

  case "$_st" in
    OK)
      printf "  ✅  %s — 可用 (%s)\n" "$name" "$detail"
      available=$((available + 1))
      ;;
    FAIL)
      printf "  ❌  %s — %s\n" "$name" "$detail"
      unavailable=$((unavailable + 1))
      ;;
    SKIP)
      printf "  ⚠️  %s — %s\n" "$name" "$detail"
      skipped=$((skipped + 1))
      ;;
  esac
}

if [[ ! -f "$MODELS_FILE" ]]; then
  echo "❌ 模型列表文件不存在: $MODELS_FILE"
  exit 1
fi

echo "🔍 AI 模型可用性检测"
echo "📋 模型列表: $MODELS_FILE"
echo "🔌 提供商配置: $PROVIDERS_FILE"
if [[ -f "$ENV_FILE" ]]; then
  echo "🔑 环境变量: $ENV_FILE"
else
  echo "🔑 环境变量: 未找到 $ENV_FILE，使用系统环境变量"
fi
echo ""

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

model_file="$tmpdir/models.txt"
variant_file="$tmpdir/variants.txt"

while IFS= read -r line || [[ -n "$line" ]]; do
  line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue

  line_variants=""
  if echo "$line" | grep -qE '\([^)]+\)'; then
    line_variants="$(echo "$line" | sed -n 's/.*(\([^)]*\)).*/\1/p')"
    line="$(echo "$line" | sed 's/ ([^)]*)//' | sed 's/([^)]*)//')"
    line="$(echo "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
  fi

  provider="${line%%/*}"
  model="${line#*/}"

  [[ -z "$provider" || -z "$model" ]] && continue
  is_known_provider "$provider" || continue

  echo "${provider}/${model}" >> "$model_file"
  echo "${provider}/${model}|${line_variants}" >> "$variant_file"
done < "$MODELS_FILE"

if [[ ! -f "$model_file" ]]; then
  echo "❌ 未找到有效模型条目"
  exit 1
fi

provider_list="$(cut -d'/' -f1 "$model_file" | sort -u)"

while IFS= read -r provider; do
  [[ -z "$provider" ]] && continue

  key_env="$(get_key_env "$provider")"
  api_key=""
  eval "api_key=\${$key_env:-}"

  echo "🔌 提供商: $provider"

  if [[ -z "$api_key" ]]; then
    echo "   ⚠️  缺少 ${key_env}，跳过该提供商所有模型"
    missing_providers="${missing_providers} ${provider}"
    while IFS= read -r entry; do
      [[ -z "$entry" ]] && continue
      p="${entry%%/*}"
      [[ "$p" != "$provider" ]] && continue
      m="${entry#*/}"
      print_result "SKIP|${entry}|缺少 ${key_env}"
    done < "$model_file"
    echo ""
    continue
  fi

  while IFS= read -r entry; do
    [[ -z "$entry" ]] && continue
    p="${entry%%/*}"
    [[ "$p" != "$provider" ]] && continue

    m="${entry#*/}"
    variants="$(grep "^${entry}|" "$variant_file" | head -1 | cut -d'|' -f2-)"

    if [[ -n "$variants" ]]; then
      default_variant="medium"
      if echo "$variants" | grep -qv "medium"; then
        default_variant="$(echo "$variants" | cut -d'/' -f1)"
      fi
      result="$(check_model "$provider" "$m" "$default_variant")"
    else
      result="$(check_model "$provider" "$m" "")"
    fi

    print_result "$result"
  done < "$model_file"
  echo ""
done <<< "$provider_list"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 检测汇总"
echo "  ✅ 可用: $available"
echo "  ❌ 不可用: $unavailable"
echo "  ⚠️  跳过: $skipped"
if [[ -n "$missing_providers" ]]; then
  echo "  🔑 缺少 API Key:${missing_providers}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
