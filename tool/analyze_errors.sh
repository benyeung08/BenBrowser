#!/usr/bin/env bash
# 只打印 analyze 的错误行（含文件和行号），方便贴给助手精确定位。
# 用法： ./tool/analyze_errors.sh
set -uo pipefail

cd "$(dirname "$0")/.."

OUT=$(flutter analyze lib test --no-fatal-infos --no-fatal-warnings 2>&1)

echo "$OUT" | grep -E "^\s*(error|warning)" | sed 's/ • /  |  /g'

echo
echo "---- 汇总 ----"
echo "$OUT" | tail -n 5
