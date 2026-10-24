# BenBrowser

基于 **Flutter + 系统原生 WebView** 的个人自研浏览器：一份 Dart 代码，同时跑在 **Android / Windows / macOS** 上，靠 GitHub Actions 自动出三端安装包。

| 平台 | 内核 | 说明 |
| --- | --- | --- |
| Android | 系统 WebView（Chromium） | 由厂商/Google Play 更新，无需自带内核 |
| Windows | WebView2（Edge Chromium） | 需 Windows 10 1809+，Win10 需装 WebView2 Runtime |
| macOS | WKWebView | 需 macOS 10.14+ |

## 已实现功能

- 多标签（新建 / 关闭 / 切换，上限 20 个）
- 地址栏：裸域名自动补 `https://`，普通关键词走搜索引擎
- 前进 / 后退 / 刷新 / 停止 / 主页，加载进度条
- 书签（收藏、搜索、删除、清空）
- 历史记录（按站点去重、关键词搜索，无痕标签不入库）
- 下载管理（Dio 直连，进度条 + 打开文件，三端行为一致）
- 无痕标签（独立 incognito 上下文，不写缓存与历史）
- User-Agent 切换（跟随系统 / 桌面 Chrome / 移动 Chrome / 自定义）
- 新标签页：搜索框 + 常用站点 + 最近访问
- 设置持久化、亮/暗/跟随系统主题
- `target=_blank` 链接自动在新标签打开

## 目录结构

```
lib/
├── main.dart                      入口
├── app.dart                       MaterialApp（主题随设置切换）
├── core/                          常量、主题、平台判断、URL 解析
├── data/
│   ├── models/                    Tab / 书签 / 历史 / 下载 / 设置
│   ├── repositories/              持久化读写
│   └── storage/prefs_store.dart   SharedPreferences JSON 存储
├── state/                         Riverpod：设置、标签、下载、仓库
└── features/
    ├── browser/                   标签条、工具栏、WebView、导航动作
    ├── new_tab/                   新标签页
    ├── bookmarks｜history｜downloads｜settings
tool/
├── bootstrap.sh / .ps1            生成各平台原生壳
└── patch_platform.py              Android 明文流量 + macOS 网络权限
.github/workflows/build.yml        analyze/test + 三端构建 + Release
```

**为什么仓库里没有 android/、windows/、macos/ 目录？**
原生壳由 Flutter SDK 版本决定，硬编码进仓库会随 SDK 升级产生大量冲突。因此统一由 `tool/bootstrap.sh` 或 CI 里的 `flutter create` 生成，代码库只维护 Dart 侧。需要自定义 Android 签名或 macOS 公证时，把对应目录从 `.gitignore` 里放出来提交即可。

## 快速开始

```bash
# 1. 生成本机原生壳（可只生成部分平台）
PLATFORMS=android,windows,macos ./tool/bootstrap.sh

# 2. 运行
flutter run -d windows          # Windows
flutter run -d macos            # macOS
flutter run -d <device-id>      # Android（flutter devices 查看）
```

Windows 用户在 PowerShell 里执行 `.\tool\bootstrap.ps1`。

改动包名 / 组织名：

```bash
ORG=com.yourname ./tool/bootstrap.sh
```

## 改应用名

想把 BenBrowser 换成你自己的名字，一条命令搞定（Windows 上把 `python3` 换成 `python`）：

```bash
python3 tool/rename.py "MyBrowser" --org com.myname
python3 tool/rename.py "MyBrowser" --dry-run     # 先预览会改哪些文件
./tool/bootstrap.sh                              # 改名后重新生成原生壳
flutter pub get
```

脚本会自动重写四处名字：

| 项目 | 来源 | 示例 |
| --- | --- | --- |
| 显示名（窗口标题 / 新标签页） | 原样使用 | `MyBrowser` |
| Dart 包名（`pubspec` / `import`） | 自动 slug 化 | `my_browser` |
| Android / iOS 包名 | `--org` 指定 | `com.myname.my_browser` |
| CI 产物名 | 跟随显示名 | `MyBrowser-windows-x64.zip` |

名字里带英文别名的写法也可以：`python3 tool/rename.py "小浏览器 MyBrowser"`。
纯中文名不行——`pubspec` 的 `name` 只允许 `a-z0-9_`，脚本会提示加上英文别名。

## 本地自检（push 前先跑）

```bash
./tool/check.sh
```

等价于 CI 的 verify 步骤：`flutter pub get` → `flutter analyze lib test` → `flutter test`。
CI 只把 error 当失败（`--no-fatal-infos --no-fatal-warnings`），所以看到红叉时盯 error 那几行就行。

## 推送到你自己的 GitHub

```bash
git init && git add . && git commit -m "feat: init BenBrowser"
git remote add origin git@github.com:<你的账号>/ben_browser.git
git push -u origin main
```

- 推 `main` / 提 PR → 跑 analyze + test
- 打 tag `git tag v0.1.0 && git push --tags` → 自动构建并在 Release 挂上：
  `benbrowser-android（3 个 ABI 的 APK）`、`BenBrowser-windows-x64.zip`、`BenBrowser-macos.zip`

> CI 里的 `flutter create` 会用模板覆盖 `lib/main.dart`，还会生成引用 `MyApp` 的
> `test/widget_test.dart`。workflow 已经做了备份还原 + 删除模板测试，本地跑
> `tool/bootstrap.sh` 也一样处理。如果你自己改了 workflow，记得保留这两步，
> 否则打出来的包会是计数器 demo。

## 架构要点

- **状态管理**：Riverpod。设置用 `AsyncNotifier` 异步加载；标签用 `Notifier<TabsState>`
- **控制器托管**：`InAppWebViewController` 不进状态类，统一放 `webViewRegistryProvider`（`tabId → controller`），避免状态对象持有原生句柄
- **标签渲染**：`IndexedStack` 保持所有标签存活，关闭时从 registry 摘除 controller
- **存储**：`SharedPreferences` + JSON，三端零权限；数据量大了可平滑换成 Isar / Drift，只需替换 repository 实现
- **下载**：不走各平台自带下载器，统一 Dio 落到应用数据目录下的 `BenBrowser/Downloads`，Android 13+ 无需存储权限

## 平台注意事项

- **Windows**：Win10 未预装 WebView2 时首次启动会报错，安装 [WebView2 Runtime](https://developer.microsoft.com/microsoft-edge/webview2/) 即可；Win11 自带
- **macOS**：Release 包默认 ad-hoc 签名，别人电脑上会被 Gatekeeper 拦。分发前用 Developer ID 签名 + 公证
- **Android**：http 明文站点已通过补丁脚本开启；`minSdkVersion` 若低于 21 需自行上调
- **网络权限**：Android INTERNET 权限与 macOS `network.client` entitlement 已由 `tool/patch_platform.py` 注入

## 后续可加（按性价比排序）

1. 广告拦截：拦截规则订阅 + `shouldOverrideUrlLoading` 过滤（本机规则文件，无需服务器）
2. 标签会话持久化（当前关闭即丢失，重启后只恢复主页）
3. 书签/历史导入导出（HTML / JSON）
4. 密码与表单填充（需加密存储，建议 `flutter_secure_storage`）
5. 侧边栏、阅读模式、网页截图分享
6. 插件脚本注入（`evaluateJavascript` + 用户脚本管理）

## 依赖版本适配提示

`flutter_inappwebview` 6.x 与 5.x 的 API 名称有差异，本项目按 **6.x** 编写：

| 用途 | 6.x（本项目） | 5.x |
| --- | --- | --- |
| WebView 配置 | `InAppWebViewSettings` | `InAppWebViewGroupOptions` |
| URL 类型 | `WebUri(url)` | `Uri` |
| 下载回调 | `onDownloadStartRequest` | `onDownloadStart` |

若你锁到 5.x，只需按上表替换 `lib/features/browser/web_view_surface.dart` 里的对应写法。
