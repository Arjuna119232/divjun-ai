package com.divjun.ai

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.core.content.ContextCompat

/**
 * Voice input TANPA dialog Google.
 *
 * Pakai SpeechRecognizer langsung (bukan ACTION_RECOGNIZE_SPEECH), jadi tidak ada
 * activity/popup dari Google yang muncul. Semua UIhandled oleh WebView (#voice overlay).
 * KalauRecognitionService tidak ada, SpeechRecognizer otomatis dialihkan ke on-device.
 */
class Voice(private val act: MainActivity) {

    private var sr: SpeechRecognizer? = null
    private var ready = false
    var onText: ((String, Boolean) -> Unit)? = null      // text, isFinal
    var onEvent: ((String) -> Unit)? = null              // ready | denied | nostop | end | error
    private var gotAny = false

    private fun haveMic(): Boolean =
        ContextCompat.checkSelfPermission(act, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    fun isAvailable(): Boolean = haveMic() && recognizerPresent()

    private fun recognizerPresent(): Boolean = try {
        SpeechRecognizer.isRecognitionAvailable(act)
    } catch (e: Exception) {
        false
    }

    fun start() {
        if (!haveMic()) {
            onEvent?.invoke("denied")
            return
        }
        if (!recognizerPresent()) {
            onEvent?.invoke("nostop")
            return
        }
        stop()
        gotAny = false
        val r = try {
            if (Build.VERSION.SDK_INT >= 31) {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(act)
            } else {
                SpeechRecognizer.createSpeechRecognizer(act)
            }
        } catch (e: Exception) {
            onEvent?.invoke("nostop")
            return
        }
        sr = r

        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, "id-ID")
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_MAX_RESULTS, 1)
            // prefer offline / on-device -> tidak perlu kirim ke server Google
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_POSSIBLY_COMPLETE_SILENCE_LENGTH_MILLIS, 1500L)
            putExtra(RecognizerIntent.EXTRA_SPEECH_INPUT_MINIMUM_LENGTH_MILLIS, 1200L)
        }

        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                ready = true
                onEvent?.invoke("ready")
            }

            override fun onBeginningOfSpeech() {}

            override fun onRmsChanged(rmsdB: Float) {
                // kirim level suara supaya UI bisa menganimasi waveform
                act.web.evaluateJavascript(
                    "window.__voiceRms&&window.__voiceRms(" + (rmsdB.coerceIn(0f, 12f) / 12f) + ")",
                    null
                )
            }

            override fun onBufferReceived(buffer: ByteArray?) {}

            override fun onEndOfSpeech() {}

            override fun onError(error: Int) {
                ready = false
                // ERROR_NO_MATCH / SPEECH_TIMEOUT -> user diam, tutup overlay
                val ev = when (error) {
                    SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> "denied"
                    SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> "quiet"
                    SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> "end"
                    SpeechRecognizer.ERROR_SERVER, SpeechRecognizer.ERROR_NETWORK,
                    SpeechRecognizer.ERROR_NETWORK_TIMEOUT -> "neterror"
                    else -> "end"
                }
                onEvent?.invoke(ev)
            }

            override fun onResults(results: Bundle?) {
                ready = false
                val list = results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val txt = list?.firstOrNull().orEmpty()
                if (txt.isNotBlank()) {
                    gotAny = true
                    onText?.invoke(txt, true)
                    onEvent?.invoke("end")
                } else {
                    onEvent?.invoke(if (gotAny) "end" else "quiet")
                }
            }

            override fun onPartialResults(partialResults: Bundle?) {
                val list = partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                val txt = list?.firstOrNull().orEmpty()
                if (txt.isNotBlank()) {
                    gotAny = true
                    onText?.invoke(txt, false)
                }
            }

            override fun onEvent(eventType: Int, params: Bundle?) {}
        })

        try {
            r.startListening(intent)
        } catch (e: Exception) {
            onEvent?.invoke("nostop")
        }
    }

    fun stop() {
        val r = sr ?: return
        sr = null
        ready = false
        try {
            r.cancel()
            r.destroy()
        } catch (e: Exception) {
        }
    }
}
