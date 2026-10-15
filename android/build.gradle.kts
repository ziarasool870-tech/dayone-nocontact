buildscript {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
    dependencies {
        // Matches the KGP version in settings.gradle.kts; puts the Kotlin DSL
        // types on this script's classpath so plugin modules can be configured.
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:2.4.0")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force JVM target 11 on every Kotlin AND Java compile task of plugin modules
// (e.g. home_widget 0.8.1 hardcodes kotlinOptions.jvmTarget="1.8" in its own
// build.gradle while inlining JVM-11 bytecode, which fails release builds).
// Configured in afterEvaluate (registered via withPlugin, so no "already
// evaluated" ordering problem): this runs AFTER the module's own script and
// after AGP's internal wiring, so it beats both. Both languages must move
// together — the toolchain rejects mixed 1.8/11 modules.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        afterEvaluate {
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
                }
            }
            tasks.withType<JavaCompile>().configureEach {
                sourceCompatibility = "11"
                targetCompatibility = "11"
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
