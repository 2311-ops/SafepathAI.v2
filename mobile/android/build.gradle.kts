// Google Services (Firebase) Gradle plugin — version declared here (root
// project) with apply false; mobile/android/app/build.gradle.kts applies it
// without a version. Required for FCM (03-06); resolved via the google()
// repository already declared in settings.gradle.kts's pluginManagement
// block. Applying this plugin requires google-services.json to be present
// at build time (mobile/android/app/) — absent that file, `flutter build
// apk` fails while `flutter test`/`flutter analyze` are unaffected (they
// never invoke the native Android Gradle build).
plugins {
    id("com.google.gms.google-services") version "4.4.4" apply false
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
