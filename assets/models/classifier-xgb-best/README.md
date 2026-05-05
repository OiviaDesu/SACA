# Staged XGBoost Diagnosis Bundle

This bundle is exported from the best inspected HPC XGBoost diagnosis run:

```text
/fred/oz396/dunguyen/saca_whisper/outputs/classifier_diagnosis_multi_xgb/best_model.joblib
```

It is a 24-class diagnosis classifier trained from the cleaned
`normalized_diagnosis_dataset.csv` split. It is staged for parity testing and
future Flutter integration after the LR ONNX path is stable.

Do not make this bundle the default classifier until a parity report confirms
the Dart bundle runtime matches the Python `best_model.joblib` predictions.
