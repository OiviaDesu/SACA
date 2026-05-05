from __future__ import annotations

import argparse
import json
from pathlib import Path

import jiwer
import torch
from transformers import WhisperForConditionalGeneration, WhisperProcessor

from training.train_whisper_gue import _disable_unsupported_gue_language_tokens, _load_audio
from whisper_metrics import load_orthography_mapping, normalize_for_metric


def load_rows(path: Path, limit: int) -> list[dict[str, str]]:
    rows: list[dict[str, str]] = []
    with path.open(encoding="utf-8") as handle:
        for line in handle:
            if line.strip():
                rows.append(json.loads(line))
            if len(rows) >= limit:
                break
    return rows


def main() -> None:
    parser = argparse.ArgumentParser(description="Audit Gurindji Whisper decode samples.")
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument(
        "--processor",
        type=Path,
        help="Whisper processor/tokenizer path. Defaults to --model when tokenizer files exist.",
    )
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument(
        "--orthography-mapping",
        type=Path,
        default=Path(__file__).resolve().parent / "orthography_mapping.tsv",
    )
    parser.add_argument("--hyphen-mode", choices=["space", "keep"], default="space")
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--batch-size", type=int, default=4)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    processor_path = args.processor or args.model
    orthography_mapping, mapping_warnings = load_orthography_mapping(args.orthography_mapping)
    processor = WhisperProcessor.from_pretrained(processor_path)
    model = WhisperForConditionalGeneration.from_pretrained(args.model)
    _disable_unsupported_gue_language_tokens(model)
    model.eval()
    if torch.cuda.is_available():
        model.to("cuda")

    rows = load_rows(args.manifest, args.limit)
    predictions: list[str] = []
    references: list[str] = []
    lines: list[str] = []

    for batch_start in range(0, len(rows), args.batch_size):
        batch_rows = rows[batch_start : batch_start + args.batch_size]
        audio_arrays = []
        sampling_rate = 16000
        for row in batch_rows:
            audio, sampling_rate = _load_audio(Path(row["audio"]))
            audio_arrays.append(audio)
        inputs = processor.feature_extractor(
            audio_arrays,
            sampling_rate=sampling_rate,
            return_tensors="pt",
            return_attention_mask=False,
        )
        input_features = inputs.input_features.to(model.device)
        with torch.no_grad():
            predicted_ids = model.generate(input_features, max_length=225)
        batch_predictions = processor.tokenizer.batch_decode(
            predicted_ids,
            skip_special_tokens=True,
        )
        for offset, (row, prediction) in enumerate(
            zip(batch_rows, batch_predictions, strict=True),
            1,
        ):
            index = batch_start + offset
            prediction = prediction.strip()
            reference = row["text"].strip()
            predictions.append(prediction)
            references.append(reference)
            lines.extend(
                [
                    f"[{index}]",
                    f"PRED: {prediction}",
                    f"REF : {reference}",
                    "",
                ]
            )

    normalized_predictions = [
        normalize_for_metric(text, orthography_mapping, hyphen_mode=args.hyphen_mode)
        for text in predictions
    ]
    normalized_references = [
        normalize_for_metric(text, orthography_mapping, hyphen_mode=args.hyphen_mode)
        for text in references
    ]
    summary = [
        f"raw_wer={jiwer.wer(references, predictions):.6f}",
        f"raw_cer={jiwer.cer(references, predictions):.6f}",
        f"norm_wer={jiwer.wer(normalized_references, normalized_predictions):.6f}",
        f"norm_cer={jiwer.cer(normalized_references, normalized_predictions):.6f}",
    ]
    summary.extend(f"warning={warning}" for warning in mapping_warnings)
    summary.append("")
    text = "\n".join(summary + lines)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
