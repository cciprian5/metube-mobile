package com.yasir.metubesuper

import android.app.Activity
import android.app.PendingIntent
import android.app.PictureInPictureParams
import android.app.RemoteAction
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.graphics.drawable.Icon
import android.os.Build
import android.util.Rational
import androidx.core.content.ContextCompat
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
 *
 * The window carries the video's own play and pause button. Without one
 * Android shows the buttons of the app's media session instead, and that
 * session belongs to the audio player, not the video.
 */
object PictureInPicture {
    private var channel: MethodChannel? = null
    private var auto = false
    private var aspect: Rational? = null

    /** Whether the video plays, for the window's button; null for none. */
    private var playing: Boolean? = null
    private var playLabel = ""
    private var pauseLabel = ""

    /** Heard once for the whole process, whichever activity is current. */
    private var listening = false

    fun register(activity: Activity, messenger: BinaryMessenger) {
        listen(activity)
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
                        playing = call.argument<Boolean>("playing")
                        playLabel = call.argument<String>("play") ?: ""
                        pauseLabel = call.argument<String>("pause") ?: ""
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

    private fun toggleAction(context: Context) = "${context.packageName}.PIP_TOGGLE"

    /** The window's button arrives as a broadcast from the system. */
    private fun listen(activity: Activity) {
        if (listening) return
        listening = true
        val context = activity.applicationContext
        ContextCompat.registerReceiver(
            context,
            object : BroadcastReceiver() {
                override fun onReceive(context: Context, intent: Intent) {
                    channel?.invokeMethod("toggle", null)
                }
            },
            IntentFilter(toggleAction(context)),
            ContextCompat.RECEIVER_NOT_EXPORTED,
        )
    }

    private fun supported(activity: Activity): Boolean =
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
            activity.packageManager.hasSystemFeature(
                PackageManager.FEATURE_PICTURE_IN_PICTURE,
            )

    private fun params(activity: Activity): PictureInPictureParams? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val builder = PictureInPictureParams.Builder()
        aspect?.let { builder.setAspectRatio(it) }
        builder.setActions(listOfNotNull(button(activity)))
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            builder.setAutoEnterEnabled(auto)
        }
        return builder.build()
    }

    private fun button(activity: Activity): RemoteAction? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return null
        val isPlaying = playing ?: return null
        val label = if (isPlaying) pauseLabel else playLabel
        val icon = if (isPlaying) {
            android.R.drawable.ic_media_pause
        } else {
            android.R.drawable.ic_media_play
        }
        val intent = Intent(toggleAction(activity)).setPackage(activity.packageName)
        val pending = PendingIntent.getBroadcast(
            activity,
            0,
            intent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        return RemoteAction(Icon.createWithResource(activity, icon), label, label, pending)
    }

    private fun arm(activity: Activity) {
        if (!supported(activity)) return
        val built = params(activity) ?: return
        try {
            activity.setPictureInPictureParams(built)
        } catch (e: IllegalStateException) {
            // The activity is finishing; nothing to arm.
        }
    }

    private fun enter(activity: Activity): Boolean {
        if (!supported(activity)) return false
        val built = params(activity) ?: return false
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
