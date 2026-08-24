group = "com.app.moonlightstream.ringtone_native"
version = "1.0-SNAPSHOT"

// Deliberately no buildscript{} block pinning its own AGP/Kotlin versions
// here — this module is built as part of the main app's multi-project
// Gradle build (see android/settings.gradle.kts), which already resolves
// com.android.library and org.jetbrains.kotlin.android via its own
// pluginManagement. Declaring different versions here (the flutter create
// scaffold defaults to newer ones than the main app uses) risks a version
// conflict rather than actually doing anything useful.

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
}

android {
    namespace = "com.app.moonlightstream.ringtone_native"

    compileSdk = 36

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    sourceSets {
        getByName("main") {
            java.srcDirs("src/main/kotlin")
        }
    }

    defaultConfig {
        minSdk = 21
    }
}
