package com.taqaapp.fitness

import android.graphics.Color
import android.os.Build
import android.os.Bundle
import android.view.View
import io.flutter.embedding.android.FlutterFragmentActivity

// Use FragmentActivity to satisfy plugins that expect a ComponentActivity/FragmentActivity host.
class MainActivity : FlutterFragmentActivity() {

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

    // Samsung OneUI can reset the bar color when the activity resumes (e.g.
    // after dark-mode or nav-mode changes); re-apply to be safe.
    override fun onPostResume() {
        super.onPostResume()
        applyNavigationBarColor()
    }
}
