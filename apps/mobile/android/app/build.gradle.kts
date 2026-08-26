plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

val releaseSigningValues = mapOf(
    "storeFile" to providers.environmentVariable("CAMPUS_ANDROID_KEYSTORE_PATH").orNull,
    "storePassword" to providers.environmentVariable("CAMPUS_ANDROID_KEYSTORE_PASSWORD").orNull,
    "keyAlias" to providers.environmentVariable("CAMPUS_ANDROID_KEY_ALIAS").orNull,
    "keyPassword" to providers.environmentVariable("CAMPUS_ANDROID_KEY_PASSWORD").orNull,
)
val releaseSigningConfigured = releaseSigningValues.values.all { !it.isNullOrBlank() }
val releaseSigningPartiallyConfigured = releaseSigningValues.values.any { !it.isNullOrBlank() }

if (releaseSigningPartiallyConfigured && !releaseSigningConfigured) {
    throw GradleException("Android release signing is only partially configured; set all CAMPUS_ANDROID_* signing variables.")
}

android {
    namespace = "dev.erikengler.campuskoethen"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // Voraussetzung von flutter_local_notifications ab Version 10: Das
        // Plugin nutzt java.time, damit geplante Benachrichtigungen auch auf
        // aelteren Android-Versionen zonenrichtig zugestellt werden. Ohne
        // Desugaring schlaegt bereits der Build fehl.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "dev.erikengler.campuskoethen"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (releaseSigningConfigured) {
            create("release") {
                val configuredStore = file(releaseSigningValues.getValue("storeFile")!!)
                if (!configuredStore.isFile) {
                    throw GradleException("The configured Android release keystore does not exist or is not a file.")
                }
                storeFile = configuredStore
                storePassword = releaseSigningValues.getValue("storePassword")
                keyAlias = releaseSigningValues.getValue("keyAlias")
                keyPassword = releaseSigningValues.getValue("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            // No in-repository fallback: without the four environment variables
            // Gradle emits an unsigned artefact, which cannot impersonate an
            // official release. The public debug key is never a release key.
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
