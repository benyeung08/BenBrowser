# BenBrowser

基于 **Flutter + 各平台原生 WebView** 的个人自研浏览器：一份 Dart 代码，同时跑在 **Android / Windows** 上，靠 GitHub Actions 自动出两端安装包。
*A personal browser built on **Flutter + each platform's native WebView**: one Dart codebase running on **Android / Windows**, with GitHub Actions building both automatically.*

| 平台 Platform | 内核 Engine | 要求 Requirements |
| --- | --- | --- |
| Android | 系统 WebView（Chromium） · *System WebView* | Android 10+ |
| Windows | WebView2（Edge Chromium） | **Win10 1809+ / Win11**；Win10 需装 [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) · *Win11 bundles it* |

| 项目 Item | 值 Value |
| --- | --- |
| Android 内核 Engine | 系统 WebView（Chromium），由厂商 / Google Play 更新 · *updated by the OEM / Play Store* |
| 最低系统 minSdk | **29（Android 10）** |
| 目标系统 targetSdk | **37（Android 17）** |
| 渲染 Renderer | **Vulkan 优先**，无 Vulkan 的设备自动回退 **OpenGL ES 3.0** · ***Vulkan** preferred, auto-fallback to **GLES 3.0*** |
| 编译 SDK compileSdk | **37（Android 17）** |
| 构建要求 Build | Flutter ≥ 3.38、NDK r28、Android SDK Platform 37 · *Flutter ≥ 3.38, NDK r28, SDK Platform 37* |
| 安装方式 Install | `app-<abi>-release.apk`，按 CPU 架构拆分 · *split per ABI* |

---

## 已实现功能 / Features

- **多标签** 新建 / 关闭 / 切换，上限 20 个 — *Tabs: open / close / switch, up to 20*
- **地址栏** 裸域名自动补 `https://`，普通关键词走搜索引擎 — *Address bar: bare domains auto-complete to `https://`, anything else goes to search*
- **导航** 前进 / 后退 / 刷新 / 停止 / 主页，带加载进度条 — *Back / forward / reload / stop / home, with a progress bar*
- **书签** 收藏、搜索、删除、清空 — *Bookmarks: add, search, delete, clear*
- **历史记录** 按站点去重、关键词搜索（无痕标签不入库）— *History: deduplicated per site, keyword search (incognito is never recorded)*
- **下载管理** Dio 直连，进度条 + 打开文件 — *Downloads: direct via Dio, progress bar + open file*
- **无痕标签** 独立 incognito 上下文，不写缓存与历史 — *Incognito tabs: separate context, no cache and no history*
- **User-Agent 切换** 跟随系统 / 桌面 Chrome / 移动 Chrome / 自定义 — *UA switching: system / desktop Chrome / mobile Chrome / custom*
- **新标签页** 搜索框 + 常用站点 + 最近访问 — *New tab page: search box + favorite sites + recent visits*
- **主题与设置** 持久化、亮 / 暗 / 跟随系统 — *Persistent settings, light / dark / system theme*
- **`target=_blank`** 自动在新标签打开 — *`target=_blank` links open in a new tab*
- **应用内更新** 读 GitHub Releases，含 changelog；下载后可直接在应用内安装 — *In-app updates: reads GitHub Releases with changelog; installs from within the app after download*

---

## 应用内更新 / In-App Updates

基于 **GitHub Releases**：打 tag 后 CI 自动生成 Release 与 APK，应用端查询 `releases/latest` 拿到版本号与附件。
*Built on **GitHub Releases**: pushing a tag makes CI create the Release and the APKs; the app queries `releases/latest` for the version and assets.*

**首次启用 / First-time setup**：设置 → 更新 → 把「GitHub 仓库」从默认的 `OWNER/ben_browser` 改成你自己的 `用户名/仓库名`。留着 `OWNER` 会被识别为未配置，不会发起请求。
*Settings → Update → change "GitHub repository" from the default `OWNER/ben_browser` to your own `username/ben_browser`. Leaving `OWNER` in place is treated as "not configured" and no request is made.*

**Android 更新流程 / Android update flow**：设置 → 更新 → 检查更新 → 发现新版本 → 「后台下载」→ 在「下载」页看进度 → 完成后点「安装」。
*Settings → Update → Check for updates → new version found → "Download in background" → track progress in Downloads → tap "Install" when finished.*

**Windows 更新流程 / Windows update flow**：设置 → 更新 → 检查更新 → 发现新版本 → 「**下载并安装**」→ 应用自动退出 → 替换完成 → **自动重启**。全程不用手动找文件。
*Settings → Update → Check for updates → new version found → "**Download and install**" → the app exits → files are replaced → **relaunches automatically**. No manual file handling.*

**原理 / How it works**：Windows 不允许覆盖正在运行的 `.exe` / `.dll`，所以程序没法自己替换自己。做法是——新版本解压到临时目录后，启动一个**脱离主进程的批处理脚本**，脚本等主程序退出、文件释放后再拷贝并重启。
*Windows won't let a running `.exe`/`.dll` be overwritten, so an app can't replace itself. Instead: the new version is unpacked to a temp folder, then a **detached batch script** is launched — it waits for the main process to exit, copies the files, and relaunches the app.*

```
主程序                        updater.bat（独立进程）
  │                                 │
  ├─ 下载 zip ── 解压 ──┐            │
  ├─ 生成脚本 ──────────┼── 启动 ───▶│ 等主进程 PID 消失
  └─ exit(0) ───────────┘            ├─ robocopy 覆盖（失败回退 xcopy）
                                     ├─ 启动新 exe
                                     └─ 清理临时目录
```

日志写在临时目录的 `updater.log`，更新失败时可以翻它排查。
*Logs go to `updater.log` in the temp folder — check it if an update fails.*

**为什么没用 WinSparkle / Why not WinSparkle**：`auto_updater`（WinSparkle）是更标准的路子，但它要求把产物做成**安装包**（installer），还得维护 DSA 密钥和 `appcast.xml`。本项目 CI 直接出 portable zip，用自建脚本能原样复用产物，零证书零额外依赖。想换成标准方案的话，Windows 侧只需 DSA 密钥，不花钱。
*`auto_updater` (WinSparkle) is the more standard route, but it requires shipping an **installer** plus maintaining DSA keys and an `appcast.xml`. This project's CI already emits a portable zip, so the self-built script reuses that artifact as-is — no certificates, no extra dependencies. Switching to the standard approach later would only need a DSA key on Windows, which is free.*

> **安装目录必须可写** —— 别装在 `C:\Program Files\` 下（那里写入需要管理员权限，脚本会静默失败）。推荐解压到 `%LOCALAPPDATA%\BenBrowser` 这类用户目录。
> *The install directory must be writable — don't put it under `C:\Program Files\` (writing there needs elevation and the script would fail silently). Unzip to a user-owned folder such as `%LOCALAPPDATA%\BenBrowser`.*
*Settings → Update → Check for updates → new version found → "Download in background" → track progress in Downloads → tap "Install" when finished.*

更新包走**浏览器自带下载器**（`DownloadKind.update`），在下载列表里带版本号徽章，只有下载完成的更新包才显示「安装」按钮。安装时需用户授权「允许安装未知应用」，这是 Android 的硬性要求。
*Update packages go through the **browser's own downloader** (`DownloadKind.update`), show a version badge in the list, and only expose an "Install" button once finished. Installing requires the user to allow "install unknown apps" — a hard Android requirement.*

版本比较用 `compareVersion()`（`lib/services/update_service.dart`）：容忍 `v` 前缀、`+build` 后缀与位数不齐（`1.2` 与 `1.2.0` 视为相等），有对应的单元测试 `test/version_test.dart`。
*Version comparison uses `compareVersion()` (`lib/services/update_service.dart`): tolerant of the `v` prefix, `+build` suffix and uneven segment counts (`1.2` equals `1.2.0`). Covered by `test/version_test.dart`.*

**原生配置 / Native setup**：装 APK 需要 `REQUEST_INSTALL_PACKAGES` 权限 + FileProvider（Android 7.0+ 禁止 `file://` URI）。这两项以及 `res/xml/file_paths.xml` 都由 `tool/patch_platform.py` 自动注入，跑 `flutter create` 后记得执行它。
*Installing an APK needs the `REQUEST_INSTALL_PACKAGES` permission plus a FileProvider (Android 7.0+ rejects `file://` URIs). Both, together with `res/xml/file_paths.xml`, are injected by `tool/patch_platform.py` — remember to run it after `flutter create`.*

---

## 目录结构 / Project Layout

```
lib/
├── main.dart                      入口 / entry point
├── app.dart                       MaterialApp（主题随设置切换）/ MaterialApp (theme follows settings)
├── core/                          常量、主题、URL 解析 / constants, theme, URL parsing
├── data/
│   ├── models/                    Tab / 书签 / 历史 / 下载 / 设置 / tab, bookmark, history, download, settings
│   ├── repositories/              持久化读写 / persistence
│   └── storage/prefs_store.dart   SharedPreferences JSON 存储 / SharedPreferences JSON store
├── state/                         Riverpod：设置、标签、下载、仓库 / settings, tabs, downloads, repos
└── features/
    ├── browser/                   标签条、工具栏、WebView、导航 / tab strip, toolbar, WebView, navigation
    ├── new_tab/                   新标签页 / new tab page
    ├── bookmarks｜history｜downloads｜settings
tool/
├── bootstrap.sh / .ps1            生成各平台原生壳 / generate platform shells
└── patch_platform.py              Android 明文流量 / 权限 / FileProvider · *Android cleartext, permissions, FileProvider*
.github/workflows/build.yml        analyze/test + 三端构建 + Release
```

**为什么仓库里没有 android/、windows/ 目录？**
原生壳由 Flutter SDK 版本决定，硬编码进仓库会随 SDK 升级产生大量冲突。因此统一由 `tool/bootstrap.sh` 或 CI 里的 `flutter create` 生成，代码库只维护 Dart 侧。需要自定义签名时，把对应目录从 `.gitignore` 里放出来提交即可。
*Why isn't `android/`, `windows/` in the repo? The shells depend on the Flutter SDK version; committing them causes constant conflicts on SDK upgrades. They're generated by `tool/bootstrap.sh` or `flutter create` in CI, so the repo only tracks Dart code. To customize signing, un-ignore those directories and commit them.*

---

## 快速开始 / Quick Start

```bash
# 1. 生成本机原生壳（可只生成部分平台）/ generate shells (subset is fine)
PLATFORMS=android,windows ./tool/bootstrap.sh

# 2. 运行 / run
flutter run -d windows          # Windows
flutter run -d <device-id>      # Android（flutter devices 查看 / see `flutter devices`）
```

Windows 用户在 PowerShell 里执行 `tool/bootstrap.ps1`，Linux / macOS 上用 `tool/bootstrap.sh` 生成 Android 壳。
*On Windows, run `tool/bootstrap.ps1` in PowerShell; on Linux / macOS use `tool/bootstrap.sh` to generate the Android shell.*

改动包名 / 组织名 — *To change the package / organization name*:

```bash
ORG=com.yourname ./tool/bootstrap.sh
```

---

## 改应用名 / Renaming

想把 BenBrowser 换成你自己的名字，一条命令搞定（Windows 上把 `python3` 换成 `python`）：
*Rename BenBrowser to whatever you like with a single command (use `python` instead of `python3` on Windows):*

```bash
python3 tool/rename.py "MyBrowser" --org com.myname
python3 tool/rename.py "MyBrowser" --dry-run     # 先预览会改哪些文件 / preview which files change
./tool/bootstrap.sh                              # 改名后重新生成原生壳 / regenerate shells after renaming
flutter pub get
```

脚本会自动重写四处名字 — *The script rewrites four names*:

| 项目 Field | 规则 Rule | 示例 Example |
| --- | --- | --- |
| 显示名（窗口标题 / 新标签页）Display name | 原样使用 / as-is | `MyBrowser` |
| Dart 包名（`pubspec` / `import`）Dart package | 自动 slug 化 / auto-slugified | `my_browser` |
| Android / iOS 包名 Bundle ID | `--org` 指定 / from `--org` | `com.myname.my_browser` |
| CI 产物名 / CI artifact | 跟随显示名 / follows display name | `app-arm64-v8a-release.apk` |

名字里带英文别名的写法也可以：`python3 tool/rename.py "小浏览器 MyBrowser"`。纯中文名不行——`pubspec` 的 `name` 只允许 `a-z0-9_`，脚本会提示加上英文别名。
*A Chinese name with an English alias also works: `python3 tool/rename.py "小浏览器 MyBrowser"`. A purely Chinese name won't — `pubspec`'s `name` only allows `a-z0-9_`, and the script will prompt you for an alias.*

---

## 本地自检（push 前先跑）/ Local Checks (run before pushing)

```bash
./tool/check.sh
```

等价于 CI 的 verify 步骤：`flutter pub get` → `flutter analyze lib test` → `flutter test`。CI 只把 error 当失败（`--no-fatal-infos --no-fatal-warnings`），所以看到红叉时盯 error 那几行就行。
*Same as CI's verify step: `flutter pub get` → `flutter analyze lib test` → `flutter test`. CI only fails on errors (`--no-fatal-infos --no-fatal-warnings`), so when you see a red X, look at the `error` lines.*

只想看 error 行 — *Only show error lines*:

```bash
./tool/analyze_errors.sh     # 只输出「error | 文件:行:列 | 错误码」/ prints only "error | file:line:col | code"
```

### 踩过的坑（写代码时留意）/ Gotchas (keep these in mind)

- **Dart 没有传递导入** — 用到 `bookmarksProvider` / `tabsProvider` 就要 import 它们所在的 `state/providers.dart` / `state/tabs_controller.dart`，靠别的文件间接引过来不算 · *Dart has no transitive imports: if you use `bookmarksProvider` / `tabsProvider`, import `state/providers.dart` / `state/tabs_controller.dart` directly*
- **const 表达式里不能访问实例字段** — `SearchEngine.bing.id` 不能做 const 默认值，要另开 `static const String defaultId` · *You can't access instance fields in const expressions; use a separate `static const String defaultId`*
- **`?? const []` 会推断成 `List<Never>`** — 后续元素访问判类型错误，要写 `?? <Bookmark>[]` · *`?? const []` infers `List<Never>`; write `?? <Bookmark>[]` instead*
- **插件回调别写 `return null`** — `onDownloadStartRequest` 是 void 签名，写 async 但不要 return，能同时兼容 `void` 与 `FutureOr<T?>` · *Don't `return null` from plugin callbacks: `onDownloadStartRequest` is void — make it async but return nothing, which works for both `void` and `FutureOr<T?>`*
- **`useOnDownloadStart: true`** 必须显式设置，否则 6.x 的下载回调根本不触发 · *`useOnDownloadStart: true` must be set explicitly or the 6.x download callback never fires*

---

## 推送到你自己的 GitHub / Push to Your Own GitHub

```bash
git init && git add . && git commit -m "feat: init BenBrowser"
git remote add origin git@github.com:<你的账号/your-account>/ben_browser.git
git push -u origin main
```

- 推 `main` / 提 PR → 跑 analyze + test · *Pushing `main` or opening a PR runs analyze + test*
- 打 tag `git tag v0.1.0 && git push --tags` → 自动构建并在 Release 挂上：3 个 ABI 的 APK、`BenBrowser-windows-x64.zip` · *Tagging builds and attaches: 3 per-ABI APKs and `BenBrowser-windows-x64.zip`*

> CI 里的 `flutter create` 会用模板覆盖 `lib/main.dart`，还会生成引用 `MyApp` 的 `test/widget_test.dart`。workflow 已经做了备份还原 + 删除模板测试，本地跑 `tool/bootstrap.sh` 也一样处理。如果你自己改了 workflow，记得保留这两步，否则打出来的包会是计数器 demo。
> *`flutter create` in CI overwrites `lib/main.dart` from the template and generates `test/widget_test.dart` referencing `MyApp`. The workflow backs up and restores the file and deletes that template test; `tool/bootstrap.sh` does the same locally. If you edit the workflow, keep those two steps or your builds will ship the counter demo.*

---

## 架构要点 / Architecture

- **状态管理 State** — Riverpod。设置用 `AsyncNotifier` 异步加载；标签用 `Notifier<TabsState>` · *Riverpod: settings via `AsyncNotifier`, tabs via `Notifier<TabsState>`*
- **控制器托管 Controllers** — `InAppWebViewController` 不进状态类，统一放 `webViewRegistryProvider`（`tabId → controller`），避免状态对象持有原生句柄 · *Controllers live in `webViewRegistryProvider` (`tabId → controller`), never inside state objects*
- **标签渲染 Tabs** — `IndexedStack` 保持所有标签存活，关闭时从 registry 摘除 controller · *`IndexedStack` keeps tabs alive; closing removes the controller from the registry*
- **存储 Storage** — `SharedPreferences` + JSON，三端零权限；数据量大了可平滑换成 Isar / Drift，只需替换 repository 实现 · *SharedPreferences + JSON, no permissions on any platform; swap repositories for Isar / Drift when data grows*
- **下载 Downloads** — 不走各平台自带下载器，统一 Dio 落到 `BenBrowser/Downloads`，Android 13+ 无需存储权限 · *No platform downloaders; Dio saves to `BenBrowser/Downloads`, so Android 13+ needs no storage permission*

---

## 平台注意事项 / Platform Notes

- **系统 WebView** — 本项目不带内核，依赖系统自带的 WebView。老设备或定制 ROM 上如遇白屏，先去应用商店更新「Android System WebView」· *This app bundles no engine and relies on the system WebView. If pages render blank on older devices or custom ROMs, update "Android System WebView" from the Play Store first*
- **安装 APK** — 需授权「允许安装未知应用」（Android 8.0+ 的硬性要求）· *Requires granting "install unknown apps" (a hard requirement since Android 8.0)*
- **明文 http** — `usesCleartextTraffic` 已由 `tool/patch_platform.py` 打开 · *Cleartext HTTP is enabled by `tool/patch_platform.py`*
- **minSdkVersion** — 已由补丁脚本设为 29（Android 10）；插件若要求更高再自行上调 · *Set to 29 (Android 10) by the patch script; raise it further if a plugin demands it*
- **渲染回退** — 无 Vulkan 的设备自动走 OpenGL ES，无需配置；详见下方章节 · *Devices without Vulkan automatically use OpenGL ES, no configuration needed; see below*
- **签名** — Release APK 目前用调试密钥签名，能正常安装，但上架 Google Play 需另配 keystore · *Release APKs are signed with the debug key: they install fine, but publishing to Google Play requires your own keystore*
- **Windows 启动失败** — Win10 未装 WebView2 Runtime 时首次启动会报错，装上即可；Win11 自带 · *Win10 without WebView2 Runtime fails on first launch; Win11 bundles it*
- **Windows SmartScreen** — 未签名的 exe 会弹警告，选「仍要运行」 · *Unsigned exe triggers a SmartScreen warning; choose "Run anyway"*

---

## 渲染后端与 Android 17 / Rendering & Android 17

### 回退策略：Vulkan 优先，OpenGL ES 兜底

本项目**不再把 Vulkan 设为硬性门槛**。Manifest 里是这样声明的：
*This project **no longer makes Vulkan a hard gate**. The manifest declares:*

```xml
<!-- 可选：有就用，没有也能装 -->
<uses-feature
    android:name="android.hardware.vulkan.version"
    android:version="0x00400000"
    android:required="false" />

<!-- 必选：保证设备至少能 GPU 渲染 -->
<uses-feature android:glEsVersion="0x00030000" android:required="true" />
```

**没有 Vulkan 的设备照样能装，装上就走 OpenGL ES。**
*Devices without Vulkan install fine and run on OpenGL ES.*

关键点：**这个回退不需要你写任何代码。** 自 Flutter 3.29 起，没有可用 Vulkan
驱动的设备会自动回退到 Impeller 的 OpenGL ES 后端；官方原话是
「No action on your part is necessary for this fallback behavior」。
*Key point: **this fallback needs no code.** Since Flutter 3.29, devices without a working Vulkan driver fall back to Impeller's OpenGL ES backend automatically — "No action on your part is necessary".*

### 一条容易误解的细节

Manifest 里声明的是 Vulkan ≥ **1.0**，但 Flutter 引擎走 Vulkan 分支的条件其实是
**Vulkan ≥ 1.1**（外加若干必需扩展和运行时校验）。所以：
*The manifest declares Vulkan ≥ **1.0**, but Flutter's engine only takes the Vulkan path when the device reports **Vulkan ≥ 1.1** (plus required extensions and runtime checks). Therefore:*

- 报 1.1 / 1.2 / 1.3 / 1.4 的设备 → 走 **Vulkan**
- 报 1.0 的设备 → 虽然满足 Manifest，引擎仍会回退到 **OpenGL ES**
- 完全没有 Vulkan 驱动的设备 → 回退到 **OpenGL ES**

这不是 bug，只是声明门槛与引擎门槛不一致。想让声明更贴近实际，可以把
`VULKAN_MIN_VERSION` 提到 1.1（不影响能不能装，只是提示更准确）。
*Not a bug — just a mismatch between the declared floor and the engine's floor. To align them, raise `VULKAN_MIN_VERSION` to 1.1 (doesn't affect installability, only makes the hint more accurate).*

### Android 17（API 37）支持

Android 17 = **API 37**，代号 Cinnamon Bun，2026 年 6 月 16 日发布。
补丁脚本会自动对齐：
*Android 17 = **API 37**, codename Cinnamon Bun, released June 16, 2026. The patch script aligns:*

| 项 Field | 值 Value | 说明 Why |
| --- | --- | --- |
| `compileSdk` | 37 | 才能用到 Android 17 的新 API · *to access Android 17 APIs* |
| `targetSdk` | 37 | 声明已适配 Android 17 的行为变更 · *opt into Android 17 behavior changes* |
| `minSdk` | **29** | Android 10 起 · *Android 10 and up* |
| `ndkVersion` | r28+ | 16KB 内存分页对齐的最低要求 · *minimum for 16KB page alignment* |

**关于 `flutter.xxxVersion` 变量**：官方建议沿用 Flutter SDK 提供的这些变量，
避免 AGP / Gradle 版本打架。但 Flutter 的 `flutter.compileSdkVersion` 通常
落后于最新 Android——要真正 target 到 37 就必须覆盖。所以脚本**默认强制覆盖**
成字面量；想回到「跟随 Flutter」模式：

```bash
ANDROID_KEEP_FLUTTER_SDK=true python3 tool/patch_platform.py
```
*The official guidance is to keep Flutter's `flutter.xxxVersion` variables, but `flutter.compileSdkVersion` typically lags the newest Android — reaching API 37 requires overriding it. The script **overrides by default**; to opt back out, set `ANDROID_KEEP_FLUTTER_SDK=true`.*

覆盖成字面量的代价是：**构建环境必须装好 Android SDK Platform 37**，否则 Gradle
会报 `failed to find target`。

CI 会先更新 `sdkmanager` 再安装 `platforms;android-37`。**若 runner 确实提供不了，
会自动用其最高可用版本继续构建**，并在日志里打出醒目 warning——挂掉整条流水线、
一个包都出不来没有意义，降级只影响 `targetSdk`，`minSdk 29` 与全部功能都不变。
想强制锁定某个版本，在 workflow 的 android job 里设：

```yaml
env:
  ANDROID_TARGET_SDK: 37   # 或 36
  ANDROID_COMPILE_SDK: 37
```
*CI updates `sdkmanager` then installs `platforms;android-37`. **If the runner can't provide it, the build continues with the highest available API** and logs a prominent warning — failing the whole pipeline and shipping nothing helps no one; downgrading only affects `targetSdk`, while `minSdk 29` and all functionality stay the same. To pin a version, set `ANDROID_TARGET_SDK` / `ANDROID_COMPILE_SDK` in the android job's `env`.*
*The cost of pinning a literal is that **Android SDK Platform 37 must be installed** or Gradle fails with `failed to find target`. CI installs it and **fails hard** if it's unavailable, rather than silently downgrading.*

#### 为什么 minSdk 定在 29（Android 10）

- Android 10 起，64 位设备**强制**要求 Vulkan 1.1 驱动，图形能力有保障
- 覆盖了绝大多数在用设备，同时避开了 Android 7–9 那批驱动质量参差的机型
- Android 10 也是 scoped storage 的分界线，存储行为更可预测

*Android 10 is where 64-bit devices **must** ship a Vulkan 1.1 driver, where the installed base is still broad, and where scoped storage begins — it skips the Android 7–9 generation with inconsistent driver quality.*

#### targetSdk 37 需要注意的行为变更

target 到 Android 17 会启用下面这些变更，浏览器类应用主要受前两条影响：

| 变更 Change | 影响 Impact |
| --- | --- |
| 大屏强制自适应 UI | 平板 / 折叠屏上 `screenOrientation`、`resizeableActivity=false` 等**被系统忽略**，必须适配任意窗口尺寸 · *on large screens (`sw > 600dp`) the system **ignores** orientation/resizability restrictions* |
| 默认开启证书透明度（CT） | 访问用内网/自签证书的站点可能失败，需在网络安全配置里显式放行 · *Certificate Transparency is on by default; private-CA sites may fail unless opted out* |
| `usesCleartextTraffic` 已废弃 | 本项目已迁移到 `res/xml/network_security_config.xml`（明文放行 + 信任用户 CA），该属性与新配置并存、以配置为准 · *migrated to `res/xml/network_security_config.xml`; both coexist and the config wins* |
| Keystore 密钥上限降到 5 万 | 本项目不用 Keystore，无影响 · *unused here* |
| 应用内存上限 | 所有应用生效（与 targetSdk 无关），WebView 重度页面需留意 · *applies to all apps regardless of targetSdk* |

> Google Play 会在 **2027 年 8 月**起强制要求 `targetSdk = 37`，提前对齐省得后面赶。
> *Google Play will **require `targetSdk = 37` from August 2027** — aligning now avoids a rush later.*
> ***The script won't overwrite `flutter.xxxVersion` variables.** Flutter recommends using the SDK-provided variables; hardcoding invites AGP / Gradle / Kotlin conflicts. The script only bumps values that are hardcoded and too low.*

### 关于 Google Play 的两个期限（仅上架时才在意）

本项目走 GitHub Releases 分发，下面这些**不影响你**。只有上架 Play 才需要留意：
*This project ships via GitHub Releases, so the following **doesn't affect you**. Only relevant if you publish to Play:*

- **targetSdk 必须 ≥ 36**：2026-08-31 起的新应用与更新（可申请延期到 11-01）
- **16KB 内存分页**：面向 Android 15+ 的应用必须支持；2027-02-01 起不支持的更新无法发布

### 想改回「只装 Vulkan 设备」

```bash
VULKAN_REQUIRED=true python3 tool/patch_platform.py
```

代价是会排除约 15% 的设备（多是 Android 7–9 老机型）。
*The cost: it excludes roughly 15% of devices (mostly Android 7–9 handsets).*

---

## 后续可加（按性价比排序）/ Roadmap (by value)

1. 广告拦截：拦截规则订阅 + `shouldOverrideUrlLoading` 过滤（本机规则文件，无需服务器）· *Ad blocking: rule subscriptions + `shouldOverrideUrlLoading` filtering (local rules, no server)*
2. 标签会话持久化（当前关闭即丢失，重启后只恢复主页）· *Persist tab sessions (currently lost on exit; only the home page is restored)*
3. 书签 / 历史导入导出（HTML / JSON）· *Import / export bookmarks and history (HTML / JSON)*
4. 密码与表单填充（需加密存储，建议 `flutter_secure_storage`）· *Password and form autofill (needs encrypted storage, e.g. `flutter_secure_storage`)*
5. 侧边栏、阅读模式、网页截图分享 · *Sidebar, reader mode, screenshot sharing*
6. 插件脚本注入（`evaluateJavascript` + 用户脚本管理）· *User script injection (`evaluateJavascript` + script management)*

---

## 依赖版本适配提示 / Dependency Version Notes

`flutter_inappwebview` 6.x 与 5.x 的 API 名称有差异，本项目按 **6.x** 编写：
*The `flutter_inappwebview` 6.x and 5.x APIs differ; this project targets **6.x**:*

| 用途 Use | 6.x（本项目 this project） | 5.x |
| --- | --- | --- |
| WebView 配置 Settings | `InAppWebViewSettings` | `InAppWebViewGroupOptions` |
| URL 类型 URL type | `WebUri(url)` | `Uri` |
| 下载回调 Download callback | `onDownloadStartRequest` | `onDownloadStart` |

若你锁到 5.x，只需按上表替换 `lib/features/browser/web_view_surface.dart` 里的对应写法。
*If you pin to 5.x, swap the corresponding calls in `lib/features/browser/web_view_surface.dart` per the table above.*
