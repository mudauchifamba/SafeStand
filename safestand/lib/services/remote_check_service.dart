import '../models/models.dart';
import 'photo_evidence_service.dart';
import 'risk_scorer.dart';

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

  RiskVerdict evaluate({
    required String claimedArea,
    String seller = '',
    required List<PhotoCheckResult> photoResults,
    double? pinLat,
    double? pinLon,
    GazetteerPlace? claimedPlace,
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
