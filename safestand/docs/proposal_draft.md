# AI4I Written Proposal — DRAFT for Word formatting

> **Formatting instructions (delete this block in Word):** Paste into Word/Google
> Docs. Arial 11 pt, 1.15 line spacing, 1-inch margins. Cover page separate
> (uncounted). Body must stay ≤ 10 pages — this draft is sized ~8.5 pages to leave
> room. Export as PDF named `[ProjectID]_AI4I_Proposal_Development.pdf` (PDF only —
> .docx submissions are disqualified). Replace `[ProjectID]` and `[Date]`.

---

## COVER PAGE

**Project Title:** SafeStand — Check Before You Pay
**Track:** Track 3 — Development
**Team Name:** SafeStand
**Lead Innovator:** Jimiel Chifamba
**Team:** Jimiel Chifamba (Team Lead — idea, design, development); Mthusi Mudau (design, development)
**Project ID:** [ProjectID]
**Date:** [Date]
**Repository:** github.com/mudauchifamba/SafeStand

---

## Section 1 — Problem Definition & Strategic Alignment

### 1.1 The problem

Thousands of Zimbabwean families lose their life savings — and later their homes —
to land barons who sell residential stands they have no legal right to sell. The
pattern is documented and repetitive: a buyer is handed an "offer letter" from an
unregistered cooperative or self-styled developer, pays USD 2,000–10,000 in cash,
builds, and is later declared an illegal occupant when demolitions begin. The
Uchena Commission of Inquiry documented widespread illegal sales of state and
council land; enforcement periodically produces arrests, but restitution for buyers
is rare. The economic loss lands on the household least able to absorb it, and the
social cost — demolished homes in Budiriro, Whitecliff, Retreat, Epworth — recurs
every year.

Two structural facts make this fraud durable. First, **the verification path is
manual and unknown**: confirming a stand requires visits to the Deeds Registry, the
Surveyor-General, the Registrar of Cooperative Societies and the local council —
offices most buyers cannot name, let alone navigate, before the seller's "pay today
or lose it" deadline expires. Second, **the fastest-growing victim group cannot
visit at all**: diaspora Zimbabweans buying land from the UK, South Africa and
beyond pay remotely on the strength of WhatsApp photos and a suburb name supplied
by the seller — the person with the strongest incentive to lie.

### 1.2 Target users and beneficiaries

- **Primary users:** (a) local home-seekers at the point of payment decision;
  (b) diaspora buyers purchasing remotely.
- **Secondary/professional users:** conveyancers, micro-lenders and banks
  pre-screening land-related transactions and collateral.
- **Beneficiaries:** home-seeking families (protected savings); local authorities
  and EMA (fewer illegal settlements and wetland invasions to reverse); the housing
  market (a demand-side deterrent that makes fraud harder to sell).

### 1.3 The solution in one paragraph

SafeStand is a mobile app that lets a buyer run an AI-assisted risk check on a land
deal **in seconds, before paying**. A buyer can scan the seller's offer letter or
agreement of sale — on-device OCR reads it and our own trained classifier scores it
against learned fraud patterns, fully offline — or check a stand remotely by
entering the claimed area, pasting the seller's location pin and adding the
seller's photos, which the app verifies against documented fraud cases, a wetlands
database, live satellite imagery and two independent AI analyses. Every check
returns a Green/Amber/Red risk verdict with plain-language, source-cited reasons
and concrete next steps naming the correct authority. SafeStand is explicitly a
**risk-triage tool, not a legal-verification service** — it cannot declare a deal
clean, and says so on every verdict; its job is to stop the money for long enough
that verification can happen.

### 1.4 Strategic alignment

- **Zimbabwe's National AI Strategy:** SafeStand is citizen-centred applied AI —
  a locally trained model, on local fraud patterns, deployed on-device so it works
  within local connectivity constraints; it demonstrates responsible-AI practice
  (explainability, human oversight, cited sources) rather than importing an opaque
  service.
- **National development priorities (housing and settlements):** national housing
  delivery goals are undermined when delivered stands and self-built homes are
  demolished as irregular; SafeStand attacks the demand side of land baronry, and
  its wetland layer reinforces environmental-protection enforcement (EMA) rather
  than competing with it.
- **Digital inclusion:** the core check is free and offline-capable, targeting
  low-connectivity, low-income users on entry-level Android phones.
- **POTRAZ AI4I objectives:** the project is designed to consume the Challenge's
  real dataset when provided — its training pipeline is contract-defined so real
  data is a retrain, not a rebuild (Section 3.4).

---

## Section 2 — Technical Design & Product Logic

### 2.1 Architecture overview

SafeStand v1 has **no backend server: the phone is the system**. This is a
deliberate product decision with three consequences: the core check works offline
(inclusion), marginal cost per check is zero (sustainability), and no user data
exists server-side (privacy and security by architecture).

```
USERS: local home-seeker (offline) · diaspora buyer (online)
   │
FLUTTER APP (Android, v1)
   ├── FLOW 1  Scan a document (fully offline)
   │     camera → ML Kit OCR [AI-1] → trained fraud classifier [AI-2]
   │     → red-flag rule engine (explainability layer)
   ├── FLOW 2  Check a stand (offline core + optional online AI)
   │     area/seller/stand → documented-cases DB
   │     seller's pin → wetlands DB · satellite tiles (Esri)
   │     seller's photos → EXIF forensics (offline)
   │     vision LLM [AI-3a]: satellite land-class + vlei indicators (online)
   │     vision LLM [AI-3b]: photo content/authenticity — BLIND (online)
   │     → deterministic cross-examination of 3a vs 3b (app code, not AI)
   └── RISK SCORER (deterministic, unit-tested)
         → GREEN / AMBER / RED + cited reasons + authority next steps

BUNDLED DATA (versioned JSON, ~100 KB): known_cases · red_flag_rules ·
gazetteer · wetlands · model_export (classifier weights)
EXTERNAL (online only, user-invoked): Esri World Imagery · Groq API (vision LLM)
```

**Stack:** Flutter/Dart (Android first); `google_mlkit_text_recognition`
(on-device OCR); our classifier exported to JSON and executed by ~200 lines of
pure-Dart arithmetic; `exif` for photo metadata; Groq-hosted
`meta-llama/llama-4-scout-17b-16e-instruct` for the two vision analyses; no
database engine — versioned JSON assets. API keys are injected at build time
(`--dart-define`), never committed.

### 2.2 The AI layer and its justification

The Track 3 rule we designed around: **forced AI is penalised**. SafeStand's
principle is the same rule stated positively — *AI where judgment of unseen input
is required; databases where an authority has already answered; deterministic code
where the question has an exact answer.* Every verdict reason is labelled with the
tier that produced it.

**AI-2 — our trained document classifier (the core AI contribution).**
TF-IDF (1–2 grams, sublinear TF, min_df 2) + balanced logistic regression, trained
on 900 synthetic documents generated to a published data contract and augmented
with a stamp-content concept (genuine documents carry dated, file-referenced
official stamps; imitations get the content wrong — missing dates, missing
references, misspellings such as "OFICIAL"). The model learns the statistical
boundary of how fraudulent vs genuine land documents are worded; the rule engine
stays in the loop as the explainability layer — the model decides, the rules
explain. **Why this model class:** ~50 KB, offline, milliseconds per inference on
entry-level phones, and every prediction decomposes into per-term contributions —
explainability is a hard requirement when output influences a family's savings. A
deep model would be slower, opaque, and unjustifiable at this data volume; a pure
rule system cannot generalise to unseen phrasing. Document score = 60% model + 40%
rules.

**AI-1 — on-device OCR (ML Kit).** Reading arbitrary photographed documents
(including stamp text) is a perception task with no rule-based equivalent.
Extracted text is shown to the user before scoring — a built-in human check.

**AI-3 — vision LLM, used twice, blind, then cross-examined.** No database says
what exists *today* at an arbitrary coordinate, and no formula judges photo
content; both are perception judgments. (a) The satellite analysis classifies land
cover at the seller's pin (close-up + zoomed-out context tiles) and reports
seasonal-wetland (vlei) indicators. (b) The photo analysis judges the seller's
photos **without ever seeing the satellite or pin**: what they show, the terrain
class, and authenticity tells (screenshot UI bars, watermarks, renders). The app —
deterministic, tested code — then cross-examines the two independent testimonies
with a conservative compatibility table: photos showing dense housing against a
bare-land satellite reading is a scored contradiction; bare land vs vegetation is
innocently compatible; agreement is a zero-weight note ("consistent" never proves
safety). Guardrails: temperature 0, strict JSON contracts with whitelisted enums,
failed calls ignored rather than guessed, and conservative scoring throughout.

**Deliberately not AI:** the wetlands and documented-cases checks are cited
database lookups (certainty must not be replaced by inference); EXIF/pin distance
checks are haversine geometry; the final scorer is deterministic and unit-tested.

### 2.3 Dataset statement

- **Used now:** 900 synthetic training documents (disclosed generator,
  `ml/generate_synthetic.py`, stamp-augmented); 17 held-out real-style specimen
  documents used **only** for evaluation, never trained on; four curated databases
  compiled from cited public sources (documented fraud cases; red-flag rules;
  30-place gazetteer; 12 documented Harare wetlands with indicative boundaries).
  No real personal data exists anywhere in the project.
- **Simulated:** all specimen documents are team-authored and watermarked
  "SPECIMEN — FICTIONAL".
- **Still required:** the real labelled dataset (POTRAZ-provided or partner-
  provided) for production-grade retraining; EMA wetland shapefiles to replace
  indicative circles (a data swap requiring zero code change).
- **Limitations disclosed:** synthetic training distribution; Harare-first
  coverage; English-first documents; wetland boundaries indicative — each is
  stated in-app or in-repo where the user meets it.

### 2.4 Validation and testing

- **The honest metric:** out-of-distribution accuracy on held-out real-style
  specimens: **17/17**, reproduced by the shipped Dart inference in an automated
  test on every run. The retraining tool refuses to export any model scoring below
  100% on the held-out set — a regression gate, not a report.
- **51 automated tests** across the scorer, classifier port, geometry forensics,
  pin parsing (including comma-decimal locales), wetland layer (including a
  no-double-counting guard between the mapped layer and AI vlei signals), and the
  cross-examination logic. A dedicated fairness test asserts that a registered
  cooperative with proper references is NOT over-flagged.
- **Field-tested failure, fixed and documented:** the vision model initially
  misread Lake Chivero's algae-green water as vegetation. Fixed with a zoomed-out
  context tile plus local-context prompt guidance ("reservoir water in Zimbabwe is
  often green"), then re-verified on device. We treat this as evidence the
  validation loop works.
- **Offline sync/handling:** not applicable in v1 — there is no server state to
  sync; online AI degrades gracefully to an honest "unavailable" state.

### 2.5 User interaction plan

Android app (Play Store + direct APK for pilot). Progressive disclosure: an area
name alone gives a database check; adding the seller's pin unlocks satellite,
wetland and geometry checks; adding photos unlocks the AI photo analysis. Every
verdict screen carries the caveat ("a risk signal, not a legal ruling"), cited
reasons ranked by weight, and named authorities as next steps. Localisation
(Shona/Ndebele) is a scale-phase item (Section 3.3).

---

## Section 3 — Deliverables & CCE Implementation Roadmap

### 3.1 Delivered at submission (evidence in repository)

| Deliverable | Location |
|---|---|
| Working Android MVP (two AI flows, splash, branding) | repo + demo APK |
| Trained classifier + export + Dart inference | `ml/`, `assets/ml/`, `lib/services/fraud_classifier.dart` |
| No-Python retraining tool with regression gate | `tool/train_model.dart` |
| Data contract + synthetic generator + validation reports | `ml/DATA_CONTRACT.md`, `ml/generate_synthetic.py`, `ml/*.json` |
| Four curated databases with citations | `assets/data/` |
| 51 automated tests, analyzer-clean codebase, structured commit history | `test/`, git log |
| Documentation pack: architecture, data & AI note (model card), risk & compliance checklist, testing evidence, business model, deployment plan, screenshots | `docs/` |
| Specimen document set (10 stamped PDFs) for judge testing | `test_docs/` |

Dependencies are pinned via `pubspec.lock` (Flutter/Dart's locked manifest);
`ml/requirements.txt` pins the optional Python path.

### 3.2 CCE (ZCHPC) implementation plan

Our compute footprint is deliberately small — training completes in seconds on a
single CPU core — so our Controlled Compute Environment use is about **data
custody, not horsepower**: the real labelled dataset should never leave the
controlled environment, and our pipeline is built for exactly that.

1. **Ingest (inside CCE):** map the provided dataset to the published contract
   (`ml/DATA_CONTRACT.md`: text, label, doc_type, source, verified columns);
   hold out a stratified real evaluation slice.
2. **Retrain (inside CCE):** run the reference trainer (`ml/train.py`,
   scikit-learn, CPU) or the dependency-free Dart trainer; both print
   in-distribution vs held-out metrics and enforce the no-regression export gate.
3. **Export only the model:** the artefact leaving the CCE is `model_export.json`
   — vocabulary, IDF weights, coefficients (~50–100 KB). **No source documents
   leave the environment.**
4. **Verify:** the app's automated test re-validates the export against the
   (non-sensitive) specimen set before any release.

CCE resource request: CPU-only instance, Python 3 + scikit-learn or Dart SDK,
< 1 GB storage, hours not days.

### 3.3 Timeline and milestones

| Period | Milestones |
|---|---|
| **0–30 days** | Judge-feedback fixes; Play Store listing live; consent notice at online-AI point of use; pilot onboarding (two diaspora groups + one Harare residents association); support line live; key rotation + release build hardening |
| **31–60 days** | 100+ installs; CCE retrain on real dataset (if access granted) and A/B against synthetic baseline; disputed-verdict review loop; dataset v2 (moderated, source-cited additions); usage/crash monitoring review |
| **61–90 days** | 250+ checks/month; pilot report with measurable outcomes (fraud-avoided testimonies, verdict distribution, dispute rate); EMA shapefile integration if obtained; Shona/Ndebele localisation start; paid-tier go/no-go on real unit data; scale plan to a second city |

### 3.4 Post-challenge development priorities

Real-dataset retrain (highest value; already engineered for) → EMA wetland
shapefiles → localisation → Phase-3 seasonal wetland classifier (wet/dry-season
Sentinel-2 pairs; labels bootstrapped from ESA WorldCover + documented vleis) →
lightweight backend for moderated crowd-reports (with the compliance work in
Section 4.3 as a precondition) → institutional integrations (Deeds Registry
workflow, bank due-diligence API).

---

## Section 4 — Compliance & Risk Mitigation

### 4.1 Data Protection Act [Chapter 12:07] position

v1 is engineered to be a data controller of almost nothing: **no accounts, no
server, no analytics SDK, no personal data collected or stored by us.** Documents
and photos are processed on-device; they are transmitted (to the vision API) only
when the user explicitly invokes the online AI check, which the interface states at
the point of use — a consent notice at that exact point ships in the 0–30-day
window. **Data-use consent implementation:** the online-AI button gains an explicit
first-use consent dialog (checkbox, plain language, recorded on-device) before any
image leaves the phone. The bundled databases contain no data subjects' personal
data; named schemes appear only where a public, citable source exists. Phase-2
crowd-reports will introduce personal-data processing and are gated behind a
lawful-basis assessment, consent workflow, retention rules and an incident-response
process — before that feature ships, not after.

### 4.2 Ethical safeguards and responsible AI

- **Human oversight:** the app advises; it never transacts or decides. Every
  verdict routes to human authorities. A Green verdict is explicitly framed as
  "no known warning signs," never as safety.
- **Explainability:** every reason is labelled by source tier (cited database /
  rule / AI reading with confidence); the classifier's per-term contributions are
  inspectable; AI-vs-AI agreement is marked as a weak signal.
- **Defamation control:** only documented patterns with public citations are
  flagged; area flags describe patterns, not blanket accusations.
- **Fairness:** an explicit design rule — enforced by a unit test — prevents
  "cooperative = fraud" bias; unknown areas are handled neutrally; device bias is
  addressed by the 50 KB offline model; language and geographic bias are disclosed
  with a mitigation roadmap.
- **Misuse:** risks (defamation misuse, seller pre-testing, verdict screenshots
  presented as clearance, over-reliance) are registered with mitigations in
  `docs/risk_and_compliance.md`.

### 4.3 Model unit testing and cybersecurity

Model behaviour is regression-tested in CI-fashion on every run (held-out
reproduction, stamp-signal behaviour, fairness case). Cybersecurity posture:
attack surface is the APK plus two outbound HTTPS calls; secrets injected at build
time and never committed (verified before every push); dependencies locked;
`flutter analyze` clean; no user database exists to breach. Release hardening
(obfuscation, Play integrity, key rotation) is scheduled in the 0–30-day window.

---

## Section 5 — Sustainability & Future Adoption

**Operating model.** The core product has near-zero marginal cost by architecture:
an offline check costs USD 0.00 (no server), and an online AI verification costs
~USD 0.01 in API usage. Fixed costs are minimal (Play Store registration USD 25;
team time; pilot data bundles ~USD 300 total for three months).

**Revenue model — freemium with cross-subsidy.** The offline check stays free
forever (public good). Two paying tiers: (1) **diaspora AI verification** at
~USD 1 per remote check — the user who can pay, gains the most, and is online by
definition; ~99% contribution margin funds the free tier; (2) **institutional
licences** (banks, law firms, conveyancers, micro-lenders) for land due-diligence
use — a single institutional licence covers the entire free tier's costs. Pricing
is deliberately unproven and is exactly what the pilot measures; the fallback
ordering is institutional-first if diaspora conversion underperforms.

**Cost projections (high level).** Pilot (3 months): < USD 300. Year one at scale:
USD 3,000–5,000 (API usage growth, lightweight phase-2 backend, dataset curation
stipends, support) — recoverable from ~300 paid diaspora checks/month **or** one
institutional licence.

**Licensing and registries.** Codebase under the team's control on GitHub with
dependency licence disclosure (`pubspec.lock` manifest; ML Kit, Esri imagery and
Groq API used within their published terms; Esri attribution shown in-app).
Dataset licensing: bundled databases are team-curated from public sources and
ship with the app; the real dataset remains under POTRAZ/CCE terms (Section 3.2).

**Adoption pathway.** Pilot (diaspora groups + Harare residents association) →
partnership MOUs (residents associations, ZLHR, EMA) → institutional tier →
operating partnership with a consumer-protection institution as long-term
operator, with the founding team as technical maintainers. The strongest adoption
asset is the product's honesty: it never overclaims, cites every risk it raises,
and routes users to the state institutions that own the ground truth — making it a
complement to public enforcement, not a competitor.

---

*Appendices (uncounted, attach as separate PDFs if desired): architecture diagram;
data & AI usage note; risk & compliance checklist; testing evidence; business model
summary; deployment plan — all available in the repository `docs/` folder.*
