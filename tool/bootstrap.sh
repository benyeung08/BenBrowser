#!/usr/bin/env bash
# 生成 Android 原生壳（android/ 目录不进版本库）。
# 用法： ./tool/bootstrap.sh
set -euo pipefail

cd "$(dirname "$0")/.."

ORG="${ORG:-com.ben}"
PLATFORMS="android"
PROJECT_NAME="ben_browser"

echo "==> 使用 org: $ORG  平台: $PLATFORMS"

# flutter create 会用模板覆盖 lib/main.dart，先备份再还原
BACKUP="$(mktemp -d)"
if [ -f lib/main.dart ]; then
  cp lib/main.dart "$BACKUP/main.dart"
fi

flutter create --org "$ORG" --project-name "$PROJECT_NAME" --platforms="$PLATFORMS" .

if [ -f "$BACKUP/main.dart" ]; then
  cp "$BACKUP/main.dart" lib/main.dart
fi

# flutter create 生成的模板测试引用 MyApp，与本项目无关，直接删掉
rm -f test/widget_test.dart

flutter pub get
python3 tool/patch_platform.py

echo "==> 完成。运行 flutter devices 查看设备，再 flutter run -d <设备 id>"
