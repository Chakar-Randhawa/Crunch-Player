package com.craunch.player.overlay

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.graphics.PixelFormat
import android.os.Build
import android.os.IBinder
import android.view.Gravity
import android.view.WindowManager
import com.craunch.player.MainActivity
import com.craunch.player.R

/**
 * Runs as a foreground service (required for a long-lived WindowManager
 * overlay on modern Android — the OS will otherwise tear the window down
 * shortly after the app backgrounds) and hosts a single [EdgeGlowView]
 * added directly to the window manager, outside the app's own Activity
 * window hierarchy.
 */
class EdgeOverlayService : Service() {

    private var windowManager: WindowManager? = null
    private var glowView: EdgeGlowView? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START -> {
                val primary = intent.getIntExtra(EXTRA_PRIMARY_COLOR, 0x7B5CFF)
                val secondary = intent.getIntExtra(EXTRA_SECONDARY_COLOR, 0x00E0C6)
                startOverlay(primary, secondary)
            }
            ACTION_UPDATE_COLORS -> {
                val primary = intent.getIntExtra(EXTRA_PRIMARY_COLOR, 0x7B5CFF)
                val secondary = intent.getIntExtra(EXTRA_SECONDARY_COLOR, 0x00E0C6)
                glowView?.primaryColor = primary
                glowView?.secondaryColor = secondary
                glowView?.invalidate()
            }
            ACTION_STOP -> {
                stopOverlay()
            }
        }
        return START_STICKY
    }

    private fun startOverlay(primaryColor: Int, secondaryColor: Int) {
        startForeground(NOTIFICATION_ID, buildNotification())

        if (glowView != null) {
            glowView?.primaryColor = primaryColor
            glowView?.secondaryColor = secondaryColor
            return
        }

        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        windowManager = wm

        val overlayType = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        } else {
            @Suppress("DEPRECATION")
            WindowManager.LayoutParams.TYPE_PHONE
        }

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            overlayType,
            // NOT_FOCUSABLE + NOT_TOUCHABLE: this overlay is purely
            // decorative and must never intercept touches meant for
            // whatever app is actually in the foreground beneath it.
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }

        val view = EdgeGlowView(this).apply {
            this.primaryColor = primaryColor
            this.secondaryColor = secondaryColor
        }
        glowView = view

        wm.addView(view, params)
        view.start()
    }

    private fun stopOverlay() {
        glowView?.let { view ->
            view.stopAnimating()
            windowManager?.removeView(view)
        }
        glowView = null
        windowManager = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun buildNotification(): Notification {
        val channelId = "craunch_edge_overlay"
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(NotificationManager::class.java)
            val channel = NotificationChannel(
                channelId,
                "Edge Lighting Overlay",
                NotificationManager.IMPORTANCE_MIN,
            )
            manager.createNotificationChannel(channel)
        }

        val openAppIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            openAppIntent,
            PendingIntent.FLAG_IMMUTABLE,
        )

        return Notification.Builder(this, channelId)
            .setContentTitle("CRaunch Player")
            .setContentText("Edge lighting is active")
            .setSmallIcon(R.drawable.ic_notification)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .build()
    }

    override fun onDestroy() {
        stopOverlay()
        super.onDestroy()
    }

    companion object {
        const val ACTION_START = "com.craunch.player.overlay.START"
        const val ACTION_STOP = "com.craunch.player.overlay.STOP"
        const val ACTION_UPDATE_COLORS = "com.craunch.player.overlay.UPDATE_COLORS"
        const val EXTRA_PRIMARY_COLOR = "primaryColor"
        const val EXTRA_SECONDARY_COLOR = "secondaryColor"
        private const val NOTIFICATION_ID = 4821
    }
}
