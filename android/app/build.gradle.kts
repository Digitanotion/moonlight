plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.moonlight"
    compileSdk = flutter.compileSdkVersion.toInt()
    ndkVersion = "27.0.12077973" // Force NDK version for flutter_secure_storage

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.moonlight"
        minSdk = flutter.minSdkVersion.toInt()
        targetSdk = flutter.targetSdkVersion.toInt()
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // Enable code shrinking
            isMinifyEnabled = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro" // Your custom rules
            )
            signingConfig = signingConfigs.getByName("debug") // Replace with release config later
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Critical for R8
    implementation("com.google.errorprone:error_prone_annotations:2.23.0") 
    implementation("com.google.code.findbugs:jsr305:3.0.2")
    
    // Kotlin and Flutter
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:${kotlin_version}")
    
    // Explicit Tink version (security)
    implementation("com.google.crypto.tink:tink-android:1.12.0") {
        because("Required by flutter_secure_storage")
    }
}