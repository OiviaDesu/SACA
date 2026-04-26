"""
Step 2: Fine-tune openai/whisper-small on English health corpus.

References:
  - Hugging Face Whisper fine-tuning guide
  - arxiv.org/abs/2503.18485  (Whisper fine-tuning for low-resource languages)

Hardware recommendation:
  - AWS EC2 g4dn.xlarge (T4 GPU, 16 GB VRAM) or local GPU with ≥8 GB VRAM
  - ~2–4 hours training on MedDialog-Audio subset

pip install transformers datasets accelerate evaluate jiwer soundfile librosa
"""

import torch
from dataclasses import dataclass
from typing import Any, Dict, List, Union

from datasets import load_from_disk, DatasetDict
from transformers import (
    WhisperFeatureExtractor,
    WhisperTokenizer,
    WhisperProcessor,
    WhisperForConditionalGeneration,
    Seq2SeqTrainingArguments,
    Seq2SeqTrainer,
)
import evaluate

# ──────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────
MODEL_NAME = "openai/whisper-small"
LANGUAGE = "English"
TASK = "transcribe"
SAVE_PATH = "./model_output/saca-whisper-small-en"
DATA_PATH = "./data/raw/med_dialog_audio"

# ──────────────────────────────────────────────
# Load processor & model
# ──────────────────────────────────────────────
feature_extractor = WhisperFeatureExtractor.from_pretrained(MODEL_NAME)
tokenizer = WhisperTokenizer.from_pretrained(MODEL_NAME, language=LANGUAGE, task=TASK)
processor = WhisperProcessor.from_pretrained(MODEL_NAME, language=LANGUAGE, task=TASK)
model = WhisperForConditionalGeneration.from_pretrained(MODEL_NAME)
model.generation_config.language = LANGUAGE.lower()
model.generation_config.task = TASK
model.generation_config.forced_decoder_ids = None


# ──────────────────────────────────────────────
# Dataset preparation
# ──────────────────────────────────────────────
def prepare_dataset(batch):
    audio = batch["audio"]
    batch["input_features"] = feature_extractor(
        audio["array"], sampling_rate=audio["sampling_rate"]
    ).input_features[0]
    text_col = "transcript" if "transcript" in batch else "text"
    batch["labels"] = tokenizer(batch[text_col]).input_ids
    return batch


@dataclass
class DataCollatorSpeechSeq2SeqWithPadding:
    processor: Any

    def __call__(self, features: List[Dict[str, Union[List[int], torch.Tensor]]]):
        input_features = [
            {"input_features": f["input_features"]} for f in features
        ]
        batch = self.processor.feature_extractor.pad(
            input_features, return_tensors="pt"
        )

        label_features = [{"input_ids": f["labels"]} for f in features]
        labels_batch = self.processor.tokenizer.pad(
            label_features, return_tensors="pt"
        )
        labels = labels_batch["input_ids"].masked_fill(
            labels_batch.attention_mask.ne(1), -100
        )
        # Strip <bos> token if present
        if (labels[:, 0] == self.processor.tokenizer.bos_token_id).all():
            labels = labels[:, 1:]
        batch["labels"] = labels
        return batch


# ──────────────────────────────────────────────
# Metrics
# ──────────────────────────────────────────────
wer_metric = evaluate.load("wer")

def compute_metrics(pred):
    pred_ids = pred.predictions
    label_ids = pred.label_ids
    label_ids[label_ids == -100] = tokenizer.pad_token_id

    pred_str = tokenizer.batch_decode(pred_ids, skip_special_tokens=True)
    label_str = tokenizer.batch_decode(label_ids, skip_special_tokens=True)

    wer = 100 * wer_metric.compute(predictions=pred_str, references=label_str)
    return {"wer": wer}


# ──────────────────────────────────────────────
# Training
# ──────────────────────────────────────────────
def train():
    raw_ds = load_from_disk(DATA_PATH)

    # Split into train/test if not already split
    if isinstance(raw_ds, dict):
        ds = DatasetDict(raw_ds)
    else:
        split = raw_ds.train_test_split(test_size=0.1, seed=42)
        ds = DatasetDict({"train": split["train"], "test": split["test"]})

    ds = ds.map(
        prepare_dataset,
        remove_columns=ds.column_names["train"],
        num_proc=4,
    )

    collator = DataCollatorSpeechSeq2SeqWithPadding(processor=processor)

    training_args = Seq2SeqTrainingArguments(
        output_dir=SAVE_PATH,
        per_device_train_batch_size=16,
        gradient_accumulation_steps=1,
        learning_rate=1e-5,
        warmup_steps=500,
        max_steps=4000,
        gradient_checkpointing=True,
        fp16=True,
        evaluation_strategy="steps",
        per_device_eval_batch_size=8,
        predict_with_generate=True,
        generation_max_length=225,
        save_steps=1000,
        eval_steps=1000,
        logging_steps=25,
        report_to=["tensorboard"],
        load_best_model_at_end=True,
        metric_for_best_model="wer",
        greater_is_better=False,
        push_to_hub=False,
    )

    trainer = Seq2SeqTrainer(
        args=training_args,
        model=model,
        train_dataset=ds["train"],
        eval_dataset=ds["test"],
        data_collator=collator,
        compute_metrics=compute_metrics,
        tokenizer=processor.feature_extractor,
    )

    trainer.train()
    trainer.save_model(SAVE_PATH)
    print(f"\n[SACA] Model saved to {SAVE_PATH}")


if __name__ == "__main__":
    train()
