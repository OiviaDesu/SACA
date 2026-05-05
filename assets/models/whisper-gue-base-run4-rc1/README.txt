SACA STT RC1 mobile model

Expected file:
ggml-gue-whisper-base-run4-ckpt200-rc1-q5_0.bin

Source checkpoint:
/fred/oz396/dunguyen/saca_whisper/outputs/whisper-base-gue-example-only-run4/checkpoint-200

Model family:
openai/whisper-base multilingual, fine-tuned on Gurindji example_sentence data.

Validation metrics on run4 checkpoint-200:
raw_wer=0.850450
raw_cer=0.258774
norm_wer=0.706564
norm_cer=0.241265

Test metrics on run4 checkpoint-200:
raw_wer=0.818722
raw_cer=0.231899
norm_wer=0.662910
norm_cer=0.210436

English smoke:
Three short English clinical TTS clips transcribed correctly during remote whisper.cpp smoke.

Caveat:
RC1 is demo/release-candidate only. English and Gurindji support is smoke-tested, not clinically or officially language validated.
