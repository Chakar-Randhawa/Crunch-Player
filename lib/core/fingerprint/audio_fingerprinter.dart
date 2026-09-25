import 'dart:math' as math;
import 'dart:typed_data';

import 'fft.dart';
import 'fingerprint_models.dart';
import 'pcm_source.dart';

/// Generates a fingerprint that is self-consistent within this app —
/// suitable for detecting duplicate/near-duplicate tracks already in the
/// user's own library — but is **not** compatible with AcoustID's
/// fingerprint format. AcoustID's lookup service requires a bit-exact
/// Chromaprint fingerprint, which means running the actual libchromaprint
/// C library (open source, BSD-licensed, from acoustid.org); a
/// from-scratch reimplementation like this one will not match anything
/// in their database even though the underlying idea (spectral
/// peak/energy fingerprinting) is the same family of technique. Wiring
/// real AcoustID lookups would mean vendoring libchromaprint via JNI —
/// the same category of gap as libmp3lame for the MP3 demuxer — plus a
/// developer's own AcoustID API key, which is a free but external
/// registration this code can't fabricate. See AcoustIdClient's doc
/// comment for what that would look like once both pieces exist.
class AudioFingerprinter {
  static const int _frameSize = 4096;
  static const int _hopSize = 2048; // 50% overlap
  static const int _bandCount = 6;
  // Log-spaced band edges (in FFT bins for a 4096-point FFT at 44.1kHz)
  // roughly covering 20Hz-5kHz, where most perceptually distinguishing
  // musical energy concentrates.
  static const List<int> _bandEdges = [10, 20, 40, 80, 160, 320, 640];
  static const int _targetZoneSize = 5; // how many subsequent peaks each anchor pairs with

  Future<TrackFingerprint> generate(String audioFilePath) async {
    final pcmSource = const PcmSource();
    final mono = await pcmSource.decodeToMonoFloat(audioFilePath);

    final peaksByFrame = <List<_Peak>>[];
    final window = _hannWindow(_frameSize);

    for (int start = 0; start + _frameSize <= mono.length; start += _hopSize) {
      final frame = Float64List(_frameSize);
      for (int i = 0; i < _frameSize; i++) {
        frame[i] = mono[start + i] * window[i];
      }

      final spectrum = Fft.magnitudeSpectrum(frame);
      peaksByFrame.add(_strongestPeakPerBand(spectrum));
    }

    final hashes = <FingerprintHash>[];
    for (int t = 0; t < peaksByFrame.length; t++) {
      for (final anchor in peaksByFrame[t]) {
        final zoneEnd = math.min(t + _targetZoneSize, peaksByFrame.length);
        for (int t2 = t + 1; t2 < zoneEnd; t2++) {
          for (final target in peaksByFrame[t2]) {
            final deltaTime = t2 - t;
            final hash = _combineHash(anchor.bin, target.bin, deltaTime);
            hashes.add(FingerprintHash(hash, t));
          }
        }
      }
    }

    final totalFrames = peaksByFrame.length;
    final durationMs = (totalFrames * _hopSize / 44100 * 1000).round();

    return TrackFingerprint(hashes: hashes, analysisDuration: Duration(milliseconds: durationMs));
  }

  List<_Peak> _strongestPeakPerBand(Float64List spectrum) {
    final peaks = <_Peak>[];
    for (int b = 0; b < _bandCount; b++) {
      final lo = _bandEdges[b];
      final hi = math.min(_bandEdges[b + 1], spectrum.length);
      if (hi <= lo) continue;

      int bestBin = lo;
      double bestMagnitude = spectrum[lo];
      for (int bin = lo + 1; bin < hi; bin++) {
        if (spectrum[bin] > bestMagnitude) {
          bestMagnitude = spectrum[bin];
          bestBin = bin;
        }
      }
      // Skip near-silent bands entirely rather than hashing noise-floor
      // peaks, which would otherwise pollute matching with meaningless
      // hashes during quiet passages.
      if (bestMagnitude > 0.001) peaks.add(_Peak(bestBin, bestMagnitude));
    }
    return peaks;
  }

  /// Packs (freq1, freq2, deltaTime) into a single 32-bit hash: 12 bits
  /// each for the two frequency bins (spectrum bins comfortably fit in
  /// 12 bits at this frame size) and 8 bits for the time delta between
  /// them (capped at the target zone size, which never exceeds 255).
  int _combineHash(int bin1, int bin2, int deltaTime) {
    return ((bin1 & 0xFFF) << 20) | ((bin2 & 0xFFF) << 8) | (deltaTime & 0xFF);
  }

  Float64List _hannWindow(int size) {
    final window = Float64List(size);
    for (int i = 0; i < size; i++) {
      window[i] = 0.5 * (1 - math.cos(2 * math.pi * i / (size - 1)));
    }
    return window;
  }
}

class _Peak {
  final int bin;
  final double magnitude;
  const _Peak(this.bin, this.magnitude);
}
