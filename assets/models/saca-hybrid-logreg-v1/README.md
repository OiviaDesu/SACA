# SACA Hybrid LogReg v1

On-device JSON export of the hybrid LogisticRegression diagnosis model.

- Features: TF-IDF + symptom one-hot + severity one-hot + source flags.
- Benchmark: top-1 93.35%, top-3 98.76%, top-5 99.32% on hybrid split.
- Gurindji support: dictionary normalization layer, not full free-text language model.
