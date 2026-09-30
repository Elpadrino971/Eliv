package com.app.vybzz

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    // Canal 'vybzzz/screen' (voir lib/Global/screen_guard.dart) : pendant un
    // concert, FLAG_SECURE rend les captures et enregistrements d'écran
    // noirs, et masque l'aperçu de l'app dans le sélecteur d'apps.
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "vybzzz/screen")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "secure" -> {
                        val on = call.argument<Boolean>("on") == true
                        runOnUiThread {
                            if (on) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
