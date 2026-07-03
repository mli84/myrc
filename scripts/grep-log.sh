#!/bin/bash
###
 # @Author         : midoll@midoll.ai
 # @Date           : 2026-06-18 11:03:10
 # @LastEditors    : Midoll
 # @LastEditTime   : 2026-06-18 11:06:08
 # @FilePath       : /Users/midoll/scripts/grep-log.sh
 # @Description    : 
 # 
### 

LOG_FILE="$1"
CONTEXT=5

PATTERN="[WATER_CACHE_DEBUG][didUpdateHealthData]|\
[WATER_CACHE_DEBUG][invalidate-start]|\
[WATER_CACHE_DEBUG][invalidate-cache-done] |\
[WATER_CACHE_DEBUG][invalidate-buckets-done]|\
[WATER_CACHE_DEBUG][cache-query-summary]|\
[WATER_CACHE_DEBUG][hk-query-result]|\
[WATER_CACHE_DEBUG][write-bucket]"

grep -E -C "$CONTEXT" "$PATTERN" "$LOG_FILE"