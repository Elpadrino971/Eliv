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

// Certains plugins pub.dev (receive_sharing_intent, ...) compilent leur Java en 1.8
// sans fixer la cible Kotlin, qui suit alors le JDK installé (21) : Gradle refuse
// l'écart ("Inconsistent JVM-target compatibility"). On aligne tout le monde sur 17,
// comme :app.
subprojects {
    val alignJvm: Project.() -> Unit = {
        extensions.findByType<com.android.build.gradle.LibraryExtension>()?.compileOptions {
            sourceCompatibility = JavaVersion.VERSION_17
            targetCompatibility = JavaVersion.VERSION_17
        }
        tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
            compilerOptions.jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
        }
    }
    // :app est déjà évalué à ce stade (evaluationDependsOn ci-dessus) : on applique
    // directement ; pour les plugins, on attend la fin de leur évaluation.
    if (state.executed) alignJvm() else afterEvaluate { alignJvm() }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
