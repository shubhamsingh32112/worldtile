package com.example.worldtile_app

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.OutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "media_store_saver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveImageToGallery" -> {
                    val imageBytes = call.argument<ByteArray>("imageBytes")
                    val fileName = call.argument<String>("fileName") ?: "qr_code.png"
                    
                    if (imageBytes == null) {
                        result.error("INVALID_ARGUMENT", "Image bytes are required", null)
                        return@setMethodCallHandler
                    }
                    
                    try {
                        val saved = saveImageToGallery(imageBytes, fileName)
                        if (saved) {
                            result.success(true)
                        } else {
                            result.error("SAVE_FAILED", "Failed to save image to gallery", null)
                        }
                    } catch (e: Exception) {
                        result.error("EXCEPTION", e.message, null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun saveImageToGallery(imageBytes: ByteArray, fileName: String): Boolean {
        val contentValues = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/WorldTile")
            
            // For Android 10+ (API 29+), we need to set IS_PENDING
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }

        val resolver = contentResolver
        val uri: Uri? = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)

        return if (uri != null) {
            try {
                resolver.openOutputStream(uri)?.use { outputStream: OutputStream ->
                    outputStream.write(imageBytes)
                    outputStream.flush()
                }
                
                // For Android 10+, clear IS_PENDING flag after writing
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    contentValues.clear()
                    contentValues.put(MediaStore.Images.Media.IS_PENDING, 0)
                    resolver.update(uri, contentValues, null, null)
                }
                
                true
            } catch (e: Exception) {
                // If write fails, try to delete the created entry
                try {
                    resolver.delete(uri, null, null)
                } catch (deleteException: Exception) {
                    // Ignore delete errors
                }
                false
            }
        } else {
            false
        }
    }
}
