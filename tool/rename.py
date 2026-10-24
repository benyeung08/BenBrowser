#!/usr/bin/env python3
"""一次性改名工具：把仓库里的应用名 / 包名 / 产物名全部替换。

它会从现有代码里自动读出「旧名字」，所以可以反复执行、改任何名字。

用法：
    python3 tool/rename.py "新显示名"                 # 如 "BenBrowser"
    python3 tool/rename.py "新显示名" --org com.ben   # 同时改 Android/iOS 组织名
    python3 tool/rename.py "新显示名" --dry-run       # 只看会改哪些文件，不落盘

说明：
    - 显示名（窗口标题、新标签页）：原样使用，如 BenBrowser
    - Dart 包名（pubspec name、import 路径）：自动 slug 化，如 ben_browser
    - Google Play / App Store 包名：--org 指定，如 com.ben.ben_browser
    - CI 产物名：跟随显示名，如 BenBrowser-windows-x64.zip
"""

from __future__ import annotations

import argparse
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# 不需要参与改名的目录 / 文件后缀
SKIP_DIRS = {
    ".git", ".dart_tool", ".idea", ".vscode", "build", ".pub-cache",
    "android", "ios", "windows", "macos", "linux", "web",  # 原生壳由 flutter create 生成
}
TEXT_SUFFIXES = {
    ".dart", ".yaml", ".yml", ".md", ".sh", ".ps1", ".py", ".json",
    ".txt", ".gradle", ".xml", ".xcconfig", ".plist", ".gitignore", "",
}


def read_current() -> dict[str, str]:
    """从现有代码推断当前的各类名字。"""
    info: dict[str, str] = {}

    pubspec = os.path.join(ROOT, "pubspec.yaml")
    if os.path.isfile(pubspec):
        with open(pubspec, encoding="utf-8") as fh:
            for line in fh:
                m = re.match(r"^name:\s*(\S+)", line)
                if m:
                    info["slug"] = m.group(1)
                    break

    constants = os.path.join(ROOT, "lib", "core", "constants.dart")
    if os.path.isfile(constants):
        with open(constants, encoding="utf-8") as fh:
            m = re.search(r"appName\s*=\s*(['\"])(.+?)\1", fh.read())
            if m:
                info["display"] = m.group(2)

    bootstrap = os.path.join(ROOT, "tool", "bootstrap.sh")
    if os.path.isfile(bootstrap):
        with open(bootstrap, encoding="utf-8") as fh:
            m = re.search(r'ORG:-\s*"?([^"\s}]+)', fh.read())
            if m:
                info["org"] = m.group(1)

    return info


def slugify(name: str) -> str:
    """BenBrowser -> ben_browser；Ben's Browser -> ben_s_browser"""
    s = name.strip().lower()
    s = re.sub(r"[^a-z0-9]+", "_", s)
    s = re.sub(r"_+", "_", s).strip("_")
    if not s:
        raise SystemExit(
            "名字里没有英文字母或数字，无法生成 Dart 包名（pubspec name 只允许 a-z0-9_）。\n"
            "可以写成「中文名 + 英文别名」的形式，例如：小浏览器 BenBrowser"
        )
    if not s[0].isalpha():
        s = f"app_{s}"
    return s


def build_replacements(old: dict[str, str], new_display: str, new_org: str | None) -> list[tuple[str, str]]:
    pairs: list[tuple[str, str]] = []

    if "display" in old and old["display"] != new_display:
        pairs.append((old["display"], new_display))

    new_slug = slugify(new_display)
    if old.get("slug") and old["slug"] != new_slug:
        pairs.append((old["slug"], new_slug))
        # CI 里的 artifact 名是去掉下划线的形式：benbrowser-android
        old_flat = old["slug"].replace("_", "")
        new_flat = new_slug.replace("_", "")
        if old_flat != new_flat:
            pairs.append((old_flat, new_flat))

    if new_org and old.get("org") and old["org"] != new_org:
        pairs.append((old["org"], new_org))

    # 长串优先替换，避免 package:ben_browser 被部分吃掉
    pairs.sort(key=lambda p: -len(p[0]))
    return pairs


def iter_files():
    self_path = os.path.abspath(__file__)
    for dirpath, dirnames, filenames in os.walk(ROOT):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            suffix = os.path.splitext(name)[1]
            if suffix not in TEXT_SUFFIXES:
                continue
            path = os.path.join(dirpath, name)
            # 跳过自身，避免把示例文本也改掉
            if os.path.abspath(path) == self_path:
                continue
            yield path


def fix_app_name_literal(display: str) -> bool:
    """名字里带单引号时，Dart 字符串字面量要改用双引号包，否则语法出错。"""
    path = os.path.join(ROOT, "lib", "core", "constants.dart")
    if not os.path.isfile(path):
        return False
    with open(path, encoding="utf-8") as fh:
        text = fh.read()
    quote = '"' if "'" in display else "'"
    # 整段替换到分号前，避免名字里的单引号把匹配截短
    new_text = re.sub(
        r"appName\s*=\s*[^;]*;",
        f'appName = {quote}{display}{quote};',
        text,
        count=1,
    )
    if new_text == text:
        return False
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(new_text)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description="重命名本仓库中的应用名")
    parser.add_argument("name", help="新的显示名，例如 BenBrowser")
    parser.add_argument("--org", help="新的组织名，例如 com.ben（影响 Android/iOS 包名）")
    parser.add_argument("--dry-run", action="store_true", help="只预览，不写入")
    args = parser.parse_args()

    if any(ch in args.name for ch in ('"', "\\", ";", "\n", "\r")):
        raise SystemExit("显示名里不能包含双引号、反斜杠、分号或换行")

    old = read_current()
    if not old.get("slug") or not old.get("display"):
        print("未能从 pubspec.yaml / constants.dart 读出当前名字，确认脚本放在 tool/ 下",
              file=sys.stderr)
        return 1

    pairs = build_replacements(old, args.name, args.org)
    if not pairs:
        print("名字没有变化，无需处理")
        return 0

    print(f"旧：{old}")
    print(f"新：显示名={args.name}  Dart包名={slugify(args.name)}  组织名={args.org or old.get('org')}")
    print("替换规则：")
    for a, b in pairs:
        print(f"  {a}  ->  {b}")

    changed: list[str] = []
    for path in iter_files():
        try:
            with open(path, encoding="utf-8") as fh:
                text = fh.read()
        except (UnicodeDecodeError, PermissionError):
            continue
        new_text = text
        for a, b in pairs:
            new_text = new_text.replace(a, b)
        if new_text == text:
            continue
        rel = os.path.relpath(path, ROOT)
        changed.append(rel)
        if not args.dry_run:
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(new_text)

    print(f"\n{'(预览) ' if args.dry_run else ''}共 {len(changed)} 个文件：")
    for rel in changed:
        print(f"  {rel}")

    if not args.dry_run:
        if fix_app_name_literal(args.name):
            print("  lib/core/constants.dart（appName 字面量引号已修正）")

        print("\n完成。下一步：")
        print(f"  1. 目录名可一并改为 {slugify(args.name)}（不影响编译，仅整齐）")
        print("  2. 重新生成原生壳：./tool/bootstrap.sh")
        print("  3. flutter pub get && flutter run")
    return 0


if __name__ == "__main__":
    sys.exit(main())
