package com.example.gist_hub_flutter

import android.app.Activity
import android.content.Intent
import android.content.ClipData
import android.content.ClipboardManager
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import java.io.ByteArrayOutputStream
import java.io.File
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingResult: MethodChannel.Result? = null
    private var pendingBytes: ByteArray? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory("gisthub/preview", PreviewFactory())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gisthub/files").setMethodCallHandler { call, result ->
            if (call.method == "copyImage") {
                try {
                    val folder = File(cacheDir, "exports").apply { mkdirs() }
                    val file = File(folder, "snippet.png")
                    file.writeBytes(call.arguments as ByteArray)
                    val uri = FileProvider.getUriForFile(this, "$packageName.exports", file)
                    (getSystemService(CLIPBOARD_SERVICE) as ClipboardManager)
                        .setPrimaryClip(ClipData.newUri(contentResolver, "GistHub code image", uri))
                    result.success(null)
                } catch (e: Exception) { result.error("copy_failed", e.message, null) }
                return@setMethodCallHandler
            }
            if (call.method != "save" && call.method != "open") { result.notImplemented(); return@setMethodCallHandler }
            if (pendingResult != null) { result.error("busy", "A save dialog is already open", null); return@setMethodCallHandler }
            pendingBytes = call.argument<ByteArray>("bytes")
            pendingResult = result
            if (call.method == "open") {
                val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE)
                    type = "*/*"
                }
                try { startActivityForResult(intent, 2049) }
                catch (e: Exception) { pendingResult = null; result.error("open_failed", e.message, null) }
                return@setMethodCallHandler
            }
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = call.argument<String>("mime") ?: "application/octet-stream"
                putExtra(Intent.EXTRA_TITLE, call.argument<String>("name"))
            }
            try { startActivityForResult(intent, 2048) }
            catch (e: Exception) { pendingResult = null; pendingBytes = null; result.error("save_failed", e.message, null) }
        }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != 2048 && requestCode != 2049) return
        try {
            if (requestCode == 2049) {
                if (resultCode != Activity.RESULT_OK || data?.data == null) { pendingResult?.success(null); return }
                val uri = data.data!!
                var name = "import.txt"
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (index >= 0) name = cursor.getString(index)
                    }
                }
                val bytes = contentResolver.openInputStream(uri)?.use { input ->
                    val output = ByteArrayOutputStream()
                    val buffer = ByteArray(8192)
                    while (true) {
                        val count = input.read(buffer)
                        if (count < 0) break
                        require(output.size() + count <= 20 * 1024 * 1024) { "Files must be 20 MB or smaller" }
                        output.write(buffer, 0, count)
                    }
                    output.toByteArray()
                }
                    ?: throw IllegalStateException("Could not open file")
                require(bytes.size <= 20 * 1024 * 1024) { "Files must be 20 MB or smaller" }
                pendingResult?.success(mapOf("name" to name, "bytes" to bytes))
                return
            }
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                val stream = contentResolver.openOutputStream(data.data!!) ?: throw IllegalStateException("Could not save file")
                stream.use { it.write(pendingBytes ?: byteArrayOf()) }
                pendingResult?.success(null)
            } else pendingResult?.error("cancelled", "Save cancelled", null)
        } catch (e: Exception) { pendingResult?.error("save_failed", e.message, null) }
        finally { pendingResult = null; pendingBytes = null }
    }
}
