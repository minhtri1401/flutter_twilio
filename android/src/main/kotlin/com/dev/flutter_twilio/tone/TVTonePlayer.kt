package com.dev.flutter_twilio.tone

import android.content.Context
import android.content.res.AssetFileDescriptor
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.util.Log
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.loader.FlutterLoader

/**
 * Plays a single tone (looping or one-shot). Source can be a Flutter asset
 * key (resolved via FlutterLoader) or null to fall back to the bundled
 * default at the given fallback asset path under `assets/flutter_twilio/`.
 */
class TVTonePlayer(private val context: Context) {

    private val TAG = "TVTonePlayer"
    private var player: MediaPlayer? = null

    fun play(
        flutterAssetKey: String?,
        bundledAssetPath: String,
        looping: Boolean,
        forSignalling: Boolean,
    ) {
        stop()
        try {
            val mp = MediaPlayer()
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(
                        if (forSignalling)
                            AudioAttributes.USAGE_VOICE_COMMUNICATION_SIGNALLING
                        else
                            AudioAttributes.USAGE_VOICE_COMMUNICATION
                    )
                    .setContentType(
                        if (forSignalling)
                            AudioAttributes.CONTENT_TYPE_SONIFICATION
                        else
                            AudioAttributes.CONTENT_TYPE_SPEECH
                    )
                    .build()
            )
            val afd: AssetFileDescriptor = openAfd(flutterAssetKey, bundledAssetPath)
            afd.use {
                mp.setDataSource(it.fileDescriptor, it.startOffset, it.length)
            }
            mp.isLooping = looping
            mp.setOnCompletionListener { stop() }
            mp.prepare()
            mp.start()
            player = mp
        } catch (t: Throwable) {
            // Tone playback must never break a call. Log and move on.
            Log.w(TAG, "Tone playback failed", t)
            stop()
        }
    }

    fun stop() {
        try {
            player?.let {
                if (it.isPlaying) it.stop()
                it.reset()
                it.release()
            }
        } catch (t: Throwable) {
            Log.w(TAG, "Tone stop failed", t)
        } finally {
            player = null
        }
    }

    private fun openAfd(flutterAssetKey: String?, bundledAssetPath: String): AssetFileDescriptor {
        if (flutterAssetKey != null) {
            val loader: FlutterLoader = FlutterInjector.instance().flutterLoader()
            val resolved = loader.getLookupKeyForAsset(flutterAssetKey)
            return context.assets.openFd(resolved)
        }
        return context.assets.openFd(bundledAssetPath)
    }
}
