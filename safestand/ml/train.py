"""
train.py — data-agnostic classifier training for SafeStand.

Reads ANY CSV conforming to ml/DATA_CONTRACT.md. It does not know or care
whether rows are synthetic or real. Advancing to the real POTRAZ dataset is:

    python train.py --data ml/data/real_training.csv --eval ml/data/real_eval.csv

...and comparing the eval numbers to the synthetic-trained baseline.

Phase 1 (offline v1): TF-IDF + logistic regression — tiny, on-device, explainable.
Phase 2 (robust v2): swap the vectoriser for sentence embeddings (see --model),
without touching the data pipeline or eval harness.

Usage:
    python train.py                       # trains on synthetic, evals on real held-out
    python train.py --include-unverified  # opt-in to verified=0 rows (flagged in report)
"""
import argparse, csv, json, os, sys
from collections import Counter

from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import cross_val_score
import numpy as np

REQUIRED_COLS = {"text", "label", "doc_type", "source", "verified"}


def load(path, include_unverified=False):
    rows = []
    with open(path, newline="") as f:
        reader = csv.DictReader(f)
        missing = REQUIRED_COLS - set(reader.fieldnames or [])
        if missing:
            sys.exit(f"ERROR: {path} missing required columns: {missing}")
        for r in reader:
            if not include_unverified and str(r.get("verified", "1")).strip() == "0":
                continue
            rows.append(r)
    return rows


def build_model(kind="tfidf"):
    if kind == "tfidf":
        return Pipeline([
            ("tfidf", TfidfVectorizer(ngram_range=(1, 2), min_df=2, sublinear_tf=True)),
            ("lr", LogisticRegression(max_iter=1000, class_weight="balanced")),
        ])
    raise SystemExit(f"Unknown model kind: {kind} (phase-2 embeddings not wired in this build)")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default="ml/data/synthetic_training.csv")
    ap.add_argument("--eval", default="ml/data/real_eval.csv")
    ap.add_argument("--model", default="tfidf")
    ap.add_argument("--include-unverified", action="store_true")
    ap.add_argument("--report", default="ml/eval_report.json")
    args = ap.parse_args()

    train = load(args.data, args.include_unverified)
    eval_rows = load(args.eval, include_unverified=True)  # eval always uses all rows

    Xtr = [r["text"] for r in train]
    ytr = [r["label"] for r in train]
    Xte = [r["text"] for r in eval_rows]
    yte = [r["label"] for r in eval_rows]

    n_unverified = sum(1 for r in train if str(r.get("verified","1")).strip() == "0")

    print(f"Training rows: {len(train)}  ({args.data})")
    print(f"  label balance: {dict(Counter(ytr))}")
    print(f"  source balance: {dict(Counter(r['source'] for r in train))}")
    if n_unverified:
        print(f"  WARNING: {n_unverified} unverified rows included in training (--include-unverified)")
    print(f"Held-out eval rows: {len(eval_rows)}  ({args.eval})")

    model = build_model(args.model)

    # In-distribution CV (reference only — near-perfect on synthetic is expected & meaningless)
    cv = cross_val_score(model, Xtr, ytr, cv=5)
    print(f"\nIn-distribution {args.model} 5-fold CV: {cv.mean():.3f} +/- {cv.std():.3f}")
    print("  (this number is NOT the headline; the held-out eval below is)")

    # Fit and evaluate on held-out
    model.fit(Xtr, ytr)
    preds = model.predict(Xte)
    proba = model.predict_proba(Xte)
    classes = list(model.classes_)
    correct = sum(p == t for p, t in zip(preds, yte))
    acc = correct / len(yte) if yte else 0.0

    print(f"\n== HELD-OUT EVAL (the honest metric) ==")
    print(f"Out-of-distribution accuracy: {correct}/{len(yte)} = {acc:.0%}\n")
    for r, p, pr in zip(eval_rows, preds, proba):
        conf = pr[classes.index(p)]
        mark = "OK " if p == r["label"] else "XX "
        print(f"  {mark} true={r['label']:11s} pred={p:11s} conf={conf:.2f}  [{r['doc_type']}] {r['text'][:44]}...")

    report = {
        "train_file": args.data,
        "eval_file": args.eval,
        "model": args.model,
        "train_rows": len(train),
        "train_label_balance": dict(Counter(ytr)),
        "unverified_rows_in_training": n_unverified,
        "in_distribution_cv_mean": round(float(cv.mean()), 4),
        "held_out_accuracy": round(acc, 4),
        "held_out_correct": correct,
        "held_out_total": len(yte),
    }
    os.makedirs(os.path.dirname(args.report), exist_ok=True)
    with open(args.report, "w") as f:
        json.dump(report, f, indent=2)
    print(f"\nWrote {args.report}")


if __name__ == "__main__":
    main()
