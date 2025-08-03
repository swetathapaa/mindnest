plugins {
    // Declare Android application plugin but don't apply it here (apply false)
    id("com.android.application") version "8.7.3" apply false
    // Declare Kotlin Android plugin, don't apply here (apply false)
    kotlin("android") version "2.1.0" apply false
    id("com.google.gms.google-services") version "4.3.15" apply false

}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Custom build directory logic you already have:
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
