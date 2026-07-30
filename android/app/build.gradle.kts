import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Load the upload-signing credentials from android/key.properties (gitignored).
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}


// Refuse to produce a release APK/AAB whose backend is wrong.
//
// The app reports this at runtime too, but only in a log — by then the artifact
// exists and may already be on a phone. Failing the BUILD is the only check a
// hurried release cannot skip.
//
// Runs on release variants only, so debug builds against a laptop still work.
val checkReleaseConfig = tasks.register<Exec>("checkReleaseConfig") {
    workingDir = rootProject.projectDir.parentFile          // the Flutter project root

    // `dart` is not on Gradle's PATH on a normal machine, so resolve it from
    // the Flutter SDK the build is already using rather than assuming the
    // developer's shell environment.
    val flutterSdk = Properties().apply {
        rootProject.file("local.properties").inputStream().use { load(it) }
    }.getProperty("flutter.sdk")
    val isWindows = System.getProperty("os.name").startsWith("Windows", ignoreCase = true)
    val dart = if (flutterSdk != null) {
        File(flutterSdk, if (isWindows) "bin/dart.bat" else "bin/dart").absolutePath
    } else {
        if (isWindows) "dart.bat" else "dart"
    }

    commandLine(dart, "run", "tool/check_release_config.dart")
    // The script prints the reason and exits 1; let that surface verbatim
    // rather than burying it in a Gradle stacktrace.
    isIgnoreExitValue = false
}

tasks.matching { it.name.matches(Regex("(assemble|bundle)Release")) }.configureEach {
    dependsOn(checkReleaseConfig)
}

android {
    namespace = "com.intellicash.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.intellicash.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            if (keystorePropertiesFile.exists()) {
                keyAlias = keystoreProperties["keyAlias"] as String?
                keyPassword = keystoreProperties["keyPassword"] as String?
                storeFile = (keystoreProperties["storeFile"] as String?)?.let { file(it) }
                storePassword = keystoreProperties["storePassword"] as String?
            }
        }
    }

    buildTypes {
        release {
            // Real upload signing when key.properties is present; otherwise
            // fall back to debug keys so `flutter run --release` still works
            // on a machine without the keystore.
            signingConfig = if (keystorePropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

flutter {
    source = "../.."
}
