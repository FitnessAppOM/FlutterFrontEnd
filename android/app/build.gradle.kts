plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")  // Ensure this is properly set up
}

android {
    namespace = "com.example.taqaproject"
    compileSdk = flutter.compileSdkVersion  // Ensure this points to the correct Flutter SDK version
    ndkVersion = flutter.ndkVersion  // Ensure this points to the correct NDK version

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = "17"  // Set jvmTarget as a string
    }

    defaultConfig {
        applicationId = "com.example.taqaproject"
        minSdk = 31  // Use property for minSdk
        targetSdk = 31  // Use property for targetSdk
        versionCode = 1  // You can replace this with flutter.versionCode if properly configured
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")  // Ensure the signing config is correct
        }
    }
}

flutter {
    source = "../.."  // Make sure this path points to the correct location in your Flutter project
}
