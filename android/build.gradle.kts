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
subprojects {
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByType(com.android.build.gradle.LibraryExtension::class.java)
        if (androidExt != null && androidExt.namespace == null) {
            androidExt.namespace = project.group.toString()
        }
        // After the library's own build.gradle runs and sets compileOptions, align
        // the Kotlin JVM target to match so AGP's consistency check passes.
        afterEvaluate {
            val javaTarget = extensions
                .findByType(com.android.build.gradle.LibraryExtension::class.java)
                ?.compileOptions?.targetCompatibility?.toString()
            if (javaTarget != null) {
                tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                    compilerOptions {
                        jvmTarget.set(
                            org.jetbrains.kotlin.gradle.dsl.JvmTarget.fromTarget(javaTarget)
                        )
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
