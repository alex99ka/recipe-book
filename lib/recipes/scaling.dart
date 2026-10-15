/// Scale the amounts inside free-text ingredient lines ("2 קילו אסאדו", "½ כוס").
/// A port of the server's static/js/scale.js (scaling.py mirrors it for the
/// panel); test/scaling_test.dart holds it to the same cases, so the app and
/// the panel never disagree on an amount.
library;

// "¹/₂" appears in text lifted from PDFs; normalise to plain digits first.
const _sup = {'⁰': '0', '¹': '1', '²': '2', '³': '3', '⁴': '4', '⁵': '5', '⁶': '6', '⁷': '7', '⁸': '8', '⁹': '9'};
const _sub = {'₀': '0', '₁': '1', '₂': '2', '₃': '3', '₄': '4', '₅': '5', '₆': '6', '₇': '7', '₈': '8', '₉': '9'};
const _vulgar = {
  '½': '1/2', '⅓': '1/3', '⅔': '2/3', '¼': '1/4', '¾': '3/4', '⅕': '1/5', '⅖': '2/5',
  '⅗': '3/5', '⅘': '4/5', '⅙': '1/6', '⅚': '5/6', '⅛': '1/8', '⅜': '3/8', '⅝': '5/8', '⅞': '7/8',
};

String _normalise(String text) => text.split('').map((c) => _sup[c] ?? _sub[c] ?? _vulgar[c] ?? c).join();

/// Nearest tidy fraction: 0.75 reads as 3/4, and 0.33 as 1/3.
String pretty(double value) {
  if (!value.isFinite) return '$value';
  final rounded = (value * 1000).round() / 1000;
  if ((rounded - rounded.round()).abs() < 0.001) return '${rounded.round()}';
  final whole = rounded.floor();
  final frac = rounded - whole;
  const options = [[1, 2], [1, 3], [2, 3], [1, 4], [3, 4], [1, 8], [3, 8], [5, 8], [7, 8], [1, 6], [5, 6]];
  List<int>? best;
  var bestErr = 0.045; // tighter than this and 0.3 becomes "0.3"
  for (final o in options) {
    final err = (frac - o[0] / o[1]).abs();
    if (err < bestErr) {
      bestErr = err;
      best = o;
    }
  }
  if (best != null) {
    final f = '${best[0]}/${best[1]}';
    return whole != 0 ? '$whole $f' : f;
  }
  final r = (rounded * 100).round() / 100;
  return r == r.roundToDouble() ? '${r.round()}' : '$r';
}

// Mixed numbers first, then fractions, then plain numbers: in any other order
// "1 1/2" would match as "1" followed by "1/2".
final _num = RegExp(r'(\d+)\s+(\d+)/(\d+)|(\d+)/(\d+)|(\d+(?:[.,]\d+)?)');

/// The line with every amount multiplied by [factor]. A line with no number
/// ("כף מלח") gets a visible "×2" in front instead of being left silently wrong.
String scaleIngredient(String text, int factor) {
  if (factor == 1) return text;
  final clean = _normalise(text);
  if (!_num.hasMatch(clean)) return '×$factor $text';
  return clean.replaceAllMapped(_num, (m) {
    final double value;
    if (m[1] != null) {
      value = int.parse(m[1]!) + int.parse(m[2]!) / int.parse(m[3]!);
    } else if (m[4] != null) {
      value = int.parse(m[4]!) / int.parse(m[5]!);
    } else {
      value = double.parse(m[6]!.replaceAll(',', '.'));
    }
    return value.isFinite ? pretty(value * factor) : m[0]!;
  });
}
