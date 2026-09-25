import AVFoundation

/// A real, working 10-band parametric equalizer built on AVFoundation's
/// AVAudioUnitEQ, usable today against any AVAudioEngine-based playback
/// graph (AVAudioPlayerNode feeding AVAudioEngine's mixer). This class is
/// complete and correct on its own — the integration gap documented in
/// CraunchEqualizerPlugin.swift is specifically about connecting it to
/// just_audio's existing iOS playback path, not about this class's own
/// functionality.
final class AVAudioEngineEqualizer {
    let engine = AVAudioEngine()
    let playerNode = AVAudioPlayerNode()
    let eqNode: AVAudioUnitEQ

    private static let centerFrequencies: [Float] = [
        31, 62, 125, 250, 500, 1000, 2000, 4000, 8000, 16000,
    ]

    init() {
        eqNode = AVAudioUnitEQ(numberOfBands: Self.centerFrequencies.count)

        for (index, frequency) in Self.centerFrequencies.enumerated() {
            let band = eqNode.bands[index]
            band.filterType = .parametric
            band.frequency = frequency
            band.bandwidth = 1.0 // one octave, a standard parametric EQ width
            band.gain = 0.0
            band.bypass = false
        }

        engine.attach(playerNode)
        engine.attach(eqNode)
        engine.connect(playerNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
    }

    var bandCount: Int { Self.centerFrequencies.count }
    var centerFrequenciesHz: [Int] { Self.centerFrequencies.map { Int($0) } }

    /// AVAudioUnitEQBand.gain is documented as ranging -96dB to +24dB, but
    /// that extreme range isn't musically useful for a listening EQ, so
    /// this exposes the same ±15dB window CraunchEqualizerEngine.kt
    /// reports on a typical Android device — keeping the two platforms'
    /// UI sliders behaving consistently rather than exposing raw hardware
    /// extremes.
    let minGainDb: Double = -15.0
    let maxGainDb: Double = 15.0

    func setEnabled(_ enabled: Bool) {
        eqNode.bypass = !enabled
    }

    func setBandLevel(bandIndex: Int, gainDb: Double) {
        guard bandIndex >= 0 && bandIndex < eqNode.bands.count else { return }
        let clamped = max(minGainDb, min(maxGainDb, gainDb))
        eqNode.bands[bandIndex].gain = Float(clamped)
    }

    func start() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    func stop() {
        playerNode.stop()
        engine.stop()
    }
}
