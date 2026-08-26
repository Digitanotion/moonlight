buildscript {
    val kotlin_version = "1.9.22"  // Use simple variable assignment

    repositories {
        google()
        mavenCentral()
    }

    dependencies {
        classpath("com.android.tools.build:gradle:8.3.0")
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")  // Remove the extra braces
        classpath("com.google.gms:google-services:4.4.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Targets ONLY the screen_protector module — the one new dependency
// added today that actually needs a forced Kotlin target (it defaults
// to whatever JDK is active on the build machine, 21, conflicting with
// the app's own 17). Deliberately NOT applied project-wide — an earlier
// version of this fix forced Kotlin to 17 for every subproject, which
// broke previously-working plugins (file_picker, flutter_callkit_incoming)
// that hardcode their own Java side at 1.8 and had never needed any
// override before.
project(":screen_protector") {
    afterEvaluate {
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
