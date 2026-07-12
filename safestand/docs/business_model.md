# SafeStand — Business Model Summary (AI4I Annex A)

| Field | Response |
|---|---|
| **Problem** | Zimbabwean home-seekers lose life savings to land barons selling stands they have no right to sell. Buyers pay cash for "offer letters" from unregistered cooperatives, build, and are later demolished as illegal occupants. Diaspora buyers are the most exposed: they pay remotely for land they have never seen. |
| **Primary user** | (1) Local home-seekers about to pay for a stand; (2) diaspora Zimbabweans buying land from abroad. |
| **Beneficiary** | Home-seeking families (protected savings); councils and EMA (fewer illegal settlements to demolish); the lands ecosystem (documented fraud-pattern data). |
| **Customer / payer** | Free for citizens doing basic checks (public-good core). Paying tiers: diaspora users for AI remote verification; institutions (banks, law firms, conveyancers, micro-lenders) for due-diligence use. |
| **Value proposition** | A USD 0–1 check before a USD 2,000–10,000 irreversible cash payment. One prevented fraud pays for thousands of checks. For institutions: faster, documented pre-screening of land collateral or client transactions. |
| **Revenue / funding model** | Freemium + cross-subsidy: offline document scan and area checks free forever; AI remote verification (satellite + photo analysis) free during pilot, then a small per-check fee (~USD 1) for diaspora users, who can pay and gain the most; institutional licence (annual) for professional use. Public-good funding (POTRAZ incubation, NGO partnership) covers the free tier. |
| **Cost drivers** | Near-zero marginal cost by design: the document scan runs fully on-device (no server, no API cost). Vision AI calls ~USD 0.01 per remote check (Groq). No hosting backend in v1 — the app is client-side. Fixed: Play Store registration (USD 25 once), support time, dataset curation time. |
| **Partnerships** | Combined Harare Residents Association / suburb residents groups (local reach + case reports); diaspora community groups UK/SA (remote-check users); Zimbabwe Lawyers for Human Rights (case validation, referrals); EMA (wetland map data); City of Harare Housing Dept & Registrar of Cooperative Societies (verification workflows, longer term); POTRAZ (incubation, real dataset access). |
| **Pilot market** | 90-day pilot: 100+ users via two diaspora community groups and one Harare residents association; feedback in-app and via WhatsApp. |
| **Adoption risks** | Trust (mitigated by cited sources on every claim and the honest "risk signal, not legal ruling" framing); OCR quality on poor cameras (mitigated: manual entry path); sellers coaching buyers to skip checks (mitigated: diaspora marketing directly to buyers); defamation exposure (mitigated: only documented, publicly-sourced patterns are flagged); free-tier sustainability (mitigated: near-zero marginal cost architecture). |
| **Success metrics (30/60/90 days)** | 30d: 50 installs, 200 checks, 10 structured feedback responses. 60d: 100+ installs, first documented "walked away from a bad deal" testimonies, <5% crash rate. 90d: 250+ checks/month, 2 partnership MOUs in progress, decision on paid-tier launch with real unit data. |

## Simple unit economics

- Marginal cost per offline check: **USD 0.00** (on-device AI).
- Marginal cost per AI remote check: **~USD 0.01** (vision API) → priced at USD 1.00 for diaspora tier = ~99% contribution margin funding the free tier.
- Three-month pilot budget: **< USD 300** (Play Store fee, API usage buffer, data bundles for field feedback sessions).
- One-year scale budget (high level): **~USD 3,000–5,000** — API usage at scale, a lightweight backend for moderated crowd-reports (phase 2), dataset curation stipends, support.

## Honest assumptions

We deliberately claim a small, checkable model rather than a large market figure. The
cost structure is real (the app has no server today); the price point is untested and is
exactly what the pilot measures. If diaspora conversion fails, the fallback is the
institutional licence route, where one bank or law firm covers the entire free tier.
