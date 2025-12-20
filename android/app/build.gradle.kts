plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // REQUIRED for Firebase Messaging & google-services.json
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.taqaproject"

    // REQUIRED by modern plugins
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "17"
    }

    defaultConfig {
        applicationId = "com.example.taqaproject"

        // REQUIRED by health, identity, permissions, geolocator
        minSdk = 26

        // Google Play 2024 requirement
        targetSdk = 34

        versionCode = 1
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Google authentication
    implementation("com.google.android.gms:play-services-auth:20.7.0")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")

    // AndroidX Credentials API (new Google Identity)
    implementation("androidx.credentials:credentials:1.2.2")
    implementation("androidx.credentials:credentials-play-services-auth:1.2.2")

    // New Google Identity Services
    implementation("com.google.android.libraries.identity.googleid:googleid:1.0.0")
}
