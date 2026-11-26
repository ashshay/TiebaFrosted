package com.tiebafrosted.app

import android.Manifest
import android.content.ActivityNotFoundException
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.CookieManager
import android.webkit.WebStorage
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val cookieChannel = "frosted/cookies"
    private val mediaChannel = "frosted/media"
    private val browserChannel = "frosted/browser"
    private val shareChannel = "frosted/share"
    private val deepLinkChannel = "frosted/deeplink"
    private val storageRequestCode = 0x4d46

    private var pendingSave: (() -> Unit)? = null
    private var pendingSaveFailure: ((String) -> Unit)? = null
    private var initialDeepLink: String? = null

    /// 热启动时把 onNewIntent 收到的链接推给 Dart；Dart 还没订阅就先攒着。
    private var deepLinkSink: EventChannel.EventSink? = null
    private val queuedDeepLinks = ArrayDeque<String>()

    private val cookieUrls = linkedMapOf(
        "https://tieba.baidu.com" to ".baidu.com",
        "https://c.tieba.baidu.com" to ".baidu.com",
        "https://wappass.baidu.com" to ".baidu.com",
        "https://passport.baidu.com" to ".baidu.com",
    )

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { deliverDeepLink(it) }
    }

    /// 热启动的链接直接推给 Dart；没有订阅者时先排队，等 Dart 连上再补发。
    private fun deliverDeepLink(link: String) {
        val sink = deepLinkSink
        if (sink != null) {
            sink.success(link)
        } else {
            queuedDeepLinks.addLast(link)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        intent?.dataString?.let { initialDeepLink = it }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, cookieChannel)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "read" -> result.success(readCookies())
                        "readRaw" -> {
                            val url = call.argument<String>("url") ?: "https://tieba.baidu.com"
                            val manager = CookieManager.getInstance()
                            manager.flush()
                            result.success(manager.getCookie(url) ?: "")
                        }
                        "inject" -> {
                            @Suppress("UNCHECKED_CAST")
                            val cookies = call.argument<Map<String, String>>("cookies").orEmpty()
                            plantCookies(cookies)
                            result.success(null)
                        }
                        "clear" -> {
                            val manager = CookieManager.getInstance()
                            manager.removeSessionCookies {
                                manager.removeAllCookies {
                                    manager.flush()
                                    try {
                                        WebStorage.getInstance().deleteAllData()
                                    } catch (_: Throwable) {
                                    }
                                    result.success(null)
                                }
                            }
                        }
                        else -> result.notImplemented()
                    }
                } catch (t: Throwable) {
                    result.error("cookie_failed", t.message, null)
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, mediaChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "saveImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: defaultName("jpg")
                        if (bytes == null || bytes.isEmpty()) {
                            result.error("save_failed", "图片内容为空", null)
                            return@setMethodCallHandler
                        }
                        saveToGallery(result) { insertImage(bytes, name) }
                    }
                    "saveVideo" -> {
                        val path = call.argument<String>("path").orEmpty()
                        val name = call.argument<String>("name") ?: defaultName("mp4")
                        val mime = call.argument<String>("mime") ?: "video/mp4"
                        if (path.isEmpty()) {
                            result.error("save_failed", "视频路径为空", null)
                            return@setMethodCallHandler
                        }
                        saveToGallery(result) { insertVideo(File(path), name, mime) }
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, browserChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        val url = call.argument<String>("url").orEmpty()
                        result.success(openInBrowser(url))
                    }
                    "initialLink" -> {
                        val link = initialDeepLink
                        initialDeepLink = null
                        result.success(link)
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, shareChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "shareText" -> {
                        val text = call.argument<String>("text").orEmpty()
                        val subject = call.argument<String>("subject")
                        result.success(shareText(text, subject))
                    }
                    else -> result.notImplemented()
                }
            }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, deepLinkChannel)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    deepLinkSink = events
                    while (queuedDeepLinks.isNotEmpty()) {
                        events?.success(queuedDeepLinks.removeFirst())
                    }
                }

                override fun onCancel(arguments: Any?) {
                    deepLinkSink = null
                }
            })
    }

    private fun readCookies(): Map<String, String> {
        val manager = CookieManager.getInstance()
        manager.flush()
        val merged = linkedMapOf<String, String>()
        // 反序合并：贴吧域名的 Cookie 最后写入，同名以贴吧为准。passport / wappass
        // 也会种 STOKEN，但那是网页登录凭证，贴吧写接口（回帖 / 收藏）不认它，
        // 混进来就会变成「帖子能看、收藏和回帖都说未登录」。
        for (url in cookieUrls.keys.reversed()) {
            val raw = manager.getCookie(url) ?: continue
            for (part in raw.split(';')) {
                val trimmed = part.trim()
                val idx = trimmed.indexOf('=')
                if (idx <= 0) continue
                val key = trimmed.substring(0, idx).trim()
                val value = trimmed.substring(idx + 1).trim()
                if (key.isNotEmpty() && value.isNotEmpty()) {
                    merged[key] = value
                }
            }
        }
        return merged
    }

    private fun plantCookies(cookies: Map<String, String>) {
        val manager = CookieManager.getInstance()
        manager.setAcceptCookie(true)
        for ((key, value) in cookies) {
            if (key.isBlank() || value.isBlank()) continue
            manager.setCookie("https://tieba.baidu.com", "$key=$value; Domain=.baidu.com; Path=/")
            manager.setCookie("https://tieba.baidu.com", "$key=$value; Domain=.tieba.baidu.com; Path=/")
        }
        manager.flush()
    }

    private fun openInBrowser(url: String): Boolean {
        if (url.isBlank()) return false
        val parsed = Uri.parse(url)
        val scheme = parsed.scheme?.lowercase()
        if (scheme != "http" && scheme != "https") return false
        return try {
            val intent = Intent(Intent.ACTION_VIEW, parsed).apply {
                addCategory(Intent.CATEGORY_BROWSABLE)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Throwable) {
            false
        }
    }

    private fun shareText(text: String, subject: String?): Boolean {
        if (text.isBlank()) return false
        return try {
            val intent = Intent(Intent.ACTION_SEND).apply {
                type = "text/plain"
                putExtra(Intent.EXTRA_TEXT, text)
                if (!subject.isNullOrBlank()) {
                    putExtra(Intent.EXTRA_SUBJECT, subject)
                }
            }
            startActivity(Intent.createChooser(intent, "分享"))
            true
        } catch (_: Throwable) {
            false
        }
    }

    private fun saveToGallery(result: MethodChannel.Result, action: () -> String) {
        val runAction = {
            try {
                result.success(action())
            } catch (t: Throwable) {
                result.error("save_failed", t.message ?: "保存失败", null)
            }
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            runAction()
            return
        }
        if (checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED) {
            runAction()
            return
        }
        pendingSave = runAction
        pendingSaveFailure = { msg -> result.error("permission_denied", msg, null) }
        requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), storageRequestCode)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != storageRequestCode) return
        val action = pendingSave
        val fail = pendingSaveFailure
        pendingSave = null
        pendingSaveFailure = null
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            action?.invoke()
        } else {
            fail?.invoke("未授予存储权限")
        }
    }

    private fun insertImage(bytes: ByteArray, name: String): String {
        val ext = name.substringAfterLast('.', "jpg").lowercase()
        val mime = when (ext) {
            "png" -> "image/png"
            "webp" -> "image/webp"
            "gif" -> "image/gif"
            else -> "image/jpeg"
        }
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/TiebaFrosted")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("无法写入系统相册")
        resolver.openOutputStream(uri)?.use { it.write(bytes) }
            ?: throw IllegalStateException("无法打开相册输出流")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Images.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        return uri.toString()
    }

    private fun insertVideo(file: File, name: String, mime: String): String {
        val values = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, name)
            put(MediaStore.Video.Media.MIME_TYPE, mime)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                put(MediaStore.Video.Media.RELATIVE_PATH, "${Environment.DIRECTORY_MOVIES}/TiebaFrosted")
                put(MediaStore.Video.Media.IS_PENDING, 1)
            }
        }
        val resolver = contentResolver
        val uri = resolver.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, values)
            ?: throw IllegalStateException("无法写入系统相册")
        resolver.openOutputStream(uri)?.use { out ->
            file.inputStream().use { it.copyTo(out) }
        } ?: throw IllegalStateException("无法打开视频输出流")
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            values.clear()
            values.put(MediaStore.Video.Media.IS_PENDING, 0)
            resolver.update(uri, values, null, null)
        }
        return uri.toString()
    }

    private fun defaultName(ext: String): String = "tiebafrosted_${System.currentTimeMillis()}.$ext"
}
