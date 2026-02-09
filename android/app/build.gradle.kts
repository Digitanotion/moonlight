plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    // END: FlutterFire Configuration
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// Get the kotlinVersion from root project
val kotlinVersion = "1.9.22"

android {
    namespace = "com.app.moonlightstream"
    compileSdk = 36
    ndkVersion = "27.0.12077973" //flutter.ndkVersion

    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
            keyAlias = System.getenv("KEY_ALIAS") ?: ""
            keyPassword = System.getenv("KEY_PASSWORD") ?: ""
        }
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Enable core library desugaring - CORRECT SYNTAX
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.app.moonlightstream"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        // Enable multiDex - CORRECT SYNTAX
        multiDexEnabled = true
        
        // FIXED: Correct Kotlin DSL syntax for manifestPlaceholders
        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "com.app.moonlightstream"
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ========== CORE LIBRARY DESUGARING ==========
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    
    // ========== MULTIDEX SUPPORT ==========
    implementation("androidx.multidex:multidex:2.0.1")
    
    // ========== KOTLIN ==========
    implementation("org.jetbrains.kotlin:kotlin-stdlib-jdk7:$kotlinVersion")
    
    // ========== FIREBASE ==========
    implementation("com.google.crypto.tink:tink-android:1.12.0")
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    
    // ========== WORK MANAGER ==========
    implementation("androidx.work:work-runtime:2.8.1")
    
    // ========== LOGGING ==========
    implementation("org.slf4j:slf4j-android:1.7.36")
}