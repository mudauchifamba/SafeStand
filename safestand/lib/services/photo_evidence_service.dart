import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:exif/exif.dart';
import 'package:flutter/services.dart' show rootBundle;

/// A place from the offline gazetteer.
class GazetteerPlace {
  final String name;
  final String city;
  final double lat;
  final double lon;
  final double radiusKm;

  GazetteerPlace({
    required this.name,
    required this.city,
    required this.lat,
    required this.lon,
    required this.radiusKm,
  });

  factory GazetteerPlace.fromJson(Map<String, dynamic> j) => GazetteerPlace(
        name: j['name'] as String,
        city: j['city'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        radiusKm: (j['radius_km'] as num).toDouble(),
      );
}

/// What we could read out of one seller-sent photo.
class PhotoEvidence {
  final String path;
  final double? lat;
  final double? lon;
  final DateTime? takenAt;

  PhotoEvidence({required this.path, this.lat, this.lon, this.takenAt});

  bool get hasGps => lat != null && lon != null;
}

/// Outcome of comparing photo evidence against the claimed area.
enum GpsFinding {
  noGps, // stripped in transit (normal for WhatsApp) — neutral
  matches, // weak positive: fakeable, never lowers risk
  mismatch, // strong red flag
  areaUnknown, // claimed area not in gazetteer — cannot compare
}

class PhotoCheckResult {
  final PhotoEvidence evidence;
  final GpsFinding finding;
  final GazetteerPlace? claimedPlace;
  final double? distanceKm; // photo -> claimed place centre
  final int? photoAgeDays; // from EXIF timestamp, if present

  PhotoCheckResult({
    required this.evidence,
    required this.finding,
    this.claimedPlace,
    this.distanceKm,
    this.photoAgeDays,
  });
}

/// Reads EXIF GPS + timestamp from seller-sent photos and compares them to
/// the claimed area using the bundled offline gazetteer.
///
/// Honesty rules (enforced by the callers too):
///  - A GPS match is a WEAK signal — EXIF is trivially fakeable, and this
///    check must never make a verdict greener.
///  - Absent GPS is NEUTRAL — WhatsApp strips it by default. The user is
///    told to ask for the photo "as a document" to preserve the data.
///  - Only a clear mismatch raises risk.
class PhotoEvidenceService {
  List<GazetteerPlace>? _places;

  Future<List<GazetteerPlace>> loadGazetteer() async {
    if (_places != null) return _places!;
    final raw = await rootBundle.loadString('assets/data/gazetteer.json');
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _places = (json['places'] as List)
        .map((e) => GazetteerPlace.fromJson(e as Map<String, dynamic>))
        .toList();
    return _places!;
  }

  /// Find the gazetteer place best matching the user-typed area name.
  GazetteerPlace? matchPlace(String area, List<GazetteerPlace> places) {
    final needle = area.trim().toLowerCase();
    if (needle.isEmpty) return null;
    for (final p in places) {
      final name = p.name.toLowerCase();
      if (name == needle || needle.contains(name) || name.contains(needle)) {
        return p;
      }
    }
    return null;
  }

  /// Extract GPS coordinates and the original timestamp from a photo file.
  Future<PhotoEvidence> readPhoto(String path) async {
    final bytes = await File(path).readAsBytes();
    final tags = await readExifFromBytes(bytes);

    double? lat = _gpsToDouble(tags['GPS GPSLatitude']);
    double? lon = _gpsToDouble(tags['GPS GPSLongitude']);
    if (lat != null && tags['GPS GPSLatitudeRef']?.printable == 'S') {
      lat = -lat;
    }
    if (lon != null && tags['GPS GPSLongitudeRef']?.printable == 'W') {
      lon = -lon;
    }

    DateTime? takenAt;
    final dt = tags['EXIF DateTimeOriginal'] ?? tags['Image DateTime'];
    if (dt != null) {
      // EXIF format: "2026:03/14 10:22:31" style "YYYY:MM:DD HH:MM:SS"
      final m = RegExp(r'^(\d{4}):(\d{2}):(\d{2})[ T](\d{2}):(\d{2}):(\d{2})')
          .firstMatch(dt.printable);
      if (m != null) {
        takenAt = DateTime(
          int.parse(m[1]!),
          int.parse(m[2]!),
          int.parse(m[3]!),
          int.parse(m[4]!),
          int.parse(m[5]!),
          int.parse(m[6]!),
        );
      }
    }

    return PhotoEvidence(path: path, lat: lat, lon: lon, takenAt: takenAt);
  }

  double? _gpsToDouble(IfdTag? tag) {
    if (tag == null) return null;
    final values = tag.values.toList();
    if (values.length < 3) return null;
    double toD(dynamic v) {
      if (v is Ratio) return v.numerator / v.denominator;
      return (v as num).toDouble();
    }

    try {
      final d = toD(values[0]);
      final m = toD(values[1]);
      final s = toD(values[2]);
      return d + m / 60 + s / 3600;
    } catch (_) {
      return null;
    }
  }

  /// Compare one photo against the claimed area.
  PhotoCheckResult check({
    required PhotoEvidence evidence,
    required String claimedArea,
    required List<GazetteerPlace> places,
    DateTime? now,
  }) {
    final place = matchPlace(claimedArea, places);

    int? ageDays;
    if (evidence.takenAt != null) {
      ageDays = (now ?? DateTime.now()).difference(evidence.takenAt!).inDays;
    }

    if (!evidence.hasGps) {
      return PhotoCheckResult(
        evidence: evidence,
        finding: GpsFinding.noGps,
        claimedPlace: place,
        photoAgeDays: ageDays,
      );
    }
    if (place == null) {
      return PhotoCheckResult(
        evidence: evidence,
        finding: GpsFinding.areaUnknown,
        photoAgeDays: ageDays,
      );
    }

    final dist = distanceKm(evidence.lat!, evidence.lon!, place.lat, place.lon);
    final finding =
        dist <= place.radiusKm ? GpsFinding.matches : GpsFinding.mismatch;

    return PhotoCheckResult(
      evidence: evidence,
      finding: finding,
      claimedPlace: place,
      distanceKm: dist,
      photoAgeDays: ageDays,
    );
  }

  /// Haversine great-circle distance in km.
  static double distanceKm(
      double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_rad(lat1)) *
            math.cos(_rad(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
