import 'dart:convert';
import 'dart:io';

import 'package:asteroid_ephemeris_lite/asteroid_ephemeris_lite.dart';
import 'package:ephemeris_lite/ephemeris_lite.dart';
import 'package:test/test.dart';

Asteroid _bodyById(String id) =>
    Asteroid.values.singleWhere((body) => body.id == id);

void _expectVectorClose(List<double> actual, List<dynamic> expected) {
  for (var index = 0; index < 3; index++) {
    expect(actual[index], closeTo((expected[index] as num).toDouble(), 3e-13));
  }
}

void main() {
  test('public results match the JavaScript implementation', () {
    final fixture =
        jsonDecode(
              File('test/fixtures/js-public-positions.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    for (final rawRow in fixture['rows'] as List<dynamic>) {
      final row = rawRow as Map<String, dynamic>;
      final body = _bodyById(row['body'] as String);
      final jdTT = (row['jdTT'] as num).toDouble();
      _expectVectorClose(
        asteroidHeliocentricPosition(body, jdTT),
        row['heliocentric'] as List<dynamic>,
      );
      _expectVectorClose(
        asteroidGeocentricPosition(body, jdTT, accuracy: Accuracy.fast),
        row['geocentricFast'] as List<dynamic>,
      );
      _expectVectorClose(
        asteroidGeocentricPosition(body, jdTT),
        row['geocentricAccurate'] as List<dynamic>,
      );
    }
  });
}
