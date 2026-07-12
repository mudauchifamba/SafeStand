/// Parses a location "pin" the seller shared — either raw coordinates or a
/// Google Maps link — into a lat/lon pair.
///
/// Accepted forms:
///   -17.9123, 30.9876
///   -17.9123 30.9876
///   https://www.google.com/maps?q=-17.9123,30.9876
///   https://www.google.com/maps/@-17.9123,30.9876,17z
///   https://maps.google.com/?q=-17.9123,30.9876
///   geo:-17.9123,30.9876
///
/// Short links (maps.app.goo.gl/...) can't be resolved offline; we return
/// null and the UI tells the user to open the link and copy the coordinates.
class PinParser {
  static final _coordPair = RegExp(
      r'(-?\d{1,2}(?:\.\d+))\s*[, ]\s*(-?\d{1,3}(?:\.\d+))');

  // Comma-decimal locales (common on Zimbabwean phones): "-17,908532".
  // A comma immediately followed by digits is a decimal separator — a real
  // thousands grouping would put the number far outside coordinate range,
  // so the range check below disambiguates safely.
  static final _commaDecimal = RegExp(r'-?\d{1,3},\d+');

  /// Returns (lat, lon) or null if nothing parseable was found.
  static (double, double)? parse(String input) {
    final text = Uri.decodeFull(input.trim());
    if (text.isEmpty) return null;

    final m = _coordPair.firstMatch(text);
    if (m != null) {
      return _validated(double.tryParse(m[1]!), double.tryParse(m[2]!));
    }

    // Fallback: comma-decimal pair, e.g. "-17,908532, 30,810459".
    final cm = _commaDecimal.allMatches(text).toList();
    if (cm.length == 2) {
      return _validated(
        double.tryParse(cm[0].group(0)!.replaceAll(',', '.')),
        double.tryParse(cm[1].group(0)!.replaceAll(',', '.')),
      );
    }
    return null;
  }

  static (double, double)? _validated(double? lat, double? lon) {
    if (lat == null || lon == null) return null;
    if (lat.abs() > 90 || lon.abs() > 180) return null;
    return (lat, lon);
  }

  /// True for shortened map links that need opening in a browser first.
  static bool isShortLink(String input) {
    final t = input.trim().toLowerCase();
    return t.contains('maps.app.goo.gl') || t.contains('goo.gl/maps');
  }
}
