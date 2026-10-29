package ru.ms777.compliancenavigator

import android.content.ActivityNotFoundException
import android.content.ClipData
import android.content.Intent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private var appUpdates: AppUpdates? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        appUpdates = AppUpdates(this).also {
            it.attach(MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
                "ru.ms777.compliancenavigator/updates"))
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != OPEN_TRANSIENT_FILE) {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val suppliedPath = call.argument<String>("path")
            if (suppliedPath.isNullOrBlank()) {
                result.error("invalid_file", "Файл не выбран.", null)
                return@setMethodCallHandler
            }
            try {
                openTransientFile(suppliedPath)
                result.success(null)
            } catch (_: ActivityNotFoundException) {
                result.error("viewer_unavailable", "Нет приложения для открытия файла.", null)
            } catch (_: SecurityException) {
                result.error("invalid_file", "Файл нельзя открыть безопасно.", null)
            } catch (_: IllegalArgumentException) {
                result.error("invalid_file", "Файл нельзя открыть безопасно.", null)
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        appUpdates?.dispose()
        appUpdates = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private fun openTransientFile(suppliedPath: String) {
        val allowedRoot = File(cacheDir, TRANSIENT_DIRECTORY).canonicalFile
        val file = File(suppliedPath).canonicalFile
        val rootPrefix = allowedRoot.path + File.separator
        require(file.isFile && file.path.startsWith(rootPrefix))
        val mimeType = MIME_TYPES[file.extension.lowercase()]
            ?: throw IllegalArgumentException("Unsupported extension")
        val uri = FileProvider.getUriForFile(
            this,
            "$packageName.transientFileProvider",
            file,
        )
        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, mimeType)
            clipData = ClipData.newRawUri(file.name, uri)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(Intent.createChooser(viewIntent, "Открыть файл"))
    }

    private companion object {
        const val CHANNEL = "ru.ms777.compliancenavigator/transient-file"
        const val OPEN_TRANSIENT_FILE = "openTransientFile"
        const val TRANSIENT_DIRECTORY = "compliance-navigator-transient"
        val MIME_TYPES = mapOf(
            "csv" to "text/csv",
            "docx" to "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "html" to "text/html",
            "jpeg" to "image/jpeg",
            "jpg" to "image/jpeg",
            "json" to "application/json",
            "pdf" to "application/pdf",
            "png" to "image/png",
            "txt" to "text/plain",
            "xlsx" to "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
        )
    }
}
