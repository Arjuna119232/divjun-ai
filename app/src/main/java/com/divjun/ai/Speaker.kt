package com.divjun.ai

import android.speech.tts.TextToSpeech
import android.speech.tts.UtteranceProgressListener
import java.util.Locale
import java.util.concurrent.atomic.AtomicInteger

/**
 * Suara AI (TTS) untuk mode panggilan.
 *
 * Cara pakai: kirim kalimat per kalimat (bukan seluruh jawaban sekaligus) supaya
 * AI mulai bicara begitu kalimat pertama selesai, tidak menunggu jawaban penuh.
 * Ini yang bikin percakapan terasa mengalir dan tidak lama diam.
 */
class Speaker(private val act: MainActivity) {

    private var tts: TextToSpeech? = null
    private var inited = false
    private val seq = AtomicInteger(0)
    private var pending = 0

    // Kalimat yang arrive sebelum TTS siap. Dulu kata-kata ini DIBAWAH diam-diam,
    // jadi user cuma lihat teks tanpa suara sama sekali.
    private val backlog = ArrayList<String>()

    // Kalau engine tidak pernah memanggil onDone/onError (umum saat HP tidak punya
    // data suara), pending akan macet >0 dan mikrofon tidak akan hidup lagi.
    // Watchdog ini yang compulsiveNzMaka grafik: setelah 6 detik paksa selesai.
    private val mainHandler = android.os.Handler(android.os.Looper.getMainLooper())
    private var watchdog: Runnable? = null

    var onReady: ((Boolean) -> Unit)? = null
    var onSpeakStart: (() -> Unit)? = null
    var onQueueDone: (() -> Unit)? = null
    var onError: ((String) -> Unit)? = null

    val isSpeaking: Boolean get() = pending > 0

    fun init() {
        if (inited) return
        tts = TextToSpeech(act) { status ->
            val ok = status == TextToSpeech.SUCCESS
            if (ok) {
                tts?.language = Locale("id", "ID")
                val avail = tts?.isLanguageAvailable(Locale("id", "ID"))
                if (avail == TextToSpeech.LANG_MISSING_DATA || avail == TextToSpeech.LANG_NOT_SUPPORTED) {
                    tts?.language = Locale.US
                }
                tts?.setSpeechRate(1.0f)
                tts?.setPitch(1.0f)
            }
            inited = ok
            act.runOnUiThread {
                if (ok && backlog.isNotEmpty()) {
                    val q = ArrayList(backlog)
                    backlog.clear()
                    say(q)
                }
                onReady?.invoke(ok)
            }
        }
        tts?.setOnUtteranceProgressListener(object : UtteranceProgressListener() {
            override fun onStart(utteranceId: String?) {}
            override fun onDone(utteranceId: String?) {
                act.runOnUiThread {
                    pending--
                    if (pending <= 0) {
                        pending = 0
                        onQueueDone?.invoke()
                    }
                }
            }
            @Deprecated("Deprecated in Java")
            override fun onError(utteranceId: String?) {
                act.runOnUiThread { drain() }
            }
            override fun onError(utteranceId: String?, errorCode: Int) {
                act.runOnUiThread { drain() }
            }
        })
    }

    private fun drain() {
        pending--
        if (pending <= 0) {
            pending = 0
            onQueueDone?.invoke()
        }
    }

    /** Baca daftar kalimat satu per satu (antrian). */
    fun say(sentences: List<String>) {
        val t = tts ?: return
        if (!inited) return
        val clean = sentences.map { it.trim() }.filter { it.length > 1 }
        if (clean.isEmpty()) return
        act.runOnUiThread {
            if (pending == 0) onSpeakStart?.invoke()
            for (s in clean) {
                val id = "u" + seq.incrementAndGet()
                pending++
                val r = t.speak(s, TextToSpeech.QUEUE_ADD, null, id)
                if (r == TextToSpeech.ERROR) {
                    drain()
                }
            }
        }
    }

    fun stop() {
        act.runOnUiThread {
            watchdog?.let { mainHandler.removeCallbacks(it) }
            watchdog = null
            synchronized(backlog) { backlog.clear() }
            tts?.stop()
            pending = 0
            onQueueDone?.invoke()
        }
    }

    /** true kalau suara siap dipakai. */
    fun ready(): Boolean = inited

    fun release() {
        try {
            watchdog?.let { mainHandler.removeCallbacks(it) }
            synchronized(backlog) { backlog.clear() }
            tts?.stop()
            tts?.shutdown()
        } catch (e: Exception) {
        }
        watchdog = null
        tts = null
        inited = false
    }
}
