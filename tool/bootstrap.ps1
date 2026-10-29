# 生成各平台原生壳（Windows 端用 PowerShell 跑）
# 用法： .\tool\bootstrap.ps1
param(
    [string]$Org = "com.ben",
    [string]$Platforms = "android,windows"
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

flutter config --enable-windows-desktop

$backup = Join-Path $env:TEMP "benbrowser_main.dart.bak"
if (Test-Path "lib\main.dart") {
    Copy-Item "lib\main.dart" $backup -Force
}

flutter create --org $Org --project-name ben_browser --platforms $Platforms .

if (Test-Path $backup) {
    Copy-Item $backup "lib\main.dart" -Force
}

# flutter create 生成的模板测试引用 MyApp，与本项目无关
if (Test-Path "test\widget_test.dart") {
    Remove-Item "test\widget_test.dart" -Force
}

flutter pub get

# Windows 端没有 android 目录时，补丁脚本自动跳过
# 先清掉错位副本（手动拷文件容易放错目录，会让后续 analyze 报一大片假错误）
python tool/check_layout.py

python tool/patch_platform.py

Write-Host "==> 完成。flutter run -d windows 即可调试"
