# SafeStand — Testing & Validation Evidence

Run everything: `flutter analyze` (expected: no issues) and `flutter test`
(expected: **51 tests, all passing**).

## What each suite guards

| Suite | Tests | What it proves |
|---|---|---|
| `risk_scorer_test.dart` | 4 | Rule engine: fraudulent letter scores RED, genuine council letter GREEN, **registered cooperative is NOT over-flagged** (fairness guard), known high-risk area raises score |
| `fraud_classifier_test.dart` | 5 | **The honest AI metric**: the shipped Dart model reproduces 100% (17/17) on the held-out real-style specimens it never trained on; obvious fraud scores high / genuine scores low; stamp-concept behavioural test (official dated stamp reads safer than imitation/misspelled stamps); explainability output non-empty |
| `remote_check_test.dart` | 12 | Geometry forensics: haversine correctness, gazetteer matching, EXIF GPS findings, and the **honesty asymmetry** — GPS mismatch raises risk, GPS match never lowers it, missing GPS is neutral, stale photos flagged |
| `pin_check_test.dart` | 9 | Pin parsing (raw coords, Google Maps links, **comma-decimal locales**, junk rejection) and pin-vs-area / photo-vs-pin scoring |
| `wetland_test.dart` | 8 | Wetland layer: inside/near/none detection, citable scoring, EMA next-step, and **no double-counting** between the mapped layer and AI vlei signals |
| `land_context_test.dart` | 12 | AI scoring guardrails: wetland/dense-build-up flags, informational classes stay zero-weight, unavailable AI ignored entirely, **blind cross-examination** (contradiction flags, innocent-difference tolerance, agreement stays zero-weight, unknown skips), tile math |
| `tools/icon_generator_test.dart` | 1 | Icon pipeline reproducibility |

## Validation beyond unit tests

- **Model validation**: `tool/train_model.dart` re-evaluates every retrain against
  the sacred held-out set and **refuses to export** below 100% — a regression gate,
  not just a report. `ml/eval_report.json` records the current result.
- **Synthetic data validation**: `ml/validate_synthetic.py` +
  `ml/synthetic_validation_report.json` (disclosed generation, distribution checks).
- **End-to-end device testing** (manual, on Samsung SM-A057F / Android 14):
  scan flow against the 10 stamped specimen PDFs in `test_docs/`; remote-check flow
  against scripted pins (Monavale Vlei inside-hit, boundary edge-hit, clean control,
  Lake Chivero water); AI photo check with genuine photos and listing screenshots.
- **Real failure found via field testing and fixed**: algae-green reservoir water
  misread as vegetation by the vision model → fixed (context tile + prompt
  guidance), then re-verified on device. Logged here as honest evidence that
  testing changed the product.

## Known bugs / open items

- Flaky USB debug link on the dev machine (tooling, not app).
- Stamp rim text OCRs with extra spaces ("CI TY OF HARARE") — expected for curved
  text; scoring tokenisation is unaffected.
- Satellite tiles show a spinner indefinitely on very slow connections — timeout UX
  polish scheduled in pilot window.
