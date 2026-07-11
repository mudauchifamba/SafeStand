# SafeStand

**An offline early-warning app that helps Zimbabwean home-seekers spot risky land deals before they pay.**

Submitted to the POTRAZ *AI for Impact Challenge 2026* — Development Track.

---

## The problem

Thousands of Zimbabwean families lose their life savings, and later their homes, to
land barons who sell stands they have no legal right to sell. Buyers are handed
"offer letters" from unregistered cooperatives, pay in cash, build — and are later
declared illegal occupants when bulldozers arrive. Government inquiries (e.g. the
Uchena Commission) have documented widespread illegal sales of state and council
land, and enforcement operations have made thousands of arrests, yet the buyers are
usually the ones left homeless while the sellers walk free.

The advice given to buyers today ("verify at the district office, engage your own
conveyancer, check the deeds registry") is correct but slow, manual, and unknown to
most people until it is too late.

## What SafeStand does

SafeStand is a **risk-triage tool, not a legal-verification service.** It cannot
declare a stand legally clean — there is no public, queryable land registry to check
against. What it *can* do is flag risk fast, based on known patterns, and route the
user to the correct authorities before they hand over money.

A user can:

1. **Enter stand details** — stand number, area, seller/cooperative name.
2. **Scan an offer letter / agreement of sale** — on-device OCR extracts the text.

SafeStand then:

- Checks the details against a bundled database of documented fraud cases and
  high-risk areas (compiled from public news, court judgments on ZimLII, and
  anti-corruption commission reports).
- Runs a red-flag rule engine over any scanned document (missing council reference,
  no Surveyor-General / Diagram number, "regularise later" language, cash-only
  payment, payment to an individual, etc.).
- Returns a **Green / Amber / Red** verdict with a plain-language explanation of
  *why*, and **recommended next steps** pointing to the Deeds Registry, the
  Surveyor-General, and the Registrar of Cooperative Societies.

Everything runs **offline** — important where the buyers most at risk have patchy
mobile data.

## Honest scope & safeguards

- SafeStand outputs a **risk signal, not a legal ruling.** This is stated in-app.
- Cases are flagged **by documented pattern and area**, with a cited public source
  for every specific claim. Named entities are only shown where a public,
  citable source (news report, court judgment) exists — to avoid defamation and to
  avoid the tool itself becoming a weapon.
- Crowdsourced reports (a future feature) are held as **"unverified — under review"**
  until corroborated.

## Tech

- **Flutter** (Android first)
- `google_mlkit_text_recognition` — on-device OCR (offline)
- Local bundled JSON for the known-cases database and red-flag rules
- Pure-Dart rule engine (`lib/services/risk_scorer.dart`) — auditable and testable

## Project structure

```
lib/
  models/        data classes (KnownCase, ScanResult, RiskVerdict)
  services/      risk_scorer.dart, case_repository.dart, ocr_service.dart
  screens/       home, manual entry, scan, result
  widgets/       shared UI components
assets/data/     known_cases.json, red_flag_rules.json, specimen manifest
test/            unit tests for the scorer
```

## Getting started

```bash
flutter pub get
flutter run           # on a connected Android device or emulator
flutter test          # run the scorer unit tests
```

## Team

_(add names + roles — 2 to 5 Zimbabwean citizens, per challenge rules)_

## Status

Prototype built for the AI for Impact Challenge 2026. Seed dataset of documented
cases; designed to grow via moderated user reports and, post-incubation, partnerships
with the City of Harare, ZACC, and Zimbabwe Lawyers for Human Rights.
