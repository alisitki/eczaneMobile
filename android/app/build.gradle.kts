plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.eczanepanosu.app.eczane_panosu"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Java 8 obsolete warning'lerini sustur
    tasks.withType<JavaCompile> {
        options.compilerArgs.add("-Xlint:-options")
    }

    tasks.withType<JavaCompile>().configureEach {
        options.compilerArgs.add("-Xlint:-options")
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.eczanepanosu.app.eczane_panosu"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    packaging {
        jniLibs {
            pickFirsts += listOf("**/libc++_shared.so", "**/libjsc.so")
        }
    }
    
    buildFeatures {
        buildConfig = false
    }
    
    lint {
        checkReleaseBuilds = false
        abortOnError = false
        disable.add("NotificationPermission")
        disable.add("ObsoleteSdkInt")
    }
}

flutter {
    source = "../.."
}
