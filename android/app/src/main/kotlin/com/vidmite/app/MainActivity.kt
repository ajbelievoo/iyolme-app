package com.vidmite.app

import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelName = "com.vidmite.app/app_config"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getGoogleMapsApiKey" -> {
                        try {
                            val ai = packageManager.getApplicationInfo(packageName, PackageManager.GET_META_DATA)
                            val key = ai.metaData?.getString("com.google.android.geo.API_KEY")
                            result.success(key)
                        } catch (e: Exception) {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun shouldDestroyEngineWithHost(): Boolean {
        return false
    }
}
