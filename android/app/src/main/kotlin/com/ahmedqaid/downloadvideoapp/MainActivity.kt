package com.ahmedqaid.downloadvideoapp

import android.content.Intent
import android.net.Uri
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import androidx.work.Constraints
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkInfo
import androidx.work.WorkManager
import androidx.work.workDataOf
import com.yausername.aria2c.Aria2c
import com.yausername.ffmpeg.FFmpeg
import com.yausername.youtubedl_android.YoutubeDL
import com.yausername.youtubedl_android.YoutubeDLRequest
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.io.File
import java.util.Locale
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private var shareSink: EventChannel.EventSink? = null
    private var pendingSharedText: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pendingSharedText = sharedTextFromIntent(intent) ?: pendingSharedText

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "inspectMedia" -> {
                        val url = call.argument<String>("url")?.trim().orEmpty()
                        if (!isHttpUrl(url)) {
                            result.error("invalid_url", "A valid HTTP/HTTPS URL is required.", null)
                        } else {
                            inspectMedia(url, result)
                        }
                    }
                    "enqueueMedia" -> enqueueMedia(call.arguments as? Map<*, *>, result)
                    "mediaJobStates" -> mediaJobStates(
                        call.argument<List<String>>("ids") ?: emptyList(),
                        result,
                    )
                    "cancelMedia" -> {
                        val id = call.argument<String>("id")
                        result.success(id != null && cancelMedia(id))
                    }
                    "openPath" -> result.success(openPath(call.argument<String>("path")))
                    "sharePath" -> result.success(sharePath(call.argument<String>("path")))
                    "updateMediaEngine" -> updateMediaEngine(result)
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, SHARE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    shareSink = events
                    pendingSharedText?.let {
                        events?.success(it)
                        pendingSharedText = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    shareSink = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedTextFromIntent(intent)?.let { value ->
            val sink = shareSink
            if (sink == null) {
                pendingSharedText = value
            } else {
                sink.success(value)
            }
        }
    }

    private fun inspectMedia(url: String, result: MethodChannel.Result) {
        executor.execute {
            try {
                ensureMediaLibraries()
                val request = YoutubeDLRequest(url)
                request.addOption("--dump-single-json")
                request.addOption("--skip-download")
                request.addOption("--no-warnings")
                request.addOption("--ignore-config")
                request.addOption("--flat-playlist")
                val response = YoutubeDL.execute(request)
                val json = JSONObject(extractJsonObject(response.out))
                val mapped = mediaInfoMap(json, url)
                runOnUiThread { result.success(mapped) }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error("media_inspection_failed", conciseError(error), null)
                }
            }
        }
    }

    private fun enqueueMedia(arguments: Map<*, *>?, result: MethodChannel.Result) {
        if (arguments == null) {
            result.error("invalid_arguments", "Missing media download arguments.", null)
            return
        }
        val url = arguments["url"]?.toString()?.trim().orEmpty()
        val title = arguments["title"]?.toString()?.trim().orEmpty().ifEmpty { "media" }
        val selector = arguments["formatSelector"]?.toString()?.trim().orEmpty()
        val formatLabel = arguments["formatLabel"]?.toString()?.trim().orEmpty()
        val audioFormat = arguments["audioFormat"]?.toString()?.takeIf { it.isNotBlank() }
        val wifiOnly = arguments["wifiOnly"] as? Boolean ?: false
        val useAria2 = arguments["useAria2"] as? Boolean ?: true
        val playlist = arguments["playlist"] as? Boolean ?: false

        if (!isHttpUrl(url) || selector.isEmpty()) {
            result.error("invalid_arguments", "URL and format selector are required.", null)
            return
        }

        val input = workDataOf(
            YtDlpWorker.KEY_URL to url,
            YtDlpWorker.KEY_TITLE to title,
            YtDlpWorker.KEY_FORMAT_SELECTOR to selector,
            YtDlpWorker.KEY_FORMAT_LABEL to formatLabel,
            YtDlpWorker.KEY_AUDIO_FORMAT to (audioFormat ?: ""),
            YtDlpWorker.KEY_USE_ARIA2 to useAria2,
            YtDlpWorker.KEY_PLAYLIST to playlist,
        )
        val constraints = Constraints.Builder()
            .setRequiredNetworkType(if (wifiOnly) NetworkType.UNMETERED else NetworkType.CONNECTED)
            .build()
        val request = OneTimeWorkRequestBuilder<YtDlpWorker>()
            .setInputData(input)
            .setConstraints(constraints)
            .addTag(MEDIA_WORK_TAG)
            .build()

        WorkManager.getInstance(applicationContext).enqueue(request)
        result.success(request.id.toString())
    }

    private fun mediaJobStates(ids: List<String>, result: MethodChannel.Result) {
        executor.execute {
            val manager = WorkManager.getInstance(applicationContext)
            val values = ids.mapNotNull { id ->
                try {
                    val uuid = UUID.fromString(id)
                    val info = manager.getWorkInfoById(uuid).get() ?: return@mapNotNull null
                    val state = when (info.state) {
                        WorkInfo.State.RUNNING -> "running"
                        WorkInfo.State.SUCCEEDED -> "succeeded"
                        WorkInfo.State.FAILED -> "failed"
                        WorkInfo.State.CANCELLED -> "canceled"
                        WorkInfo.State.ENQUEUED, WorkInfo.State.BLOCKED -> "queued"
                    }
                    mapOf(
                        "id" to id,
                        "state" to state,
                        "progress" to if (info.state == WorkInfo.State.SUCCEEDED) {
                            100
                        } else {
                            info.progress.getInt(YtDlpWorker.KEY_PROGRESS, 0)
                        },
                        "eta" to info.progress.getLong(YtDlpWorker.KEY_ETA, -1L)
                            .takeIf { it >= 0 },
                        "outputPath" to info.outputData.getString(YtDlpWorker.KEY_OUTPUT_PATH),
                        "error" to info.outputData.getString(YtDlpWorker.KEY_ERROR),
                        "sizeBytes" to info.outputData.getLong(YtDlpWorker.KEY_SIZE_BYTES, 0L)
                            .takeIf { it > 0 },
                    )
                } catch (_: Throwable) {
                    null
                }
            }
            runOnUiThread { result.success(values) }
        }
    }

    private fun cancelMedia(id: String): Boolean {
        return try {
            WorkManager.getInstance(applicationContext).cancelWorkById(UUID.fromString(id))
            YoutubeDL.destroyProcessById(id)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun updateMediaEngine(result: MethodChannel.Result) {
        executor.execute {
            try {
                ensureMediaLibraries()
                val status = YoutubeDL.updateYoutubeDL(applicationContext)
                val message = status?.let { "yt-dlp update result: $it" }
                    ?: "yt-dlp is already up to date."
                runOnUiThread { result.success(message) }
            } catch (error: Throwable) {
                runOnUiThread {
                    result.error("update_failed", conciseError(error), null)
                }
            }
        }
    }

    @Synchronized
    private fun ensureMediaLibraries() {
        YoutubeDL.init(applicationContext)
        FFmpeg.init(applicationContext)
        Aria2c.init(applicationContext)
    }

    private fun mediaInfoMap(json: JSONObject, originalUrl: String): Map<String, Any?> {
        val formats = mutableListOf<Map<String, Any?>>()
        json.optJSONArray("formats")?.let { array ->
            for (index in 0 until array.length()) {
                val item = array.optJSONObject(index) ?: continue
                val id = stringOrNull(item, "format_id") ?: continue
                formats.add(
                    mapOf(
                        "id" to id,
                        "ext" to stringOrNull(item, "ext"),
                        "note" to stringOrNull(item, "format_note"),
                        "width" to intOrNull(item, "width"),
                        "height" to intOrNull(item, "height"),
                        "fps" to intOrNull(item, "fps"),
                        "vcodec" to stringOrNull(item, "vcodec"),
                        "acodec" to stringOrNull(item, "acodec"),
                        "sizeBytes" to (longOrNull(item, "filesize")
                            ?: longOrNull(item, "filesize_approx")),
                        "tbr" to doubleOrNull(item, "tbr"),
                        "abr" to doubleOrNull(item, "abr"),
                    ),
                )
            }
        }

        val entries = mutableListOf<Map<String, Any?>>()
        json.optJSONArray("entries")?.let { array ->
            val limit = minOf(array.length(), 500)
            for (index in 0 until limit) {
                val item = array.optJSONObject(index) ?: continue
                entries.add(
                    mapOf(
                        "id" to (stringOrNull(item, "id") ?: index.toString()),
                        "title" to (stringOrNull(item, "title") ?: "Untitled"),
                        "url" to (stringOrNull(item, "webpage_url")
                            ?: stringOrNull(item, "url")),
                        "thumbnail" to stringOrNull(item, "thumbnail"),
                        "duration" to intOrNull(item, "duration"),
                    ),
                )
            }
        }

        return mapOf(
            "id" to stringOrNull(json, "id"),
            "title" to (stringOrNull(json, "title")
                ?: stringOrNull(json, "playlist_title")
                ?: "Untitled media"),
            "uploader" to stringOrNull(json, "uploader"),
            "extractor" to (stringOrNull(json, "extractor_key")
                ?: stringOrNull(json, "extractor")
                ?: "generic"),
            "thumbnail" to stringOrNull(json, "thumbnail"),
            "duration" to intOrNull(json, "duration"),
            "description" to stringOrNull(json, "description"),
            "webpageUrl" to (stringOrNull(json, "webpage_url") ?: originalUrl),
            "formats" to formats,
            "entries" to entries,
        )
    }

    private fun extractJsonObject(output: String): String {
        val start = output.indexOf('{')
        val end = output.lastIndexOf('}')
        if (start < 0 || end <= start) {
            throw IllegalStateException("yt-dlp returned no metadata JSON.")
        }
        return output.substring(start, end + 1)
    }

    private fun sharedTextFromIntent(intent: Intent?): String? {
        if (intent == null) return null
        val raw = when (intent.action) {
            Intent.ACTION_SEND -> intent.getStringExtra(Intent.EXTRA_TEXT)
            Intent.ACTION_VIEW -> intent.dataString
            else -> null
        }?.trim()
        return raw?.takeIf { it.isNotEmpty() }
    }

    private fun openPath(path: String?): Boolean {
        val file = path?.let(::File) ?: return false
        if (!file.exists() || !file.isFile) return false
        return try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, mimeTypeFor(file))
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(intent)
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun sharePath(path: String?): Boolean {
        val file = path?.let(::File) ?: return false
        if (!file.exists() || !file.isFile) return false
        return try {
            val uri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                file,
            )
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = mimeTypeFor(file)
                putExtra(Intent.EXTRA_STREAM, uri)
                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivity(Intent.createChooser(intent, "Share download"))
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun mimeTypeFor(file: File): String {
        val extension = file.extension.lowercase(Locale.ROOT)
        return MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?: "application/octet-stream"
    }

    private fun stringOrNull(json: JSONObject, key: String): String? {
        if (!json.has(key) || json.isNull(key)) return null
        return json.optString(key).takeIf { it.isNotBlank() && it != "null" }
    }

    private fun intOrNull(json: JSONObject, key: String): Int? {
        if (!json.has(key) || json.isNull(key)) return null
        return json.optDouble(key, Double.NaN)
            .takeIf { !it.isNaN() }
            ?.toInt()
    }

    private fun longOrNull(json: JSONObject, key: String): Long? {
        if (!json.has(key) || json.isNull(key)) return null
        return json.optDouble(key, Double.NaN)
            .takeIf { !it.isNaN() && it > 0 }
            ?.toLong()
    }

    private fun doubleOrNull(json: JSONObject, key: String): Double? {
        if (!json.has(key) || json.isNull(key)) return null
        return json.optDouble(key, Double.NaN).takeIf { !it.isNaN() }
    }

    private fun isHttpUrl(value: String): Boolean {
        return try {
            val uri = Uri.parse(value)
            (uri.scheme == "http" || uri.scheme == "https") && uri.host.isNotBlank()
        } catch (_: Throwable) {
            false
        }
    }

    private fun conciseError(error: Throwable): String {
        val message = error.message ?: error.javaClass.simpleName
        return if (message.length > 600) message.take(600) + "…" else message
    }

    override fun onDestroy() {
        executor.shutdownNow()
        super.onDestroy()
    }

    companion object {
        private const val MEDIA_CHANNEL = "download_video_app/media"
        private const val SHARE_CHANNEL = "download_video_app/share"
        private const val MEDIA_WORK_TAG = "media-download"
    }
}
