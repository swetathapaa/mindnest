plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.mindnest"
    compileSdk = 35
    ndkVersion = "27.0.12077973"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // Make sure this matches what you register in Firebase console.
        applicationId = "com.example.mindnest"
        minSdk = 23
        targetSdk = 35
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // You should add a proper signing config for production.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

apply(plugin = "com.google.gms.google-services")

dependencies {
    coreLibraryDesugaring ("com.android.tools:desugar_jdk_libs:2.1.4")
    implementation(platform("com.google.firebase:firebase-bom:33.16.0"))

    // Firebase core analytics (optional)
    implementation("com.google.firebase:firebase-analytics")

    // Authentication
    implementation("com.google.firebase:firebase-auth")

    // Firestore (user profiles and other structured data)
    implementation("com.google.firebase:firebase-firestore")

    // If you still need Realtime Database as well, uncomment:
    // implementation("com.google.firebase:firebase-database")
}
