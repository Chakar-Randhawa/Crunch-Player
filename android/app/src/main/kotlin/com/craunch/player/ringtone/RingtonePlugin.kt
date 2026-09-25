package com.craunch.player.ringtone

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class RingtonePlugin : FlutterPlugin, MethodCallHandler {

    private var channel: MethodChannel? = null
    private var context: android.content.Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.craunch.player/ringtone")
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        context = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val ctx = context ?: return result.error("NO_CONTEXT", "Plugin not attached", null)
        val setter = RingtoneSetter(ctx)

        when (call.method) {
            "canWriteSystemSettings" -> result.success(setter.canWriteSystemSettings())

            "openWriteSettingsPermissionScreen" -> {
                setter.openWriteSettingsPermissionScreen()
                result.success(null)
            }

            "setAsRingtone" -> {
                val path = call.argument<String>("sourceFilePath")
                    ?: return result.error("BAD_ARGS", "sourceFilePath is required", null)
                val displayName = call.argument<String>("displayName")
                    ?: return result.error("BAD_ARGS", "displayName is required", null)
                try {
                    val uri = setter.setAsRingtone(path, displayName)
                    result.success(mapOf("uri" to uri.toString(), "autoApplied" to setter.canWriteSystemSettings()))
                } catch (e: Exception) {
                    result.error("RINGTONE_ERROR", e.message, null)
                }
            }

            else -> result.notImplemented()
        }
    }
}
