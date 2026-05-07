from __future__ import annotations

import argparse
import csv
import difflib
import json
from collections import defaultdict
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


def _metric_rows(
    rows: list[dict[str, str]],
    predictions: list[str],
    references: list[str],
    normalized_predictions: list[str],
    normalized_references: list[str],
) -> list[dict[str, str | float]]:
    output: list[dict[str, str | float]] = []
    for row, prediction, reference, pred_norm, ref_norm in zip(
        rows,
        predictions,
        references,
        normalized_predictions,
        normalized_references,
        strict=True,
    ):
        output.append(
            {
                "id": row.get("id", ""),
                "label_type": row.get("label_type", ""),
                "ref": reference,
                "pred": prediction,
                "ref_norm": ref_norm,
                "pred_norm": pred_norm,
                "raw_cer": jiwer.cer(reference, prediction),
                "norm_cer": jiwer.cer(ref_norm, pred_norm),
                "raw_wer": jiwer.wer(reference, prediction),
                "norm_wer": jiwer.wer(ref_norm, pred_norm),
                "audio": row.get("audio", ""),
            }
        )
    return output


def _per_label_summary(metric_rows: list[dict[str, str | float]]) -> list[str]:
    grouped: dict[str, dict[str, list[str]]] = defaultdict(
        lambda: {"ref": [], "pred": [], "ref_norm": [], "pred_norm": []}
    )
    for row in metric_rows:
        label_type = str(row["label_type"] or "unknown")
        grouped[label_type]["ref"].append(str(row["ref"]))
        grouped[label_type]["pred"].append(str(row["pred"]))
        grouped[label_type]["ref_norm"].append(str(row["ref_norm"]))
        grouped[label_type]["pred_norm"].append(str(row["pred_norm"]))

    lines: list[str] = []
    for label_type in sorted(grouped):
        group = grouped[label_type]
        lines.extend(
            [
                f"{label_type}/count={len(group['ref'])}",
                f"{label_type}/raw_wer={jiwer.wer(group['ref'], group['pred']):.6f}",
                f"{label_type}/raw_cer={jiwer.cer(group['ref'], group['pred']):.6f}",
                f"{label_type}/norm_wer={jiwer.wer(group['ref_norm'], group['pred_norm']):.6f}",
                f"{label_type}/norm_cer={jiwer.cer(group['ref_norm'], group['pred_norm']):.6f}",
            ]
        )
    return lines


def _mapping_candidates(
    metric_rows: list[dict[str, str | float]],
) -> list[dict[str, str | int]]:
    candidates: dict[tuple[str, str], dict[str, object]] = {}
    for row in metric_rows:
        pred_tokens = str(row["pred_norm"]).split()
        ref_tokens = str(row["ref_norm"]).split()
        matcher = difflib.SequenceMatcher(a=pred_tokens, b=ref_tokens, autojunk=False)
        for tag, pred_start, pred_end, ref_start, ref_end in matcher.get_opcodes():
            if tag != "replace":
                continue
            pred_span = pred_tokens[pred_start:pred_end]
            ref_span = ref_tokens[ref_start:ref_end]
            if len(pred_span) != 1 or len(ref_span) != 1:
                continue
            pred_token = pred_span[0]
            ref_token = ref_span[0]
            if pred_token == ref_token:
                continue
            key = (pred_token, ref_token)
            entry = candidates.setdefault(
                key,
                {"pred_token": pred_token, "ref_token": ref_token, "count": 0, "example_ids": []},
            )
            entry["count"] = int(entry["count"]) + 1
            example_ids = entry["example_ids"]
            assert isinstance(example_ids, list)
            row_id = str(row["id"])
            if row_id and row_id not in example_ids:
                example_ids.append(row_id)

    sorted_entries = sorted(
        candidates.values(),
        key=lambda item: (-int(item["count"]), str(item["pred_token"]), str(item["ref_token"])),
    )
    return [
        {
            "pred_token": str(entry["pred_token"]),
            "ref_token": str(entry["ref_token"]),
            "count": int(entry["count"]),
            "example_ids": ",".join(str(value) for value in entry["example_ids"]),
        }
        for entry in sorted_entries
    ]


def _write_tsv(path: Path, rows: list[dict[str, str | float | int]], fieldnames: list[str]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames, delimiter="\t")
        writer.writeheader()
        writer.writerows(rows)


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
    parser.add_argument("--audit-tsv", type=Path)
    parser.add_argument("--mapping-candidates", type=Path)
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
    metric_rows = _metric_rows(
        rows,
        predictions,
        references,
        normalized_predictions,
        normalized_references,
    )
    summary = [
        f"raw_wer={jiwer.wer(references, predictions):.6f}",
        f"raw_cer={jiwer.cer(references, predictions):.6f}",
        f"norm_wer={jiwer.wer(normalized_references, normalized_predictions):.6f}",
        f"norm_cer={jiwer.cer(normalized_references, normalized_predictions):.6f}",
    ]
    summary.extend(_per_label_summary(metric_rows))
    summary.extend(f"warning={warning}" for warning in mapping_warnings)
    summary.append("")
    text = "\n".join(summary + lines)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text, encoding="utf-8")
    if args.audit_tsv:
        _write_tsv(
            args.audit_tsv,
            metric_rows,
            [
                "id",
                "label_type",
                "ref",
                "pred",
                "ref_norm",
                "pred_norm",
                "raw_cer",
                "norm_cer",
                "raw_wer",
                "norm_wer",
                "audio",
            ],
        )
    if args.mapping_candidates:
        _write_tsv(
            args.mapping_candidates,
            _mapping_candidates(metric_rows),
            ["pred_token", "ref_token", "count", "example_ids"],
        )
    print(text)


if __name__ == "__main__":
    main()
