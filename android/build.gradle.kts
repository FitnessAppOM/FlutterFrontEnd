plugins {
    // Firebase plugin for all subprojects
    id("com.google.gms.google-services") version "4.4.4" apply false
}

fun manifestPackage(manifestFile: File): String? {
    if (!manifestFile.exists()) return null
    val match = Regex("""package\s*=\s*"([^"]+)"""").find(manifestFile.readText())
    return match?.groupValues?.getOrNull(1)?.trim()?.takeIf { it.isNotEmpty() }
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
    plugins.withId("com.android.library") {
        val androidExt = extensions.findByName("android") ?: return@withId
        val getNamespace = androidExt.javaClass.methods.firstOrNull {
            it.name == "getNamespace" && it.parameterCount == 0
        } ?: return@withId
        val currentNamespace = getNamespace.invoke(androidExt) as? String
        if (!currentNamespace.isNullOrBlank()) return@withId

        val ns = manifestPackage(file("src/main/AndroidManifest.xml"))
            ?: "com.taqa.autons.${project.name.replace('-', '_')}"

        val setNamespace = androidExt.javaClass.methods.firstOrNull {
            it.name == "setNamespace" && it.parameterCount == 1
        } ?: return@withId

        setNamespace.invoke(androidExt, ns)
    }
}

subprojects {
    if (name != "image_gallery_saver") return@subprojects
    plugins.withId("org.jetbrains.kotlin.android") {
        tasks.configureEach {
            if (!name.contains("Kotlin", ignoreCase = true)) return@configureEach
            val options = javaClass.methods.firstOrNull {
                it.name == "getKotlinOptions" && it.parameterCount == 0
            }?.invoke(this) ?: return@configureEach
            options.javaClass.methods.firstOrNull {
                it.name == "setJvmTarget" && it.parameterCount == 1
            }?.invoke(options, "1.8")
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
