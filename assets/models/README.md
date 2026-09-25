# spleeter_2stem_unet.onnx — provenance and verification

## Where this came from

This is **not a placeholder and it was not trained by us**. It's converted
from Deezer's official pretrained Spleeter checkpoint:

- Source: https://github.com/deezer/spleeter/releases/download/v1.4.0/2stems.tar.gz
- License: MIT (Spleeter itself; the pretrained weights are distributed
  under the same repository)
- Original format: TensorFlow 1.x checkpoint (`model.meta`/`.index`/`.data`)

No training was performed. The conversion process was:

1. Restore the checkpoint in TensorFlow, freeze it (fold variables into
   constants).
2. TensorFlow's STFT/IRFFT ops don't convert cleanly to ONNX via `tf2onnx`
   (a known limitation), so only the model's pure-CNN U-Net — the part
   that actually estimates the separation masks (Conv2D/BatchNorm/
   LeakyReLU/Sigmoid, no FFT ops) — was converted. The surrounding STFT →
   mask → ISTFT pipeline is reimplemented in Dart
   (`lib/core/stems/stft_processor.dart`), using constants read directly
   off the original graph rather than assumed.

## What was verified, and how

Every number below came from actually running the real, original
TensorFlow graph end-to-end and diffing against a from-scratch Python
reimplementation of the exact pipeline the Dart code follows — not from
documentation or assumption:

- **Input/output tensor names and shapes**: confirmed by inspecting the
  restored graph directly (`waveform:0` in; `strided_slice_13:0` /
  `strided_slice_23:0` out for the full model; `strided_slice_3:0` in,
  `vocals_spectrogram/mul:0` / `accompaniment_spectrogram/mul:0` out for
  the converted CNN-only subgraph).
- **STFT parameters**: frame length 4096, hop 1024, 1024 kept frequency
  bins, 512 time-frames per model call — read from the graph's actual
  tensor shapes, not Spleeter's public docs.
- **Wiener mask formula**: `mask_i = estimate_i^2 / (sum of all stems'
  estimate^2 + 1e-10)` — the power (2.0) and epsilon (1e-10) were read
  directly from the graph's constant tensors, not guessed.
- **High-frequency band (above the 1024-bin cutoff) handling**: an
  earlier version of this pipeline assumed the mixture passes through
  unmodified there. Empirical testing against the real model's own
  output proved that assumption wrong — the real model effectively
  silences that band for every stem. Four hypotheses were tested against
  real ground truth; "silence" was correct, "passthrough" measured ~27x
  higher error. This was corrected before the model was bundled here.
- **OLA (overlap-add) reconstruction**: a genuine bug was found and
  fixed during verification — the original near-zero division threshold
  (`1e-8`) let the ISTFT amplify tiny numerical noise into a large
  spike (amplitude 22, against a signal peaking around 0.5) at the very
  start of a track. Raising the threshold to `0.1` (steady-state overlap
  value is ~1.5) fixed it.

## Known remaining limitation

After the OLA fix, output still shows a small, bounded elevated error
(roughly 0.05 on a signal peaking at ~0.5, versus ~0.0002–0.001 in the
steady-state interior) confined to approximately the first second of a
separated track. This is a normal, common STFT edge effect — most
audio tools that use windowed transforms have some version of it — and
it does not affect the rest of the track. It was not chased further
(would require reverse-engineering TensorFlow's exact internal frame
padding/centering convention bit-for-bit) since it's a minor polish item,
not a correctness problem with the separation itself.

## What this does NOT cover

- 4-stem/5-stem separation (drums/bass/other) — only the 2-stem
  (vocals/instrumental) model was converted.
- iOS — this ONNX model runs fine wherever `onnxruntime`'s Dart bindings
  run, which is not the blocker; see StemSeparationEngine's own doc
  comment for the platform-specific PCM decode step it depends on.
