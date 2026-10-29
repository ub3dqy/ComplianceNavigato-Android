val minimumJava = rootProject.file("../.java-version").readText().trim()
val minimumUpdate = Regex("^17\\.0\\.([1-9][0-9]*)$").matchEntire(minimumJava)
    ?.groupValues?.get(1)?.toInt() ?: error("Invalid project Java minimum")
val runtimeJava = Runtime.version()
check(runtimeJava.feature() == 17 && runtimeJava.interim() == 0 && runtimeJava.update() >= minimumUpdate) {
    "JDK 17 >= $minimumJava is required; actual runtime is $runtimeJava. Use docs/development.md."
}
println("PROJECT_JAVA_QUALIFIED runtime=$runtimeJava minimum=$minimumJava")

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
