package com.craunch.player.overlay

import android.animation.ValueAnimator
import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.SweepGradient
import android.view.View
import android.view.animation.LinearInterpolator

/**
 * A lightweight, native (non-Flutter) equivalent of the in-app
 * EdgeGlowOverlay CustomPainter, purpose-built to run inside a
 * WindowManager overlay window while the Flutter engine may not have an
 * active surface. This intentionally does not attempt full parity with
 * the 10 in-app presets (waveCount/sparkle/cornerEmphasis parameters) —
 * embedding a full FlutterView inside a system overlay window to reuse
 * that exact painter is a materially larger integration (a second
 * FlutterEngine instance, its own platform view lifecycle, and careful
 * memory management since it would run for as long as the OS keeps this
 * service alive) that is a reasonable next step but a distinct piece of
 * work from this simpler, genuinely functional native renderer.
 */
class EdgeGlowView(context: Context) : View(context) {

    @Volatile var primaryColor: Int = Color.parseColor("#7B5CFF")
    @Volatile var secondaryColor: Int = Color.parseColor("#00E0C6")

    private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE
        strokeWidth = 10f
        strokeCap = Paint.Cap.ROUND
    }

    private var rotationDegrees = 0f
    private val animator = ValueAnimator.ofFloat(0f, 360f).apply {
        duration = 4000
        repeatCount = ValueAnimator.INFINITE
        interpolator = LinearInterpolator()
        addUpdateListener {
            rotationDegrees = it.animatedValue as Float
            invalidate()
        }
    }

    fun start() {
        if (!animator.isRunning) animator.start()
    }

    fun stopAnimating() {
        animator.cancel()
    }

    @SuppressLint("DrawAllocation")
    override fun onDraw(canvas: Canvas) {
        super.onDraw(canvas)
        if (width == 0 || height == 0) return

        val inset = paint.strokeWidth
        val rect = RectF(inset, inset, width - inset, height - inset)

        val gradient = SweepGradient(
            width / 2f,
            height / 2f,
            intArrayOf(primaryColor, secondaryColor, primaryColor),
            floatArrayOf(0f, 0.5f, 1f),
        )

        canvas.save()
        canvas.rotate(rotationDegrees, width / 2f, height / 2f)
        paint.shader = gradient
        canvas.drawRoundRect(rect, 24f, 24f, paint)
        canvas.restore()
    }

    override fun onDetachedFromWindow() {
        stopAnimating()
        super.onDetachedFromWindow()
    }
}
