/// Number formatting helpers for Warehouse Sort's infinite-scaling
/// economy. The Districts + Reputation meta-loop produces exponentially
/// growing cash values — by District 20 the player is earning $1M+ per
/// clear, by District 50 it's 10^15+. Raw numbers ($1,234,567,890,123)
/// break the HUD layout and stop being readable. This module formats
/// them with AdVenture-Capitalist-style suffixes (K, M, B, T, Qa, ...)
/// so the player can pattern-match growth at a glance.
///
/// Pattern: split the value's magnitude into 3-digit groups (10^3,
/// 10^6, 10^9, ...), pick the matching suffix, format the mantissa
/// with 1-2 decimal places (truncated, not rounded — players notice
/// "10K" for $9999 and feel cheated). Negative values get a leading
/// minus sign; zero is just "0".
///
/// The suffix list goes up to 10^48 (Qid). Past that we fall back to
/// scientific notation ("1.2e52") rather than invent more letters
/// nobody recognizes — by then the player has cleared 100+ districts
/// and the numbers have stopped meaning anything specific anyway.
library;

import 'dart:math' as math;

/// Standard idle-game suffix progression. Each entry covers a 10^3
/// band. Index 0 = no suffix, index 1 = K (thousand), index 2 = M
/// (million), and so on. Sourced from common short-scale conventions
/// used by AdVenture Capitalist, Cookie Clicker, Tap Titans 2, etc.
const List<String> _suffixes = [
  '',     // 10^0  — ones
  'K',    // 10^3  — thousand
  'M',    // 10^6  — million
  'B',    // 10^9  — billion
  'T',    // 10^12 — trillion
  'Qa',   // 10^15 — quadrillion
  'Qi',   // 10^18 — quintillion
  'Sx',   // 10^21 — sextillion
  'Sp',   // 10^24 — septillion
  'Oc',   // 10^27 — octillion
  'No',   // 10^30 — nonillion
  'Dc',   // 10^33 — decillion
  'Ud',   // 10^36 — undecillion
  'Dd',   // 10^39 — duodecillion
  'Td',   // 10^42 — tredecillion
  'Qad',  // 10^45 — quattuordecillion
  'Qid',  // 10^48 — quindecillion
];

/// Format a cash / currency value with idle-game-style suffixes.
///
/// Examples:
///   `formatCash(0)`            → "0"
///   `formatCash(42)`           → "42"
///   `formatCash(1234)`         → "1.23K"
///   `formatCash(1_500_000)`    → "1.50M"
///   `formatCash(1_500_000_000)`→ "1.50B"
///   `formatCash(-2500)`        → "-2.50K"
///
/// Values below 1000 are rendered as integers (no decimal). From 1000
/// up, two decimal places. This matches AdVenture Capitalist's display
/// convention — the eye reads "1.23M" and "12.3M" as different orders
/// without having to count digits.
///
/// [decimals] overrides the default decimal count. Useful for compact
/// HUD chips that want "1.2K" instead of "1.23K".
String formatCash(num value, {int? decimals}) {
  if (value == 0) return '0';
  final isNegative = value < 0;
  final abs = value.abs().toDouble();

  // Below 1000: render as integer, no suffix. Whole dollars feel more
  // tactile than "0.99K" for a $987 payout.
  if (abs < 1000) {
    final s = abs.toInt().toString();
    return isNegative ? '-$s' : s;
  }

  // Find the suffix band via log10. Add a tiny epsilon to handle the
  // IEEE 754 case where exact powers of 10 evaluate slightly under
  // (e.g. log10(1e33) ≈ 32.99999... not 33.0 — would land us in the
  // wrong band without the nudge). Epsilon is small enough that it
  // doesn't push genuine sub-power values into the wrong band.
  final logExp = (math.log(abs) / math.ln10 + 1e-9).floor();
  int suffixIndex = (logExp ~/ 3).clamp(0, _suffixes.length - 1);
  // `math.pow(10, N)` returns `num` and overflows to int wraparound
  // past 2^63 (~10^19). Force double semantics by passing a double
  // base so the result stays IEEE 754 across the full 10^48 range.
  double mantissa = abs / math.pow(10.0, suffixIndex * 3).toDouble();

  // Edge case: floating-point can give mantissa slightly above 1000
  // (e.g. 999.9999...→1000.000...01) which would push us into the
  // next band's display. Bump up if needed.
  if (mantissa >= 1000 && suffixIndex < _suffixes.length - 1) {
    mantissa /= 1000;
    suffixIndex++;
  }

  // Past the suffix table: scientific notation fallback.
  if (mantissa >= 1000) {
    final sci = abs.toStringAsExponential(2);
    return isNegative ? '-$sci' : sci;
  }

  final decimalCount = decimals ?? 2;
  // Truncate (not round) toward zero — 9999 should read "9.99K" not
  // "10K". Players see the higher number as a separate band beat.
  final factor = math.pow(10.0, decimalCount).toDouble();
  final truncated = (mantissa * factor).floor() / factor;
  String mantissaStr = truncated.toStringAsFixed(decimalCount);
  // Strip trailing zeros (1.00K → 1K, 1.50K → 1.5K).
  if (mantissaStr.contains('.')) {
    mantissaStr = mantissaStr.replaceAll(RegExp(r'0+$'), '');
    mantissaStr = mantissaStr.replaceAll(RegExp(r'\.$'), '');
  }

  final out = '$mantissaStr${_suffixes[suffixIndex]}';
  return isNegative ? '-$out' : out;
}

/// Compact one-decimal variant for tight HUD pills (e.g. WH Lv chip,
/// cash chip on home). Same as `formatCash(value, decimals: 1)`.
String formatCashCompact(num value) => formatCash(value, decimals: 1);

/// Format with a leading dollar sign. Convenience for receipt payouts,
/// shop prices, etc. that always show currency.
///   `formatCashWithSymbol(1500000)` → "$1.50M"
String formatCashWithSymbol(num value, {int? decimals}) {
  if (value < 0) {
    return '-\$${formatCash(value.abs(), decimals: decimals)}';
  }
  return '\$${formatCash(value, decimals: decimals)}';
}

/// Format an income multiplier with an "×" suffix.
///   `formatMultiplier(1.0)`   → "1×"
///   `formatMultiplier(1.5)`   → "1.5×"
///   `formatMultiplier(10.75)` → "10.75×"
///   `formatMultiplier(100)`   → "100×"
///
/// Multipliers don't use idle-game suffixes — they max out in the
/// double digits typically. We just trim trailing zeros so "1.00×"
/// reads as "1×".
String formatMultiplier(double value) {
  if (value == value.roundToDouble() && value < 1000) {
    return '${value.toInt()}×';
  }
  String s = value.toStringAsFixed(2);
  if (s.contains('.')) {
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
  }
  return '$s×';
}

/// Format an XP value. XP is usually smaller than cash and doesn't
/// reach exponential territory in current scope, but we still want
/// graceful scaling for the Reputation tier ladder.
String formatXp(int value) => formatCash(value, decimals: 1);

/// Parse the suffix portion of a formatted string back into a
/// 10^N exponent — primarily useful for tests + balance audits.
/// Returns null if the suffix is unknown or empty.
int? parseSuffixExponent(String suffix) {
  if (suffix.isEmpty) return 0;
  final idx = _suffixes.indexOf(suffix);
  return idx < 0 ? null : idx * 3;
}
