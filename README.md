# BrowserApp — 跨平台 Chromium 浏览器

基于 **Kotlin Multiplatform + Compose Multiplatform** 构建，一个代码库覆盖：

| 平台 | 渲染内核 | 产物 |
|------|----------|------|
| Android | 系统 Chromium WebView | APK |
| Windows 11 | KCEF (Chromium Embedded Framework) | `.msi` / `.exe` |
| macOS 15+ (macOS 26 兼容) | KCEF (Chromium Embedded Framework) | `.dmg` |

## 特性

- 统一地址栏 / 前进后退 / 刷新 / 主页
- 书签管理（跨平台共用数据结构）
- 桌面模式（切换 User-Agent）
- 进度条
- **支持 Google 账号登录**（Android 端已配置第三方 Cookie 与 DOM storage）
- Deep Link：外部链接可直接唤起 Android App

## 项目结构

```
BrowserApp/
├── shared/                    # 共享代码（UI + 状态 + expect/actual WebView 接口）
│   ├── commonMain/            # Compose UI、ViewModel、Bookmark 模型
│   ├── androidMain/           # Android WebView 实现
│   └── desktopMain/           # KCEF/Chromium 实现
├── androidApp/                # Android 入口与 Manifest
└── desktopApp/                # 桌面端入口与打包配置
```

## 快速开始

### 前置要求

- **JDK 17**（推荐 JetBrains Runtime / JBR，KCEF 需要 JCEF 支持）
- Android Studio 2024.2+
- Xcode 16+（仅 macOS 打包需要）

### 运行 Android

```bash
./gradlew :androidApp:installDebug
```

### 运行桌面端（Windows / macOS）

```bash
./gradlew :desktopApp:run
```

首次运行会下载 Chromium 运行时（约数百 MB），请保持网络畅通。

### 打包安装包

```bash
# Windows
./gradlew :desktopApp:packageMsi
# 产物: desktopApp/build/compose/binaries/main/msi/*.msi

# macOS
./gradlew :desktopApp:packageDmg
# 产物: desktopApp/build/compose/binaries/main/dmg/*.dmg
```

## Google 账号登录说明

Android 端已启用以下关键配置：

- `domStorageEnabled = true`
- `databaseEnabled = true`
- `setSupportMultipleWindows(true)`
- 允许 `accounts.google.com` 的第三方 Cookie
- `MIXED_CONTENT_ALWAYS_ALLOW`
- Chrome User-Agent

## 关于 KCEF

桌面端使用 [KCEF](https://github.com/DATL4G/KCEF) 封装的 Chromium 内核。它提供：

- 完整的 Chromium 渲染能力，与网页标准兼容性好
- 首启动需下载 Chromium 运行时
- 内存占用高于原生 WebView，发布时请关注打包体积

## License

Apache-2.0
