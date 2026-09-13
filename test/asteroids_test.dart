import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:asteroid_ephemeris_lite/asteroid_ephemeris_lite.dart';
import 'package:asteroid_ephemeris_lite/src/generated/asteroid_data.dart';
import 'package:ephemeris_lite/ephemeris_lite.dart';
import 'package:test/test.dart';

const _auKm = 149597870.7;

Asteroid _bodyById(String id) =>
    Asteroid.values.singleWhere((body) => body.id == id);

double _distanceKm(List<double> left, List<double> right) =>
    math.sqrt(
      List<double>.generate(
        3,
        (index) => math.pow(left[index] - right[index], 2).toDouble(),
      ).reduce((left, right) => left + right),
    ) *
    _auKm;

void main() {
  test('positions stay inside conservative cross-epoch budgets', () {
    final fixture =
        jsonDecode(
              File('test/fixtures/asteroid-reference.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    final bodies = fixture['bodies'] as Map<String, dynamic>;
    for (final entry in bodies.entries) {
      final body = _bodyById(entry.key);
      for (final rawRow in entry.value as List<dynamic>) {
        final row = (rawRow as List<dynamic>).cast<num>();
        final jdTT = row[0].toDouble();
        final expected = icrfEquatorialToJ2000Ecliptic(
          row.skip(1).map((value) => value.toDouble()).toList(),
        );
        final actual = asteroidHeliocentricPosition(body, jdTT);
        final errorKm = _distanceKm(actual, expected);
        expect(
          errorKm,
          lessThan(asteroidModelInfo.positionErrorBudgetKm[body]!),
          reason: '${body.id} at $jdTT: $errorKm km',
        );
      }
    }
  });

  test('piecewise models do not jump at segment boundaries', () {
    const epsilonDays = 1e-6;
    for (final body in Asteroid.values.take(6)) {
      for (var year = -2400; year <= 2400; year += 600) {
        final jdTT = 2451545 + (year - 2000) * 365.25;
        final movement = _distanceKm(
          asteroidHeliocentricPosition(body, jdTT - epsilonDays),
          asteroidHeliocentricPosition(body, jdTT + epsilonDays),
        );
        expect(
          movement,
          lessThan(8),
          reason: '${body.id} boundary $year: $movement km',
        );
      }
    }

    final bytes = base64Decode(centaurAsteroidDataBase64);
    final view = ByteData.sublistView(bytes);
    const recordBytes = 98;
    var bodyRecordOffset = 0;
    for (var bodyIndex = 0; bodyIndex < 3; bodyIndex++) {
      final body = Asteroid.values[bodyIndex + 6];
      final count = centaurAsteroidCounts[bodyIndex];
      for (var record = 1; record < count; record++) {
        final tick = view.getUint16(
          (bodyRecordOffset + record) * recordBytes,
          Endian.little,
        );
        final jdTT = 625295 + tick * 0.125 * 365.25;
        final movement = _distanceKm(
          asteroidHeliocentricPosition(body, jdTT - epsilonDays),
          asteroidHeliocentricPosition(body, jdTT + epsilonDays),
        );
        expect(
          movement,
          lessThan(8),
          reason: '${body.id} boundary $jdTT: $movement km',
        );
      }
      bodyRecordOffset += count;
    }
  });

  test('geocentric positions subtract the selected Earth model', () {
    for (final body in Asteroid.values) {
      final heliocentric = asteroidHeliocentricPosition(body, 2451545);
      final earth = earthHeliocentricPosition(2451545, accuracy: Accuracy.fast);
      final geocentric = asteroidGeocentricPosition(
        body,
        2451545,
        accuracy: Accuracy.fast,
      );
      for (var index = 0; index < 3; index++) {
        expect(
          geocentric[index],
          closeTo(heliocentric[index] - earth[index], 1e-14),
        );
      }
    }
  });

  test('API validates supported dates', () {
    for (final body in Asteroid.values) {
      for (final jdTT in [625295.0, 2816795.0]) {
        expect(
          asteroidHeliocentricPosition(body, jdTT).every((x) => x.isFinite),
          isTrue,
        );
      }
    }
    expect(
      () => asteroidHeliocentricPosition(Asteroid.ceres, double.nan),
      throwsArgumentError,
    );
    expect(
      () => asteroidHeliocentricPosition(Asteroid.ceres, 625294.9),
      throwsRangeError,
    );
    expect(
      () => asteroidHeliocentricPosition(Asteroid.ceres, 2816795.1),
      throwsRangeError,
    );
  });
}
