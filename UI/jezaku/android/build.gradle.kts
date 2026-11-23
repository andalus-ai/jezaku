allprojects {
    repositories {
        google()
        maven { url = uri("https://repo1.maven.org/maven2/") }
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

subprojects {
    val configureCommon: Project.() -> Unit = {
        extensions.findByType(com.android.build.api.dsl.CommonExtension::class.java)?.let { ext ->
            if ((ext.compileSdk ?: 0) < 34) {
                ext.compileSdk = 35
            }
        }
    }
    if (state.executed) {
        configureCommon()
    } else {
        afterEvaluate {
            configureCommon()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
