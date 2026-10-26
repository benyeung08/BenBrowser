#!/usr/bin/env python3
"""为 flutter create 生成的 Android 原生壳打上本项目需要的补丁，可重复执行。

- 打开明文流量（http 站点）
- 确保 INTERNET 权限
- 应用内更新装 APK 需要 REQUEST_INSTALL_PACKAGES + FileProvider
- 渲染：Vulkan 声明为**可选**，OpenGL ES 3.0 作为**兜底必有**
- 对齐 Android 17（API 37）：compileSdk / targetSdk 提到 37
  最低系统 Android 10（API 29）
  NDK 提到 r28（16KB 内存分页所需）

同时确认 Windows 壳的产物目录（macOS 已不再支持）。

可用环境变量（CI 或本地 export 后执行）：
  VULKAN_MIN_VERSION   声明的最低 Vulkan 版本，默认 1.0（不强制，仅作提示）
  VULKAN_REQUIRED      true=无 Vulkan 的设备禁止安装；默认 false
  GLES_MIN_VERSION     OpenGL ES 最低版本，默认 3.0
  GLES_REQUIRED        默认 true（兜底渲染能力，建议保持）
  ANDROID_COMPILE_SDK  默认 37（Android 17）
  ANDROID_TARGET_SDK   默认 37（Android 17）
  ANDROID_MIN_SDK      默认 29（Android 10）
  ANDROID_NDK          默认 28.2.13676358（NDK r28，16KB 分页下限）
  ANDROID_KEEP_FLUTTER_SDK
                       设为 true 则**不覆盖** build.gradle 里的
                       flutter.xxxSdkVersion 变量，改回官方推荐的
                       「跟随 Flutter SDK」模式（此时 target 会退回
                       Flutter 默认，多半是 36 而不是 37）

关于 flutter.xxxSdkVersion：
  官方建议沿用 Flutter SDK 提供的变量，避免 AGP / Gradle 版本打架。
  但 Flutter 的 flutter.compileSdkVersion 通常落后于最新 Android，
  本项目明确要求 target 到 Android 17（API 37），所以默认**强制覆盖**
  成字面量。代价是 CI 必须先装好 Android SDK Platform 37，
  否则 Gradle 会报 "failed to find target"。
"""

from __future__ import annotations

import os
import re
import sys
import xml.etree.ElementTree as ET

# Windows 控制台默认用 cp1252（或 GBK），遇到中文日志字符会抛
# UnicodeEncodeError 让整个脚本崩掉——而补丁脚本崩了会让 job 直接失败。
# 这里无论如何都把 stdout/stderr 调成 UTF-8，失败就降级成 ASCII 安全输出。
def _force_utf8_console() -> None:
    for stream_name in ("stdout", "stderr"):
        stream = getattr(sys, stream_name, None)
        if stream is None:
            continue
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except Exception:
            try:
                import io
                import codecs

                wrapped = codecs.getwriter("utf-8")(
                    stream.buffer if hasattr(stream, "buffer") else stream,
                    errors="replace",
                )
                setattr(sys, stream_name, wrapped)
            except Exception:
                pass


_force_utf8_console()

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ANDROID_NS = "http://schemas.android.com/apk/res/android"
VULKAN_FEATURE = "android.hardware.vulkan.version"
GLES_ATTR = f"{{{ANDROID_NS}}}glEsVersion"
REQ_ATTR = f"{{{ANDROID_NS}}}required"
NAME_ATTR = f"{{{ANDROID_NS}}}name"


def log(message: str) -> None:
    """打印日志。

    双重保险：即使控制台编码没修好（比如极端环境下 reconfigure 失败），
    也要把无法编码的字符替换掉而不是抛异常——补丁脚本挂掉会让整个
    CI job 失败，那是本末倒置。
    """
    text = f"[patch] {message}"
    try:
        print(text)
    except (UnicodeEncodeError, OSError):
        try:
            print(text.encode("utf-8", "replace").decode("utf-8", "replace"))
        except Exception:
            # 实在打不出来就放弃，绝不让日志影响构建
            pass


# ------------------------------------------------------------------ 版本号


def vulkan_version_code(text: str) -> int:
    """把 '1.0' / '1.1' / '1.4' 编码成 Android 要求的 32 位整数。

    编码规则来自 VkPhysicalDeviceProperties::apiVersion：
      bit 31-22 = major，bit 21-12 = minor，bit 11-0 = patch

    所以 1.0 → 0x00400000，1.1 → 0x00401000，1.4 → 0x00404000。
    """
    parts = (text or "1.0").strip().split(".")
    try:
        major = int(parts[0]) if len(parts) > 0 else 1
        minor = int(parts[1]) if len(parts) > 1 else 0
        patch = int(parts[2]) if len(parts) > 2 else 0
    except ValueError:
        log(f"VULKAN_MIN_VERSION={text!r} 解析失败，回退到 1.0")
        return 0x00400000
    return (major << 22) | (minor << 12) | patch


def gles_version_code(text: str) -> str:
    """把 '3.0' / '2.0' 编码成 android:glEsVersion 的字符串。

    高 16 位是主版本，低 16 位是次版本：3.0 → '0x00030000'。
    """
    parts = (text or "3.0").strip().split(".")
    try:
        major = int(parts[0]) if len(parts) > 0 else 3
        minor = int(parts[1]) if len(parts) > 1 else 0
    except ValueError:
        log(f"GLES_MIN_VERSION={text!r} 解析失败，回退到 3.0")
        return "0x00030000"
    return f"0x{major:04X}{minor:04X}"


def version_at_least(current: str, wanted: str) -> bool:
    """比较两个点分版本号，逐段补零。"""
    def parts(v: str) -> list[int]:
        out: list[int] = []
        for seg in re.split(r"[.\-_]", v):
            m = re.match(r"\d+", seg)
            out.append(int(m.group()) if m else 0)
        return out

    pa, pb = parts(current), parts(wanted)
    n = max(len(pa), len(pb))
    pa += [0] * (n - len(pa))
    pb += [0] * (n - len(pb))
    return pa >= pb


# ------------------------------------------------------------------ manifest


def _add_vulkan_feature(root: ET.Element) -> None:
    """声明 Vulkan 为**可选**特性。

    默认 required=false：没有 Vulkan 的设备也能装，由 Flutter 自动回退到
    OpenGLES。想恢复成硬性门槛就设 VULKAN_REQUIRED=true。

    另外 android:version 是「最低版本」语义，不是精确匹配：声明 1.0 就覆盖
    1.0~1.4 乃至更高，所以不需要、也无法设上限。
    """
    min_version = os.environ.get("VULKAN_MIN_VERSION", "1.0").strip() or "1.0"
    required = os.environ.get("VULKAN_REQUIRED", "false").strip().lower() == "true"

    code = vulkan_version_code(min_version)
    version_attr = f"0x{code:08X}"
    req_attr = "true" if required else "false"

    for child in root:
        if child.tag == "uses-feature" and child.get(NAME_ATTR) == VULKAN_FEATURE:
            child.set(f"{{{ANDROID_NS}}}version", version_attr)
            child.set(REQ_ATTR, req_attr)
            log(f"android: 更新 {VULKAN_FEATURE} = {version_attr}")
            _log_vulkan_mode(required)
            return

    ET.SubElement(
        root,
        "uses-feature",
        {
            NAME_ATTR: VULKAN_FEATURE,
            f"{{{ANDROID_NS}}}version": version_attr,
            REQ_ATTR: req_attr,
        },
    )
    log(f"android: + {VULKAN_FEATURE} = {version_attr} (Vulkan >= {min_version})")
    _log_vulkan_mode(required)


def _log_vulkan_mode(required: bool) -> None:
    if required:
        log("android:   required=true —— 无 Vulkan 的设备将被拒绝安装")
    else:
        log("android:   required=false —— 无 Vulkan 的设备照装，自动回退 OpenGL ES")


def _add_gles_feature(root: ET.Element) -> None:
    """声明 OpenGL ES 为兜底渲染能力。

    Vulkan 变成可选后，必须有一条「底线」保证设备至少能画东西，
    否则可能装到完全没有 GPU 加速的环境上。GLES 3.0 在 Android 7+ 上
    几乎是 100% 覆盖，所以默认 3.0 且 required=true。
    """
    min_version = os.environ.get("GLES_MIN_VERSION", "3.0").strip() or "3.0"
    required = os.environ.get("GLES_REQUIRED", "true").strip().lower() != "false"

    code = gles_version_code(min_version)

    for child in root:
        if child.tag == "uses-feature" and child.get(GLES_ATTR) is not None:
            child.set(GLES_ATTR, code)
            child.set(REQ_ATTR, "true" if required else "false")
            log(f"android: 更新 glEsVersion = {code}")
            return

    ET.SubElement(
        root,
        "uses-feature",
        {
            GLES_ATTR: code,
            REQ_ATTR: "true" if required else "false",
        },
    )
    log(f"android: + glEsVersion = {code} (OpenGL ES >= {min_version})")


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
        and child.get(NAME_ATTR) == "android.permission.INTERNET"
        for child in root
    )
    if not has_internet:
        ET.SubElement(root, "uses-permission", {NAME_ATTR: "android.permission.INTERNET"})
        log("android: + INTERNET permission")

    # 应用内安装 APK（设置里的「下载并安装」需要）
    wanted = {
        "android.permission.REQUEST_INSTALL_PACKAGES": "应用内更新安装",
    }
    for perm, desc in wanted.items():
        exists = any(
            child.tag == "uses-permission" and child.get(NAME_ATTR) == perm
            for child in root
        )
        if not exists:
            ET.SubElement(root, "uses-permission", {NAME_ATTR: perm})
            log(f"android: + {perm}（{desc}）")

    # 渲染能力：Vulkan 可选 + OpenGL ES 兜底
    _add_vulkan_feature(root)
    _add_gles_feature(root)

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
        # Android 17 起 usesCleartextTraffic 已废弃，官方建议改用
        # 网络安全配置。两者并存时以配置为准。
        nsc_attr = f"{{{ANDROID_NS}}}networkSecurityConfig"
        if application.get(nsc_attr) is None:
            application.set(nsc_attr, "@xml/network_security_config")
            log("android: + networkSecurityConfig=@xml/network_security_config")

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
            provider.set(NAME_ATTR, "androidx.core.content.FileProvider")
            provider.set(f"{{{ANDROID_NS}}}authorities", authority)
            provider.set(f"{{{ANDROID_NS}}}exported", "false")
            provider.set(f"{{{ANDROID_NS}}}grantUriPermissions", "true")
            meta = ET.SubElement(provider, "meta-data")
            meta.set(NAME_ATTR, "android.support.FILE_PROVIDER_PATHS")
            meta.set(f"{{{ANDROID_NS}}}resource", "@xml/file_paths")
            log(f"android: + FileProvider ({authority})")

    tree.write(manifest, encoding="utf-8", xml_declaration=True)
    log("android: manifest updated")

    _write_file_paths()
    _write_network_security_config()
    _patch_gradle()


def _write_network_security_config() -> None:
    """Android 17 起 android:usesCleartextTraffic 已废弃，
    官方建议改用网络安全配置来声明明文流量放行。

    顺带把用户 CA 也纳入信任锚——访问内网 / 自签证书的站点时会用到。
    """
    xml_dir = os.path.join(ROOT, "android", "app", "src", "main", "res", "xml")
    path = os.path.join(xml_dir, "network_security_config.xml")
    if os.path.isfile(path):
        return

    os.makedirs(xml_dir, exist_ok=True)
    content = """<?xml version="1.0" encoding="utf-8"?>
<network-security-config>
    <!-- 放行 http 明文站点（对应已废弃的 usesCleartextTraffic） -->
    <base-config cleartextTrafficPermitted="true">
        <trust-anchors>
            <certificates src="system" />
            <certificates src="user" />
        </trust-anchors>
    </base-config>
</network-security-config>
"""
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(content)
    log("android: + res/xml/network_security_config.xml")


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


# ------------------------------------------------------------------ gradle


def _find_gradle() -> str | None:
    for name in ("build.gradle", "build.gradle.kts"):
        path = os.path.join(ROOT, "android", "app", name)
        if os.path.isfile(path):
            return path
    return None


def _patch_gradle_value(
    text: str,
    names: tuple[str, ...],
    wanted: str,
    label: str,
    *,
    as_string: bool = False,
    override_flutter: bool = False,
) -> tuple[str, str]:
    """把 compileSdk / targetSdk / minSdk / ndkVersion 提到目标值。

    遇到 flutter.xxxVersion 这类由 Flutter SDK 提供的变量时：
      - override_flutter=False：原样保留（官方推荐，写死容易和 AGP 打架）
      - override_flutter=True ：强制换成本项目要求的字面量。
        本项目要 target 到 Android 17（API 37），而 Flutter 的
        flutter.compileSdkVersion 一般落后于最新 Android，不覆盖就到不了 37。
    """
    pattern = re.compile(
        r"\b(" + "|".join(names) + r")(\s*(?:=|\s)\s*)(flutter\.[A-Za-z]+|\"[^\"]+\"|\d[\w.]*)"
    )
    m = pattern.search(text)
    if m is None:
        return text, f"{label}: 未找到，跳过"

    current = m.group(3)
    replacement = f'"{wanted}"' if as_string else wanted

    if current.startswith("flutter."):
        if not override_flutter:
            return text, f"{label}: 沿用 {current}（不覆盖）"
        new_text = text[: m.start(3)] + replacement + text[m.end(3) :]
        return new_text, f"{label}: {current} -> {wanted}（强制覆盖）"

    current_num = current.strip('"')
    if version_at_least(current_num, wanted):
        return text, f"{label}: {current_num} 已满足"

    new_text = text[: m.start(3)] + replacement + text[m.end(3) :]
    return new_text, f"{label}: {current_num} -> {wanted}"


def _patch_gradle() -> None:
    """对齐 Android 17（API 37），最低系统 Android 10（API 29）。"""
    path = _find_gradle()
    if path is None:
        log("skip gradle (build.gradle not found)")
        return

    with open(path, "r", encoding="utf-8") as fh:
        original = fh.read()
    text = original

    compile_sdk = os.environ.get("ANDROID_COMPILE_SDK", "37").strip() or "37"
    target_sdk = os.environ.get("ANDROID_TARGET_SDK", "37").strip() or "37"
    min_sdk = os.environ.get("ANDROID_MIN_SDK", "29").strip() or "29"
    # NDK r28 是 16KB 分页对齐的最低要求（Flutter 3.38 起作为默认值）
    ndk = os.environ.get("ANDROID_NDK", "28.2.13676358").strip() or "28.2.13676358"

    # 默认强制覆盖 flutter.* 变量，否则到不了 API 37；
    # 想回到「跟随 Flutter」模式就设 ANDROID_KEEP_FLUTTER_SDK=true
    keep_flutter = os.environ.get("ANDROID_KEEP_FLUTTER_SDK", "false").strip().lower() == "true"
    force = not keep_flutter

    text, m1 = _patch_gradle_value(
        text, ("compileSdkVersion", "compileSdk"), compile_sdk, "compileSdk",
        override_flutter=force,
    )
    text, m2 = _patch_gradle_value(
        text, ("targetSdkVersion", "targetSdk"), target_sdk, "targetSdk",
        override_flutter=force,
    )
    text, m3 = _patch_gradle_value(
        text, ("minSdkVersion", "minSdk"), min_sdk, "minSdk",
        override_flutter=force,
    )
    # NDK 沿用 Flutter 给的即可（r28 起才支持 16KB 分页，Flutter 3.38+ 默认已是）
    text, m4 = _patch_gradle_value(
        text, ("ndkVersion",), ndk, "ndkVersion", as_string=True,
        override_flutter=False,
    )

    for msg in (m1, m2, m3, m4):
        log(f"android: {msg}")

    if text != original:
        with open(path, "w", encoding="utf-8") as fh:
            fh.write(text)
        log(f"android: {os.path.basename(path)} updated")


# ------------------------------------------------- 第三方插件兼容补丁


def _pub_cache_roots() -> list[str]:
    """可能的 pub-cache 位置。CI 与本地不同，逐个试。"""
    roots = []
    env = os.environ.get("PUB_CACHE", "").strip()
    if env:
        roots.append(os.path.join(env, "hosted", "pub.dev"))
        roots.append(env)
    home = os.path.expanduser("~")
    for base in (home, os.path.join(home, ".pub-cache")):
        roots.append(os.path.join(base, ".pub-cache", "hosted", "pub.dev"))
    # Flutter SDK 自带缓存的可能位置
    for flutter_root in (os.environ.get("FLUTTER_ROOT", ""),):
        if flutter_root:
            roots.append(os.path.join(flutter_root, ".pub-cache", "hosted", "pub.dev"))
    return [r for r in roots if r]


def patch_plugin_proguard() -> None:
    """修补插件里已被 AGP 移除的 ProGuard 写法。

    典型报错（flutter_inappwebview_android 1.1.3 会触发）：

        getDefaultProguardFile('proguard-android.txt') is no longer supported
        since it includes -dontoptimize, which prevents R8 from performing
        many optimizations.

    新版 AGP 删掉了 proguard-android.txt，只允许 -optimize 变体。
    插件在 pub-cache 里、路径每次可能变，所以遍历整个缓存目录，
    把所有插件的 android/build.gradle 一起修掉（不止 inappwebview，
    别的插件出同样问题时也一并覆盖）。

    必须在 `flutter pub get` 之后执行，否则缓存里还没有插件。
    """
    replaced: list[str] = []
    seen: set[str] = set()

    for base in _pub_cache_roots():
        real = os.path.realpath(base)
        if real in seen:
            continue
        seen.add(real)
        if not os.path.isdir(base):
            continue
        try:
            entries = sorted(os.listdir(base))
        except OSError:
            continue
        for name in entries:
            pkg_dir = os.path.join(base, name)
            if not os.path.isdir(pkg_dir):
                continue
            gradle = os.path.join(pkg_dir, "android", "build.gradle")
            if not os.path.isfile(gradle):
                continue
            try:
                with open(gradle, "r", encoding="utf-8") as fh:
                    text = fh.read()
            except OSError:
                continue
            if "proguard-android.txt" not in text:
                continue
            new = text.replace(
                "getDefaultProguardFile('proguard-android.txt')",
                "getDefaultProguardFile('proguard-android-optimize.txt')",
            ).replace(
                'getDefaultProguardFile("proguard-android.txt")',
                'getDefaultProguardFile("proguard-android-optimize.txt")',
            )
            if new == text:
                continue
            try:
                with open(gradle, "w", encoding="utf-8") as fh:
                    fh.write(new)
                replaced.append(name)
            except OSError as exc:
                log(f"!! 无法写入 {name}: {exc}")

    if replaced:
        for name in replaced:
            log(f"plugin: {name} proguard-android -> -optimize")
    else:
        log("plugin: 无需修补（可能尚未 pub get，或插件已自行修复）")


# ------------------------------------------------------------------ 桌面端


def patch_windows() -> None:
    """Windows: 保证 CMake 产物名与 Release 目录可预期。

    flutter build windows 默认就输出到 build/windows/x64/runner/Release，
    这里只是确认目录名符合 CI 打包脚本的预期（x64）。
    """
    cmake = os.path.join(ROOT, "windows", "CMakeLists.txt")
    if not os.path.isfile(cmake):
        log("skip windows (CMakeLists.txt not found)")
        return
    log("windows: 产物目录 build/windows/x64/runner/Release（默认，无需改动）")


def main() -> int:
    # 补丁是「锦上添花」：任何一步出错都不应该让构建挂掉。
    # 万一某个平台的目录结构和预期不同，宁可跳过也别中断流水线——
    # 否则排查时会被这个非致命错误误导，看不到真正的构建报错。
    for fn in (patch_android, patch_windows, patch_plugin_proguard):
        try:
            fn()
        except Exception as exc:  # noqa: BLE001
            log(f"!! {fn.__name__} 出错但已忽略：{exc}")
    log("done")
    return 0


if __name__ == "__main__":
    sys.exit(main())
