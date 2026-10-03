package com.divjun.ai

import android.app.Activity
import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Base64
import android.webkit.JavascriptInterface
import android.webkit.WebView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.util.concurrent.ConcurrentHashMap

class MainActivity : Activity() {
    private lateinit var web: WebView
    private val conns = ConcurrentHashMap<String, HttpURLConnection>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        web = WebView(this)
        web.setBackgroundColor(0xFF0D1228.toInt())
        web.settings.javaScriptEnabled = true
        web.settings.domStorageEnabled = true
        web.addJavascriptInterface(Bridge(), "Android")
        setContentView(web)
        web.loadUrl("file:///android_asset/index.html")
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

        @JavascriptInterface fun version(): String =
            packageManager.getPackageInfo(packageName, 0).versionName ?: ""

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
