from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

import jiwer
import torch
from transformers import WhisperForConditionalGeneration, WhisperProcessor

from training.train_whisper_gue import _disable_unsupported_gue_language_tokens, _load_audio


def normalize_for_metric(text: str) -> str:
    text = text.lower()
    text = re.sub(r"[^\w\s-]", " ", text, flags=re.UNICODE)
    return re.sub(r"\s+", " ", text).strip()


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
    parser.add_argument("--manifest", type=Path, required=True)
    parser.add_argument("--limit", type=int, default=20)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    processor = WhisperProcessor.from_pretrained(args.model)
    model = WhisperForConditionalGeneration.from_pretrained(args.model)
    _disable_unsupported_gue_language_tokens(model)
    model.eval()
    if torch.cuda.is_available():
        model.to("cuda")

    rows = load_rows(args.manifest, args.limit)
    predictions: list[str] = []
    references: list[str] = []
    lines: list[str] = []

    for index, row in enumerate(rows, 1):
        audio, sampling_rate = _load_audio(Path(row["audio"]))
        inputs = processor.feature_extractor(
            audio,
            sampling_rate=sampling_rate,
            return_tensors="pt",
            return_attention_mask=False,
        )
        input_features = inputs.input_features.to(model.device)
        with torch.no_grad():
            predicted_ids = model.generate(input_features, max_length=225)
        prediction = processor.tokenizer.batch_decode(
            predicted_ids,
            skip_special_tokens=True,
        )[0].strip()
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

    normalized_predictions = [normalize_for_metric(text) for text in predictions]
    normalized_references = [normalize_for_metric(text) for text in references]
    summary = [
        f"raw_wer={jiwer.wer(references, predictions):.6f}",
        f"raw_cer={jiwer.cer(references, predictions):.6f}",
        f"normalized_wer={jiwer.wer(normalized_references, normalized_predictions):.6f}",
        f"normalized_cer={jiwer.cer(normalized_references, normalized_predictions):.6f}",
        "",
    ]
    text = "\n".join(summary + lines)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    print(text)


if __name__ == "__main__":
    main()
