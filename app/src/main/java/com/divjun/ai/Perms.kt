package com.divjun.ai

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat

/**
 * Manajer izin modern.
 *
 * Semua izin punya alasan (alasan/alasannya). Alasan dikirim ke WebView supaya
 * UI bisa menampilkan sheet penjelasan sebelum dialog sistem muncul.
 * Ini pola yang dipakai app profesional: jelas dulu, baru minta.
 */
object Perms {

    const val REQ_GROUP = 900
    const val REQ_CAMERA = 901
    const val REQ_MIC = 902
    const val REQ_PHOTO = 903
    const val REQ_NOTIF = 904

    data class Info(
        val id: String,
        val title: String,
        val why: String,
        val perms: Array<String>
    )

    fun list(id: String): Info? = when (id) {
        "camera" -> Info(
            "camera",
            "Akses kamera",
            "Dipakai kalau kamu ambil foto untuk ditanyakan ke AI. Foto hanya di HP kamu sampai dikirim ke model yang kamu pilih.",
            if (Build.VERSION.SDK_INT >= 23) arrayOf(Manifest.permission.CAMERA) else emptyArray()
        )
        "mic" -> Info(
            "mic",
            "Akses mikrofon",
            "Dipakai kalau kamu bicara ke AI tanpa mengetik. Audio diproses di HP lalu diubah jadi teks.",
            if (Build.VERSION.SDK_INT >= 23) arrayOf(Manifest.permission.RECORD_AUDIO) else emptyArray()
        )
        "photo" -> Info(
            "photo",
            "Akses foto",
            "Dipakai supaya kamu bisa memilih gambar dari galeri untuk ditanyakan ke AI.",
            when {
                Build.VERSION.SDK_INT >= 33 -> arrayOf(
                    Manifest.permission.READ_MEDIA_IMAGES,
                    Manifest.permission.READ_MEDIA_VIDEO
                )
                Build.VERSION.SDK_INT >= 23 -> arrayOf(Manifest.permission.READ_EXTERNAL_STORAGE)
                else -> emptyArray()
            }
        )
        "notif" -> Info(
            "notif",
            "Kirim notifikasi",
            "Biar DIVJUN AI bisa memberi tahu kalau jawaban sudah selesai, walau kamu sedang pakai aplikasi lain.",
            if (Build.VERSION.SDK_INT >= 33) arrayOf("android.permission.POST_NOTIFICATIONS") else emptyArray()
        )
        else -> null
    }

    fun all(): List<Info> = listOf("notif", "camera", "mic", "photo").mapNotNull { list(it) }

    fun granted(ctx: Context, perms: Array<String>): Boolean =
        perms.isEmpty() || perms.all {
            ContextCompat.checkSelfPermission(ctx, it) == PackageManager.PERMISSION_GRANTED
        }

    fun grantedId(ctx: Context, id: String): Boolean {
        val info = list(id) ?: return true
        return granted(ctx, info.perms)
    }

    fun statusJson(ctx: Context): String {
        val sb = StringBuilder("{")
        all().forEachIndexed { i, info ->
            if (i > 0) sb.append(',')
            sb.append('"').append(info.id).append("\":")
            sb.append(if (granted(ctx, info.perms)) "true" else "false")
        }
        return sb.append('}').toString()
    }

    /** Minta izin. Kirim status akhir balik ke WebView sebagai __onPerm(type, ok). */
    fun request(activity: Activity, id: String) {
        val info = list(id) ?: return
        if (info.perms.isEmpty() || granted(activity, info.perms)) {
            activity.web.evaluateJavascript(
                "window.__onPerm&&window.__onPerm('${info.id}',true)",
                null
            )
            return
        }
        activity.runOnUiThread {
            activity.pendingPermId = info.id
            ActivityCompat.requestPermissions(activity, info.perms, requestCodeFor(info.id))
        }
    }

    private fun requestCodeFor(id: String): Int = when (id) {
        "camera" -> REQ_CAMERA
        "mic" -> REQ_MIC
        "photo" -> REQ_PHOTO
        "notif" -> REQ_NOTIF
        else -> REQ_GROUP
    }

    /**true kalau izin sudahGranted dan tidak perlu dialog lagi (pernah ditolak permanen). */
    fun shouldExplain(activity: Activity, id: String): Boolean {
        val info = list(id) ?: return false
        if (info.perms.isEmpty()) return false
        return info.perms.any {
            ActivityCompat.shouldShowRequestPermissionRationale(activity, it)
        }
    }

    fun isBlocked(activity: Activity, id: String): Boolean {
        val info = list(id) ?: return false
        if (info.perms.isEmpty()) return false
        return info.perms.any {
            !ActivityCompat.shouldShowRequestPermissionRationale(activity, it) &&
                ContextCompat.checkSelfPermission(activity, it) != PackageManager.PERMISSION_GRANTED
        }
    }
}