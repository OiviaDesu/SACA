from pathlib import Path
import json
import pandas as pd

PIPELINE_ROOT = Path(__file__).resolve().parents[1]
DATA = PIPELINE_ROOT / "data"
OUT = PIPELINE_ROOT / "outputs" / "local_data_audit"
OUT.mkdir(parents=True, exist_ok=True)

files = sorted([p for p in DATA.rglob("*") if p.is_file() and p.suffix.lower() in {'.csv', '.json', '.jsonl', '.xlsx', '.xls'}])
summary = []
for p in files:
    item = {"file": str(p.relative_to(PIPELINE_ROOT)), "size_bytes": p.stat().st_size}
    print(f"\n=== {p.name} ===", flush=True)
    try:
        if p.suffix.lower() == '.csv':
            df = pd.read_csv(p)
        elif p.suffix.lower() in {'.xlsx', '.xls'}:
            df = pd.read_excel(p)
        elif p.suffix.lower() == '.jsonl':
            df = pd.read_json(p, lines=True)
        else:
            df = pd.read_json(p)
        item["rows"] = int(len(df))
        item["cols"] = list(map(str, df.columns))
        item["missing"] = {str(k): int(v) for k, v in df.isna().sum().items()}
        item["samples"] = df.head(3).astype(str).to_dict(orient="records")
        print(f"rows={len(df)} cols={list(df.columns)}", flush=True)
        for col in df.columns[:8]:
            vc = df[col].astype(str).value_counts(dropna=False).head(5).to_dict()
            print(f"top[{col}]={vc}", flush=True)
    except Exception as e:
        item["error"] = repr(e)
        print(f"ERROR {repr(e)}", flush=True)
    summary.append(item)

(OUT / "audit_summary.json").write_text(json.dumps(summary, indent=2, ensure_ascii=False), encoding="utf-8")
print(f"\nWROTE {OUT / 'audit_summary.json'}", flush=True)
