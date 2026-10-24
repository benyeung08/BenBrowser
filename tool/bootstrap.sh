#!/usr/bin/env bash
# 生成各平台原生壳（android/windows/macos/linux），这些目录不进版本库。
# 用法：
#   ./tool/bootstrap.sh                          # 全平台
#   PLATFORMS=android,windows ./tool/bootstrap.sh
set -euo pipefail

cd "$(dirname "$0")/.."

ORG="${ORG:-com.nimbus}"
PLATFORMS="${PLATFORMS:-android,windows,macos,linux}"
PROJECT_NAME="nimbus_browser"

echo "==> 使用 org: $ORG  平台: $PLATFORMS"

# flutter create 会用模板覆盖 lib/main.dart，先备份再还原
BACKUP="$(mktemp -d)"
if [ -f lib/main.dart ]; then
  cp lib/main.dart "$BACKUP/main.dart"
fi

flutter config --enable-windows-desktop --enable-macos-desktop --enable-linux-desktop || true
flutter create --org "$ORG" --project-name "$PROJECT_NAME" --platforms="$PLATFORMS" .

if [ -f "$BACKUP/main.dart" ]; then
  cp "$BACKUP/main.dart" lib/main.dart
fi

flutter pub get
python3 tool/patch_platform.py

echo "==> 完成。运行 flutter run -d windows / -d macos / -d <android 设备> 即可调试"
