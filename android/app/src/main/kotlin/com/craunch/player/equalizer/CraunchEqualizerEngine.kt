package com.craunch.player.equalizer

import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Virtualizer

/**
 * Owns the actual platform AudioFx instances for one audio session. Every
 * one of these effects is tied at construction time to a specific
 * `audioSessionId` — they do not follow the audio automatically if
 * playback later moves to a different session (e.g. a new ExoPlayer
 * instance created by a crossfade swap), so this class's lifecycle is
 * exactly one attach/release pair per session.
 */
class CraunchEqualizerEngine(private val audioSessionId: Int) {

    private var equalizer: Equalizer? = null
    private var bassBoost: BassBoost? = null
    private var virtualizer: Virtualizer? = null
    private var presetReverb: PresetReverb? = null

    data class Capabilities(
        val bandCount: Int,
        val centerFrequenciesHz: List<Int>,
        val minGainDb: Double,
        val maxGainDb: Double,
    )

    /**
     * Priority 0 (the value Android docs recommend for app-level, as
     * opposed to system-level, audio effects) for every effect below —
     * higher priority effects further down the chain could otherwise
     * override these.
     */
    private val effectPriority = 0

    fun attach(): Capabilities {
        val eq = Equalizer(effectPriority, audioSessionId).apply { enabled = false }
        equalizer = eq

        val bb = BassBoost(effectPriority, audioSessionId).apply { enabled = false }
        bassBoost = bb

        val virt = Virtualizer(effectPriority, audioSessionId).apply { enabled = false }
        virtualizer = virt

        val reverb = PresetReverb(effectPriority, audioSessionId).apply { enabled = false }
        presetReverb = reverb

        val bandCount = eq.numberOfBands.toInt()
        val frequencies = (0 until bandCount).map { band ->
            // getCenterFreq returns millihertz; convert to whole Hz for the
            // Dart side, which only needs display-precision.
            eq.getCenterFreq(band.toShort()) / 1000
        }

        // getBandLevelRange returns [minMillibel, maxMillibel] — Android's
        // Equalizer works in millibels (1/100 dB) internally.
        val range = eq.bandLevelRange
        val minGainDb = range[0] / 100.0
        val maxGainDb = range[1] / 100.0

        return Capabilities(bandCount, frequencies, minGainDb, maxGainDb)
    }

    fun release() {
        equalizer?.release()
        bassBoost?.release()
        virtualizer?.release()
        presetReverb?.release()
        equalizer = null
        bassBoost = null
        virtualizer = null
        presetReverb = null
    }

    fun setEnabled(enabled: Boolean) {
        equalizer?.enabled = enabled
        bassBoost?.enabled = enabled
        virtualizer?.enabled = enabled
        presetReverb?.enabled = enabled
    }

    fun setBandLevel(bandIndex: Int, gainDb: Double) {
        val eq = equalizer ?: return
        if (bandIndex < 0 || bandIndex >= eq.numberOfBands) return
        val millibel = (gainDb * 100).toInt().toShort()
        eq.setBandLevel(bandIndex.toShort(), millibel)
    }

    fun setBassBoostStrength(strength0to1000: Int) {
        val bb = bassBoost ?: return
        if (!bb.strengthSupported) return
        bb.setStrength(strength0to1000.coerceIn(0, 1000).toShort())
    }

    fun setVirtualizerStrength(strength0to1000: Int) {
        val virt = virtualizer ?: return
        if (!virt.strengthSupported) return
        virt.setStrength(strength0to1000.coerceIn(0, 1000).toShort())
    }

    /**
     * Maps the Dart-side [ReverbPreset] enum name to Android's PresetReverb
     * integer constants. "3D reverb vector" from the original feature list
     * is realized as Virtualizer (stereo widening) + this spatial reverb
     * preset together — Android has no per-axis positional reverb API, so
     * this pairing is the honest, real equivalent rather than a fabricated
     * capability.
     */
    fun setReverbPreset(presetKey: String) {
        val reverb = presetReverb ?: return
        val preset = when (presetKey) {
            "smallRoom" -> PresetReverb.PRESET_SMALLROOM
            "mediumRoom" -> PresetReverb.PRESET_MEDIUMROOM
            "largeRoom" -> PresetReverb.PRESET_LARGEROOM
            "mediumHall" -> PresetReverb.PRESET_MEDIUMHALL
            "largeHall" -> PresetReverb.PRESET_LARGEHALL
            "plate" -> PresetReverb.PRESET_PLATE
            else -> PresetReverb.PRESET_NONE
        }
        reverb.preset = preset.toShort()
    }
}
