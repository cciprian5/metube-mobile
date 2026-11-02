package com.yasir.metubesuper

import android.app.Activity
import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.os.Build
import android.util.Rational
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * Picture in picture for the video player, on the `mt/pip` channel the
 * app's Dart side shares with the other app.
 *
 * Nothing happens until the user turns it on in the playback settings:
 * the Dart side then asks for it by hand (`enter`), or keeps it armed
 * while a video plays (`setAuto`) so leaving the app enters it by itself.
 * Android 12 does that on its own once armed; before 12 the activity asks
 * when the user leaves ([onUserLeaveHint]).
 */
object PictureInPicture {
    private var channel: MethodChannel? = null
    private var auto = false
    private var aspect: Rational? = null

    fun register(activity: Activity, messenger: BinaryMessenger) {
        channel = MethodChannel(messenger, "mt/pip").apply {
            setMethodCallHandler { call, result ->
                when (call.method) {
                    "enter" -> {
                        aspect = rational(call.argument<Double>("aspect"))
                        result.success(enter(activity))
                    }
                    "setAuto" -> {
                        auto = call.argument<Boolean>("on") == true
                        aspect = rational(call.argument<Double>("aspect"))
                        arm(activity)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    /** The user is leaving the app: before Android 12, enter if armed. */
    fun onUserLeaveHint(activity: Activity) {
        if (auto && Build.VERSION.SDK_INT < Build.VERSION_CODES.S) enter(activity)
    }

    /** Tells the Dart side the window moved into a corner or back. */
    fun onModeChanged(inPicture: Boolean) {
        channel?.invokeMethod("changed", inPicture)
    }

    private fun supported(activity: Activity): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(
                PackageManager.FEATURE_PICTURE_IN_PICTURE,
            )

    private fun params(): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val builder = PictureInPictureParams.Builder()
        aspect?.let { builder.setAspectRatio(it) }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(auto)
        }
        return builder.build()
    }

    private fun arm(activity: Activity) {
        if (!supported(activity)) return
        val built = params() ?: return
        try {
            activity.setPictureInPictureParams(built)
        } catch (e: IllegalStateException) {
            // The activity is finishing; nothing to arm.
        }
    }

    private fun enter(activity: Activity): Boolean {
        if (!supported(activity)) return false
        val built = params() ?: return false
        return try {
            activity.enterPictureInPictureMode(built)
        } catch (e: IllegalStateException) {
            false
        }
    }

    private fun rational(value: Double?): Rational? {
        if (value == null || value <= 0) return null
        return Rational((value * 1000).toInt(), 1000)
    }
}
