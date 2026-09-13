import 'dart:math' as math;

import 'package:asteroid_ephemeris_lite/src/asteroid_kepler.dart';
import 'package:test/test.dart';

const _arcsecPerRadian = 206264.80624709636;

double _exactTrueAnomaly(double meanAnomaly, double eccentricity) {
  var eccentricAnomaly = meanAnomaly;
  for (var iteration = 0; iteration < 12; iteration++) {
    eccentricAnomaly -=
        (eccentricAnomaly -
            eccentricity * math.sin(eccentricAnomaly) -
            meanAnomaly) /
        (1 - eccentricity * math.cos(eccentricAnomaly));
  }
  return 2 *
      math.atan2(
        math.sqrt(1 + eccentricity) * math.sin(eccentricAnomaly / 2),
        math.sqrt(1 - eccentricity) * math.cos(eccentricAnomaly / 2),
      );
}

void main() {
  test('shared expansion stays below one arcsecond', () {
    var worstArcsec = 0.0;
    for (
      var eccentricityIndex = 0;
      eccentricityIndex <= 84;
      eccentricityIndex++
    ) {
      final eccentricity = 0.42 * eccentricityIndex / 84;
      for (var anomalyIndex = 0; anomalyIndex <= 2048; anomalyIndex++) {
        final meanAnomaly = -math.pi + 2 * math.pi * anomalyIndex / 2048;
        final approximate = asteroidTrueAnomaly(meanAnomaly, eccentricity);
        final exact = _exactTrueAnomaly(meanAnomaly, eccentricity);
        final difference = math.atan2(
          math.sin(approximate - exact),
          math.cos(approximate - exact),
        );
        worstArcsec = math.max(
          worstArcsec,
          difference.abs() * _arcsecPerRadian,
        );
      }
    }
    expect(worstArcsec, lessThan(1), reason: '$worstArcsec arcsec');
  });

  test('orbital radius is exact at apsides', () {
    expect(asteroidOrbitalRadius(2, 0.25, 0), 1.5);
    expect(asteroidOrbitalRadius(2, 0.25, math.pi), 2.5);
  });

  test('shared expansion rejects eccentricities outside its domain', () {
    expect(() => asteroidTrueAnomaly(0, 0.42001), throwsRangeError);
  });
}
