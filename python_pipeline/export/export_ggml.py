"""
Step 3: Export fine-tuned HuggingFace Whisper → ggml binary for whisper.cpp / whisper_kit.

This uses the official whisper.cpp conversion script:
  git clone https://github.com/ggerganov/whisper.cpp
  pip install -r whisper.cpp/requirements.txt

Quantization options (Q5_0 recommended for mobile balance):
  - F16   : ~310 MB  – full precision, best accuracy
  - Q5_0  : ~165 MB  – good accuracy, half the size (RECOMMENDED for Phase 1)
  - Q4_0  : ~130 MB  – slightly lower accuracy, smallest size
  - Q8_0  : ~240 MB  – near-lossless, larger

Usage:
  python 03_export_ggml.py --model_path ./model_output/saca-whisper-small-en
                           --quant Q5_0
                           --output ./model_output/ggml-saca-small-q5_0.bin
"""

import argparse
import subprocess
import sys
from pathlib import Path


def export_ggml(model_path: str, quant: str, output: str):
    model_path = Path(model_path).resolve()
    output = Path(output).resolve()
    output.parent.mkdir(parents=True, exist_ok=True)

    whisper_cpp = Path("./whisper.cpp")
    if not whisper_cpp.exists():
        print("[!] whisper.cpp not found. Cloning ...")
        subprocess.run(
            ["git", "clone", "--depth=1", "https://github.com/ggerganov/whisper.cpp"],
            check=True,
        )

    convert_script = whisper_cpp / "models" / "convert-h5-to-ggml.py"

    # Step 1: Convert HF → ggml F16
    fp16_path = output.with_suffix("").with_name(output.stem + "_fp16.bin")
    print(f"[1/2] Converting {model_path} → ggml F16 ...")
    subprocess.run(
        [sys.executable, str(convert_script), str(model_path), str(output.parent)],
        check=True,
    )

    # The script outputs: ggml-model.bin  in output dir
    ggml_fp16 = output.parent / "ggml-model.bin"

    if quant == "F16":
        ggml_fp16.rename(output)
        print(f"[2/2] Done (F16 – no quantization). Output: {output}")
        return

    # Step 2: Quantize
    quantize_bin = whisper_cpp / "build" / "bin" / "quantize"
    if not quantize_bin.exists():
        print("[!] whisper.cpp not compiled. Building ...")
        subprocess.run(["cmake", "-B", "build", "-S", "."], cwd=whisper_cpp, check=True)
        subprocess.run(["cmake", "--build", "build", "--config", "Release", "-j4"],
                       cwd=whisper_cpp, check=True)

    quant_type_map = {"Q4_0": "2", "Q5_0": "8", "Q8_0": "7"}
    quant_type = quant_type_map.get(quant, "8")

    print(f"[2/2] Quantizing F16 → {quant} ...")
    subprocess.run(
        [str(quantize_bin), str(ggml_fp16), str(output), quant_type],
        check=True,
    )
    ggml_fp16.unlink(missing_ok=True)
    size_mb = output.stat().st_size / (1024 * 1024)
    print(f"[SACA] Export complete: {output}  ({size_mb:.1f} MB)")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--model_path", default="./model_output/saca-whisper-small-en")
    parser.add_argument("--quant", choices=["F16", "Q4_0", "Q5_0", "Q8_0"], default="Q5_0")
    parser.add_argument("--output", default="./model_output/ggml-saca-small-q5_0.bin")
    args = parser.parse_args()
    export_ggml(args.model_path, args.quant, args.output)
