allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Legacy Flutter plugins in the Agora dependency graph still default to API
// 31. The app already compiles against API 36; expose that existing SDK to
// those plugins so their AndroidX metadata can be checked consistently.
extra["compileSdkVersion"] = 36

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
