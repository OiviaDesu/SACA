"""Fine-tune multilingual Whisper on local Gurindji + English ASR data.

Current repo note:
- Local DoReCo folder currently contains annotation files (.eaf/.TextGrid/.xml)
  and metadata CSV, but no audio files were found during inspection.
- Fine-tuning cannot start until waveform files exist.
- This script therefore supports two stages:
  1) manifest validation from existing local CSV/JSONL manifest
  2) training once audio paths are available

Reference implementation updated from current Hugging Face Transformers
speech-recognition seq2seq example and Whisper docs.
"""

from __future__ import annotations

import argparse
import json
import math
import random
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import numpy as np
import pandas as pd

try:
    import evaluate
    import torch
    from datasets import Audio, Dataset, DatasetDict
    from transformers import (
        AutoModelForSpeechSeq2Seq,
        AutoProcessor,
        Seq2SeqTrainer,
        Seq2SeqTrainingArguments,
        set_seed,
    )
except ImportError:  # pragma: no cover
    evaluate = None
    torch = None
    Audio = None
    Dataset = None
    DatasetDict = None
    AutoModelForSpeechSeq2Seq = None
    AutoProcessor = None
    Seq2SeqTrainer = None
    Seq2SeqTrainingArguments = None
    set_seed = None


PIPELINE_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DATA_ROOT = PIPELINE_ROOT.parent / "Data"
DEFAULT_OUTPUT_ROOT = PIPELINE_ROOT / "outputs" / "whisper_gurindji"
SUPPORTED_AUDIO_SUFFIXES = {".wav", ".flac", ".mp3", ".m4a", ".ogg", ".opus"}
LANGUAGE_NORMALIZATION = {
    "en": "english",
    "eng": "english",
    "english": "english",
    "gurindji": "gurindji",
    "gk": "gurindji-kriol",
    "gurindji kriol": "gurindji-kriol",
    "gurindji-kriol": "gurindji-kriol",
    "mixed": "gurindji-kriol",
    "mixed gurindji": "gurindji-kriol",
}


@dataclass
class DataCollatorSpeechSeq2SeqWithPadding:
    processor: Any
    decoder_start_token_id: int
    forward_attention_mask: bool = False

    def __call__(self, features: list[dict[str, Any]]) -> dict[str, torch.Tensor]:
        model_input_name = self.processor.model_input_names[0]
        input_features = [{model_input_name: feature[model_input_name]} for feature in features]
        label_features = [{"input_ids": feature["labels"]} for feature in features]

        batch = self.processor.feature_extractor.pad(input_features, return_tensors="pt")

        if self.forward_attention_mask:
            batch["attention_mask"] = torch.LongTensor([feature["attention_mask"] for feature in features])

        labels_batch = self.processor.tokenizer.pad(label_features, return_tensors="pt")
        labels = labels_batch["input_ids"].masked_fill(labels_batch.attention_mask.ne(1), -100)

        if (labels[:, 0] == self.decoder_start_token_id).all().cpu().item():
            labels = labels[:, 1:]

        batch["labels"] = labels
        return batch


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fine-tune multilingual Whisper on Gurindji + English local data.")
    parser.add_argument("--data-root", default=str(DEFAULT_DATA_ROOT), help="Root folder with local corpus files.")
    parser.add_argument("--manifest", default="", help="CSV or JSONL manifest with columns: audio,text,language,speaker_id,source_id")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_ROOT), help="Output folder for manifests and checkpoints.")
    parser.add_argument("--model-name", default="openai/whisper-small", help="Base Whisper checkpoint.")
    parser.add_argument("--mode", choices=["validate", "train"], default="validate", help="Validate manifest or run training.")
    parser.add_argument("--train-split", type=float, default=0.8, help="Train fraction when splitting by source_id.")
    parser.add_argument("--eval-split", type=float, default=0.1, help="Eval fraction when splitting by source_id.")
    parser.add_argument("--test-split", type=float, default=0.1, help="Test fraction when splitting by source_id.")
    parser.add_argument("--num-proc", type=int, default=1, help="Datasets map workers.")
    parser.add_argument("--max-duration", type=float, default=30.0, help="Drop segments longer than this many seconds.")
    parser.add_argument("--min-duration", type=float, default=0.2, help="Drop segments shorter than this many seconds.")
    parser.add_argument("--learning-rate", type=float, default=1e-5)
    parser.add_argument("--warmup-steps", type=int, default=100)
    parser.add_argument("--max-steps", type=int, default=1000)
    parser.add_argument("--per-device-train-batch-size", type=int, default=4)
    parser.add_argument("--per-device-eval-batch-size", type=int, default=4)
    parser.add_argument("--gradient-accumulation-steps", type=int, default=4)
    parser.add_argument("--eval-steps", type=int, default=100)
    parser.add_argument("--save-steps", type=int, default=100)
    parser.add_argument("--logging-steps", type=int, default=10)
    parser.add_argument("--generation-max-length", type=int, default=225)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--fp16", action="store_true", help="Use fp16 if CUDA supports it.")
    parser.add_argument("--bf16", action="store_true", help="Use bf16 if CUDA supports it.")
    parser.add_argument("--gradient-checkpointing", action="store_true", help="Enable gradient checkpointing.")
    return parser.parse_args()


def normalize_language(value: Any) -> str:
    text = str(value).strip().lower() if value is not None else ""
    return LANGUAGE_NORMALIZATION.get(text, text or "unknown")


def has_training_dependencies() -> bool:
    return all(
        item is not None
        for item in [
            evaluate,
            torch,
            Audio,
            Dataset,
            DatasetDict,
            AutoModelForSpeechSeq2Seq,
            AutoProcessor,
            Seq2SeqTrainer,
            Seq2SeqTrainingArguments,
            set_seed,
        ]
    )


def find_audio_files(data_root: Path) -> list[Path]:
    return sorted([p for p in data_root.rglob("*") if p.suffix.lower() in SUPPORTED_AUDIO_SUFFIXES])


def load_manifest(path: Path) -> pd.DataFrame:
    if not path.exists():
        raise FileNotFoundError(f"Manifest not found: {path}")
    if path.suffix.lower() == ".csv":
        return pd.read_csv(path)
    if path.suffix.lower() == ".jsonl":
        return pd.read_json(path, lines=True)
    if path.suffix.lower() == ".json":
        return pd.read_json(path)
    raise ValueError(f"Unsupported manifest format: {path}")


def resolve_audio_path(path_text: str, data_root: Path) -> Path:
    candidate = Path(str(path_text))
    if candidate.is_absolute():
        return candidate
    return (data_root / candidate).resolve()


def validate_manifest(df: pd.DataFrame, data_root: Path, output_dir: Path, min_duration: float, max_duration: float) -> dict[str, Any]:
    required = ["audio", "text"]
    missing_required = [col for col in required if col not in df.columns]
    if missing_required:
        raise ValueError(f"Manifest missing required columns: {missing_required}")

    frame = df.copy()
    if "language" not in frame.columns:
        frame["language"] = "unknown"
    if "speaker_id" not in frame.columns:
        frame["speaker_id"] = "unknown"
    if "source_id" not in frame.columns:
        frame["source_id"] = frame["audio"].astype(str).map(lambda x: Path(x).stem)
    if "duration_sec" not in frame.columns:
        frame["duration_sec"] = np.nan

    frame["language"] = frame["language"].map(normalize_language)
    frame["text"] = frame["text"].fillna("").astype(str).map(lambda x: " ".join(x.split()))
    frame["audio_path"] = frame["audio"].map(lambda x: str(resolve_audio_path(x, data_root)))
    frame["audio_exists"] = frame["audio_path"].map(lambda x: Path(x).exists())
    frame["text_len"] = frame["text"].map(len)
    frame["word_len"] = frame["text"].map(lambda x: len(x.split()))

    valid = frame[(frame["audio_exists"]) & (frame["text"] != "")].copy()
    if "duration_sec" in valid.columns:
        valid["duration_sec"] = pd.to_numeric(valid["duration_sec"], errors="coerce")
        valid = valid[(valid["duration_sec"].isna()) | ((valid["duration_sec"] >= min_duration) & (valid["duration_sec"] <= max_duration))].copy()

    output_dir.mkdir(parents=True, exist_ok=True)
    valid_manifest_path = output_dir / "validated_manifest.csv"
    valid.to_csv(valid_manifest_path, index=False)

    audit = {
        "input_rows": int(len(frame)),
        "valid_rows": int(len(valid)),
        "missing_audio_rows": int((~frame["audio_exists"]).sum()),
        "empty_text_rows": int((frame["text"] == "").sum()),
        "languages": frame["language"].value_counts(dropna=False).to_dict(),
        "valid_languages": valid["language"].value_counts(dropna=False).to_dict(),
        "speakers": int(frame["speaker_id"].nunique()),
        "sources": int(frame["source_id"].nunique()),
        "sample_missing_audio": frame.loc[~frame["audio_exists"], ["audio", "audio_path"]].head(20).to_dict(orient="records"),
        "sample_rows": valid.head(10).to_dict(orient="records"),
        "validated_manifest": str(valid_manifest_path),
    }
    (output_dir / "manifest_audit.json").write_text(json.dumps(audit, indent=2, ensure_ascii=False), encoding="utf-8")
    return audit


def split_manifest_by_source(df: pd.DataFrame, train_split: float, eval_split: float, test_split: float, seed: int) -> dict[str, pd.DataFrame]:
    total = train_split + eval_split + test_split
    if not math.isclose(total, 1.0, rel_tol=1e-5, abs_tol=1e-5):
        raise ValueError(f"Splits must sum to 1.0, got {total}")

    source_ids = sorted(df["source_id"].dropna().astype(str).unique().tolist())
    if len(source_ids) < 3:
        raise ValueError("Need at least 3 unique source_id values for train/eval/test split without leakage.")

    rng = random.Random(seed)
    rng.shuffle(source_ids)

    n_total = len(source_ids)
    n_train = max(1, int(round(n_total * train_split)))
    n_eval = max(1, int(round(n_total * eval_split)))
    n_test = n_total - n_train - n_eval
    if n_test < 1:
        n_test = 1
        if n_train > n_eval:
            n_train -= 1
        else:
            n_eval -= 1

    train_ids = set(source_ids[:n_train])
    eval_ids = set(source_ids[n_train:n_train + n_eval])
    test_ids = set(source_ids[n_train + n_eval:])

    return {
        "train": df[df["source_id"].astype(str).isin(train_ids)].copy(),
        "eval": df[df["source_id"].astype(str).isin(eval_ids)].copy(),
        "test": df[df["source_id"].astype(str).isin(test_ids)].copy(),
    }


def dataframe_to_dataset(frame: pd.DataFrame) -> Dataset:
    columns = [col for col in ["audio_path", "text", "language", "speaker_id", "source_id", "duration_sec"] if col in frame.columns]
    ds = Dataset.from_pandas(frame[columns].rename(columns={"audio_path": "audio"}), preserve_index=False)
    ds = ds.cast_column("audio", Audio(sampling_rate=16_000))
    return ds


def build_dataset_dict(valid_manifest_path: Path, train_split: float, eval_split: float, test_split: float, seed: int, output_dir: Path) -> DatasetDict:
    df = pd.read_csv(valid_manifest_path)
    splits = split_manifest_by_source(df, train_split, eval_split, test_split, seed)
    split_summary = {
        name: {
            "rows": int(len(split_df)),
            "languages": split_df["language"].value_counts(dropna=False).to_dict(),
            "sources": int(split_df["source_id"].nunique()),
            "speakers": int(split_df["speaker_id"].nunique()),
        }
        for name, split_df in splits.items()
    }
    (output_dir / "split_summary.json").write_text(json.dumps(split_summary, indent=2, ensure_ascii=False), encoding="utf-8")
    return DatasetDict({name: dataframe_to_dataset(split_df) for name, split_df in splits.items()})


def prepare_dataset_builder(processor: Any, forward_attention_mask: bool):
    model_input_name = processor.model_input_names[0]

    def prepare_dataset(batch: dict[str, Any]) -> dict[str, Any]:
        sample = batch["audio"]
        inputs = processor.feature_extractor(
            sample["array"],
            sampling_rate=sample["sampling_rate"],
            return_attention_mask=forward_attention_mask,
        )
        batch[model_input_name] = inputs.get(model_input_name)[0]
        if forward_attention_mask and "attention_mask" in inputs:
            batch["attention_mask"] = inputs["attention_mask"][0]
        batch["input_length"] = len(sample["array"]) / sample["sampling_rate"]
        batch["labels"] = processor.tokenizer(batch["text"]).input_ids
        return batch

    return prepare_dataset


def train_whisper(args: argparse.Namespace, manifest_path: Path) -> None:
    if not has_training_dependencies():
        raise ImportError(
            "Missing Whisper training dependencies. Run: python -m pip install -r python_pipeline/requirements/whisper.txt"
        )
    if torch is None or not torch.cuda.is_available():
        raise RuntimeError("CUDA GPU required for Whisper fine-tuning on this local setup.")

    set_seed(args.seed)
    output_dir = Path(args.output_dir)
    validated_manifest_path = output_dir / "validated_manifest.csv"
    if not validated_manifest_path.exists():
        manifest_df = load_manifest(manifest_path)
        validate_manifest(manifest_df, Path(args.data_root), output_dir, args.min_duration, args.max_duration)

    dataset_dict = build_dataset_dict(
        validated_manifest_path,
        train_split=args.train_split,
        eval_split=args.eval_split,
        test_split=args.test_split,
        seed=args.seed,
        output_dir=output_dir,
    )

    processor = AutoProcessor.from_pretrained(args.model_name)
    model = AutoModelForSpeechSeq2Seq.from_pretrained(args.model_name)

    # Gurindji not in Whisper language list. Keep multilingual decoder open.
    if hasattr(model.generation_config, "language"):
        model.generation_config.language = None
    if hasattr(model.generation_config, "task"):
        model.generation_config.task = "transcribe"
    model.generation_config.forced_decoder_ids = None
    model.config.forced_decoder_ids = None
    model.config.suppress_tokens = []

    if args.gradient_checkpointing:
        model.gradient_checkpointing_enable()

    forward_attention_mask = False
    prepare_dataset = prepare_dataset_builder(processor, forward_attention_mask)
    vectorized_datasets = dataset_dict.map(
        prepare_dataset,
        remove_columns=dataset_dict["train"].column_names,
        num_proc=args.num_proc,
    )

    wer_metric = evaluate.load("wer")
    cer_metric = evaluate.load("cer")

    def compute_metrics(pred):
        pred_ids = pred.predictions
        label_ids = pred.label_ids
        label_ids[label_ids == -100] = processor.tokenizer.pad_token_id

        pred_str = processor.tokenizer.batch_decode(pred_ids, skip_special_tokens=True)
        label_str = processor.tokenizer.batch_decode(label_ids, skip_special_tokens=True)
        return {
            "wer": float(wer_metric.compute(predictions=pred_str, references=label_str)),
            "cer": float(cer_metric.compute(predictions=pred_str, references=label_str)),
        }

    data_collator = DataCollatorSpeechSeq2SeqWithPadding(
        processor=processor,
        decoder_start_token_id=model.config.decoder_start_token_id,
        forward_attention_mask=forward_attention_mask,
    )

    training_args = Seq2SeqTrainingArguments(
        output_dir=str(output_dir / "checkpoints"),
        per_device_train_batch_size=args.per_device_train_batch_size,
        per_device_eval_batch_size=args.per_device_eval_batch_size,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        learning_rate=args.learning_rate,
        warmup_steps=args.warmup_steps,
        max_steps=args.max_steps,
        gradient_checkpointing=args.gradient_checkpointing,
        fp16=args.fp16,
        bf16=args.bf16,
        eval_strategy="steps",
        predict_with_generate=True,
        generation_max_length=args.generation_max_length,
        save_steps=args.save_steps,
        eval_steps=args.eval_steps,
        logging_steps=args.logging_steps,
        logging_first_step=True,
        logging_strategy="steps",
        disable_tqdm=True,
        load_best_model_at_end=True,
        metric_for_best_model="wer",
        greater_is_better=False,
        report_to="none",
        save_total_limit=2,
        remove_unused_columns=False,
    )

    trainer = Seq2SeqTrainer(
        model=model,
        args=training_args,
        train_dataset=vectorized_datasets["train"],
        eval_dataset=vectorized_datasets["eval"],
        processing_class=processor.feature_extractor,
        data_collator=data_collator,
        compute_metrics=compute_metrics,
    )

    trainer.train()
    trainer.save_model(str(output_dir / "final_model"))
    processor.save_pretrained(str(output_dir / "final_model"))

    test_metrics = trainer.predict(vectorized_datasets["test"]).metrics
    (output_dir / "test_metrics.json").write_text(json.dumps(test_metrics, indent=2, ensure_ascii=False), encoding="utf-8")


def main() -> None:
    args = parse_args()
    output_dir = Path(args.output_dir)
    output_dir.mkdir(parents=True, exist_ok=True)
    data_root = Path(args.data_root)

    audio_files = find_audio_files(data_root)
    corpus_probe = {
        "data_root": str(data_root),
        "audio_file_count": len(audio_files),
        "audio_examples": [str(path) for path in audio_files[:20]],
        "note": "Fine-tuning requires waveform audio. Current DoReCo folder inspection found 0 audio files in earlier repo scan.",
    }
    (output_dir / "corpus_probe.json").write_text(json.dumps(corpus_probe, indent=2, ensure_ascii=False), encoding="utf-8")

    if not args.manifest:
        raise FileNotFoundError(
            "Need --manifest CSV/JSONL with audio,text,language,speaker_id,source_id. Annotation files alone are not enough."
        )

    manifest_path = Path(args.manifest)
    manifest_df = load_manifest(manifest_path)
    audit = validate_manifest(manifest_df, data_root, output_dir, args.min_duration, args.max_duration)

    print(json.dumps({"mode": args.mode, "manifest_audit": audit}, indent=2, ensure_ascii=False))

    if args.mode == "train":
        if audit["valid_rows"] == 0:
            raise RuntimeError("No valid rows in manifest after validation.")
        if audit["missing_audio_rows"] > 0:
            raise RuntimeError("Manifest still has missing audio. Fix paths first.")
        train_whisper(args, manifest_path)


if __name__ == "__main__":
    main()
