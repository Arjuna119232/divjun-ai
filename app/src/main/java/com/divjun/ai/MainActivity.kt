package com.divjun.ai

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Base64
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.media.ExifInterface
import android.provider.MediaStore
import android.speech.RecognizerIntent
import androidx.core.content.FileProvider
import java.io.ByteArrayOutputStream
import java.io.File
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap
import android.Manifest
import android.content.pm.PackageManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

class MainActivity : Activity() {
    lateinit var web: WebView
    var pendingPermId: String = ""
    private val conns = ConcurrentHashMap<String, HttpURLConnection>()
    private lateinit var voice: Voice

    private fun applyBars(dark: Boolean) {
        var f = 0
        if (!dark) {
            f = android.view.View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
            if (android.os.Build.VERSION.SDK_INT >= 26) {
                f = f or android.view.View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
            }
        }
        window.decorView.systemUiVisibility = f
        val bg = if (dark) 0xFF1F1E1D.toInt() else 0xFFFAF9F7.toInt()
        try {
            window.statusBarColor = bg
            window.navigationBarColor = bg
        } catch (e: Exception) {
        }
    }

    private fun initVoice() {
        voice = Voice(this)
        voice.onText = { txt, final ->
            runOnUiThread {
                web.evaluateJavascript(
                    "window.__voiceText&&window.__voiceText(" + JSONObject.quote(txt) + "," + final + ")",
                    null
                )
            }
        }
        voice.onEvent = { ev ->
            runOnUiThread {
                web.evaluateJavascript("window.__voiceEv&&window.__voiceEv('" + ev + "')", null)
            }
        }
    }

    override fun onDestroy() {
        if (::voice.isInitialized) voice.stop()
        super.onDestroy()
    }
    private val REQ_CAMERA = 101
    private val REQ_GALLERY = 102
    private val REQ_STORAGE = 103

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        applyBars(
            (resources.configuration.uiMode and android.content.res.Configuration.UI_MODE_NIGHT_MASK) ==
                android.content.res.Configuration.UI_MODE_NIGHT_YES
        )
        web = WebView(this)
        web.setBackgroundColor(resources.getColor(R.color.bg, theme))
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.addJavascriptInterface(Bridge(), "Android")
        setContentView(web)
        initVoice()
        web.loadUrl("file:///android_asset/index.html")
    }

    override fun onRequestPermissionsResult(code: Int, perms: Array<out String>, grants: IntArray) {
        super.onRequestPermissionsResult(code, perms, grants)
        val tipe = pendingPermId.ifEmpty { "unknown" }
        val ok = perms.isNotEmpty() && grants.isNotEmpty() &&
            perms.size == grants.size && grants.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermId = ""
        val blocked = !ok && Perms.isBlocked(this, tipe)
        runOnUiThread {
            web.evaluateJavascript(
                "window.__onPerm&&window.__onPerm('" + tipe + "'," + ok + "," + blocked + ")",
                null
            )
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onBackPressed() {
        web.evaluateJavascript("window.__back&&window.__back()") { r -> if (r != "true") finish() }
    }

    private fun js(id: String, type: String, data: String) {
        runOnUiThread {
            web.evaluateJavascript("window.__net('$id','$type',${JSONObject.quote(data)})", null)
        }
    }

    private var camUri: Uri? = null

    private fun evalJs(code: String) = runOnUiThread { web.evaluateJavascript(code, null) }
    private fun pickErr(m: String) = evalJs("window.__pickErr&&window.__pickErr(${JSONObject.quote(m)})")

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (resultCode != RESULT_OK) return
        when (requestCode) {
            11, 12 -> data?.data?.let { readUri(it) }
            13 -> camUri?.let { readUri(it) }
            21 -> {
                val r = data?.getStringArrayListExtra(RecognizerIntent.EXTRA_RESULTS)
                if (!r.isNullOrEmpty()) evalJs("window.__voice&&window.__voice(${JSONObject.quote(r[0])})")
            }
        }
    }

    private fun readUri(u: Uri) {
        Thread {
            try {
                val mime = contentResolver.getType(u) ?: "application/octet-stream"
                val name = (u.lastPathSegment ?: "file").substringAfterLast('/')
                if (mime.startsWith("image/")) {
                    val b = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                    contentResolver.openInputStream(u)?.use { BitmapFactory.decodeStream(it, null, b) }
                    var s = 1
                    while (maxOf(b.outWidth, b.outHeight) / s > 3200) s *= 2
                    val o = BitmapFactory.Options().apply { inSampleSize = s }
                    val src = contentResolver.openInputStream(u)?.use { BitmapFactory.decodeStream(it, null, o) }
                        ?: throw Exception("Gambar tidak bisa dibaca")
                    val deg = contentResolver.openInputStream(u)?.use {
                        when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, 1)) {
                            6 -> 90f; 3 -> 180f; 8 -> 270f; else -> 0f
                        }
                    } ?: 0f
                    val m = Matrix()
                    if (deg != 0f) m.postRotate(deg)
                    val sc = 1600f / maxOf(src.width, src.height)
                    if (sc < 1f) m.postScale(sc, sc)
                    val bmp = Bitmap.createBitmap(src, 0, 0, src.width, src.height, m, true)
                    val out = ByteArrayOutputStream()
                    bmp.compress(Bitmap.CompressFormat.JPEG, 85, out)
                    val b64 = Base64.encodeToString(out.toByteArray(), Base64.NO_WRAP)
                    evalJs("window.__picked(${JSONObject.quote(name)},'image/jpeg','$b64')")
                } else {
                    val bytes = contentResolver.openInputStream(u)?.use { it.readBytes() }
                        ?: throw Exception("File tidak bisa dibaca")
                    if (bytes.size > 200_000) throw Exception("File terlalu besar (maksimal 200 KB)")
                    val b64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
                    evalJs("window.__picked(${JSONObject.quote(name)},${JSONObject.quote(mime)},'$b64')")
                }
            } catch (e: Exception) {
                pickErr(e.message ?: "Gagal membaca file")
            }
        }.start()
    }

    inner class Bridge {
        private val prefs = getSharedPreferences("divjun", Context.MODE_PRIVATE)

        @JavascriptInterface fun get(k: String): String = prefs.getString(k, "") ?: ""

        @JavascriptInterface fun set(k: String, v: String) { prefs.edit().putString(k, v).apply() }

        @JavascriptInterface fun open(url: String) {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        }

        @JavascriptInterface fun copy(text: String) {
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
            cm.setPrimaryClip(ClipData.newPlainText("DIVJUN AI", text))
        }

        @JavascriptInterface fun share(text: String) {
            val i = Intent(Intent.ACTION_SEND).apply { type = "text/plain"; putExtra(Intent.EXTRA_TEXT, text) }
            startActivity(Intent.createChooser(i, "Bagikan"))
        }

        @JavascriptInterface fun toast(msg: String) {
            runOnUiThread { web.evaluateJavascript("window.toast&&window.toast(" + JSONObject.quote(msg) + ")", null) }
        }

        /** Ikuti tema dalam-app untuk system bar. */
        @JavascriptInterface fun setTheme(dark: Boolean) {
            runOnUiThread { applyBars(dark) }
        }

        @JavascriptInterface fun version(): String =
            packageManager.getPackageInfo(packageName, 0).versionName ?: ""

        @JavascriptInterface fun builtin(p: String): String = when (p) {
            "groq" -> BuildConfig.GROQ_KEY
            "gemini" -> BuildConfig.GEMINI_KEY
            else -> ""
        }

        @JavascriptInterface
        fun minta(tipe: String) {
            val id = when (tipe) {
                "camera" -> "camera"
                "photo" -> "photo"
                "mic", "voice" -> "mic"
                else -> "photo"
            }
            Perms.request(this@MainActivity, id)
        }

        /** Alasan + daftar izin, untuk sheet penjelasan di UI. */
        @JavascriptInterface
        fun permInfo(): String {
            val sb = StringBuilder("[")
            Perms.all().forEachIndexed { i, info ->
                if (i > 0) sb.append(',')
                sb.append('{')
                sb.append("\"id\":\"").append(info.id).append("\",")
                sb.append("\"title\":\"").append(info.title).append("\",")
                sb.append("\"why\":\"").append(info.why).append("\",")
                sb.append("\"granted\":").append(Perms.grantedId(this@MainActivity, info.id))
                sb.append(",\"blocked\":").append(Perms.isBlocked(this@MainActivity, info.id))
                sb.append('}')
            }
            return sb.append(']').toString()
        }

        @JavascriptInterface
        fun permGranted(id: String): Boolean = Perms.grantedId(this@MainActivity, id)

        /** Buka pengaturan sistem supaya user bisa mencabut/memberikan izin. */
        @JavascriptInterface
        fun openAppSettings() {
            runOnUiThread {
                try {
                    val i = android.content.Intent(
                        android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                        android.net.Uri.fromParts("package", packageName, null)
                    )
                    i.addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    startActivity(i)
                } catch (e: Exception) {
                    web.evaluateJavascript("window.toast&&window.toast('Gagal membuka pengaturan')", null)
                }
            }
        }

        @JavascriptInterface fun pick(kind: String) {
            runOnUiThread {
                try {
                    when (kind) {
                        "photo" -> startActivityForResult(Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"; addCategory(Intent.CATEGORY_OPENABLE)
                        }, 11)
                        "file" -> startActivityForResult(Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("image/*", "text/*", "application/json"))
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }, 12)
                        "camera" -> {
                            val f = File(cacheDir, "cam_${System.currentTimeMillis()}.jpg")
                            camUri = FileProvider.getUriForFile(this@MainActivity, "$packageName.fileprovider", f)
                            val i = Intent(MediaStore.ACTION_IMAGE_CAPTURE).putExtra(MediaStore.EXTRA_OUTPUT, camUri)
                            i.addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            startActivityForResult(i, 13)
                        }
                    }
                } catch (e: Exception) {
                    pickErr("Tidak bisa membuka pemilih ini di HP Anda")
                }
            }
        }

        /** Voice native on-device: tanpa dialog Google. */
        @JavascriptInterface fun voice() {
            if (!voice.isAvailable) {
                runOnUiThread {
                    web.evaluateJavascript("window.__voiceEv&&window.__voiceEv('nostop')", null)
                }
                return
            }
            runOnUiThread { voice.start() }
        }

        @JavascriptInterface fun voiceStop() {
            runOnUiThread { voice.stop() }
        }

        @JavascriptInterface fun voiceAvailable(): Boolean = voice.isAvailable

        @JavascriptInterface fun cancel(id: String) { conns.remove(id)?.disconnect() }

        @JavascriptInterface
        fun request(id: String, method: String, url: String, headers: String, body: String) {
            Thread {
                try {
                    val conn = URL(url).openConnection() as HttpURLConnection
                    conns[id] = conn
                    conn.requestMethod = method
                    conn.connectTimeout = 20000
                    conn.readTimeout = 120000
                    val h = JSONObject(headers)
                    for (key in h.keys()) conn.setRequestProperty(key, h.getString(key))
                    if (body.isNotEmpty()) {
                        conn.doOutput = true
                        conn.outputStream.use { os -> os.write(body.toByteArray(Charsets.UTF_8)) }
                    }
                    val code = conn.responseCode
                    js(id, "status", code.toString())
                    val stream = if (code < 400) conn.inputStream else conn.errorStream
                    val buf = ByteArray(4096)
                    stream?.use { s ->
                        while (true) {
                            val n = s.read(buf)
                            if (n < 0) break
                            js(id, "chunk", Base64.encodeToString(buf, 0, n, Base64.NO_WRAP))
                        }
                    }
                    js(id, "done", "")
                } catch (e: Exception) {
                    if (conns.containsKey(id)) js(id, "err", e.message ?: "Tidak bisa terhubung ke internet")
                } finally {
                    conns.remove(id)
                }
            }.start()
        }
    }
}
