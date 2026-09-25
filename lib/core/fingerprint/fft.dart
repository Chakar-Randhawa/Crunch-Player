import 'dart:math' as math;
import 'dart:typed_data';

/// Iterative radix-2 Cooley-Tukey FFT, in place. Input length must be a
/// power of two — callers are responsible for zero-padding, since that
/// policy differs by use case (the fingerprinter pads the last partial
/// frame; a different caller might prefer truncation).
class Fft {
  const Fft._();

  static void transform(Float64List real, Float64List imag) {
    final n = real.length;
    assert(imag.length == n);
    assert((n & (n - 1)) == 0, 'FFT length must be a power of two, got $n');
    if (n <= 1) return;

    // Bit-reversal permutation.
    for (int i = 1, j = 0; i < n; i++) {
      int bit = n >> 1;
      for (; (j & bit) != 0; bit >>= 1) {
        j ^= bit;
      }
      j ^= bit;
      if (i < j) {
        final tempReal = real[i];
        real[i] = real[j];
        real[j] = tempReal;
        final tempImag = imag[i];
        imag[i] = imag[j];
        imag[j] = tempImag;
      }
    }

    for (int length = 2; length <= n; length <<= 1) {
      final angle = -2 * math.pi / length;
      final wReal = math.cos(angle);
      final wImag = math.sin(angle);

      for (int start = 0; start < n; start += length) {
        double curReal = 1.0;
        double curImag = 0.0;

        for (int k = 0; k < length ~/ 2; k++) {
          final evenIndex = start + k;
          final oddIndex = start + k + length ~/ 2;

          final oddReal = real[oddIndex] * curReal - imag[oddIndex] * curImag;
          final oddImag = real[oddIndex] * curImag + imag[oddIndex] * curReal;

          real[oddIndex] = real[evenIndex] - oddReal;
          imag[oddIndex] = imag[evenIndex] - oddImag;
          real[evenIndex] += oddReal;
          imag[evenIndex] += oddImag;

          final nextCurReal = curReal * wReal - curImag * wImag;
          final nextCurImag = curReal * wImag + curImag * wReal;
          curReal = nextCurReal;
          curImag = nextCurImag;
        }
      }
    }
  }

  /// Inverse FFT via the standard conjugate trick: conjugate the input,
  /// run the forward transform, conjugate the result, and scale by 1/n —
  /// avoids needing a second, separately-maintained transform
  /// implementation that could drift out of sync with the forward one.
  static void inverseTransform(Float64List real, Float64List imag) {
    final n = real.length;
    for (int i = 0; i < n; i++) {
      imag[i] = -imag[i];
    }
    transform(real, imag);
    for (int i = 0; i < n; i++) {
      real[i] /= n;
      imag[i] = -imag[i] / n;
    }
  }

  /// Returns the magnitude spectrum (length n/2 + 1, the non-redundant
  /// half for a real-valued input signal) for [samples], which is padded
  /// with zeros up to the next power of two if needed.
  static Float64List magnitudeSpectrum(Float64List samples) {
    int n = 1;
    while (n < samples.length) {
      n <<= 1;
    }

    final real = Float64List(n);
    final imag = Float64List(n);
    real.setRange(0, samples.length, samples);

    transform(real, imag);

    final half = n ~/ 2 + 1;
    final magnitude = Float64List(half);
    for (int i = 0; i < half; i++) {
      magnitude[i] = math.sqrt(real[i] * real[i] + imag[i] * imag[i]);
    }
    return magnitude;
  }
}
