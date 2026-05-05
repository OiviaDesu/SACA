SACA STT RC1 Windows sherpa-onnx model

Expected files:
encoder.onnx
decoder.onnx
tokens.txt

Source checkpoint:
/fred/oz396/dunguyen/saca_whisper/outputs/whisper-base-gue-example-only-run4/checkpoint-200

Model family:
openai/whisper-base multilingual, fine-tuned on Gurindji example_sentence data.

Validation metrics on run4 checkpoint-200:
raw_wer=0.850450
raw_cer=0.258774
norm_wer=0.706564
norm_cer=0.241265

Fallback:
If these RC1 ONNX assets are absent, Windows runtime falls back to assets/models/sherpa-onnx-whisper-base.

Caveat:
RC1 is demo/release-candidate only. English and Gurindji support must pass local Windows ONNX smoke before replacing fallback in builds.
