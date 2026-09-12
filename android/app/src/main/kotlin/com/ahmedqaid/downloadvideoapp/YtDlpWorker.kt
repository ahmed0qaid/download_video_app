package com.ahmedqaid.downloadvideoapp

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Environment
import androidx.core.app.NotificationCompat
import androidx.work.Data
import androidx.work.ForegroundInfo
import androidx.work.Worker
import androidx.work.WorkerParameters
import androidx.work.workDataOf
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import java.io.File
import java.util.Locale
import kotlin.math.roundToInt

class YtDlpWorker(
    appContext: Context,
    workerParams: WorkerParameters,
) : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        val url = inputData.getString(KEY_URL)?.trim().orEmpty()
        val title = inputData.getString(KEY_TITLE)?.trim().orEmpty().ifEmpty { "media" }
        val selector = inputData.getString(KEY_FORMAT_SELECTOR)?.trim().orEmpty()
        val audioFormat = inputData.getString(KEY_AUDIO_FORMAT)?.trim()?.takeIf { it.isNotEmpty() }
        val useAria2 = inputData.getBoolean(KEY_USE_ARIA2, true)
        val playlist = inputData.getBoolean(KEY_PLAYLIST, false)

        if (url.isEmpty() || selector.isEmpty()) {
            return Result.failure(errorData("Missing URL or format selector."))
        }

        return try {
            setForegroundAsync(createForegroundInfo(0, "Preparing media download"))
            YoutubeDL.init(applicationContext)
            FFmpeg.init(applicationContext)
            if (useAria2) Aria2c.init(applicationContext)

            val outputDirectory = File(
                applicationContext.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    ?: applicationContext.filesDir,
                APP_FOLDER,
            )
            if (!outputDirectory.exists() && !outputDirectory.mkdirs()) {
                return Result.failure(errorData("Unable to create the media download folder."))
            }

            val safeBase = sanitizeBaseName(title) + "_" + System.currentTimeMillis()
            val outputTemplate = if (playlist) {
                File(
                    outputDirectory,
                    "%(playlist_index)03d - %(title).150B [%(id)s].%(ext)s",
                ).absolutePath
            } else {
                File(outputDirectory, "$safeBase.%(ext)s").absolutePath
            }

            val request = YoutubeDLRequest(url)
            request.addOption("--ignore-config")
            request.addOption("--newline")
            request.addOption("--no-mtime")
            request.addOption("--no-overwrites")
            request.addOption("--trim-filenames", "180")
            request.addOption("--concurrent-fragments", "4")
            request.addOption("-o", outputTemplate)
            request.addOption(if (playlist) "--yes-playlist" else "--no-playlist")
            request.addOption("-f", selector)

            if (audioFormat != null) {
                request.addOption("-x")
                request.addOption("--audio-format", audioFormat)
                request.addOption("--audio-quality", "0")
            } else {
                request.addOption("--merge-output-format", "mp4")
            }

            if (useAria2) {
                request.addOption("--downloader", "libaria2c.so")
            }

            YoutubeDL.execute(
                request,
                id.toString(),
            ) { progress, etaSeconds, _ ->
                val percent = progress.roundToInt().coerceIn(0, 100)
                setProgressAsync(
                    workDataOf(
                        KEY_PROGRESS to percent,
                        KEY_ETA to etaSeconds.coerceAtLeast(0L),
                    ),
                )
                setForegroundAsync(
                    createForegroundInfo(
                        percent,
                        if (audioFormat == null) "Downloading video" else "Processing audio",
                    ),
                )
            }

            val outputFile = if (playlist) {
                null
            } else {
                outputDirectory.listFiles()
                    ?.filter { it.isFile && it.name.startsWith(safeBase) }
                    ?.maxByOrNull { it.lastModified() }
            }

            val successData = Data.Builder()
                .putString(
                    KEY_OUTPUT_PATH,
                    outputFile?.absolutePath ?: outputDirectory.absolutePath,
                )
                .putLong(KEY_SIZE_BYTES, outputFile?.length() ?: 0L)
                .build()
            Result.success(successData)
        } catch (error: Throwable) {
            if (isStopped) {
                Result.failure(errorData("Download canceled."))
            } else {
                Result.failure(errorData(conciseError(error)))
            }
        }
    }

    override fun onStopped() {
        YoutubeDL.destroyProcessById(id.toString())
        super.onStopped()
    }

    private fun createForegroundInfo(progress: Int, text: String): ForegroundInfo {
        createNotificationChannel()
        val launchIntent = applicationContext.packageManager
            .getLaunchIntentForPackage(applicationContext.packageName)
            ?: Intent(applicationContext, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            applicationContext,
            notificationId(),
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = NotificationCompat.Builder(applicationContext, NOTIFICATION_CHANNEL)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle(inputData.getString(KEY_TITLE) ?: "Media download")
            .setContentText(text)
            .setContentIntent(pendingIntent)
            .setOnlyAlertOnce(true)
            .setOngoing(progress < 100)
            .setProgress(100, progress, progress <= 0)
            .build()

        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ForegroundInfo(
                notificationId(),
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            ForegroundInfo(notificationId(), notification)
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = applicationContext.getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL) != null) return
        manager.createNotificationChannel(
            NotificationChannel(
                NOTIFICATION_CHANNEL,
                "Media downloads",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Progress for video and audio downloads"
            },
        )
    }

    private fun notificationId(): Int = id.hashCode() and 0x7fffffff

    private fun errorData(message: String): Data =
        workDataOf(KEY_ERROR to message.take(600))

    private fun sanitizeBaseName(value: String): String {
        val cleaned = value
            .replace(Regex("[\\\\/:*?\"<>|]"), "_")
            .replace(Regex("\\s+"), " ")
            .trim()
            .trim('.')
        return cleaned.take(120).ifEmpty { "media" }
    }

    private fun conciseError(error: Throwable): String {
        val message = error.message ?: error.javaClass.simpleName
        return message
            .replace(applicationContext.filesDir.absolutePath, "<app>")
            .replace(applicationContext.cacheDir.absolutePath, "<cache>")
            .take(600)
    }

    companion object {
        const val KEY_URL = "url"
        const val KEY_TITLE = "title"
        const val KEY_FORMAT_SELECTOR = "formatSelector"
        const val KEY_FORMAT_LABEL = "formatLabel"
        const val KEY_AUDIO_FORMAT = "audioFormat"
        const val KEY_USE_ARIA2 = "useAria2"
        const val KEY_PLAYLIST = "playlist"
        const val KEY_PROGRESS = "progress"
        const val KEY_ETA = "eta"
        const val KEY_OUTPUT_PATH = "outputPath"
        const val KEY_ERROR = "error"
        const val KEY_SIZE_BYTES = "sizeBytes"

        private const val APP_FOLDER = "Download Video App"
        private const val NOTIFICATION_CHANNEL = "media_downloads"
    }
}
