package com.taqaapp.fitness

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Use FragmentActivity to satisfy plugins that expect a ComponentActivity/FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {

    private val instagramShareChannel = "instagram_share"

    // Flutter's SystemUiOverlayStyle.light/.dark constants hardcode the system
    // navigation bar color to black and re-apply it on frame changes, so a
    // white bar set from Dart does not stick (only the divider obeyed). Setting
    // it natively on the window keeps the bar solid white to match
    // TaqaBottomNavBar, and survives Flutter's overlay-style cycle.
    private fun applyNavigationBarColor() {
        window.navigationBarColor = Color.WHITE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            // Dark icons on the white bar so back/home/recents stay visible.
            window.decorView.systemUiVisibility =
                window.decorView.systemUiVisibility or
                View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Stop the OS drawing its own translucent contrast scrim over white.
            window.isNavigationBarContrastEnforced = false
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyNavigationBarColor()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, instagramShareChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "shareSticker") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }

                val image = call.argument<ByteArray>("image")
                if (image == null || image.isEmpty()) {
                    result.error("bad_image", "Missing image bytes", null)
                    return@setMethodCallHandler
                }

                try {
                    val directory = File(cacheDir, "instagram_share").apply { mkdirs() }
                    val imageFile = File(directory, "story_sticker.png")
                    imageFile.outputStream().use { it.write(image) }
                    val imageUri = FileProvider.getUriForFile(
                        this,
                        "$packageName.fileprovider",
                        imageFile,
                    )
                    val sourceApplication =
                        call.argument<String>("appId")?.trim().takeUnless { it.isNullOrEmpty() }
                            ?: packageName
                    val intent = Intent("com.instagram.share.ADD_TO_STORY").apply {
                        setDataAndType(imageUri, "image/png")
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        putExtra("source_application", sourceApplication)
                    }
                    if (intent.resolveActivity(packageManager) == null) {
                        result.error("unavailable", "Instagram not available", null)
                        return@setMethodCallHandler
                    }
                    startActivity(intent)
                    result.success(true)
                } catch (error: Exception) {
                    result.error("open_failed", "Failed to open Instagram", error.message)
                }
            }
    }

    // Samsung OneUI can reset the bar color when the activity resumes (e.g.
    // after dark-mode or nav-mode changes); re-apply to be safe.
    override fun onPostResume() {
        super.onPostResume()
        applyNavigationBarColor()
    }
}
