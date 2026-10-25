#!/usr/bin/env python3
"""为 flutter create 生成的 Android 原生壳打上本项目需要的补丁，可重复执行。

- 打开明文流量（http 站点）
- 确保 INTERNET 权限
- 应用内更新装 APK 需要 REQUEST_INSTALL_PACKAGES + FileProvider

项目已精简为纯 Android，不再处理 Windows / macOS 壳。
"""

from __future__ import annotations

import os
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

    # 应用内安装 APK（设置里的「下载并安装」需要）
    wanted = {
        "android.permission.REQUEST_INSTALL_PACKAGES": "应用内更新安装",
    }
    for perm, desc in wanted.items():
        exists = any(
            child.tag == "uses-permission" and child.get(f"{{{ANDROID_NS}}}name") == perm
            for child in root
        )
        if not exists:
            ET.SubElement(root, "uses-permission", {f"{{{ANDROID_NS}}}name": perm})
            log(f"android: + {perm}（{desc}）")

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

        # FileProvider：Android 7.0+ 禁止 file:// URI，
        # 不配这段的话「下载并安装」打开 APK 会抛 FileUriExposedException
        authority = "${applicationId}.fileprovider"
        has_provider = any(
            child.tag == "provider"
            and child.get(f"{{{ANDROID_NS}}}authorities") == authority
            for child in application
        )
        if not has_provider:
            provider = ET.SubElement(application, "provider")
            provider.set(f"{{{ANDROID_NS}}}name", "androidx.core.content.FileProvider")
            provider.set(f"{{{ANDROID_NS}}}authorities", authority)
            provider.set(f"{{{ANDROID_NS}}}exported", "false")
            provider.set(f"{{{ANDROID_NS}}}grantUriPermissions", "true")
            meta = ET.SubElement(provider, "meta-data")
            meta.set(f"{{{ANDROID_NS}}}name", "android.support.FILE_PROVIDER_PATHS")
            meta.set(f"{{{ANDROID_NS}}}resource", "@xml/file_paths")
            log(f"android: + FileProvider ({authority})")

    tree.write(manifest, encoding="utf-8", xml_declaration=True)
    log("android: manifest updated")

    _write_file_paths()


def _write_file_paths() -> None:
    """APK 下载到 getFilesDir()，这里把该目录映射给 FileProvider。"""
    xml_dir = os.path.join(ROOT, "android", "app", "src", "main", "res", "xml")
    path = os.path.join(xml_dir, "file_paths.xml")
    if os.path.isfile(path):
        return

    os.makedirs(xml_dir, exist_ok=True)
    content = """<?xml version="1.0" encoding="utf-8"?>
<paths>
    <!-- 应用内更新下载的 APK 落在 getFilesDir()/BenBrowser/Updates/ -->
    <files-path name="files" path="." />
    <cache-path name="cache" path="." />
    <external-files-path name="external_files" path="." />
</paths>
"""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)
    log("android: + res/xml/file_paths.xml")


def main() -> int:
    patch_android()
    patch_macos()
    log("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
