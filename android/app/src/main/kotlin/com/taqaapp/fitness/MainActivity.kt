package com.taqaapp.fitness

import android.content.Intent
import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import com.google.android.play.core.appupdate.AppUpdateManager
import com.google.android.play.core.appupdate.AppUpdateManagerFactory
import com.google.android.play.core.appupdate.AppUpdateOptions
import com.google.android.play.core.install.InstallStateUpdatedListener
import com.google.android.play.core.install.model.AppUpdateType
import com.google.android.play.core.install.model.InstallStatus
import com.google.android.play.core.install.model.UpdateAvailability
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

// Use FragmentActivity to satisfy plugins that expect a ComponentActivity/FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {

    private val instagramShareChannel = "instagram_share"
    private val playUpdateChannelName = "taqa/play_in_app_update"
    private lateinit var appUpdateManager: AppUpdateManager
    private var playUpdateChannel: MethodChannel? = null

    private val updateResultLauncher =
        registerForActivityResult(ActivityResultContracts.StartIntentSenderForResult()) { activityResult ->
            playUpdateChannel?.invokeMethod(
                "onUpdateFlowResult",
                mapOf("resultCode" to activityResult.resultCode),
            )
        }

    private val updateInstallListener = InstallStateUpdatedListener { state ->
        playUpdateChannel?.invokeMethod(
            "onInstallStateChanged",
            mapOf(
                "status" to installStatusName(state.installStatus()),
                "bytesDownloaded" to state.bytesDownloaded(),
                "totalBytesToDownload" to state.totalBytesToDownload(),
                "installErrorCode" to state.installErrorCode(),
            ),
        )
    }

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
        appUpdateManager = AppUpdateManagerFactory.create(this)
        appUpdateManager.registerListener(updateInstallListener)
        applyNavigationBarColor()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        playUpdateChannel =
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, playUpdateChannelName).apply {
                setMethodCallHandler { call, result ->
                    when (call.method) {
                        "checkForUpdate" -> checkForPlayUpdate(result)
                        "startFlexibleUpdate" -> startFlexibleUpdate(result)
                        "completeFlexibleUpdate" -> completeFlexibleUpdate(result)
                        else -> result.notImplemented()
                    }
                }
            }
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

    private fun checkForPlayUpdate(result: MethodChannel.Result) {
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                result.success(
                    mapOf(
                        "available" to
                            (info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE),
                        "flexibleAllowed" to info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE),
                        "availableVersionCode" to info.availableVersionCode(),
                        "stalenessDays" to info.clientVersionStalenessDays(),
                        "priority" to info.updatePriority(),
                        "installStatus" to installStatusName(info.installStatus()),
                    ),
                )
            }
            .addOnFailureListener { error ->
                result.error("update_check_failed", error.message, null)
            }
    }

    private fun startFlexibleUpdate(result: MethodChannel.Result) {
        appUpdateManager.appUpdateInfo
            .addOnSuccessListener { info ->
                val available =
                    info.updateAvailability() == UpdateAvailability.UPDATE_AVAILABLE
                if (!available || !info.isUpdateTypeAllowed(AppUpdateType.FLEXIBLE)) {
                    result.success(false)
                    return@addOnSuccessListener
                }
                try {
                    val started =
                        appUpdateManager.startUpdateFlowForResult(
                            info,
                            updateResultLauncher,
                            AppUpdateOptions.newBuilder(AppUpdateType.FLEXIBLE).build(),
                        )
                    result.success(started)
                } catch (error: Exception) {
                    result.error("update_start_failed", error.message, null)
                }
            }
            .addOnFailureListener { error ->
                result.error("update_check_failed", error.message, null)
            }
    }

    private fun completeFlexibleUpdate(result: MethodChannel.Result) {
        appUpdateManager.completeUpdate()
            .addOnSuccessListener { result.success(true) }
            .addOnFailureListener { error ->
                result.error("update_install_failed", error.message, null)
            }
    }

    private fun notifyIfUpdateDownloaded() {
        if (!::appUpdateManager.isInitialized) return
        appUpdateManager.appUpdateInfo.addOnSuccessListener { info ->
            if (info.installStatus() == InstallStatus.DOWNLOADED) {
                playUpdateChannel?.invokeMethod(
                    "onInstallStateChanged",
                    mapOf("status" to "downloaded"),
                )
            }
        }
    }

    private fun installStatusName(status: Int): String =
        when (status) {
            InstallStatus.PENDING -> "pending"
            InstallStatus.DOWNLOADING -> "downloading"
            InstallStatus.DOWNLOADED -> "downloaded"
            InstallStatus.INSTALLING -> "installing"
            InstallStatus.INSTALLED -> "installed"
            InstallStatus.FAILED -> "failed"
            InstallStatus.CANCELED -> "canceled"
            else -> "unknown"
        }

    // Samsung OneUI can reset the bar color when the activity resumes (e.g.
    // after dark-mode or nav-mode changes); re-apply to be safe.
    override fun onPostResume() {
        super.onPostResume()
        applyNavigationBarColor()
        notifyIfUpdateDownloaded()
    }

    override fun onDestroy() {
        if (::appUpdateManager.isInitialized) {
            appUpdateManager.unregisterListener(updateInstallListener)
        }
        playUpdateChannel?.setMethodCallHandler(null)
        playUpdateChannel = null
        super.onDestroy()
    }
}
