package io.github.red0xi.jellyflex

import android.app.UiModeManager
import android.content.Context
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.media.AudioAttributes
import android.media.SoundPool
import android.net.ConnectivityManager
import android.os.Environment
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.KeyStore
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Android-Gegenstücke zu den Desktop-Kanälen:
 * - `jellyflex/keychain`: Schlüssel für secure.bin (wie macos/Runner/Keychain.swift). Der
 *   eigentliche 32-Byte-Schlüssel liegt verschlüsselt in den App-Einstellungen; entschlüsseln
 *   kann ihn nur ein nicht exportierbarer Schlüssel im Android-Keystore dieses Geräts.
 * - `jellyflex/platform`: App-Ordner und ob die App auf einem Fernseher läuft.
 * - `jellyflex/shell`: getaktete Verbindung (mobile Daten) für "Nur über WLAN/LAN",
 *   Bildschirmhelligkeit, kurze Oberflächen-Klänge (`loadSound`/`playSound`, wie unter iOS/macOS).
 */
class MainActivity : FlutterActivity() {
    /** Oberflächen-Klänge (Intro, Glücksrad): einmal geladen, ohne Verzögerung abspielbar. */
    private val soundPool: SoundPool by lazy {
        SoundPool.Builder()
            .setMaxStreams(2)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
            .also { pool ->
                pool.setOnLoadCompleteListener { _, sampleId, status ->
                    pendingLoads.remove(sampleId)?.success(status == 0)
                }
            }
    }
    private val sounds = HashMap<String, Int>()

    /// Klänge, die noch laden: Antwort an Dart, sobald sie abspielbar sind.
    private val pendingLoads = HashMap<Int, MethodChannel.Result>()
    private var streamId = 0

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "jellyflex/keychain").setMethodCallHandler { call, result ->
            when (call.method) {
                "storeKey" -> try {
                    result.success(StoreKey.load(applicationContext))
                } catch (e: Exception) {
                    result.error("keystore", e.javaClass.simpleName, null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "jellyflex/platform").setMethodCallHandler { call, result ->
            when (call.method) {
                "paths" -> result.success(
                    mapOf(
                        "files" to filesDir.absolutePath,
                        "cache" to cacheDir.absolutePath,
                        "movies" to (getExternalFilesDir(Environment.DIRECTORY_MOVIES) ?: filesDir).absolutePath,
                        "pictures" to (getExternalFilesDir(Environment.DIRECTORY_PICTURES) ?: filesDir).absolutePath,
                        "downloads" to (getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS) ?: filesDir).absolutePath,
                    ),
                )
                "isTv" -> result.success(isTv())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "jellyflex/shell").setMethodCallHandler { call, result ->
            when (call.method) {
                "connectionCost" -> {
                    val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    result.success(if (cm.isActiveNetworkMetered) "metered" else "unmetered")
                }
                // Klang aus den Bytes einer WAV-Datei laden (SoundPool braucht eine Datei).
                "loadSound" -> {
                    val name = call.argument<String>("name")
                    val data = call.argument<ByteArray>("data")
                    if (name == null || data == null) {
                        result.success(false)
                    } else {
                        val file = java.io.File(cacheDir, "sound_$name.wav")
                        file.writeBytes(data)
                        // Erst antworten, wenn der Klang fertig geladen ist – sonst bliebe ein
                        // gleich danach gespielter (das Intro) stumm.
                        val id = soundPool.load(file.path, 1)
                        sounds[name] = id
                        pendingLoads[id] = result
                    }
                }
                // Ein neuer Klang beendet den vorherigen (wie unter Windows/macOS).
                "playSound" -> {
                    val id = sounds[call.arguments as? String]
                    if (id == null) {
                        result.success(false)
                    } else {
                        if (streamId != 0) soundPool.stop(streamId)
                        streamId = soundPool.play(id, 1f, 1f, 1, 0, 1f)
                        result.success(streamId != 0)
                    }
                }
                // Helligkeit nur für dieses Fenster (0…1; -1 = wie im System) – Wischen im Player.
                "getBrightness" -> {
                    val value = window.attributes.screenBrightness
                    result.success(if (value < 0) -1.0 else value.toDouble())
                }
                "setBrightness" -> {
                    val value = (call.arguments as? Double) ?: -1.0
                    val attrs = window.attributes
                    attrs.screenBrightness = if (value < 0) -1f else value.toFloat().coerceIn(0.01f, 1f)
                    window.attributes = attrs
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Fernseher: Android TV / Google TV (Leanback) oder Fire TV. */
    private fun isTv(): Boolean {
        val ui = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
        return ui.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION ||
            packageManager.hasSystemFeature(PackageManager.FEATURE_LEANBACK) ||
            packageManager.hasSystemFeature("amazon.hardware.fire_tv")
    }
}

/** Schlüssel für secure.bin: zufällig, einmal erzeugt, mit dem Android-Keystore verschlüsselt abgelegt. */
private object StoreKey {
    private const val ALIAS = "jellyflex_store"
    private const val PREFS = "jellyflex_keychain"
    private const val WRAPPED = "wrapped_key"

    fun load(context: Context): ByteArray {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val stored = prefs.getString(WRAPPED, null)
        if (stored != null) {
            try {
                return unwrap(Base64.decode(stored, Base64.NO_WRAP))
            } catch (e: Exception) {
                // Der abgelegte Schlüssel passt nicht mehr zum Keystore dieses Geräts (App neu
                // installiert, Daten von einem anderen Gerät übernommen, Keystore zurückgesetzt).
                // Er ist endgültig verloren – ohne Neuanfang ließe sich nie wieder eine Anmeldung
                // speichern. Die alte secure.bin lässt sich danach nicht mehr lesen; die App
                // beginnt dort leer (wie nach einer frischen Installation).
                prefs.edit().remove(WRAPPED).commit()
                try {
                    KeyStore.getInstance("AndroidKeyStore").apply { load(null) }.deleteEntry(ALIAS)
                } catch (ignored: Exception) {
                }
            }
        }
        val key = ByteArray(32).also { SecureRandom().nextBytes(it) }
        // commit: erst zurückgeben, wenn der Schlüssel sicher auf dem Speicher liegt – sonst könnte
        // secure.bin mit einem Schlüssel geschrieben werden, den es nach einem Absturz nicht mehr gibt.
        val saved = prefs.edit().putString(WRAPPED, Base64.encodeToString(wrap(key), Base64.NO_WRAP)).commit()
        if (!saved) throw IllegalStateException("Schlüssel nicht gespeichert")
        return key
    }

    private fun keystoreKey(): SecretKey {
        val store = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (store.getKey(ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(ALIAS, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256)
                .build(),
        )
        return generator.generateKey()
    }

    /** IV (12 Byte) + Geheimtext mit Prüfsumme. */
    private fun wrap(plain: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, keystoreKey())
        return cipher.iv + cipher.doFinal(plain)
    }

    private fun unwrap(data: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, keystoreKey(), GCMParameterSpec(128, data, 0, 12))
        return cipher.doFinal(data, 12, data.size - 12)
    }
}
