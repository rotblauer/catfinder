import 'dart:math';

extension Precision on double {
  double toPrecision(int fractionDigits) {
    if (this == null || this.isInfinite || this.isNaN || this == 0) return 0;
    double mod = pow(10, fractionDigits.toDouble());
    double out;
    try {
      out = ((this * mod).round().toDouble() / mod);
    } catch (err) {
      print('toPrecision failed: ${err.toString()} (value was: ${this}');
    }
    return out;
  }
}
