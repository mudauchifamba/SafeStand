# SafeStand — Risk & Compliance Checklist

Mapped to ToR §10 (security, privacy, responsible AI). Risk level self-assessment:
**medium-high** — no personal data is stored and no decisions are automated, but the
output influences major financial decisions, so we apply high-risk-grade oversight
to the advice itself.

## 10.1 Minimum safeguards

| Safeguard | SafeStand implementation | Status |
|---|---|---|
| Data minimisation | No accounts, no server, no analytics SDK; runtime inputs processed on-device; nothing collected beyond what the check needs | ✅ by architecture |
| Consent | Online AI photo analysis happens only on explicit user tap, stated at point of use; explicit consent notice text at that point | 🔶 pilot checklist |
| Access control | No server-side data exists to control; repo access controlled via GitHub | ✅ |
| Authentication | Not applicable in v1 (no accounts, purely client-side); phase-2 backend will add auth before launch | ✅ n/a, planned |
| Secrets management | API key via `--dart-define` at build time; never committed (`.env.example` documents it); keys rotated before public builds | ✅ |
| Encryption | All network calls HTTPS; no data at rest beyond the user's own device storage | ✅ |
| Auditability | Every verdict reason carries its source tier (database citation / rule / AI reading); model export + eval report versioned in git; disputed AI outputs logged in pilot | ✅ / 🔶 pilot |
| Human oversight | App advises, never acts; all verdicts route to human authorities; GREEN explicitly ≠ safe; disputed-output review loop | ✅ |
| Misuse risk | See register below | ✅ documented |
| Bias & fairness | See register below | ✅ documented |

## Data Protection Act [Chapter 12:07] position

- v1 is a **data controller of almost nothing**: no personal data is collected,
  stored, or transmitted to any server we operate — the strongest compliance
  position available. Photos a user submits to the online AI check are transmitted
  transiently at the user's explicit instruction and are not retained by us.
- The bundled databases contain no data subjects' personal data; named entities are
  organisations with public, cited sources.
- Phase 2 (moderated crowd-reports) will introduce personal-data processing and
  therefore: a lawful-basis assessment, consent workflow, retention rules, and an
  incident-response process **before** that feature ships (it is not in v1).

## Misuse risk register

| Risk | Mitigation |
|---|---|
| App used to defame legitimate sellers/areas | Only documented patterns with public citations are flagged; area flags describe patterns, not blanket accusations; disclaimer on every verdict |
| Sellers "pre-testing" documents to evade rules | The classifier learns distributional signals, not just keywords; the layered checks (area, wetland, geometry, photo AI) can't be beaten by wording alone; datasets update via releases |
| GREEN verdict read as legal clearance | Explicit in-app framing on every result + next-steps always shown; the strongest wording we have, tested in pilot |
| Fake "SafeStand said it's safe" screenshots by fraudsters | Verdicts always include the caveat text in the shareable view; public awareness messaging in pilot |
| Over-reliance in place of professional conveyancing | Every verdict's next steps point to professionals and authorities by name |

## Bias & fairness register

| Risk | Mitigation |
|---|---|
| Geographic bias: datasets are Harare-first | Disclosed everywhere; "area unknown" is handled neutrally (never penalised); expansion is the documented scale pathway |
| Language: documents/UI are English-first | OCR reads English documents best; Shona/Ndebele UI + document phrasing in the training generator are roadmap items before scale-up |
| Cooperative ≠ fraud | Explicit design rule: registered cooperatives with proper references score clean — enforced by a dedicated unit test ("registered cooperative is NOT over-flagged") |
| Device bias: low-end phones | Classifier is ~50 KB pure arithmetic; OCR is on-device ML Kit; offline-first design targets exactly these users |
| Wetland false positives near indicative boundaries | Edge hits score lower than inside-hits, wording says "indicative", every flag routes to EMA |

## Security posture summary

Client-side app; attack surface = the APK and two outbound HTTPS API calls. No
credentials in the repo (verified before every push), no user database to breach,
dependency versions locked (`pubspec.lock`), analyzer + 51 tests green in CI usage.
