package com.craunch.player.overlay

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class CraunchOverlayPlugin : FlutterPlugin, ActivityAware, MethodCallHandler {

    private var channel: MethodChannel? = null
    private var appContext: Context? = null
    private var activityContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        appContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityContext = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activityContext = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activityContext = binding.activity
    }

    override fun onDetachedFromActivity() {
        activityContext = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val context = appContext ?: return result.error("NO_CONTEXT", "Plugin not attached", null)

        when (call.method) {
            "hasPermission" -> {
                val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    Settings.canDrawOverlays(context)
                } else {
                    true // pre-Marshmallow: granted at install time via the manifest permission alone
                }
                result.success(granted)
            }

            "openPermissionSettings" -> {
                val target = activityContext ?: context
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}"),
                ).apply {
                    if (target !is android.app.Activity) addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                target.startActivity(intent)
                result.success(null)
            }

            "start" -> {
                val primary = call.argument<Long>("primaryColorArgb")?.toInt()
                    ?: return result.error("BAD_ARGS", "primaryColorArgb is required", null)
                val secondary = call.argument<Long>("secondaryColorArgb")?.toInt()
                    ?: return result.error("BAD_ARGS", "secondaryColorArgb is required", null)

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M && !Settings.canDrawOverlays(context)) {
                    return result.error(
                        "PERMISSION_DENIED",
                        "SYSTEM_ALERT_WINDOW not granted — call openPermissionSettings first",
                        null,
                    )
                }

                val intent = Intent(context, EdgeOverlayService::class.java).apply {
                    action = EdgeOverlayService.ACTION_START
                    putExtra(EdgeOverlayService.EXTRA_PRIMARY_COLOR, primary)
                    putExtra(EdgeOverlayService.EXTRA_SECONDARY_COLOR, secondary)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(intent)
                } else {
                    context.startService(intent)
                }
                result.success(null)
            }

            "updateColors" -> {
                val primary = call.argument<Long>("primaryColorArgb")?.toInt()
                    ?: return result.error("BAD_ARGS", "primaryColorArgb is required", null)
                val secondary = call.argument<Long>("secondaryColorArgb")?.toInt()
                    ?: return result.error("BAD_ARGS", "secondaryColorArgb is required", null)

                val intent = Intent(context, EdgeOverlayService::class.java).apply {
                    action = EdgeOverlayService.ACTION_UPDATE_COLORS
                    putExtra(EdgeOverlayService.EXTRA_PRIMARY_COLOR, primary)
                    putExtra(EdgeOverlayService.EXTRA_SECONDARY_COLOR, secondary)
                }
                context.startService(intent)
                result.success(null)
            }

            "stop" -> {
                val intent = Intent(context, EdgeOverlayService::class.java).apply {
                    action = EdgeOverlayService.ACTION_STOP
                }
                context.startService(intent)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "com.craunch.player/overlay"
    }
}
