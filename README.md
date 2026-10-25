# BenBrowser

基于 **Flutter + Android 系统 WebView** 的个人自研浏览器：轻量、无自带内核，靠 GitHub Actions 自动出安装包。
*A personal browser built on **Flutter + Android's system WebView**: lightweight, no bundled engine, built automatically by GitHub Actions.*

> 本项目已精简为**纯 Android**。早期版本支持的 Windows / macOS 已移除——
> 桌面端静默更新依赖 Sparkle / WinSparkle，macOS 上还需要付费的 Apple Developer
> 账号（$99/年）做签名公证，维护成本远高于收益。
> *This project is now **Android-only**. Windows / macOS support has been removed — silent desktop updates depend on Sparkle / WinSparkle, and on macOS a paid Apple Developer account ($99/year) is required for signing and notarization. The maintenance cost outweighed the benefit.*

| 项目 Item | 值 Value |
| --- | --- |
| 内核 Engine | Android 系统 WebView（Chromium），由厂商 / Google Play 更新 · *Android System WebView (Chromium), updated by the OEM / Play Store* |
| 最低版本 Min SDK | 21（Android 5.0） |
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

**更新流程 / Update flow**：设置 → 更新 → 检查更新 → 发现新版本 → 「后台下载」→ 在「下载」页看进度 → 完成后点「安装」。
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
└── patch_platform.py              Android 明文流量 + 安装权限 + FileProvider / cleartext, install permission, FileProvider
.github/workflows/build.yml        analyze/test + 三端构建 + Release
```

**为什么仓库里没有 android/ 目录？**
原生壳由 Flutter SDK 版本决定，硬编码进仓库会随 SDK 升级产生大量冲突。因此统一由 `tool/bootstrap.sh` 或 CI 里的 `flutter create` 生成，代码库只维护 Dart 侧。需要自定义签名时，把 `android/` 从 `.gitignore` 里放出来提交即可。
*Why isn't `android/` in the repo? The shell depends on the Flutter SDK version; committing it causes constant conflicts on SDK upgrades. It's generated by `tool/bootstrap.sh` or `flutter create` in CI, so the repo only tracks Dart code. To customize signing, un-ignore `android/` and commit it.*

---

## 快速开始 / Quick Start

```bash
# 1. 生成 Android 原生壳 / generate the Android shell
./tool/bootstrap.sh

# 2. 运行（先用 flutter devices 查设备 id） / run (check `flutter devices` first)
flutter run -d <device-id>
```

Windows / macOS 用户在各自终端里执行 `tool/bootstrap.sh` 或 `tool/bootstrap.ps1`。
*On Windows / macOS, run `tool/bootstrap.sh` or `tool/bootstrap.ps1` respectively.*

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
- 打 tag `git tag v0.1.0 && git push --tags` → 自动构建并在 Release 挂上 3 个 ABI 的 APK · *Tagging builds and attaches 3 per-ABI APKs*

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
- **minSdkVersion** — 若低于 21 需自行上调 · *Raise it if it's below 21*
- **签名** — Release APK 目前用调试密钥签名，能正常安装，但上架 Google Play 需另配 keystore · *Release APKs are signed with the debug key: they install fine, but publishing to Google Play requires your own keystore*

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
