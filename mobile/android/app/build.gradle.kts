import java.util.Properties

plugins {
    id("com.android.application")
    id("dev.flutter.flutter-gradle-plugin")
}

val signingPropertiesPath = providers.gradleProperty("COMPLIANCE_SIGNING_PROPERTIES").orNull
val signingProperties = Properties()
val hasPilotSigning = signingPropertiesPath != null && file(signingPropertiesPath).isFile
if (hasPilotSigning) {
    file(signingPropertiesPath!!).inputStream().use { signingProperties.load(it) }
}

android {
    namespace = "ru.ms777.compliancenavigator"
    compileSdk = 36
    buildToolsVersion = "36.1.0"
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "ru.ms777.compliancenavigator"
        minSdk = 26
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }

    flavorDimensions += "environment"
    productFlavors {
        create("staging") {
            dimension = "environment"
            applicationIdSuffix = ".staging"
            versionNameSuffix = "-pilot"
        }
    }

    signingConfigs {
        if (hasPilotSigning) {
            create("pilot") {
                storeFile = file(signingProperties.getProperty("storeFile"))
                storePassword = signingProperties.getProperty("storePassword")
                keyAlias = signingProperties.getProperty("keyAlias")
                keyPassword = signingProperties.getProperty("keyPassword")
                enableV1Signing = true
                enableV2Signing = true
                enableV3Signing = true
                enableV4Signing = true
            }
        }
    }

    buildTypes {
        release {
            isDebuggable = false
            isJniDebuggable = false
            isMinifyEnabled = true
            isShrinkResources = true
            signingConfig = if (hasPilotSigning) signingConfigs.getByName("pilot") else null
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }

    lint {
        abortOnError = true
        checkReleaseBuilds = true
        htmlReport = true
        xmlReport = true
        // AGP lint normalizes the ignored Windows local.properties SDK path before
        // PropertyEscape inspects it. docs/development.md validates the
        // original file and keeps every other lint issue blocking.
        disable += "PropertyEscape"
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

tasks.configureEach {
    if (name.contains("Release", ignoreCase = true)) {
        doFirst {
            require(hasPilotSigning) {
                "Release signing is required. Use docs/development.md."
            }
        }
    }
}
