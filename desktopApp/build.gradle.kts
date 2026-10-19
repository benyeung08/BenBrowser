import org.gradle.nativeplatform.platform.internal.DefaultNativePlatform

plugins {
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    kotlin("multiplatform")
}

// 判断当前构建平台（在配置阶段就确定，用于条件判断）
val isMac: Boolean = DefaultNativePlatform.getCurrentOperatingSystem().isMacOsX
val isWindows: Boolean = DefaultNativePlatform.getCurrentOperatingSystem().isWindows

kotlin {
    jvm("desktop") {
        compilations.all {
            kotlinOptions.jvmTarget = "17"
        }
    }
    sourceSets {
        desktopMain.dependencies {
            implementation(project(":shared"))
            implementation(compose.desktop.currentOs)
            implementation(libs.kcef)
        }
    }
}

compose.desktop {
    application {
        mainClass = "com.example.browser.MainKt"

        nativeDistributions {
            targetFormats(
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Exe,
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Dmg,
                org.jetbrains.compose.desktop.application.dsl.TargetFormat.Msi
            )
            packageName = "BrowserApp"
            packageVersion = "1.0.0"
            description = "跨平台 Chromium 浏览器 (Android / Windows / macOS)"
            copyright = "Copyright © 2025 BrowserApp"

            windows {
                menu = true
                menuGroup = "BrowserApp"
                // upgradeUuid 必须全局唯一，发布新版本时保持不变
                upgradeUuid = "b1a2c3d4-e5f6-7890-abcd-ef1234567890"
            }
            macOS {
                bundleID = "com.example.browser"
                // ⚠️ 不能用 null！删掉这一行，或者换成真实存在的 .icns 路径
                // iconFile = file("src/desktopMain/resources/icon.icns")
                minimumVersion = "11.0"
            }
        }

        // KCEF 在 macOS 上需要额外 JVM flags 才能正常运行
        // 这些 flags 仅对 `run` task 生效；packageDmg 走的是 jpackage，
        // 所以还需要在启动脚本/launcher 里注入（见下方 appResources）
        if (isMac) {
            applicationDefaultJvmArgs = listOf(
                "--add-opens", "java.desktop/sun.awt=ALL-UNNAMED",
                "--add-opens", "java.desktop/java.awt.peer=ALL-UNNAMED",
                "--add-opens", "java.desktop/sun.lwawt=ALL-UNNAMED",
                "--add-opens", "java.desktop/sun.lwawt.macosx=ALL-UNNAMED"
            )
        }
    }
}

// 让 KCEF 的 Chromium runtime 能被 jpackage 正确打包进 .app / .exe
// 避免运行打包后的产物出现 "chromium not found"
tasks.withType<org.jetbrains.compose.desktop.tasks.AbstractComposeDesktopPackageTask> {
    if (name.contains("package", ignoreCase = true)) {
        // 给打包后的启动器注入 KCEF 需要的 JVM 参数
        doFirst {
            if (isMac) {
                // 通过环境变量传递给 launcher
                environment("KCEF_ADDITIONAL_JVM_ARGS",
                    "--add-opens java.desktop/sun.awt=ALL-UNNAMED " +
                    "--add-opens java.desktop/java.awt.peer=ALL-UNNAMED"
                )
            }
        }
    }
}
