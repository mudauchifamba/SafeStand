import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'photo_evidence_service.dart' show PhotoEvidenceService;

/// A documented wetland/vlei with an indicative circular boundary.
class Wetland {
  final String name;
  final double lat;
  final double lon;
  final double radiusKm;
  final String designation;
  final String source;

  Wetland({
    required this.name,
    required this.lat,
    required this.lon,
    required this.radiusKm,
    required this.designation,
    required this.source,
  });

  factory Wetland.fromJson(Map<String, dynamic> j) => Wetland(
        name: j['name'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        radiusKm: (j['radius_km'] as num).toDouble(),
        designation: j['designation'] as String,
        source: j['source'] as String,
      );
}

/// Result of checking a coordinate against the wetland layer.
class WetlandHit {
  final Wetland wetland;
  final double distanceKm; // from the wetland centre
  final bool inside; // within the indicative boundary

  WetlandHit({
    required this.wetland,
    required this.distanceKm,
    required this.inside,
  });
}

/// Offline, deterministic wetland check: is this pin inside (or right next
/// to) a documented Harare wetland/vlei? This is authoritative-data lookup,
/// not AI — it is the certainty backstop under the AI satellite reading.
/// Boundaries are indicative; every hit routes the user to EMA to verify.
class WetlandService {
  static const nearMarginKm = 0.5; // "near" = within boundary + this margin

  List<Wetland>? _wetlands;

  Future<List<Wetland>> load() async {
    if (_wetlands != null) return _wetlands!;
    final raw = await rootBundle.loadString('assets/data/wetlands.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _wetlands = (json['wetlands'] as List)
        .map((e) => Wetland.fromJson(e as Map<String, dynamic>))
        .toList();
    return _wetlands!;
  }

  /// Pure check against a provided list (testable without assets).
  static WetlandHit? check(double lat, double lon, List<Wetland> wetlands) {
    WetlandHit? best;
    for (final w in wetlands) {
      final d = PhotoEvidenceService.distanceKm(lat, lon, w.lat, w.lon);
      if (d <= w.radiusKm + nearMarginKm) {
        final hit = WetlandHit(wetland: w, distanceKm: d, inside: d <= w.radiusKm);
        if (best == null ||
            (hit.inside && !best.inside) ||
            (hit.inside == best.inside && d < best.distanceKm)) {
          best = hit;
        }
      }
    }
    return best;
  }
}
