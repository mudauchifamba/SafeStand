// Generates the 10 SafeStand OCR test-specimen PDFs without any packages,
// by emitting minimal single-page PDF files (Helvetica, A4) by hand.
//
// Every document carries a SYNTHETIC STAMP:
//  - Genuine docs (G1-G5) share ONE consistent official design: purple-blue
//    ink, double rectangular border, office name + "OFFICIAL DATE STAMP" +
//    date + file reference, slight -8 degree tilt.
//  - Fake docs (F1-F5) drift from that design progressively:
//      F1 slightly off  - right shape/ink, but no date and no reference
//      F2 mildly off    - green ink, single border, "APPROVED", no date
//      F3 moderately    - red CIRCLE stamp, misspelled "OFICIAL", no ref
//      F4 very off      - thick bright-red box, just "APPROVED", marketing
//      F5 massively off - orange double box "RESERVED!!!" / "PAY TODAY"
import 'dart:io';
import 'dart:math' as math;

class StampLine {
  final String text;
  final double size;
  const StampLine(this.text, this.size);
}

class Stamp {
  final List<StampLine> lines;
  final double r, g, b; // ink colour
  final String shape; // 'rect' or 'circle'
  final bool doubleBorder;
  final double borderWidth;
  final double w, h; // rect size (circle uses w as diameter)
  final double angleDeg;
  final double cx, cy; // centre position on page

  const Stamp({
    required this.lines,
    required this.r,
    required this.g,
    required this.b,
    this.shape = 'rect',
    this.doubleBorder = true,
    this.borderWidth = 1.8,
    this.w = 208,
    this.h = 80,
    this.angleDeg = -8,
    this.cx = 420,
    this.cy = 165,
  });
}

/// The one consistent official design used by every genuine document.
Stamp officialStamp(List<String> lines, {double cx = 420, double cy = 165}) {
  assert(lines.length == 4, 'official stamp is office/label/date/ref');
  return Stamp(
    lines: [
      StampLine(lines[0], 10),
      StampLine(lines[1], 8),
      StampLine(lines[2], 11),
      StampLine(lines[3], 8),
    ],
    r: 0.28,
    g: 0.20,
    b: 0.62, // purple-blue office ink
    cx: cx,
    cy: cy,
  );
}

class Doc {
  final String file;
  final String tag;
  final String title;
  final String subtitle;
  final List<String> paras;
  final Stamp stamp;
  Doc(this.file, this.tag, this.title, this.subtitle, this.paras, this.stamp);
}

final docs = <Doc>[
  Doc(
    'G1_deed_of_transfer_mabelreign',
    'TEST SPECIMEN G1 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'DEED OF TRANSFER',
    'No. 4821/2026',
    [
      'BE IT HEREBY MADE KNOWN that CHIPO RUVIMBO MAKONI appeared before me, Registrar of Deeds at Harare, and declared that her principal did truly and legally sell on 14 March 2026, and did cede and transfer to',
      'TENDAI JOSEPH MARUFU (ID 63-2214867-K-42)',
      'his heirs, executors, or assigns, in full and free property:',
      'CERTAIN piece of land situate in the district of Salisbury called Stand 2174 Mabelreign Township of Stand 190A Mabelreign, measuring 312 square metres as shown on Diagram S.G. No. 1447/98 annexed hereto, held under General Plan CG 3312.',
      'Transfer duty paid per Receipt No. 118842, ZIMRA Harare. Rates clearance certificate issued by City of Harare, Town Clerk\'s reference CH/RC/2174/26, Rowan Martin Building.',
      'SEALED at the Deeds Registry, Harare, this 2nd day of April 2026.',
      '______________________',
      'REGISTRAR OF DEEDS',
    ],
    officialStamp([
      'REGISTRAR OF DEEDS - HARARE',
      'OFFICIAL DATE STAMP',
      '02 APR 2026',
      'REF: DT 4821/2026',
    ]),
  ),
  Doc(
    'G2_council_offer_letter_kuwadzana',
    'TEST SPECIMEN G2 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'CITY OF HARARE',
    'Department of Housing and Community Services - Rowan Martin Building',
    [
      'Our Ref: CH/HD/KWD/0662/26     Council Minute: HCS 41/2026',
      'Dear Ms R. Chikafu (ID 63-1893324-B-70),',
      'RE: OFFER OF RESIDENTIAL STAND 662 KUWADZANA EXTENSION',
      'Following your position on the municipal housing waiting list (No. WL-88412), Council at its meeting of 19 February 2026 resolved to offer you Stand 662 Kuwadzana Extension, measuring 200 square metres, as surveyed under Diagram S.G. No. 902/2011 and General Plan TP 771.',
      'The intrinsic value of USD 3,400 is payable to the City of Harare municipal account at the banking hall, Rowan Martin Building. An official numbered receipt will be issued for every payment. Title deeds will be registered at the Deeds Registry upon completion of payment and issuance of a certificate of compliance by the Housing Department.',
      '______________________',
      'DIRECTOR OF HOUSING, for the Town Clerk',
    ],
    officialStamp([
      'CITY OF HARARE',
      'HOUSING & COMMUNITY SERVICES',
      '26 FEB 2026',
      'REF: CH/HD/KWD/0662/26',
    ]),
  ),
  Doc(
    'G3_agreement_of_sale_marlborough',
    'TEST SPECIMEN G3 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'AGREEMENT OF SALE',
    'Stand 88 Marlborough Township, Harare',
    [
      'Entered into between FARAI GWENZI (the Seller), registered owner under Deed of Transfer 2291/2004, and NYASHA DUBE (the Purchaser).',
      '1. The Seller sells Stand 88 Marlborough Township, measuring 450 square metres, as depicted on Diagram S.G. No. 388/79, held under General Plan 1122, together with all improvements.',
      '2. The purchase price of USD 45,000 shall be paid into the trust account of Chirwa & Associates, Legal Practitioners and Conveyancers, who shall attend to transfer at the Deeds Registry, Harare.',
      '3. A rates clearance certificate shall be obtained from the City of Harare (council reference CH/RC/088/26) prior to lodgement.',
      '4. Transfer shall be registered in the name of the Purchaser upon payment in full; occupation on date of registration.',
      'Signed at Harare this 8th day of June 2026 before two witnesses.',
      'SELLER ______________   PURCHASER ______________   CONVEYANCER ______________',
    ],
    officialStamp([
      'CHIRWA & ASSOCIATES',
      'LEGAL PRACTITIONERS - OFFICIAL DATE STAMP',
      '08 JUN 2026',
      'REF: CH/RC/088/26',
    ]),
  ),
  Doc(
    'G4_registered_coop_cession',
    'TEST SPECIMEN G4 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'TAKUNDA HOUSING CO-OPERATIVE SOCIETY LIMITED',
    'Registration No. CR/1174/2009 - Registrar of Cooperative Societies',
    [
      'Our Ref: THC/CES/031/26    Council Ref: CH/HD/GLEN/0417/25',
      'RE: APPROVED CESSION - STAND 417 GLEN NORAH C, HARARE',
      'This letter confirms that the cession of Stand 417 Glen Norah C (Diagram S.G. No. 655/94) from member T. Moyo to member S. Ncube was approved by the City of Harare Housing Department, Rowan Martin Building, per the council cession approval dated 11 May 2026, endorsed by the Town Clerk\'s office.',
      'The society is registered with the Registrar of Cooperative Societies and audited annually. All payments are made to the society\'s registered CBZ institutional account; numbered receipts are issued.',
      'Title registration at the Deeds Registry will follow the council\'s certificate of compliance already issued for this scheme.',
      '______________________',
      'SECRETARY, Takunda Housing Co-operative Society Ltd',
    ],
    officialStamp([
      'CITY OF HARARE',
      'HOUSING & COMMUNITY SERVICES',
      '11 MAY 2026',
      'REF: CH/HD/GLEN/0417/25',
    ]),
  ),
  Doc(
    'G5_deed_of_grant_norton',
    'TEST SPECIMEN G5 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'DEED OF GRANT',
    'No. 771/2026 - Norton Town Council',
    [
      'The Norton Town Council, in terms of its powers under the Urban Councils Act, hereby grants to PRECIOUS TAPIWA HOVE (ID 58-448812-Q-22):',
      'CERTAIN Stand 1105 Knowe Township, Norton, measuring 264 square metres, as represented on Diagram S.G. No. 2210/2015 and General Plan NTC 44, subject to the conditions of establishment of the township.',
      'Council reference: NTC/HD/1105/26. The full intrinsic value has been paid to the council\'s institutional account; receipts 00412-00419 refer. The Housing Department certificate of compliance is attached.',
      'This grant shall be registered at the Deeds Registry, Harare, in the name of the grantee.',
      'GIVEN under the Common Seal of the Norton Town Council this 20th day of May 2026.',
      '______________________     ______________________',
      'TOWN SECRETARY              CHAIRPERSON OF COUNCIL',
    ],
    officialStamp([
      'NORTON TOWN COUNCIL',
      'COMMON SEAL - OFFICIAL DATE STAMP',
      '20 MAY 2026',
      'REF: NTC/HD/1105/26',
    ]),
  ),
  Doc(
    'F1_coop_offer_letter_cash_only',
    'TEST SPECIMEN F1 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'TASHINGA VISION HOUSING CO-OPERATIVE',
    'Offer Letter',
    [
      'Dear Member,',
      'Congratulations! You have been allocated Stand 74, Phase 3 in our new development. The stand measures approximately 200 square metres.',
      'The joining fee of USD 500 and the stand price of USD 3,000 are payable in cash only to the co-operative offices. All payments are strictly non-refundable. Pay quickly to secure your stand - the list is moving fast.',
      'Your title deeds will be processed once the area has been serviced. Development is in progress and the papers are pending council approval, which our leadership has been verbally approved to expect before year end.',
      'Start building as soon as you pay - everyone else has.',
      '______________________',
      'CHAIRMAN, Tashinga Vision Housing Co-operative',
    ],
    // Slightly off: right shape and near-right ink, but NO date and NO ref.
    const Stamp(
      lines: [
        StampLine('TASHINGA VISION HOUSING', 10),
        StampLine('CO-OPERATIVE', 9),
        StampLine('OFFICIAL STAMP', 11),
      ],
      r: 0.30,
      g: 0.18,
      b: 0.58,
      angleDeg: -8,
    ),
  ),
  Doc(
    'F2_housing_trust_regularise_later',
    'TEST SPECIMEN F2 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'UNITED DESTINY HOUSING TRUST',
    'Stand Allocation Certificate',
    [
      'This certifies that the bearer has been allocated Stand No. 233 in the United Destiny scheme, Harare South.',
      'The land is currently being regularised with the relevant authorities and full papers will follow once the area has been formalised. Members are advised that the process is in progress and patience is required.',
      'Balance of USD 2,800 payable in instalments of USD 200 per month. Payments are received at the trust offices every Saturday. All amounts already paid are non-refundable under trust rules.',
      'The trust reserves the right to reallocate any stand where a member misses two instalments.',
      '______________________',
      'FOUNDER & TRUSTEE, United Destiny Housing Trust',
    ],
    // Mildly off: green ink, single border, "APPROVED", no date, no ref.
    const Stamp(
      lines: [
        StampLine('APPROVED', 14),
        StampLine('UNITED DESTINY TRUST', 9),
      ],
      r: 0.10,
      g: 0.48,
      b: 0.22,
      doubleBorder: false,
      w: 176,
      h: 62,
      angleDeg: 6,
    ),
  ),
  Doc(
    'F3_sabhuku_allocation_letter',
    'TEST SPECIMEN F3 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'ALLOCATION LETTER',
    'Village 6, Seke Communal Area',
    [
      'To whom it may concern,',
      'I, the undersigned Sabhuku of Village 6, confirm that I have allocated a residential piece of land measuring 40m x 25m to the bearer of this letter, who has paid the customary token of appreciation.',
      'The land is family land under my jurisdiction as village head and the allocation is done according to our customs. The bearer may commence building immediately.',
      'Payment of the balance of USD 1,500 shall be made in cash only to the village head directly. This letter serves as full proof of ownership.',
      '______________________',
      'VILLAGE HEAD (SABHUKU), Village 6',
    ],
    // Moderately off: red CIRCLE stamp, misspelled "OFICIAL", no reference.
    const Stamp(
      lines: [
        StampLine('SABHUKU', 11),
        StampLine('VILLAGE 6', 9),
        StampLine('OFICIAL STAMP', 8),
      ],
      r: 0.78,
      g: 0.12,
      b: 0.12,
      shape: 'circle',
      w: 108, // diameter
      angleDeg: -14,
      cx: 430,
      cy: 175,
    ),
  ),
  Doc(
    'F4_sale_payment_to_treasurer',
    'TEST SPECIMEN F4 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'AGREEMENT OF SALE',
    'Stand 19, Sunrise Park Development',
    [
      'Between Sunrise Park Land Developments (the Seller) and the Purchaser named below.',
      '1. The Seller sells Stand 19 in the Sunrise Park layout, measuring approximately 300 square metres, boundaries as pointed out on site by the Seller\'s agent.',
      '2. The purchase price of USD 4,500 shall be paid as follows: a deposit of USD 2,000 into the personal account of the project treasurer, and the balance in cash at the site office. Deposits are non-refundable.',
      '3. The Seller undertakes that papers for the stand will be processed in due course after the developer completes its arrangements.',
      '4. The Purchaser may take occupation and begin construction upon payment of the deposit.',
      'Signed at the site office.',
      'SELLER\'S AGENT ______________   PURCHASER ______________',
    ],
    // Very off: thick bright-red box, giant APPROVED, nothing official.
    const Stamp(
      lines: [
        StampLine('APPROVED', 18),
        StampLine('SUNRISE PARK', 9),
      ],
      r: 0.90,
      g: 0.10,
      b: 0.10,
      doubleBorder: false,
      borderWidth: 3.4,
      w: 190,
      h: 64,
      angleDeg: 0,
    ),
  ),
  Doc(
    'F5_ecocash_reservation_form',
    'TEST SPECIMEN F5 - FICTITIOUS DOCUMENT FOR APP TESTING',
    'STAND RESERVATION FORM',
    'Greenfields Extension - Limited Stands Available!',
    [
      'Reserve your dream stand TODAY. Only a few stands remain in this prime location. First come, first served!',
      'How to reserve: Send USD 300 reservation fee by EcoCash to the project coordinator\'s personal number (0772 XXX XXX) and bring this form to the site on Sunday.',
      'Balance payable in cash only at the site. All reservation fees are non-refundable. Stands are allocated on the day - bring your own builder and start immediately.',
      'Papers are being finalised and title deeds will be processed once the developer completes the regularisation exercise with the authorities. Do not miss out!',
      '______________________',
      'PROJECT COORDINATOR, Greenfields Extension',
    ],
    // Massively off: loud orange marketing "stamp".
    const Stamp(
      lines: [
        StampLine('RESERVED!!!', 16),
        StampLine('PAY TODAY', 12),
      ],
      r: 0.95,
      g: 0.45,
      b: 0.05,
      borderWidth: 3.0,
      w: 200,
      h: 70,
      angleDeg: 12,
    ),
  ),
];

// --- minimal PDF writer ----------------------------------------------------

String esc(String s) =>
    s.replaceAll('\\', r'\\').replaceAll('(', r'\(').replaceAll(')', r'\)');

List<String> wrap(String text, int width) {
  final words = text.split(' ');
  final lines = <String>[];
  var line = '';
  for (final w in words) {
    if (line.isEmpty) {
      line = w;
    } else if ((line.length + 1 + w.length) <= width) {
      line = '$line $w';
    } else {
      lines.add(line);
      line = w;
    }
  }
  if (line.isNotEmpty) lines.add(line);
  return lines;
}

String fmt(double v) => v.toStringAsFixed(3);

/// Emits PDF operators drawing [s] rotated about its centre.
String drawStamp(Stamp s) {
  final c = StringBuffer();
  final a = s.angleDeg * math.pi / 180;
  final cosA = math.cos(a), sinA = math.sin(a);

  c.writeln('q');
  // Rotate+translate coordinate system so (0,0) is the stamp centre.
  c.writeln('${fmt(cosA)} ${fmt(sinA)} ${fmt(-sinA)} ${fmt(cosA)} '
      '${fmt(s.cx)} ${fmt(s.cy)} cm');
  c.writeln('${fmt(s.r)} ${fmt(s.g)} ${fmt(s.b)} RG');
  c.writeln('${fmt(s.r)} ${fmt(s.g)} ${fmt(s.b)} rg');

  if (s.shape == 'circle') {
    final radius = s.w / 2;
    c.writeln('${fmt(s.borderWidth)} w');
    c.write(_circle(radius));
    c.write(_circle(radius - 6));
  } else {
    c.writeln('${fmt(s.borderWidth)} w');
    c.writeln('${fmt(-s.w / 2)} ${fmt(-s.h / 2)} ${fmt(s.w)} ${fmt(s.h)} re S');
    if (s.doubleBorder) {
      c.writeln('0.8 w');
      c.writeln('${fmt(-s.w / 2 + 4)} ${fmt(-s.h / 2 + 4)} '
          '${fmt(s.w - 8)} ${fmt(s.h - 8)} re S');
    }
  }

  // Centre the block of text lines vertically.
  const leadFactor = 1.35;
  final totalH = s.lines.fold<double>(0, (t, l) => t + l.size * leadFactor);
  var y = totalH / 2 - s.lines.first.size;
  for (final line in s.lines) {
    final width = line.text.length * line.size * 0.55;
    c.writeln('BT /F2 ${fmt(line.size)} Tf 1 0 0 1 ${fmt(-width / 2)} '
        '${fmt(y)} Tm (${esc(line.text)}) Tj ET');
    y -= line.size * leadFactor;
  }

  c.writeln('Q');
  return c.toString();
}

/// Circle path of [radius] centred on origin, stroked. (4 bezier arcs)
String _circle(double radius) {
  const k = 0.5523;
  final r = radius, kr = radius * k;
  return '${fmt(r)} 0 m '
      '${fmt(r)} ${fmt(kr)} ${fmt(kr)} ${fmt(r)} 0 ${fmt(r)} c '
      '${fmt(-kr)} ${fmt(r)} ${fmt(-r)} ${fmt(kr)} ${fmt(-r)} 0 c '
      '${fmt(-r)} ${fmt(-kr)} ${fmt(-kr)} ${fmt(-r)} 0 ${fmt(-r)} c '
      '${fmt(kr)} ${fmt(-r)} ${fmt(r)} ${fmt(-kr)} ${fmt(r)} 0 c S\n';
}

void writePdf(Doc d) {
  // A4: 595 x 842 pt. Margins 60. Body font 12pt, leading 17.
  final content = StringBuffer();
  double y = 790;

  void text(String s, double x, double size, String font) {
    content.writeln(
        'BT /$font $size Tf 1 0 0 1 $x ${y.toStringAsFixed(1)} Tm (${esc(s)}) Tj ET');
  }

  void center(String s, double size, String font) {
    final w = s.length * size * 0.55;
    text(s, (595 - w) / 2, size, font);
  }

  content.writeln('0.6 0.6 0.6 rg');
  center(d.tag, 9, 'F1');
  content.writeln('0 0 0 rg');
  y -= 28;
  center(d.title, 17, 'F2');
  y -= 20;
  center(d.subtitle, 12, 'F1');
  y -= 12;
  content.writeln(
      '1.5 w 60 ${y.toStringAsFixed(1)} m 535 ${y.toStringAsFixed(1)} l S');
  y -= 26;

  for (final p in d.paras) {
    for (final line in wrap(p, 82)) {
      text(line, 60, 12, 'F1');
      y -= 17;
    }
    y -= 9; // paragraph gap
  }

  // Stamp goes below the body, overlapping the signature zone like real ink.
  content.write(drawStamp(d.stamp));

  final stream = content.toString();
  final objects = <String>[
    '<< /Type /Catalog /Pages 2 0 R >>',
    '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
    '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
    '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
    '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
  ];

  final buf = StringBuffer('%PDF-1.4\n');
  final offsets = <int>[];
  for (var i = 0; i < objects.length; i++) {
    offsets.add(buf.length);
    buf.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
  }
  final xref = buf.length;
  buf.write('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n');
  for (final o in offsets) {
    buf.write('${o.toString().padLeft(10, '0')} 00000 n \n');
  }
  buf.write(
      'trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xref\n%%EOF');

  File('${d.file}.pdf').writeAsStringSync(buf.toString());
  print('wrote ${d.file}.pdf (stamp: ${d.stamp.shape}, '
      '${d.stamp.lines.map((l) => l.text).join(" / ")})');
}

void main() {
  for (final d in docs) {
    writePdf(d);
  }
}
