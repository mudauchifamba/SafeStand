# SafeStand — Pitch Deck Outline (12 slides)

Design guidance: brand green `#0E6B4F` background on title/section slides, white
content slides, teal `#19E3C2` accents, screenshots at device-frame scale. One idea
per slide, minimal text — the speaker carries the narrative.

---

**Slide 1 — Title.**
Logo + "SafeStand — Check before you pay."
AI4I Challenge 2026 · Development Track · Jimiel Chifamba & Mthusi Mudau.

**Slide 2 — The problem (make it human).**
One family's story arc in three lines: paid cash for a stand in Budiriro → built →
demolished as illegal occupants. Anchor stats: Uchena Commission documented
widespread illegal land sales; buyers lose USD 2,000–10,000, usually their life
savings. *"The seller walks free. The buyer loses the house."*

**Slide 3 — The most exposed victim.**
The diaspora buyer: pays thousands remotely for land they've never seen, based on
WhatsApp photos from the person with the strongest motive to lie.

**Slide 4 — The solution.**
Screenshot: home screen. Two AI-led checks, seconds each:
Scan a document (fully offline) · Check a stand (satellite + photo AI).
Every verdict: Green/Amber/Red + cited reasons + who to verify with.

**Slide 5 — Live demo.**
(Switch to phone — see demo script. Fallback: screenshots 05 → 06 → 08/09.)

**Slide 6 — The AI, honestly.**
Three models, each earning its place: ML Kit OCR (reads documents) → **our trained
fraud classifier** (learned fraud vs genuine language; 50 KB; offline; explainable)
→ vision LLM (reads satellite + judges seller photos, blind, then cross-examined
by deterministic code). And what is deliberately NOT AI: cited databases, geometry.
*"AI where judgment is needed, data where certainty exists, rules where
explanations are owed."*

**Slide 7 — Validation (the credibility slide).**
17/17 on held-out real-style specimens the model never trained on · trainer refuses
to export any regression · 51 automated tests · a real field failure (algae-green
water read as vegetation) found, fixed, and documented. Honest limits stated:
synthetic bootstrap, retrain-ready for the real POTRAZ dataset
(a retrain, not a rebuild).

**Slide 8 — Responsible by design.**
Risk signal, not a legal ruling (in-app, every verdict) · every claim cites a public
source (defamation control) · no accounts, no server, no personal data stored —
strongest DPA [Chapter 12:07] position · registered cooperatives protected by a
dedicated fairness test.

**Slide 9 — Business model.**
Free forever: offline checks (public good). Paying: diaspora AI verification
(~USD 1/check vs USD 0.01 cost) + institutional licences (banks, law firms,
conveyancers). Marginal cost of an offline check: **zero** — there is no server.
One prevented fraud pays for thousands of checks.

**Slide 10 — Deployment & pilot.**
90-day pilot: two diaspora community groups (UK/SA) + a Harare residents
association · Play Store + direct APK · WhatsApp support · no hosting to stand up.
30/60/90 milestones on slide.

**Slide 11 — Roadmap.**
Real-dataset retrain (POTRAZ) → EMA wetland shapefiles → Shona/Ndebele →
seasonal wetland classifier (our third model) → second cities → institutional
integrations (Deeds Registry workflow).

**Slide 12 — The ask + close.**
Incubation, real dataset access, EMA/council introductions.
Close: *"A small tool that works, explained by the team that built it —
protecting the biggest purchase of a family's life."*

---

# Demo Script (5 minutes, maps to Annex F)

**Setup (before walking up):** phone charged, SafeStand freshly killed (so the
splash plays), G5 + F1 specimen PDFs open in a viewer on the laptop, pins copied
into a note on the phone: `-17.795, 31.010` (Monavale) and the Chivero water pin.
Airplane-mode toggle rehearsed. Fallback: screenshots in docs/screenshots.

1. **[0:00] Open on the problem, not the app.** "Last year, families in Budiriro
   paid cash for stands, built homes, and watched them demolished. The seller walked
   free. We built the check they never had." Open the app — splash plays (movie
   moment, don't talk over it).

2. **[0:30] Scan a document — offline AI.** *Turn airplane mode ON, visibly.*
   Photograph the F1 specimen (fake cooperative letter, green seal without
   date/reference). Show extracted text appearing → Check → **Red verdict**: read
   two reasons aloud — the trained model's assessment and one rule flag ("title
   deeds once the area is regularised"). Punchline: *"No internet. The AI that just
   caught this lives in 50 kilobytes on this phone."*

3. **[1:45] Contrast with a genuine document.** Scan G5 (Norton deed of grant,
   proper seal, council ref) → **Green, low score** — read the caveat aloud:
   *"No known warning signs — NOT proof the deal is legal."* That honesty is the
   product.

4. **[2:30] Check a stand — the diaspora flow.** Airplane mode OFF. Paste the
   Monavale pin: the **wetland warning card appears instantly, offline** — cite it:
   Ramsar-listed. *"Stands on wetlands get demolished. The seller won't tell you;
   the app just did."*

5. **[3:15] The AI seeing the ground.** Swap in the Chivero water pin → satellite
   shows green water → tap **Analyse with AI** (scan animation) → reading: *Water
   or wetland — "often appears green due to algae."* Tell the story: *"Our first
   test misread this as vegetation. We found it, fixed it with local context, and
   documented it — that's how we treat AI failures."*

6. **[4:15] Close on the architecture in one breath.** "Three AIs — one we trained
   ourselves, validated 17-for-17 on documents it never saw — grounded by cited
   databases, cross-examined by code, wrapped in a UI that tells the truth about
   its own limits. Free for the citizen, paid for by the diaspora check and
   institutions. We're ready to pilot."

**Q&A landmines rehearsed:** "Why AI and not rules?" (rules are in it — as the
explanation layer; the model generalises to unseen phrasing) · "What if the seller
games it?" (layered independent signals; datasets update by release) · "Where's
real data?" (synthetic bootstrap disclosed; held-out real-style eval; contract-ready
for the POTRAZ dataset) · "Green verdict liability?" (never says safe; every verdict
routes to authorities).
