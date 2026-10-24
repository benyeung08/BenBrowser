# 生成各平台原生壳（Windows 端用 PowerShell 跑）
# 用法： .\tool\bootstrap.ps1
param(
    [string]$Org = "com.nimbus",
    [string]$Platforms = "android,windows,macos,linux"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

$backup = Join-Path $env:TEMP "nimbus_main.dart.bak"
if (Test-Path "lib\main.dart") {
    Copy-Item "lib\main.dart" $backup -Force
}

flutter config --enable-windows-desktop --enable-macos-desktop --enable-linux-desktop
flutter create --org $Org --project-name nimbus_browser --platforms $Platforms .

if (Test-Path $backup) {
    Copy-Item $backup "lib\main.dart" -Force
}

flutter pub get

# Windows 端没有 android/macos 目录时，补丁脚本自动跳过
python tool/patch_platform.py

Write-Host "==> 完成。flutter run -d windows 即可调试"
