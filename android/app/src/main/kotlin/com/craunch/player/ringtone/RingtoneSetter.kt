package com.craunch.player.ringtone

import android.content.ContentValues
import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.provider.Settings
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class RingtoneSetter(private val context: Context) {

    /**
     * Whether this app currently has permission to change the system
     * ringtone directly. Below API 23 this is implicit; API 23+ requires
     * WRITE_SETTINGS, granted only via a dedicated Settings screen (like
     * the overlay permission) rather than the normal runtime dialog.
     */
    fun canWriteSystemSettings(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.System.canWrite(context)
        } else {
            true
        }
    }

    fun openWriteSettingsPermissionScreen() {
        val intent = android.content.Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
            data = Uri.parse("package:${context.packageName}")
            addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    /**
     * Copies [sourceFilePath] into the system Ringtones media collection
     * and, if permission allows, sets it as the default ringtone.
     * Returns the new MediaStore content URI on success.
     */
    fun setAsRingtone(sourceFilePath: String, displayName: String): Uri {
        val sourceFile = File(sourceFilePath)
        require(sourceFile.exists()) { "Source file does not exist: $sourceFilePath" }

        val resolver = context.contentResolver
        val ringtoneUri: Uri

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // API 29+: MediaStore is the only sanctioned way to add a new
            // ringtone under scoped storage — writing directly into
            // /system or /sdcard/Ringtones as older guides describe no
            // longer works.
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Ringtones/")
                put(MediaStore.Audio.Media.IS_RINGTONE, true)
                put(MediaStore.Audio.Media.IS_MUSIC, false)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val collection = MediaStore.Audio.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val itemUri = resolver.insert(collection, values)
                ?: throw IllegalStateException("MediaStore insert failed for ringtone")

            resolver.openOutputStream(itemUri)?.use { out ->
                FileInputStream(sourceFile).use { input -> input.copyTo(out) }
            } ?: throw IllegalStateException("Could not open output stream for $itemUri")

            values.clear()
            values.put(MediaStore.MediaColumns.IS_PENDING, 0)
            resolver.update(itemUri, values, null, null)

            ringtoneUri = itemUri
        } else {
            // Pre-API 29: direct filesystem copy into the shared
            // Ringtones directory, then a legacy MediaStore insert
            // pointing at that path so the system's ringtone picker
            // recognizes it.
            @Suppress("DEPRECATION")
            val ringtonesDir = File(
                android.os.Environment.getExternalStoragePublicDirectory(android.os.Environment.DIRECTORY_RINGTONES),
                "",
            )
            if (!ringtonesDir.exists()) ringtonesDir.mkdirs()
            val destFile = File(ringtonesDir, displayName)

            FileInputStream(sourceFile).use { input ->
                FileOutputStream(destFile).use { output -> input.copyTo(output) }
            }

            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DATA, destFile.absolutePath)
                put(MediaStore.MediaColumns.TITLE, displayName)
                put(MediaStore.MediaColumns.MIME_TYPE, "audio/mpeg")
                put(MediaStore.Audio.Media.IS_RINGTONE, true)
                put(MediaStore.Audio.Media.IS_NOTIFICATION, false)
                put(MediaStore.Audio.Media.IS_ALARM, false)
                put(MediaStore.Audio.Media.IS_MUSIC, false)
            }

            @Suppress("DEPRECATION")
            val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
            resolver.delete(
                collection,
                "${MediaStore.MediaColumns.DATA}=?",
                arrayOf(destFile.absolutePath),
            )
            ringtoneUri = resolver.insert(collection, values)
                ?: throw IllegalStateException("MediaStore insert failed for ringtone")
        }

        if (canWriteSystemSettings()) {
            RingtoneManager.setActualDefaultRingtoneUri(context, RingtoneManager.TYPE_RINGTONE, ringtoneUri)
        }
        // If permission isn't granted, the file is still added to the
        // system's ringtone collection and selectable manually from
        // Settings > Sound > Phone ringtone — just not auto-applied.

        return ringtoneUri
    }
}
