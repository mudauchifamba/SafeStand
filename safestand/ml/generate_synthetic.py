"""
Synthetic data generator — conforms to ml/DATA_CONTRACT.md.

Emits the full schema (text, label, doc_type, source, verified, region) so the
synthetic file is a drop-in shape-match for the future real dataset. Variety is
deliberate: many phrasings and flag combinations so the classifier learns
generalisable signal, not one template.
"""
import random, csv

random.seed(7)

COOP_NAMES = [
    "Ruvimbo Yetu Housing Co-operative", "Takaitora Nyika Co-operative",
    "Parkridge Housing Trust", "Excellence Stars Housing Co-op",
    "United We Stand Housing Co-operative", "Bantu Housing Co-operative",
    "Zvikomborero Housing Co-operative", "Kubatana Housing Society",
    "Tashinga Home Seekers Trust", "Simukai Land Group", "Vimbai Housing Scheme",
    "Batanai Cooperative", "Tariro Housing Consortium", "Garikai Land Trust",
]
COUNCIL_ISSUERS = [
    "City of Harare Housing and Community Services Department",
    "City of Harare, Town House", "Chitungwiza Municipality Housing Office",
    "Mabvuku-Tafara District Housing Office", "Harare City Council Housing Department",
    "Bulawayo City Council Housing Office",
]
AREAS = ["Budiriro", "Whitecliff", "Hopley", "Retreat", "Seke", "Caledonia",
         "Southlea Park", "Glen View", "Mabvuku", "Domboshava", "Melfort",
         "Southerton", "Waterfalls", "Epworth"]

FRAUD_REGULARISE = [
    "title deeds will be processed once the area is regularised by council",
    "papers are in progress and will follow after regularisation",
    "the stand is pending council survey; you may occupy immediately",
    "council has verbally approved the layout; written confirmation to follow",
    "deeds will come once the area is proclaimed",
    "regularisation is underway, occupation allowed in the meantime",
    "the offer letter serves as proof of allocation while paperwork is finalised",
]
FRAUD_PAYMENT = [
    "USD {a} cash only, non-refundable, balance to the treasurer",
    "pay USD {a} via EcoCash to the chairperson's personal number",
    "USD {a} cash on the day, no receipt issued",
    "deposit USD {a} to the cooperative holding account, balance negotiable",
    "USD {a} cash, half now and half on occupation",
    "allocation fee USD {a}, cash only, paid directly to the committee",
]
FRAUD_CLOSERS = [
    "no council stamp is required for this allocation",
    "keep this letter safe as your only proof of allocation",
    "this cooperative allocates stands directly to members",
    "trust the committee; the paperwork will sort itself out",
    "no need to involve a lawyer, the cooperative handles everything",
]
GENUINE_REF = [
    "council resolution CH/RES/{n}/2025 refers",
    "council file reference CH/HOU/2026/{n}",
    "issued under Deed of Grant No. {n}/2019",
    "planning consent ref. CH/PLAN/2025/{n} attached",
    "cession approved by council per letter CH/COOP/2025/{n}",
]
GENUINE_SG = [
    "Diagram/General Plan No. SG {n}/2024, Surveyor-General's office",
    "survey Diagram No. SG {n}/2020 applies",
    "held under General Plan SG {n}/2018, Surveyor-General Harare",
]
GENUINE_PAYMENT = [
    "USD {a} payable to the council bank account, receipt no. HCC-{n}",
    "USD {a} via bank transfer to the registered account, receipt {n}",
    "deposit USD {a} into the conveyancer's trust account, balance on transfer",
    "USD {a} to the municipal account, official numbered receipt issued",
]
GENUINE_CLOSERS = [
    "title deed processing will commence within 12 months of full payment",
    "a Rates Clearance Certificate is annexed",
    "your conveyancer should conduct a deeds search before transfer",
    "the offer is valid for 60 days and is subject to the approved layout plan",
    "registration will be lodged at the Deeds Registry, Harare",
]

# --- Stamp concept ----------------------------------------------------------
# Real official documents carry a dated, referenced office stamp; fraudulent
# ones either have no stamp, or an imitation that is wrong in content
# (no date / no file reference / misspellings), structure, or colour. OCR
# picks stamp text up, so the classifier can learn this signal.
MONTHS = ["JAN","FEB","MAR","APR","MAY","JUN","JUL","AUG","SEP","OCT","NOV","DEC"]
def stamp_date():
    return f"{random.randint(1,28):02d} {random.choice(MONTHS)} {random.choice([2024,2025,2026])}"

GENUINE_STAMP = [
    "official date stamp: City of Harare Housing and Community Services {d} ref CH/HD/{n}",
    "bears the official date stamp of the Registrar of Deeds Harare dated {d} ref DT {n}",
    "common seal of the council affixed {d} ref NTC/HD/{n}",
    "official date stamp {d} council file CH/HOU/{n} appears on the letter",
    "town clerk official date stamp dated {d} with file reference CH/{n}",
]
FRAUD_STAMP = [
    "rubber stamp reads APPROVED with no date and no reference",
    "stamp reads OFICIAL STAMP of the cooperative, no council stamp",
    "bright red APPROVED stamp only, no file reference or date",
    "orange RESERVED stamp reading PAY TODAY",
    "chairman's personal stamp affixed, no official council stamp or date",
    "cooperative stamp without date, reference or issuing office",
]
GENUINE_STAMP_P = 0.6   # most genuine docs mention their stamp
FRAUD_STAMP_P = 0.35    # some fakes describe their imitation stamp; the rest have none

def amt(): return random.choice([900,1200,1500,1800,2000,2400,2600,3200,8500,12000])
def num(): return random.randint(40, 9999)

def make_fraud():
    # Real offer letters are terse. Build a shorter core, then optionally add
    # one extra clause — so lengths spread realistically (some short, some longer)
    # rather than always stacking every part.
    area = random.choice(AREAS)
    parts = [f"{random.choice(COOP_NAMES)}. Stand {num()} {area}, {random.choice([200,250,300,350])} sqm",
             random.choice(FRAUD_PAYMENT).format(a=amt()),
             random.choice(FRAUD_REGULARISE)]
    # optional extras, each low-probability, to vary length
    if random.random() < 0.3:
        parts.append(f"ref {random.choice(COOP_NAMES).split()[0][:3].upper()}/{num()} (unverified)")
    if random.random() < 0.35:
        parts.append(random.choice(FRAUD_CLOSERS))
    if random.random() < FRAUD_STAMP_P:
        parts.append(random.choice(FRAUD_STAMP))
    head = parts[0]; rest = parts[1:]; random.shuffle(rest)
    return ". ".join([head]+rest) + ".", "offer_letter", area

def make_genuine_council():
    area = random.choice(AREAS)
    dtype = random.choice(["offer_letter", "deed_of_transfer"])
    parts = [f"{random.choice(COUNCIL_ISSUERS)}. Stand {num()} {area}, {random.choice([200,250,300])} sqm",
             random.choice(GENUINE_REF).format(n=num()),
             random.choice(GENUINE_SG).format(n=num()),
             random.choice(GENUINE_PAYMENT).format(a=amt(), n=num())]
    if random.random() < 0.5:
        parts.append(random.choice(GENUINE_CLOSERS))
    if random.random() < GENUINE_STAMP_P:
        parts.append(random.choice(GENUINE_STAMP).format(d=stamp_date(), n=num()))
    head = parts[0]; rest = parts[1:]; random.shuffle(rest)
    return ". ".join([head]+rest) + ".", dtype, area

def make_genuine_coop():
    area = random.choice(AREAS)
    coop = random.choice(COOP_NAMES)
    parts = [f"{coop} Reg No {random.choice(['MTH','GHH','ZHC'])}/{random.randint(2018,2024)}/{num()}. Stand {num()} {area}, {random.choice([250,300])} sqm",
             random.choice(GENUINE_REF).format(n=num()),
             random.choice(GENUINE_SG).format(n=num()),
             random.choice(GENUINE_PAYMENT).format(a=amt(), n=num())]
    if random.random() < 0.5:
        parts.append("registration verifiable at Registrar of Cooperative Societies")
    if random.random() < GENUINE_STAMP_P:
        parts.append(random.choice(GENUINE_STAMP).format(d=stamp_date(), n=num()))
    head = parts[0]; rest = parts[1:]; random.shuffle(rest)
    return ". ".join([head]+rest) + ".", "cession", area

N = 900
rows = []
for _ in range(N//2):
    txt, dt, area = make_fraud()
    rows.append([txt, "fraudulent", dt, "synthetic", 1, area])
for _ in range(N//4):
    txt, dt, area = make_genuine_council()
    rows.append([txt, "genuine", dt, "synthetic", 1, area])
for _ in range(N//4):
    txt, dt, area = make_genuine_coop()
    rows.append([txt, "genuine", dt, "synthetic", 1, area])

random.shuffle(rows)

with open("ml/data/synthetic_training.csv", "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["text","label","doc_type","source","verified","region"])
    w.writerows(rows)

from collections import Counter
print("generated", len(rows), "rows conforming to DATA_CONTRACT.md")
print("label balance:", Counter(r[1] for r in rows))
print("doc_type balance:", Counter(r[2] for r in rows))
