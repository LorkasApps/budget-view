import 'package:budget_view/features/analytics/domain/forecast.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pure OLS, known answers. No Isar, no widgets.
void main() {
  test('a perfectly linear series fits exactly', () {
    final fit = fitLinear([1000, 2000, 3000, 4000]);

    expect(fit.slope, closeTo(1000, 1e-9));
    expect(fit.intercept, closeTo(1000, 1e-9));
    expect(fit.r2, closeTo(1.0, 1e-9));
    expect(fit.valueAt(4), closeTo(5000, 1e-9));
  });

  test('a falling series has a negative slope', () {
    final fit = fitLinear([3000, 2000, 1000]);

    expect(fit.slope, closeTo(-1000, 1e-9));
    expect(fit.r2, closeTo(1.0, 1e-9));
    expect(fit.valueAt(3), closeTo(0, 1e-9));
    expect(fit.valueAt(4), closeTo(-1000, 1e-9));
  });

  test('a flat series has slope 0 and no explainable variance', () {
    final fit = fitLinear([500, 500, 500, 500]);

    expect(fit.slope, 0);
    expect(fit.intercept, closeTo(500, 1e-9));
    // Not 1.0: nothing was explained, and 0/0 must not surface as NaN.
    expect(fit.r2, 0);
  });

  test('a series of zeros stays finite', () {
    final fit = fitLinear([0, 0, 0]);

    expect(fit.slope, 0);
    expect(fit.r2, 0);
    expect(fit.valueAt(3), 0);
  });

  test('a noisy rising series keeps the trend and a high r2', () {
    final fit = fitLinear([1050, 1900, 3100, 3950, 5050]);

    expect(fit.slope, closeTo(1000, 60));
    expect(fit.r2, greaterThan(0.99));
  });

  test('scattered data reports a low r2', () {
    final fit = fitLinear([1000, 5000, 1200, 4800, 1100]);

    expect(fit.r2, lessThan(0.2));
  });

  test('too few points degrade instead of dividing by zero', () {
    expect(fitLinear([]).slope, 0);
    expect(fitLinear([]).intercept, 0);
    expect(fitLinear([700]).slope, 0);
    expect(fitLinear([700]).intercept, 700);
    expect(fitLinear([700]).r2, 0);
  });

  test('two points still define a line', () {
    final fit = fitLinear([1000, 3000]);

    expect(fit.slope, closeTo(2000, 1e-9));
    expect(fit.r2, closeTo(1.0, 1e-9));
  });
}
