import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

configurations.all {
    // Moonlight has no screen-sharing / screen-cast feature. The Agora
    // `full-screen-sharing` artifact (pulled transitively by
    // agora_rtc_engine) ships a manifest declaring
    // FOREGROUND_SERVICE_MEDIA_PROJECTION plus a `mediaProjection`
    // service, which Google Play then flags as an undeclared foreground
    // service. Excluding it drops that permission (and the unused native
    // screen-capture libs). Re-add screen sharing here in the future by
    // removing this exclude and declaring the permission in Play Console.
    exclude(group = "io.agora.rtc", module = "full-screen-sharing")
}


// Load keystore properties
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("keystore.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.app.moonlightstream"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    signingConfigs {
        create("release") {
            storeFile = file("upload-keystore.jks")
            storePassword = System.getenv("KEYSTORE_PASSWORD") ?: keystoreProperties.getProperty("storePassword")
            keyAlias = System.getenv("KEY_ALIAS") ?: keystoreProperties.getProperty("keyAlias")
            keyPassword = System.getenv("KEY_PASSWORD") ?: keystoreProperties.getProperty("keyPassword")
        }

        // REMOVED: custom "debug" signingConfig that pointed at upload-keystore.jks.
        // That keystore is either missing or has a password mismatch on this
        // machine, which breaks every local debug build. Debug builds now use
        // Gradle's built-in debug config (auto-generates ~/.android/debug.keystore
        // if missing) — this is the standard, always-works setup for local dev.
        //
        // If you specifically need the release-keystore SHA fingerprint for
        // local testing (e.g. Google Sign-In, Play Billing sandbox), re-add:
        //
        // getByName("debug") {
        //     storeFile = file("upload-keystore.jks")
        //     storePassword = keystoreProperties.getProperty("storePassword", "")
        //     keyAlias = keystoreProperties.getProperty("keyAlias", "")
        //     keyPassword = keystoreProperties.getProperty("keyPassword", "")
        // }
        //
        // ...but only once the keystore file + password are verified working
        // via: keytool -list -v -keystore android/app/upload-keystore.jks
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

        getByName("debug") {
            isDebuggable = true
            // No signingConfig override — uses Gradle's built-in "debug" config.
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.app.moonlightstream"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
        multiDexEnabled = true

        manifestPlaceholders += mapOf(
            "appAuthRedirectScheme" to "com.app.moonlightstream",
            "applicationName" to "com.app.moonlightstream.MainApplication"
        )
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
    implementation("androidx.multidex:multidex:2.0.1")
    implementation("com.google.crypto.tink:tink-android:1.12.0")
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth")
    implementation("com.google.firebase:firebase-messaging")
    implementation("com.google.firebase:firebase-analytics")
    implementation("com.google.android.gms:play-services-auth:20.7.0")
    implementation("androidx.work:work-runtime:2.8.1")
    implementation("org.slf4j:slf4j-android:1.7.36")
}
