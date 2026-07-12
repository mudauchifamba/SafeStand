import '../models/models.dart';
import 'land_context_service.dart';
import 'photo_evidence_service.dart';
import 'risk_scorer.dart';
import 'wetland_service.dart';

/// Builds a verdict for the diaspora "check a stand remotely" flow.
///
/// Combines:
///  - the claimed area checked against the documented-cases dataset
///    (delegated to the existing [RiskScorer]), and
///  - EXIF findings from the seller's photos.
///
/// Signal asymmetry is deliberate and stated to the user:
///  - a GPS MISMATCH raises risk strongly (hard to explain innocently);
///  - a GPS MATCH adds nothing (EXIF is trivially fakeable);
///  - missing GPS is neutral (WhatsApp strips it by default).
class RemoteCheckService {
  final RiskScorer scorer;

  RemoteCheckService({required this.scorer});

  /// Points added per photo finding, on the 0-100 scale.
  static const mismatchPoints = 40;
  static const stalePhotoPoints = 10;
  static const stalePhotoThresholdDays = 365;
  static const pinMismatchPoints = 35;
  static const photoFarFromPinPoints = 25;
  static const photoNearPinKm = 1.0;
  static const wetlandPoints = 30;
  static const denseBuiltUpPoints = 12;
  static const mappedWetlandInsidePoints = 35;
  static const mappedWetlandNearPoints = 10;
  static const aiWetlandStrongPoints = 20;
  static const aiWetlandPossiblePoints = 5;
  static const photoFakeStrongPoints = 25;
  static const photoFakeSuspiciousPoints = 10;
  static const photoInconsistentPoints = 20;

  RiskVerdict evaluate({
    required String claimedArea,
    String seller = '',
    required List<PhotoCheckResult> photoResults,
    double? pinLat,
    double? pinLon,
    GazetteerPlace? claimedPlace,
    LandContext? landContext,
    WetlandHit? wetlandHit,
    PhotoContentAnalysis? photoContent,
  }) {
    // Base: claimed area vs documented fraud patterns.
    final base = scorer.score(area: claimedArea, seller: seller);

    final reasons = <VerdictReason>[
      ...base.reasons.where((r) => r.weight > 0),
    ];
    var score = base.score;

    var anyMismatch = false;
    var anyMatch = false;
    var anyNoGps = false;

    // --- Seller's pin vs claimed area -----------------------------------
    final hasPin = pinLat != null && pinLon != null;
    if (hasPin && claimedPlace != null) {
      final pinDist = PhotoEvidenceService.distanceKm(
          pinLat, pinLon, claimedPlace.lat, claimedPlace.lon);
      if (pinDist > claimedPlace.radiusKm) {
        anyMismatch = true;
        score += pinMismatchPoints;
        reasons.add(VerdictReason(
          'Seller\'s pin is outside the claimed area',
          'The location pin the seller shared is '
              '${pinDist.toStringAsFixed(1)} km from ${claimedPlace.name}. '
              'A stand advertised in one suburb but pinned in another is a '
              'serious warning sign.',
          4,
        ));
      } else {
        reasons.add(VerdictReason(
          'Seller\'s pin falls inside the claimed area',
          'The pin is consistent with ${claimedPlace.name}. This alone does '
              'not prove the seller has any right to that land — inspect the '
              'satellite view and verify ownership independently.',
          0,
        ));
      }
    }

    // --- Photos vs seller's pin ------------------------------------------
    if (hasPin) {
      for (final r in photoResults) {
        if (!r.evidence.hasGps) continue;
        final d = PhotoEvidenceService.distanceKm(
            r.evidence.lat!, r.evidence.lon!, pinLat, pinLon);
        if (d > photoNearPinKm) {
          anyMismatch = true;
          score += photoFarFromPinPoints;
          reasons.add(VerdictReason(
            'Photo was not taken at the pinned stand',
            'A photo presented as the stand was taken '
                '${d.toStringAsFixed(1)} km from the location the seller '
                'pinned. The photos may show a different piece of land.',
            3,
          ));
        } else {
          reasons.add(VerdictReason(
            'Photo was taken at the pinned location',
            'The photo\'s embedded location agrees with the seller\'s pin '
                '(within ${photoNearPinKm.toStringAsFixed(0)} km). Remember '
                'this data is fakeable — it removes a contradiction, nothing '
                'more.',
            0,
          ));
        }
      }
    }

    // --- Mapped wetland layer (offline, authoritative data) --------------
    if (wetlandHit != null) {
      final w = wetlandHit.wetland;
      if (wetlandHit.inside) {
        score += mappedWetlandInsidePoints;
        reasons.add(VerdictReason(
          'Pin falls inside a documented wetland: ${w.name}',
          '${w.designation}. Stands sold on Harare wetlands are a documented '
              'demolition risk — construction is restricted regardless of '
              'what papers the seller shows. Boundary is indicative; confirm '
              'with EMA before any payment. (Source: ${w.source})',
          4,
        ));
      } else {
        score += mappedWetlandNearPoints;
        reasons.add(VerdictReason(
          'Pin is at the edge of a documented wetland: ${w.name}',
          'The pin is ${wetlandHit.distanceKm.toStringAsFixed(1)} km from '
              'the centre of ${w.name} (${w.designation}), just outside its '
              'indicative boundary. Wetland edges are exactly where risky '
              'stands get pegged — confirm the wetland status with EMA. '
              '(Source: ${w.source})',
          2,
        ));
      }
    }

    // --- AI satellite land-context (online) ------------------------------
    if (landContext != null && landContext.available) {
      switch (landContext.landClass) {
        case LandClass.waterOrWetland:
          score += wetlandPoints;
          reasons.add(VerdictReason(
            'AI satellite check: location looks like water or wetland',
            'The AI reading of the satellite image of this spot suggests '
                'water or wetland. Stands on wetlands are a documented '
                'demolition risk in Harare. ${landContext.description}',
            4,
          ));
        case LandClass.builtUpDense:
          score += denseBuiltUpPoints;
          reasons.add(VerdictReason(
            'AI satellite check: area is already densely built up',
            'The AI reading of the satellite image shows dense existing '
                'building. If you were told this is a new or vacant serviced '
                'stand, that is a contradiction worth questioning. '
                '${landContext.description}',
            2,
          ));
        case LandClass.builtUpScattered:
        case LandClass.bareLand:
        case LandClass.vegetation:
          reasons.add(VerdictReason(
            'AI satellite check: ${landContext.landClass.label}',
            '${landContext.description} This is context to compare against '
                'what the seller told you — it is not by itself a red flag.',
            0,
          ));
        case LandClass.unknown:
          break;
      }

      // Vlei indicators (independent of the dominant class): a seasonal
      // wetland can look like plain grass in dry-season imagery, so the AI
      // is asked to look for drainage lines and undeveloped green corridors.
      // Only fires when the mapped layer hasn't already flagged the spot.
      if (landContext.landClass != LandClass.waterOrWetland &&
          !(wetlandHit?.inside ?? false)) {
        if (landContext.wetlandSigns == 'strong') {
          score += aiWetlandStrongPoints;
          reasons.add(VerdictReason(
            'AI satellite check: strong seasonal-wetland (vlei) indicators',
            'The AI reading of the satellite image found strong signs this '
                'may be a vlei — land that looks dry and buildable but '
                'floods seasonally. Confirm with EMA before any payment. '
                '${landContext.description}',
            3,
          ));
        } else if (landContext.wetlandSigns == 'possible') {
          score += aiWetlandPossiblePoints;
          reasons.add(VerdictReason(
            'AI satellite check: possible seasonal-wetland (vlei) indicators',
            'The AI reading noticed features that can indicate a vlei '
                '(drainage lines or an undeveloped green corridor). This is '
                'a weak signal — ask EMA about the wetland status of this '
                'stand. ${landContext.description}',
            1,
          ));
        }
      }
    }

    // --- AI photo-content analysis (online) ------------------------------
    // Metadata can be stripped; pixels cannot. The vision model judges the
    // seller's photos directly: recycled/fake tells and satellite mismatch.
    if (photoContent != null && photoContent.available) {
      switch (photoContent.authenticity) {
        case 'strong_concerns':
          score += photoFakeStrongPoints;
          reasons.add(VerdictReason(
            'AI photo check: strong signs the photos are not genuine',
            '${photoContent.authenticityReasons} Recycled or fake photos '
                'are a common land-scam tactic — ask for a live video call '
                'from the stand instead.',
            3,
          ));
        case 'suspicious':
          score += photoFakeSuspiciousPoints;
          reasons.add(VerdictReason(
            'AI photo check: photos look suspicious',
            '${photoContent.authenticityReasons} Ask the seller for '
                'original photos or a live video call from the stand.',
            2,
          ));
        default:
          break;
      }
      if (photoContent.satelliteConsistency == 'inconsistent') {
        score += photoInconsistentPoints;
        reasons.add(VerdictReason(
          'AI photo check: photos do not match the pinned location',
          '${photoContent.consistencyReasons} The ground in the photos '
              'does not look like the satellite view of the spot the seller '
              'pinned — the photos may show a different piece of land.',
          3,
        ));
      } else if (photoContent.satelliteConsistency == 'consistent' &&
          photoContent.authenticity == 'ok') {
        reasons.add(VerdictReason(
          'AI photo check: photos are plausible for the pinned location',
          '${photoContent.photosShow} This is a weak signal — consistent '
              'photos do not prove the seller owns the land.',
          0,
        ));
      }
    }

    for (final r in photoResults) {
      switch (r.finding) {
        case GpsFinding.mismatch:
          anyMismatch = true;
          score += mismatchPoints;
          reasons.add(VerdictReason(
            'Photo location contradicts the claimed area',
            'A photo was taken ${r.distanceKm!.toStringAsFixed(1)} km from '
                '${r.claimedPlace!.name}. A seller photographing "your stand" '
                'somewhere else entirely is a serious warning sign.',
            4,
          ));
        case GpsFinding.matches:
          anyMatch = true;
        case GpsFinding.noGps:
          anyNoGps = true;
        case GpsFinding.areaUnknown:
          reasons.add(VerdictReason(
            'Claimed area not in our map data',
            'We could not compare the photo location because '
                '"$claimedArea" is not in our offline gazetteer. '
                'Verify the exact location independently.',
            1,
          ));
      }

      if (r.photoAgeDays != null &&
          r.photoAgeDays! > stalePhotoThresholdDays) {
        score += stalePhotoPoints;
        final years = (r.photoAgeDays! / 365).toStringAsFixed(1);
        reasons.add(VerdictReason(
          'Photo is old',
          'A photo presented as current was taken about $years years ago '
              'according to its embedded timestamp. Ask for a dated, recent '
              'photo — or better, a live video call from the stand.',
          2,
        ));
      }
    }

    // Honest, non-score-changing context notes.
    if (anyMatch && !anyMismatch) {
      reasons.add(VerdictReason(
        'Photo location matches the claimed area',
        'This is only a weak signal: location data inside a photo is easy to '
            'fake, so a match never makes a deal safe — it just found no '
            'contradiction.',
        0,
      ));
    }
    if (anyNoGps) {
      reasons.add(VerdictReason(
        'Photo has no location data',
        'This is normal — WhatsApp removes location data from photos sent the '
            'usual way. Ask the seller to send the original photo "as a '
            'document" (attach > Document) so the location survives, then '
            'check again.',
        0,
      ));
    }

    if (reasons.isEmpty) {
      reasons.add(VerdictReason(
        'No documented red flags found',
        'This does not confirm the deal is legal — it only means our checks '
            'found no known warning signs. Never pay for a stand you have not '
            'had independently verified on the ground.',
        0,
      ));
    }

    score = score.clamp(0, 100);
    reasons.sort((a, b) => b.weight.compareTo(a.weight));

    return RiskVerdict(
      band: bandFor(score),
      score: score,
      reasons: reasons,
      matchedAreas: base.matchedAreas,
      nextSteps: [
        if (wetlandHit != null ||
            (landContext?.wetlandSigns ?? 'none') != 'none' ||
            landContext?.landClass == LandClass.waterOrWetland)
          'Environmental Management Agency (EMA) — confirm the wetland '
              'status of this stand before considering any payment.',
        'Ask the seller to send the original photos "as a document" on '
            'WhatsApp so the location data survives.',
        'Ask for a live video call from the stand, showing a road sign or '
            'landmark.',
        'Engage your OWN person on the ground — a relative or a conveyancer — '
            'to visit the stand and the council offices.',
        ...scorer.nextSteps,
      ],
    );
  }

  RiskBand bandFor(int score) {
    if (score >= 50) return RiskBand.red;
    if (score >= 25) return RiskBand.amber;
    return RiskBand.green;
  }
}
