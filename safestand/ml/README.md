# SafeStand — ML pipeline

This directory holds the AI reasoning layer: a text classifier that learns the
fraudulent-vs-genuine boundary from labelled documents, rather than a hardcoded
keyword list.

## Files

- `DATA_CONTRACT.md` — the schema all training data must follow. **Read this first.**
- `generate_synthetic.py` — produces the bootstrap synthetic dataset (contract-conforming).
- `data/synthetic_training.csv` — 900 varied synthetic docs (label-balanced).
- `data/real_eval.csv` — real specimen documents, **held out, never trained on.**
- `train.py` — data-agnostic trainer. Reads any contract-conforming CSV.
- `eval_report.json` — metrics from the last run.

## The honest evaluation story

Training on synthetic data risks a model that only memorises the generator's
patterns. We guard against this by **evaluating on real held-out specimens the
model never saw.** The headline metric is therefore *out-of-distribution*
accuracy on real documents — not the (meaningless) near-perfect in-distribution
score on synthetic data. `train.py` prints both and labels which is which.

Current bootstrap result: trained on 900 synthetic docs, **10/10 correct on real
held-out specimens**, including correctly classifying *registered* cooperatives
as genuine (the model did not learn "cooperative = fraud").

## Phased model plan

- **Phase 1 (this build): TF-IDF + logistic regression.** Tiny (kilobytes),
  runs on-device/offline, fully explainable — every term's contribution is
  inspectable. Ideal for low-connectivity users.
- **Phase 2 (with real data): sentence embeddings + classifier head.** More
  robust to unseen phrasing. Swap the vectoriser in `build_model()` — the data
  contract, training loop, and eval harness are unchanged.

## Advancing to the real dataset (the whole point)

Because `train.py` is blind to data provenance, migrating from synthetic to the
real POTRAZ-provided dataset is a **retrain, not a rebuild**:

```bash
# 1. Ensure the real file matches DATA_CONTRACT.md columns.
# 2. Hold out a stratified slice as real evaluation data.
# 3. Retrain and compare against the synthetic baseline:
python ml/train.py --data ml/data/real_training.csv --eval ml/data/real_eval.csv
```

Compare `held_out_accuracy` in `eval_report.json` before and after. If real-data
training wins (expected), ship it. This comparison IS the evidence that access to
real data advanced the project.

## The stamp concept

Genuine official documents carry a dated, file-referenced office stamp;
imitations get it wrong — no date, no reference, misspellings ("OFICIAL"),
marketing language ("APPROVED", "PAY TODAY"). OCR picks stamp text up, so the
training data simulates this: genuine rows carry official-stamp phrases,
fraudulent rows carry imitation-stamp phrases or none. The specimen PDFs in
`test_docs/` render matching visual stamps (consistent official design on
genuine docs; progressively wrong shape/colour/content on fakes).

## Retraining without Python

`tool/train_model.dart` (run `dart run tool/train_model.dart` from the app
root) replicates this pipeline — same vectoriser settings, same balanced
logistic regression, same export schema — and refuses to export if held-out
accuracy drops. Use it where Python isn't available; `train.py` remains the
canonical reference.

## Phase 3 (roadmap): seasonal wetland classifier

Harare's demolition-risk wetlands are mostly vleis — seasonally wet grassland
that looks dry and buildable in single-date RGB imagery. The app currently
layers (1) an offline documented-wetland lookup (authoritative data, not AI)
and (2) vision-LLM vlei-indicator detection. Phase 3 trains our own
classifier on wet-season/dry-season Sentinel-2 pairs, using ESA WorldCover's
wetland class + the documented Harare vleis as free labels — detecting
*unmapped* wetlands on-device. Needs an imagery pipeline (Python/GEE);
planned for when a training environment is available.

## Relationship to the rule engine

`lib/services/risk_scorer.dart` (the red-flag rules) is NOT the AI — it is the
**explainability layer**. The classifier produces the risk score; the rules
translate it into plain-language reasons a user (or a lawyer) can audit. Model
decision + human-readable justification is the responsible-AI pattern for a
high-stakes context.
