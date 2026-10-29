# BenBrowser

基于 **Flutter + 各平台原生 WebView** 的个人自研浏览器：一份 Dart 代码跑在 **Android 与 Windows** 上，打 tag 后由 GitHub Actions 自动出包。
*A personal browser built on **Flutter + each platform's native WebView**: one Dart codebase for **Android and Windows**, built automatically by GitHub Actions when you push a tag.*

| 平台 Platform | 内核 Engine | 要求 Requirements |
| --- | --- | --- |
| Android | 系统 WebView（Chromium） · *System WebView* | Android 10+（minSdk 29，targetSdk 37） |
| Windows | WebView2（Edge Chromium） | Win10 1809+ / Win11；Win10 需装 [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) · *Win11 bundles it* |

---

## 功能 / Features

多标签（上限 20）· 地址栏智能解析（裸域名补 `https://`，其余走搜索）· 前进/后退/刷新/主页 · 书签 · 历史（无痕不入库）· 下载管理 · 无痕标签 · UA 切换 · 新标签页 · 亮/暗/跟随系统主题 · `target=_blank` 自动开新标签 · **应用内更新**
*Tabs (max 20) · smart address bar · back/forward/reload/home · bookmarks · history (incognito excluded) · downloads · incognito tabs · UA switching · new tab page · light/dark/system theme · `target=_blank` opens a new tab · **in-app updates***

---

## 快速开始 / Quick Start

```bash
PLATFORMS=android,windows ./tool/bootstrap.sh   # 生成原生壳（不进版本库）
flutter pub get
flutter run -d windows        # 或 flutter run -d <android 设备 id>
```

打 tag 出包 / *Ship a release*：

```bash
git tag v0.1.0 && git push --tags
```

产物：3 个 ABI 的 APK + `BenBrowser-windows-x64.zip`
*Artifacts: 3 per-ABI APKs + `BenBrowser-windows-x64.zip`*

---

## 账号与云同步 / Account & Cloud Sync

支持 **Google** 与 **Microsoft** 登录，**两个渠道二选一**：登录前先选中要用哪种，再点统一的登录按钮。同一时刻只能登录一个账号，要换另一种需先退出登录。
*Sign in with **Google** or **Microsoft** — **pick one**. Select the channel first, then press the single sign-in button. Only one account can be signed in at a time; switching requires signing out first.*

UI 上刻意做成单选而非两个并列按钮：避免误点到另一个渠道，也让「只能用其中一个」这件事在点之前就明确。
*The UI is a radio-style choice rather than two parallel buttons, so you can't mis-tap the wrong channel and the "one at a time" rule is clear before you commit.*

### 两端都要登录 / Sign-in required on both platforms

**Android 与 Windows 都会先显示登录页，登录成功后自动进入浏览器。** 书签与设置的云同步挂在账号上，两端统一成同一套进入方式。
***Both Android and Windows show the sign-in screen first; the browser opens automatically once signed in.** Bookmark and settings sync is tied to the account, so both platforms share the same entry flow.*

由 `platform_info.dart` 的 `requireLoginToBrowse` 控制，对 `android` 与 `windows` 为真。想整体去掉登录墙，把该 getter 改成 `false` 即可。
*Controlled by `requireLoginToBrowse` in `platform_info.dart`, true for `android` and `windows`. Set it to `false` to remove the gate entirely.*

**Android 的两个硬性前提**（缺一个就会「点登录没反应」）：
1. `MainActivity` 必须 `android:launchMode="singleTop"` —— 深链回跳时若新建 Activity 实例，登录结果会落在那个新实例里，用户眼前的界面收不到回调
2. Manifest 里要有 `com.ben.benbrowser://login-callback/` 的 intent-filter

这两项都由 `tool/patch_platform.py` 自动注入，且与 Supabase 后台的 Redirect URLs 必须一致。
*Two hard requirements on Android (miss either and "sign in does nothing"): `MainActivity` needs `android:launchMode="singleTop"` — otherwise the deep-link return creates a new Activity and the visible screen never gets the callback — plus an intent-filter for `com.ben.benbrowser://login-callback/`. Both are injected by `tool/patch_platform.py` and must match the Redirect URLs configured in Supabase.*

> **安全网**：若 Supabase 尚未配置，此时根本登不进去，登录页会显示配置引导并提供「**暂不登录，直接使用**」按钮——
> 否则应用会完全不可用。配置好之后这个出口自然消失。
> ***Safety net**: if Supabase isn't configured, signing in is impossible, so the gate shows setup instructions plus a "**skip sign-in for now**" button — otherwise the app would be completely unusable. That escape hatch disappears once configured.*

后端用 [Supabase](https://supabase.com)：一个服务同时提供 OAuth 和数据库，
而且 Google / Microsoft 的 client id 与 secret 都配置在 Supabase 后台，
**不必写进客户端代码**——客户端只需要项目 URL 和 publishable key。
*The backend is [Supabase](https://supabase.com): one service for both OAuth and the database. Google / Microsoft client IDs and secrets live in the Supabase dashboard, **not in client code** — the app only needs the project URL and publishable key.*

### 启用步骤 / Setup

1. 建 Supabase 项目，在 **Authentication → Providers** 里启用
   **Google** 和 **Azure**，各填对应的 client id / secret
   （Azure 的 callback 填 `https://<项目>.supabase.co/auth/v1/callback`）
2. Authentication → **URL Configuration** 的 Redirect URLs 加上
   `com.ben.benbrowser://login-callback/`
3. SQL Editor 里执行一次建表（含 RLS，保证每人只能读写自己的数据）：

```sql
create table benbrowser_sync (
  user_id    text primary key default auth.uid(),
  payload    jsonb not null,
  updated_at timestamptz not null default now()
);
alter table benbrowser_sync enable row level security;
create policy "own row" on benbrowser_sync
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

4. 把两个值填进 `lib/core/constants.dart` 的 `CloudConfig`
   （或用 `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...` 注入），
   重新构建即可
5. Android 的回调深链由 `tool/patch_platform.py` 自动注入，不用手改 Manifest

### 同步范围与策略 / What syncs, and how

| 数据 | 是否同步 | 说明 |
| --- | --- | --- |
| 书签 Bookmarks | ✅ 按 id 取并集 | *merged by id (union)* |
| 设置 Settings | ✅ 较新者胜 | *last write wins* |
| 历史记录 History | ❌ | 量大且隐私敏感 · *bulky and privacy-sensitive* |
| 标签页 Tabs | ❌ | 属于会话状态 · *session state* |
| 下载 Downloads | ❌ | — |

**已知限制**：书签用并集合并，因此**删除操作不会跨设备传播**——
在一台设备上删掉的书签，同步后会被另一台设备「找回」。
这是刻意选的：丢书签的代价远大于重复。要支持删除同步需要引入墓碑记录。
*Known limitation: bookmarks merge as a union, so **deletions don't propagate**. A bookmark deleted on one device can reappear after a sync from another. This is deliberate — losing bookmarks costs far more than duplicates. Proper deletion sync needs tombstones.*

**未配置时的行为**：`CloudConfig.isConfigured` 为 false 时完全不联网，
设置页显示配置引导，其余功能照常使用，不会崩溃。
*When unconfigured, nothing hits the network: Settings shows a setup guide and everything else keeps working.*

---

## 应用内更新 / In-App Updates

基于 GitHub Releases，读 `releases/latest` 比对版本。
*Built on GitHub Releases — queries `releases/latest` and compares versions.*

**★ 首次必做 / Do this first**：`lib/core/constants.dart:15` 把 `defaultRepoSlug` 从 `'OWNER/ben_browser'` 改成你的 `用户名/仓库名`。留着 `OWNER` 会被判定为未配置，不会发起请求。
*Change `defaultRepoSlug` in `lib/core/constants.dart:15` from `'OWNER/ben_browser'` to your `username/repo`. Leaving `OWNER` means no request is made.*

| 平台 Platform | 行为 Behavior |
| --- | --- |
| Android | 更新包走浏览器自带下载器，进度在「下载」页可见，完成点「安装」唤起系统安装器（需授权「安装未知应用」）· *Downloaded by the app's own downloader; tap "Install" (requires "install unknown apps" permission)* |
| Windows | 点「下载并安装」→ 自动退出 → 脚本替换文件 → **自动重启**，全程无需手动操作 · *"Download and install" → exits → a script swaps files → **relaunches automatically*** |

Windows 一键更新的原理：正在运行的 `.exe`/`.dll` 无法自我覆盖，所以启动一个**脱离主进程的批处理脚本**，等主程序退出后再拷贝并重启。日志在临时目录的 `updater.log`。
*On Windows a running `.exe`/`.dll` can't overwrite itself, so a **detached batch script** waits for the process to exit, copies the files, and relaunches. Logs go to `updater.log` in the temp folder.*

> **Windows 安装目录必须可写** —— 别解压到 `C:\Program Files\`（写入需管理员权限，更新会静默失败）。推荐 `%LOCALAPPDATA%\BenBrowser`。
> *Don't install under `C:\Program Files\` (writing needs elevation and updates would fail silently). Use `%LOCALAPPDATA%\BenBrowser`.*

---

## 常用命令 / Commands

```bash
./tool/check.sh                                  # 本地自检（analyze + test）
./tool/analyze_errors.sh                         # 只看 error 行
python3 tool/rename.py "MyBrowser" --org com.me  # 改应用名（含包名、CI 产物名）
python3 tool/patch_platform.py                   # 给原生壳打补丁（可重复执行）
```

补丁脚本负责：http 明文放行（Android 17 起改用网络安全配置）、安装权限 + FileProvider、Vulkan 可选 / OpenGL ES 3.0 兜底、SDK 版本对齐（37/37/29）。
*The patch script handles: cleartext HTTP (via network security config on Android 17+), install permission + FileProvider, Vulkan optional / OpenGL ES 3.0 floor, and SDK alignment (37/37/29).*

---

## 项目结构 / Layout

```
lib/
├── core/        常量、主题、URL 解析 / constants, theme, URL parsing
├── data/        models / repositories / storage（SharedPreferences + JSON）
├── state/       Riverpod：设置、标签、下载 / settings, tabs, downloads
├── services/    update_service（检测）、desktop_update（Windows 更新）
└── features/    browser、new_tab、bookmarks、history、downloads、settings
tool/            bootstrap、patch_platform、check、analyze_errors、rename
.github/         workflows/build.yml（verify → android → windows）
```

**为什么没有 android/、windows/ 目录？** 原生壳随 Flutter SDK 版本变化，进仓库会频繁冲突，改由 `bootstrap.sh` / CI 生成。要自定义签名时再从 `.gitignore` 放出。
*Why no `android/`, `windows/`? They depend on the Flutter SDK version and cause conflicts; generated by `bootstrap.sh` / CI. Un-ignore them if you need custom signing.*

---

## 注意事项 / Notes

- **Android 白屏** — 不带内核，依赖系统 WebView。老设备或定制 ROM 先更新「Android System WebView」· *No bundled engine; update "Android System WebView" on blank pages*
- **Vulkan 非硬性要求** — 没有 Vulkan 驱动的设备自动走 OpenGL ES，Flutter 3.29+ 自动回退，无需配置 · *Devices without Vulkan fall back to OpenGL ES automatically since Flutter 3.29*
- **Android 17 已适配** — 大屏自适应（按窗口宽度布局）、CT 默认开启、局域网/环回新权限均已处理，详见下方专章，需访问内网自签证书站点时按专章加 `[domain-config]` · *Android 17 adapted: window-width layout, CT on by default, new LAN/loopback permissions. See the dedicated section to allow internal self-signed hosts*
- **签名** — Release APK 用调试密钥，能装但不能上架 Play；Windows exe 未签名会弹 SmartScreen，选「仍要运行」· *Release APK uses the debug key (installs fine, not Play-ready); unsigned exe triggers SmartScreen*
- **不做静默降级** — runner 若没有 `platforms;android-37`，android job **直接失败**并给出提示；要临时出包把该 job 的 `ANDROID_ALLOW_SDK_FALLBACK` 设为 `'true'` · *If the runner lacks `platforms;android-37` the android job **fails outright** with guidance; set `ANDROID_ALLOW_SDK_FALLBACK: 'true'` to ship anyway*
- **新版 MSVC 编译失败（C++ coroutine）** — `flutter_inappwebview_windows` 仍在用已废弃的 `<experimental/coroutine>`，MSVC 14.5x（VS 2026）起默认报 `error C2338 / STL1011`。`tool/patch_platform.py` 会自动往 `windows/CMakeLists.txt` 注入 `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` 绕过，插件修复后可去掉 · *`flutter_inappwebview_windows` still uses deprecated `<experimental/coroutine>`; MSVC 14.5x (VS 2026) errors with `C2338 / STL1011`. The patch script injects `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` into `windows/CMakeLists.txt`; drop it once the plugin is fixed*
- **Windows 控制台编码** — runner 默认 cp1252，脚本输出中文日志会抛 `UnicodeEncodeError` 并让 job 失败。补丁脚本已强制 UTF-8，workflow 也设了 `PYTHONIOENCODING` · *The runner defaults to cp1252 and Chinese log output throws `UnicodeEncodeError`, failing the job. The script forces UTF-8 and the workflow sets `PYTHONIOENCODING`*
- **第三方插件 ProGuard 补丁** — `flutter_inappwebview_android` 1.1.3 用了已被新版 AGP 移除的 `getDefaultProguardFile('proguard-android.txt')`，release 构建做 R8 混淆时会直接失败。`tool/patch_platform.py` 会遍历 pub-cache 把它换成 `-optimize` 变体（覆盖所有插件，不止这一个）。**必须在 `flutter pub get` 之后执行**，所以 workflow 里分了两步 · *`flutter_inappwebview_android` 1.1.3 calls `getDefaultProguardFile('proguard-android.txt')`, which newer AGP removed and which fails release builds at the R8 step. `tool/patch_platform.py` sweeps the pub-cache and swaps in the `-optimize` variant for every plugin. **Must run after `flutter pub get`**, hence two separate steps in the workflow*

---

## 后续可加 / Roadmap

广告拦截（本地规则 + 请求过滤）· 标签会话持久化（当前关闭即丢失）· 书签/历史导入导出 · 密码填充 · 阅读模式
*Ad blocking (local rules + request filtering) · persist tab sessions (currently lost on exit) · bookmark/history import-export · password autofill · reader mode*

---

## 代码审查已修问题 / Audit fixes

对全部 Dart 源码做过一轮正确性 / 性能 / 安全审查，以下是已修项与相应的设计取舍。
*A correctness / performance / security pass over the whole Dart codebase — fixed items and the tradeoffs behind them.*

### 正确性 Correctness

| 问题 Issue | 说明 Detail |
| --- | --- |
| 弹窗 pop 后仍用 context | 先取 `messenger` / `navigator` 再 `pop`，否则抛 "deactivated widget's ancestor" |
| 「取消下载」并不取消 | 改用 `CancelToken`；此前 Dio 仍在后台跑完并把状态覆盖回 done |
| Windows 更新临时目录泄漏 | 清理责任交给脚本（删整个 tempRoot）；此前只在**失败**分支删，成功时几十 MB 的 zip 永久残留 |
| `await` 后仍触碰 `ref` | 关闭标签/退出页面会让 widget 在 await 期间卸载，再 `ref.read` 会抛 StateError。已在 6 个文件的异步路径上补齐 `mounted` 守卫 |
| 同名下载互相覆盖 | 文件名冲突时自动加 `(1)` `(2)` 后缀；此前两个不同地址下载到同名文件，后完成的会悄悄替换先完成的 |
| 重复点击下载 | 同一地址正在下载时直接复用已有任务；此前会起两个 Dio 写同一个 savePath，导致文件损坏 |
| 取消后残留半截文件 | 取消时删掉未完成的文件；此前留着，下次「打开」会拿到损坏文件 |
| 标签到上限无反馈 | `openTab` 改为返回 bool，UI 给出提示；此前静默 return，点「+」毫无反应 |
| zip 带顶层目录导致静默失效 | 复制源改为 **exe 所在那一层**，否则整个目录被套进安装目录、真正的 exe 不会被替换 |

### 性能 Performance

- **标签内存**：`IndexedStack` 会同时保留全部标签的 WebView 实例（最多 20 个），Android 上极易 OOM。现按最近使用顺序保留 `maxLiveWebViews`（默认 6）个，超出部分显示占位卡，切回时重新加载。**标签数不超过 6 时行为完全不变**；想要永不挂起就把该常量设成 >= `maxTabs`。
  *Tabs beyond `maxLiveWebViews` (default 6) release their WebView; unchanged behaviour at ≤6 tabs.*
- **进度刷新**：`onProgressChanged` 一次加载触发上百次，每次都全树重建。现按 5% 台阶节流（首/末态始终上报）。
- **历史写入**：上限 2000 条时一次全量写入约 300KB。连续访问同一地址现走快速路径（只改首条时间，省掉 `removeWhere` + 重排），**但仍会整表落盘**——要做成真正的增量写入需要引入 SQLite，对当前规模不划算；更省事的方案是加写入防抖（代价是意外退出时可能丢掉最后几秒的记录），暂未采用。
- **同步 IO**：`existsSync` / `listSync` / `lengthSync` 改为异步，避免递归目录遍历卡在 UI 线程。

### 安全与健壮性 Security & robustness

- **URL scheme 白名单**：只允许 `http` / `https` / `about`。此前地址栏输入 `file:///...`、`content://...` 能把本地文件读进页面。
- **bat 脚本路径转义检查**：路径含 `&` `|` `^` `"` 等字符时拒绝更新，而不是拼出行为不确定的脚本。
- **zip slip 加固**：`isWithin` 的基准改用 `resolveSymbolicLinks()`，防止符号链接绕过。
- **GitHub 限流**：未鉴权仅 60 次/小时/IP。可用 `--dart-define=GITHUB_TOKEN=ghp_xxx` 提升额度；遇 403/429 给出明确提示而非笼统失败。
- **全局错误兜底**：新增 `core/error_reporting.dart`，接管 `FlutterError.onError` 与 `PlatformDispatcher.onError`，只做本地记录、**不上报任何用户数据**。

---

## Android 17（API 37）支持

Android 17 = **API 37**，代号 Cinnamon Bun。补丁脚本自动对齐编译目标，**并且真正适配了它的行为变更**（不只是把数字改成 37）。
*Android 17 = **API 37**, codename Cinnamon Bun. The patch script aligns the build target **and actually adapts to its behavior changes** — not just bumping a number.*

| 项 Field | 值 Value |
| --- | --- |
| `compileSdk` | 37 |
| `targetSdk` | 37 |
| `minSdk` | 29（Android 10） |
| `ndkVersion` | r28+（16KB 内存分页对齐的最低要求） |

**CI 的判据是「产物里真实的 targetSdk」，不是环境里装了什么。** 构建前即便 sdkmanager 拿不到 `android-37`，也不会立刻失败——AGP 有自动下载机制（用的仓库索引通常比 runner 自带的 sdkmanager 新），可能在构建阶段把平台拉下来。构建完成后用 `aapt2 dump badging` 读 APK 实际的 `targetSdkVersion`，不是 37 才报错。
***CI judges by the **real targetSdk in the artifact**, not by what's installed. Even if `sdkmanager` can't fetch `android-37`, the build isn't aborted up front — AGP auto-downloads SDK packages using a repository index that's usually newer than the runner's bundled sdkmanager. After building, `aapt2 dump badging` reads the APK's actual `targetSdkVersion`; only a non-37 value fails.***

临时出包可把 android job 的 `ANDROID_ALLOW_SDK_FALLBACK` 改成 `'true'`——日志会打出醒目的 warning，且**不会**静默伪装成 Android 17。
*To ship anyway, set `ANDROID_ALLOW_SDK_FALLBACK: 'true'` on the android job — the log prints a loud warning and does **not** silently pretend to be Android 17.*

> runner 自带的 sdkmanager 若太旧会**看不到** android-37 这个包（它读的 repository 索引较旧）。CI 已先把 `cmdline-tools` 升到最新再拉平台，并把仓库里可用的 platform 列表打印出来便于判断。
> *An outdated bundled sdkmanager **can't see** the android-37 package (its repository index is old). CI updates `cmdline-tools` first, then fetches the platform, and prints the list of available platforms for diagnosis.*

### 已适配的行为变更 / Adapted behavior changes

**1. 大屏自适应（无退路）** — sw ≥ 600dp 时系统会**直接忽略** `screenOrientation`、`resizeableActivity`、`minAspectRatio`、`maxAspectRatio` 与 `setRequestedOrientation()`。Android 16 还有临时 opt-out，**Android 17 已移除**。
*On sw ≥ 600dp the system **ignores** orientation/resizability/aspect-ratio restrictions. Android 16's temporary opt-out is **removed in 17**.*

应对：补丁脚本删除这些无效声明、显式设 `resizeableActivity=true`、并拒绝 `appCategory=game`（那会被豁免，但等于放弃适配）。布局侧不再按平台判断，改为按**窗口宽度**（`isCompactWindow`，阈值同为 600dp）——平板、折叠屏展开、分屏各自得到合适布局，不会把手机布局拉伸。
*Handled: the script drops those dead attributes, sets `resizeableActivity=true`, and rejects `appCategory=game`. Layout no longer branches on platform but on **window width** (`isCompactWindow`, same 600dp threshold), so tablets, unfolded foldables, and split-screen each get a sane layout instead of a stretched phone UI.*

**2. 证书透明度（CT）默认开启** — 目标 37 的应用默认校验 CT。配置刻意**不写任何 CT 开关**，让平台默认生效，公网站点获得 CT 保护。
*CT is on by default for API 37 targets. The config deliberately **declares no CT override** so the platform default applies and public sites get CT protection.*

需要访问内网 / 自签证书站点时，按域名加 `<domain-config>` 并配自定义信任锚即可——官方明确「使用自定义信任锚的连接不做 CT 校验」，因此**不需要**额外的关闭开关。示例写在生成的 `network_security_config.xml` 注释里。
*For internal/self-signed hosts, add a `<domain-config>` with custom trust anchors — Android skips CT verification for custom-anchor connections, so **no separate opt-out tag is needed**. An example sits in the generated XML comments.*

> 不要把 user CA 放进 `base-config`：那会让所有 HTTPS 连接都走自定义信任锚，等于全局关掉 CT。用户 CA 放在 `debug-overrides`（仅 debug 生效）。
> *Don't put user CAs in `base-config` — that makes every HTTPS connection use custom anchors and disables CT globally. User CAs belong in `debug-overrides` (debug only).*

**3. 局域网 / 环回访问需要新权限** — Android 17 起访问 `192.168.x.x`（路由器、NAS）需 `ACCESS_LOCAL_NETWORK`；通过 `127.0.0.1` 与其他应用通信需 `USE_LOOPBACK_INTERFACE`。两者补丁脚本都会加，对浏览器是刚需。
*Android 17 requires `ACCESS_LOCAL_NETWORK` for LAN hosts (routers, NAS) and `USE_LOOPBACK_INTERFACE` for loopback communication. Both are injected — essential for a browser.*

**4. 明文流量改用网络安全配置** — `usesCleartextTraffic` 已废弃，改由 `res/xml/network_security_config.xml` 声明（旧属性保留，与新配置并存时以配置为准）。
*`usesCleartextTraffic` is deprecated in favor of a network security config (the old attribute remains; the config wins).*

### 仅需知悉（本项目不受影响）/ Notable but N/A here

| 变更 Change | 说明 Note |
| --- | --- |
| `System.load()` 的 native 库必须只读 | Flutter 从 APK 的 `nativeLibraryDir` 加载，本身只读，无影响 |
| 无锁 MessageQueue | 仅影响反射 MessageQueue 私有字段的代码 |
| `static final` 字段真正不可变 | 反射修改抛异常、JNI 修改崩溃；需关注第三方插件 |
| Parcel 校验升级为抛异常 | 同样取决于插件 |
| RemoteViews 内存上限 | 本项目无桌面小组件 |
| Activity 不再因键盘等配置变更重启 | 对 WebView 反而更好——输入时页面不重建 |

> Google Play 会在 **2027 年 8 月**起强制要求 `targetSdk = 37`。
> *Google Play will **require `targetSdk = 37` from August 2027**.*

---

## 手动更新文件的陷阱 / Manual file-copy pitfall

**只拷贝 `lib/` 里的单个文件很容易放到错误目录**，后果极具迷惑性：例如把 `sync_service.dart` 放到
`lib/features/settings/`（正确位置是 `lib/services/`），它里面的 `import '../core/constants.dart'`
在新路径下根本不存在，analyze 会报一大片 `uri_does_not_exist` / `undefined_class` /
`undefined_identifier` / `non_type_as_type_argument`——**看着像代码写错，实际只是文件放错了地方**。
***Copying individual files into `lib/` easily lands them in the wrong directory, and the fallout is deceptive: dropping `sync_service.dart` into `lib/features/settings/` (canonical: `lib/services/`) breaks its `import '../core/constants.dart'`, so analyze floods with `uri_does_not_exist` / `undefined_class` / `non_type_as_type_argument` — **looks like a code bug, is just a misplaced file**.***

**建议整包覆盖而非挑文件替换。** 若已发生，删掉错位副本即可（`tool/check_layout.py` 会自动清理已知情况并报告重名文件，CI 三个 job 都会先跑它）：
*Prefer overwriting the whole tree over cherry-picking files. If it already happened, delete the stray copies — `tool/check_layout.py` cleans known cases and reports duplicate basenames; all three CI jobs run it first.*

```bash
# 已出现过两次的错位副本（删掉即可）
rm -f lib/features/settings/sync_service.dart lib/features/browser/sign_in_form.dart
rm -f lib/features/browser/account_page.dart lib/features/browser/login_gate.dart

# 通用清理 + 重名检测
python3 tool/check_layout.py
```

`tool/check_layout.py` 在 **CI 三个 job 与 `bootstrap.sh` / `bootstrap.ps1`** 中都会先执行，
所以本地跑 bootstrap 或推 CI 时，错位副本会被自动清掉并留下日志。
*`tool/check_layout.py` runs first in **all three CI jobs and in `bootstrap.sh` / `bootstrap.ps1`**, so stray copies are cleaned automatically with a log line.*

> 注意 `prefer_const_constructors` 是 **info** 级，CI 用了 `--no-fatal-infos`，不会让构建变红；
> 只有 `uri_does_not_exist` 那类 **error** 会。看到成片的 `uri_does_not_exist`，先查文件路径，别急着改代码。
> *`prefer_const_constructors` is **info** level and CI passes `--no-fatal-infos`, so it won't fail the build — only **errors** like `uri_does_not_exist` will. When you see a cluster of `uri_does_not_exist`, check file paths before touching code.*

---

## 依赖与 SDK 约束 / Dependency & SDK constraints

`environment.sdk` 是 **`>=3.9.0`**，不是随手写的：`supabase_flutter` 2.16+ 的 Min Dart SDK 就是 3.9。
若把这里写低，pub 的 SDK-aware 版本求解会为了「兼容整个声明区间」把 supabase_flutter 降到老版本甚至解析不出来——
表现为 `.dart_tool/package_config.json` 里根本没有 `supabase_flutter`，analyze 随之报一片
`uri_does_not_exist` / `undefined_class` / `depend_on_referenced_packages`，**看着像代码写错，实际是依赖没装上**。
*`environment.sdk` is **`>=3.9.0`** for a reason: `supabase_flutter` 2.16+ requires Min Dart SDK 3.9. Declaring it lower makes pub's SDK-aware solver downgrade or fail to resolve it — `supabase_flutter` then never appears in `package_config.json` and analyze floods with `uri_does_not_exist` / `undefined_class`, **looking like a code bug when it's actually a missing dependency**.**

更新 `lib/` 后**务必一并同步 `pubspec.yaml`**，只拷 Dart 文件会触发上面的假报错。
CI 的「校验依赖已解析」会扫描代码里真实用到的 `package:` 导入逐一核对，缺了会先尝试自愈再失败并给出明确原因。
*Always sync `pubspec.yaml` when updating `lib/` — copying only Dart files triggers the false errors above. CI's dependency check scans real `package:` imports and self-heals before failing with a clear reason.*

## 依赖版本 / Dependency Note

`flutter_inappwebview` **6.x**。若锁到 5.x，需替换 `lib/features/browser/web_view_surface.dart` 里的：`InAppWebViewSettings`→`InAppWebViewGroupOptions`、`WebUri(url)`→`Uri`、`onDownloadStartRequest`→`onDownloadStart`。
*Targets `flutter_inappwebview` **6.x**. On 5.x, swap in `lib/features/browser/web_view_surface.dart`: `InAppWebViewSettings`→`InAppWebViewGroupOptions`, `WebUri(url)`→`Uri`, `onDownloadStartRequest`→`onDownloadStart`.*
