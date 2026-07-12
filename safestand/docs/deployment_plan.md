# SafeStand — Deployment Plan (AI4I Annex B)

| Field | Response |
|---|---|
| **Deployment environment** | Mobile-first, offline-first Android app. No backend server in v1 — all core logic (OCR, trained classifier, rule engine, wetland/gazetteer databases) runs on-device. Online calls only for satellite tiles (Esri) and vision AI (Groq API), invoked directly from the device. |
| **Hosting provider or site** | v1: Google Play Store distribution (plus direct APK for pilot users). No server to host. Phase 2 (moderated crowd-reports) adds a lightweight backend — planned as a low-cost cloud function + managed database, selected during incubation. |
| **Operator** | The SafeStand team (Jimiel Chifamba, Mthusi Mudau) operates the app through pilot and incubation. Long-term target operating partner: a consumer-protection institution (ZLHR or a residents association federation) with the team as technical maintainers. |
| **Pilot site** | Greater Harare (the seed datasets cover it) + diaspora: two Zimbabwean diaspora community groups (UK / South Africa) for the remote check, one Harare residents association (e.g. CHRA or a Budiriro/Southlea Park residents group) for the on-the-ground flows. |
| **Users to onboard** | 100+ pilot users in 90 days: ~60 diaspora buyers, ~40 local home-seekers and community para-legals. |
| **Training and support** | In-app guidance is the primary training (each screen explains itself; every verdict carries plain-language reasons and next steps). Plus: a 2-page WhatsApp-shareable user guide, a demo video, and a WhatsApp support line run by the team during the pilot. |
| **Monitoring** | Pilot: in-app feedback prompt, WhatsApp feedback group, crash reporting (Play Console), and a simple usage log (checks run per path, verdict distribution — no personal data). AI outputs that users dispute are logged for review — the human-oversight loop. |
| **Backup and recovery** | The app holds no server-side user data in v1 (privacy by architecture). Code and datasets are version-controlled on GitHub. Bundled datasets are versioned files; a bad data release is recoverable by shipping a corrected release. Phase-2 backend will add automated database backups before launch. |
| **Connectivity plan** | Offline-first by design: document scanning (OCR + trained classifier + rules), area checks, wetland layer, and EXIF/pin geometry all work with zero connectivity. Only satellite imagery and the two vision-AI checks need internet, and the UI says so and degrades gracefully. This matches the reality that at-risk local buyers have patchy data while diaspora users are online. |
| **Scale pathway** | Pilot (Harare + diaspora) → incorporate POTRAZ-provided real dataset (retrain via documented pipeline — a retrain, not a rebuild) → expand gazetteer/wetlands/known-cases to Bulawayo, Chitungwiza, Gweru, Mutare → institutional tier (banks, law firms) → partnership integrations (EMA wetland shapefiles, Deeds Registry verification workflow) → iOS build if demand justifies it. |
| **Milestones** | **30 days:** Play Store listing live, 50 installs, pilot groups onboarded, feedback loop running, judge-feedback fixes shipped. **60 days:** 100+ installs, first fraud-avoided testimonies collected, dispute-log review of AI outputs, dataset v2 (community-reported cases marked unverified). **90 days:** 250+ checks/month, two partnership MOUs in progress, paid-tier decision from real unit data, scale plan to second city drafted. |

## Security and privacy posture (deployment view)

- No account, no login, no personal data collected in v1 — the strongest possible
  data-protection position under the Data Protection Act [Chapter 12:07]: there is
  nothing to breach.
- Documents and photos never leave the device except when the user explicitly runs
  the online AI photo check (stated in-app at the point of use).
- API keys are injected at build time (`--dart-define`), never committed; keys are
  rotated before any public release build.
- Every risk claim in the app cites a public source — the defamation-safety control.
