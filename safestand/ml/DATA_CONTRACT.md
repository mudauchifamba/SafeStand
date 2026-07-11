# SafeStand data contract

This file defines the schema every training example must follow — synthetic
today, real tomorrow. As long as a dataset conforms to this, advancing from
synthetic to the real POTRAZ-provided dataset is a **retrain, not a rebuild**:
drop the real CSV in, run `train.py`, compare eval numbers.

## Why this exists

The prize for a strong entry may be access to a real, labelled dataset. The
architectural risk is coupling the model to the *shape* of the synthetic data.
This contract prevents that: `train.py` reads any CSV matching the schema and
is blind to whether rows are synthetic or real.

## Schema (CSV columns)

| column          | type    | required | values / notes                                              |
|-----------------|---------|----------|-------------------------------------------------------------|
| `text`          | string  | yes      | Full OCR'd or transcribed document text.                    |
| `label`         | string  | yes      | `fraudulent` or `genuine`. The primary training target.     |
| `doc_type`      | string  | yes      | `offer_letter`, `cession`, `agreement_of_sale`, `deed_of_transfer`, `other`. Secondary target / stratification. |
| `source`        | string  | yes      | `synthetic` for generated rows; for real rows, a provenance string (e.g. `court:ZimLII HH-123-25`, `partner:CoH`). |
| `verified`      | int     | yes      | `1` if the label is corroborated (court record, council confirmation); `0` if unverified (e.g. crowdsourced, pending review). |
| `region`        | string  | no       | Area/suburb if known (e.g. `Budiriro`). Blank if unknown.   |
| `case_id`       | string  | no       | Stable ID for deduplication and provenance tracking.        |

## Rules

1. **Never train on `verified = 0` rows without flagging it.** Unverified rows
   may enter training only when explicitly enabled, and the eval report must
   note it. This protects against poisoned / defamatory crowdsourced data.
2. **The held-out real test set is sacred.** Real specimens used for evaluation
   (`data/real_eval.csv`) are NEVER added to training. This is how we prove a
   model generalises rather than memorises.
3. **`source` must be honest.** Synthetic rows are labelled `synthetic` so any
   eval can separate in-distribution from out-of-distribution performance.
4. **Labels come from evidence, not assumption.** A document is only
   `fraudulent` where a public/citable source or a corroborated report supports
   it — never inferred from the seller's name or area alone.

## Migration checklist (when real data arrives)

- [ ] Confirm the real CSV has the required columns above (rename/ map if needed).
- [ ] Keep the existing synthetic file; add the real file as a second input.
- [ ] Move a stratified slice of *real* data into `data/real_eval.csv` (held out).
- [ ] Run `train.py --data <real.csv> --eval data/real_eval.csv`.
- [ ] Compare eval metrics: real-trained vs synthetic-trained on the same held-out set.
- [ ] If real-trained wins (expected), ship it. If not, investigate before shipping.
