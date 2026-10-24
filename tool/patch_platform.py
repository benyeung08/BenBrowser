#!/usr/bin/env python3
"""为 flutter create 生成的原生壳打上本项目需要的补丁，可重复执行。

- Android: 打开明文流量（http 站点），确保 INTERNET 权限
- macOS:   补上网络访问 entitlement，并把产物名改为 Nimbus
"""

from __future__ import annotations

import os
import plistlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_NS = "http://schemas.android.com/apk/res/android"


def log(message: str) -> None:
    print(f"[patch] {message}")


def patch_android() -> None:
    manifest = os.path.join(ROOT, "android", "app", "src", "main", "AndroidManifest.xml")
    if not os.path.isfile(manifest):
        log("skip android (manifest not found)")
        return

    ET.register_namespace("android", ANDROID_NS)
    tree = ET.parse(manifest)
    root = tree.getroot()

    # INTERNET 权限
    has_internet = any(
        child.tag == "uses-permission"
        and child.get(f"{{{ANDROID_NS}}}name") == "android.permission.INTERNET"
        for child in root
    )
    if not has_internet:
        ET.SubElement(root, "uses-permission", {f"{{{ANDROID_NS}}}name": "android.permission.INTERNET"})
        log("android: + INTERNET permission")

    # 明文流量（http 站点）
    application = root.find("application")
    if application is not None:
        attr = f"{{{ANDROID_NS}}}usesCleartextTraffic"
        if application.get(attr) is None:
            application.set(attr, "true")
            log("android: + usesCleartextTraffic=true")
        # 硬件加速，WebView 播放视频更稳
        attr2 = f"{{{ANDROID_NS}}}hardwareAccelerated"
        if application.get(attr2) is None:
            application.set(attr2, "true")

    tree.write(manifest, encoding="utf-8", xml_declaration=True)
    log("android: manifest updated")


def patch_macos() -> None:
    runner = os.path.join(ROOT, "macos", "Runner")
    if not os.path.isdir(runner):
        log("skip macos (Runner not found)")
        return

    # 网络访问 entitlement
    for name in ("DebugProfile.entitlements", "Release.entitlements"):
        path = os.path.join(runner, name)
        if not os.path.isfile(path):
            continue
        with open(path, "rb") as fh:
            data = plistlib.load(fh)
        data.setdefault("com.apple.security.network.client", True)
        data.setdefault("com.apple.security.files.user-selected.read-only", True)
        with open(path, "wb") as fh:
            plistlib.dump(data, fh)
        log(f"macos: entitlements patched ({name})")

    # 产物名 Runner.app -> Nimbus.app
    config = os.path.join(runner, "Configs", "AppInfo.xcconfig")
    if os.path.isfile(config):
        with open(config, "r", encoding="utf-8") as fh:
            text = fh.read()
        new_text = re.sub(
            r"^PRODUCT_NAME\s*=.*$", "PRODUCT_NAME = Nimbus", text, flags=re.M
        )
        if new_text != text:
            with open(config, "w", encoding="utf-8") as fh:
                fh.write(new_text)
            log("macos: PRODUCT_NAME -> Nimbus")


def main() -> int:
    patch_android()
    patch_macos()
    log("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
