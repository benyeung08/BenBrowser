#!/usr/bin/env python3
"""检查并清理错位的 Dart 文件副本。

背景：手动拷贝文件时很容易把文件放到错误的目录（例如把
sync_service.dart 放成 lib/features/settings/sync_service.dart），
而正确位置 lib/services/sync_service.dart 仍然存在。

后果很隐蔽：两份同名文件里，目标文件引用的 `../core/constants.dart`
在新位置根本不存在，于是 analyze 报一大片
uri_does_not_exist / undefined_class / undefined_identifier，
看起来像代码写错了，实际只是文件放错了地方。

本脚本做两件事：
1. 删除已知的错位副本（历史遗留，写死路径，安全且幂等）
2. 报告 lib/ 下所有重名文件，避免以后再出现同类问题
"""

import os
import sys

# 已知的历史错位副本：文件名 -> 唯一正确位置
KNOWN_STRAYS = {
    "sync_service.dart": "lib/services",
    "account_service.dart": "lib/services",
    "update_service.dart": "lib/services",
    "desktop_update.dart": "lib/services",
    "sign_in_form.dart": "lib/features/settings",
    "login_gate.dart": "lib/features/settings",
    "account_page.dart": "lib/features/settings",
    "settings_page.dart": "lib/features/settings",
    "update_dialog.dart": "lib/features/settings",
    "startup_update_check.dart": "lib/features/settings",
    # 下面这几个是 browser/ 目录组，同样容易被误放到 features/browser/
    "browser_page.dart": "lib/features/browser",
    "browser_toolbar.dart": "lib/features/browser",
    "navigation.dart": "lib/features/browser",
    "tab_strip.dart": "lib/features/browser",
    "web_view_surface.dart": "lib/features/browser",
    "new_tab_page.dart": "lib/features/new_tab",
    "bookmarks_page.dart": "lib/features/bookmarks",
    "history_page.dart": "lib/features/history",
    "downloads_page.dart": "lib/features/downloads",
    "app.dart": "lib",
    "main.dart": "lib",
    "sync_snapshot.dart": "lib/data/models",
    "user_account.dart": "lib/data/models",
    "app_settings.dart": "lib/data/models",
    "bookmark.dart": "lib/data/models",
    "browser_tab.dart": "lib/data/models",
    "download_task.dart": "lib/data/models",
    "history_entry.dart": "lib/data/models",
    "release_info.dart": "lib/data/models",
    "prefs_store.dart": "lib/data/storage",
    "bookmark_repository.dart": "lib/data/repositories",
    "history_repository.dart": "lib/data/repositories",
    "settings_repository.dart": "lib/data/repositories",
    "providers.dart": "lib/state",
    "tabs_controller.dart": "lib/state",
    "downloads_controller.dart": "lib/state",
    "constants.dart": "lib/core",
    "app_theme.dart": "lib/core",
    "platform_info.dart": "lib/core",
    "url_utils.dart": "lib/core",
}


def _rel(path: str) -> str:
    return os.path.relpath(path, os.getcwd()).replace(os.sep, "/")


def remove_known_strays() -> int:
    removed = 0
    for name, canonical in KNOWN_STRAYS.items():
        canonical_path = os.path.join(canonical, name)
        if not os.path.isfile(canonical_path):
            # 正确位置都没有，说明这份可能不是副本，别乱删
            continue
        for root, _dirs, files in os.walk("lib"):
            if os.path.normpath(root) == os.path.normpath(canonical):
                continue
            if name in files:
                stray = os.path.join(root, name)
                print(f"[layout] 删除错位副本：{_rel(stray)}（正确位置 {canonical}/{name}）")
                os.remove(stray)
                removed += 1
    return removed


def report_duplicates() -> bool:
    seen: dict[str, list[str]] = {}
    for root, _dirs, files in os.walk("lib"):
        for f in files:
            if not f.endswith(".dart"):
                continue
            seen.setdefault(f, []).append(_rel(os.path.join(root, f)))

    dupes = {k: v for k, v in seen.items() if len(v) > 1}
    if not dupes:
        print("[layout] 无重名 Dart 文件 ✅")
        return False

    print("[layout] ::error::检测到重名 Dart 文件，通常意味着手动拷贝时放错了目录：")
    for name, paths in sorted(dupes.items()):
        canonical = KNOWN_STRAYS.get(name)
        print(f"[layout]   {name}:")
        for p in sorted(paths):
            mark = "  ← 正确位置" if canonical and p == f"{canonical}/{name}" else "  ← 错位副本"
            print(f"[layout]     {p}{mark}")
    return True


def main() -> int:
    if not os.path.isdir("lib"):
        print("[layout] skip（未找到 lib/）")
        return 0

    removed = remove_known_strays()
    if removed:
        print(f"[layout] 已清理 {removed} 个错位副本")

    return 1 if report_duplicates() else 0


if __name__ == "__main__":
    sys.exit(main())
