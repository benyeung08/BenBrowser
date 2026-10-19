plugins {
    alias(libs.plugins.composeMultiplatform)
    alias(libs.plugins.composeCompiler)
    kotlin("multiplatform") version libs.versions.kotlin.get() apply false
}

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
                upgradeUuid = "b1a2c3d4-e5f6-7890-abcd-ef1234567890"
            }
            macOS {
                bundleID = "com.example.browser"
                iconFile = null // 可自行添加 .icns 图标
                minimumSystemVersion = "12.0"
            }
        }

        // KCEF 在 macOS 需要额外 JVM flags
        afterEvaluate {
            tasks.withType<JavaExec> {
                if (System.getProperty("os.name").contains("Mac", ignoreCase = true)) {
                    jvmArgs("--add-opens", "java.desktop/sun.awt=ALL-UNNAMED")
                    jvmArgs("--add-opens", "java.desktop/java.awt.peer=ALL-UNNAMED")
                    jvmArgs("--add-opens", "java.desktop/sun.lwawt=ALL-UNNAMED")
                    jvmArgs("--add-opens", "java.desktop/sun.lwawt.macosx=ALL-UNNAMED")
                }
            }
        }
    }
}
