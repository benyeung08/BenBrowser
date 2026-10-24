#!/usr/bin/env bash
# 本地自检：与 CI 的 verify 步骤完全一致，push 前先跑一遍
set -uo pipefail

cd "$(dirname "$0")/.."

echo "==> flutter pub get"
flutter pub get

echo "==> flutter analyze lib test"
flutter analyze lib test
ANALYZE=$?

echo "==> flutter test"
flutter test
TEST=$?

echo
if [ $ANALYZE -eq 0 ] && [ $TEST -eq 0 ]; then
  echo "✅ 全部通过，可以 push"
else
  echo "❌ analyze=$ANALYZE test=$TEST"
  echo "把上面 analyze 的完整输出（含文件名与行号）贴给助手即可精确定位"
fi

exit $((ANALYZE + TEST))
