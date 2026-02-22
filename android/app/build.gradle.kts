plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")

    // REQUIRED for Firebase Messaging & google-services.json
    id("com.google.gms.google-services")
}

fun loadDotEnv(rootDir: File): Map<String, String> {
    val envFile = File(rootDir, ".env")
    if (!envFile.exists()) return emptyMap()

    val map = mutableMapOf<String, String>()
    envFile.forEachLine { rawLine ->
        val line = rawLine.trim()
        if (line.isEmpty() || line.startsWith("#")) return@forEachLine
        val idx = line.indexOf("=")
        if (idx <= 0) return@forEachLine
        val key = line.substring(0, idx).trim()
        var value = line.substring(idx + 1).trim()
        if ((value.startsWith("\"") && value.endsWith("\"")) ||
            (value.startsWith("'") && value.endsWith("'"))
        ) {
            value = value.substring(1, value.length - 1)
        }
        map[key] = value
    }
    return map
}

val dotEnv = loadDotEnv(rootProject.projectDir)
val mapboxToken =
    (dotEnv["MAPBOX_PUBLIC_KEY"] ?: System.getenv("MAPBOX_PUBLIC_KEY") ?: "").trim()

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

        // Mapbox access token from .env
        manifestPlaceholders["MAPBOX_ACCESS_TOKEN"] = mapboxToken
        resValue("string", "mapbox_access_token", mapboxToken)
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
