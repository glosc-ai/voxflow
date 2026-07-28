plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

fun signingInput(name: String): String? = providers.gradleProperty(name)
    .orElse(providers.environmentVariable(name))
    .orNull
    ?.trim()
    ?.takeIf { it.isNotEmpty() }

val releaseStorePath = signingInput("VOXFLOW_ANDROID_KEYSTORE_PATH")
val releaseStorePassword = signingInput("VOXFLOW_ANDROID_KEYSTORE_PASSWORD")
val releaseKeyAlias = signingInput("VOXFLOW_ANDROID_KEY_ALIAS")
val releaseKeyPassword = signingInput("VOXFLOW_ANDROID_KEY_PASSWORD")
val releaseSigningConfigured = listOf(
    releaseStorePath,
    releaseStorePassword,
    releaseKeyAlias,
    releaseKeyPassword,
).all { it != null }

android {
    namespace = "ai.glosc.voxflow"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "ai.glosc.voxflow"
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
                storeFile = file(releaseStorePath!!)
                storePassword = releaseStorePassword
                keyAlias = releaseKeyAlias
                keyPassword = releaseKeyPassword
            }
        }
    }

    buildTypes {
        release {
            if (releaseSigningConfigured) {
                signingConfig = signingConfigs.getByName("release")
            }
        }
    }
}

gradle.taskGraph.whenReady {
    val releaseArtifactRequested = allTasks.any {
        it.name.contains("release", ignoreCase = true) &&
            (it.name.startsWith("assemble", ignoreCase = true) ||
                it.name.startsWith("bundle", ignoreCase = true) ||
                it.name.startsWith("package", ignoreCase = true) ||
                it.name.startsWith("validateSigning", ignoreCase = true))
    }
    if (releaseArtifactRequested && !releaseSigningConfigured) {
        throw GradleException(
            "Android Release signing requires " +
                "VOXFLOW_ANDROID_KEYSTORE_PATH, " +
                "VOXFLOW_ANDROID_KEYSTORE_PASSWORD, " +
                "VOXFLOW_ANDROID_KEY_ALIAS, and " +
                "VOXFLOW_ANDROID_KEY_PASSWORD.",
        )
    }
    if (releaseArtifactRequested && !file(releaseStorePath!!).isFile) {
        throw GradleException(
            "VOXFLOW_ANDROID_KEYSTORE_PATH does not point to a readable file.",
        )
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
