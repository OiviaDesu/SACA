from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Any

import evaluate
import librosa
import soundfile as sf
import torch
from datasets import load_dataset
from transformers import (
    Seq2SeqTrainer,
    Seq2SeqTrainingArguments,
    WhisperForConditionalGeneration,
    WhisperProcessor,
)


@dataclass
class DataCollatorSpeechSeq2SeqWithPadding:
    processor: Any
    decoder_start_token_id: int

    def __call__(self, features: list[dict[str, Any]]) -> dict[str, torch.Tensor]:
        model_input_name = self.processor.model_input_names[0]
        input_features = [
            {model_input_name: feature[model_input_name]} for feature in features
        ]
        label_features = [{"input_ids": feature["labels"]} for feature in features]

        batch = self.processor.feature_extractor.pad(input_features, return_tensors="pt")
        labels_batch = self.processor.tokenizer.pad(label_features, return_tensors="pt")
        labels = labels_batch["input_ids"].masked_fill(
            labels_batch.attention_mask.ne(1),
            -100,
        )
        if (labels[:, 0] == self.decoder_start_token_id).all().cpu().item():
            labels = labels[:, 1:]
        batch["labels"] = labels
        return batch


def build_trainer(args: argparse.Namespace) -> tuple[Seq2SeqTrainer, Any]:
    processor = WhisperProcessor.from_pretrained(args.model_name)
    model = WhisperForConditionalGeneration.from_pretrained(args.model_name)
    _disable_unsupported_gue_language_tokens(model)

    data_files = {
        "train": str(args.data_dir / "train.jsonl"),
        "validation": str(args.data_dir / "validation.jsonl"),
        "test": str(args.data_dir / "test.jsonl"),
    }
    raw = load_dataset("json", data_files=data_files)
    model_input_name = processor.feature_extractor.model_input_names[0]

    def prepare_dataset(batch: dict[str, Any]) -> dict[str, Any]:
        audio_array, sampling_rate = _load_audio(Path(batch["audio"]))
        inputs = processor.feature_extractor(
            audio_array,
            sampling_rate=sampling_rate,
            return_attention_mask=False,
        )
        batch[model_input_name] = inputs[model_input_name][0]
        batch["input_length"] = len(audio_array)
        batch["labels"] = processor.tokenizer(batch["text"]).input_ids
        return batch

    vectorized = raw.map(
        prepare_dataset,
        remove_columns=raw["train"].column_names,
        num_proc=args.num_proc,
        desc="prepare whisper gue",
    )
    max_input_length = 30.0 * processor.feature_extractor.sampling_rate
    vectorized = vectorized.filter(
        lambda input_length: 0 < input_length < max_input_length,
        input_columns=["input_length"],
    )

    wer_metric = evaluate.load("wer")
    cer_metric = evaluate.load("cer")

    def compute_metrics(pred: Any) -> dict[str, float]:
        pred_ids = pred.predictions
        label_ids = pred.label_ids
        label_ids[label_ids == -100] = processor.tokenizer.pad_token_id
        pred_str = processor.tokenizer.batch_decode(pred_ids, skip_special_tokens=True)
        label_str = processor.tokenizer.batch_decode(label_ids, skip_special_tokens=True)
        return {
            "wer": wer_metric.compute(predictions=pred_str, references=label_str),
            "cer": cer_metric.compute(predictions=pred_str, references=label_str),
        }

    training_args = Seq2SeqTrainingArguments(
        output_dir=str(args.output_dir),
        per_device_train_batch_size=args.per_device_train_batch_size,
        gradient_accumulation_steps=args.gradient_accumulation_steps,
        per_device_eval_batch_size=args.per_device_eval_batch_size,
        learning_rate=args.learning_rate,
        warmup_steps=args.warmup_steps,
        num_train_epochs=args.num_train_epochs,
        gradient_checkpointing=args.gradient_checkpointing,
        fp16=args.fp16,
        eval_strategy="steps",
        eval_steps=args.eval_steps,
        save_steps=args.save_steps,
        logging_steps=args.logging_steps,
        logging_strategy="steps",
        logging_first_step=True,
        disable_tqdm=True,
        predict_with_generate=True,
        generation_max_length=args.generation_max_length,
        load_best_model_at_end=True,
        metric_for_best_model="cer",
        greater_is_better=False,
        report_to="none",
        push_to_hub=False,
    )
    trainer = Seq2SeqTrainer(
        model=model,
        args=training_args,
        train_dataset=vectorized["train"],
        eval_dataset=vectorized["validation"],
        data_collator=DataCollatorSpeechSeq2SeqWithPadding(
            processor=processor,
            decoder_start_token_id=model.config.decoder_start_token_id,
        ),
        compute_metrics=compute_metrics,
        processing_class=processor.feature_extractor,
    )
    return trainer, vectorized


def _disable_unsupported_gue_language_tokens(
    model: WhisperForConditionalGeneration,
) -> None:
    model.generation_config.language = None
    model.generation_config.task = None
    model.generation_config.forced_decoder_ids = None
    model.config.forced_decoder_ids = None
    model.config.suppress_tokens = []
    model.generation_config.suppress_tokens = []


def _load_audio(path: Path) -> tuple[Any, int]:
    audio_array, sampling_rate = sf.read(path, dtype="float32", always_2d=False)
    if getattr(audio_array, "ndim", 1) > 1:
        audio_array = audio_array.mean(axis=1)
    target_rate = 16000
    if sampling_rate != target_rate:
        audio_array = librosa.resample(
            audio_array,
            orig_sr=sampling_rate,
            target_sr=target_rate,
        )
        sampling_rate = target_rate
    return audio_array, sampling_rate


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Fine-tune Whisper small for Gurindji.")
    parser.add_argument("--data-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--model-name", default="openai/whisper-small")
    parser.add_argument("--num-proc", type=int, default=1)
    parser.add_argument("--per-device-train-batch-size", type=int, default=4)
    parser.add_argument("--gradient-accumulation-steps", type=int, default=4)
    parser.add_argument("--per-device-eval-batch-size", type=int, default=4)
    parser.add_argument("--learning-rate", type=float, default=1e-5)
    parser.add_argument("--warmup-steps", type=int, default=100)
    parser.add_argument("--num-train-epochs", type=float, default=10)
    parser.add_argument("--eval-steps", type=int, default=100)
    parser.add_argument("--save-steps", type=int, default=100)
    parser.add_argument("--logging-steps", type=int, default=10)
    parser.add_argument("--generation-max-length", type=int, default=225)
    parser.add_argument("--fp16", action="store_true")
    parser.add_argument("--gradient-checkpointing", action="store_true")
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    trainer, vectorized = build_trainer(args)
    print("dataset", vectorized)
    if args.dry_run:
        print("dry_run=true; training skipped")
        return
    trainer.train()
    print(trainer.evaluate(vectorized["test"]))


if __name__ == "__main__":
    main()
