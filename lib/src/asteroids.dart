import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ephemeris_lite/ephemeris_lite.dart';

import 'asteroid_kepler.dart';
import 'generated/asteroid_data.dart';

const _j2000 = 2451545.0;
const _julianYearDays = 365.25;
const _startYear = -3000.0;
const _endYear = 3000.0;
const _segmentYears = 600.0;
const _segmentsPerBody = 10;
const _stableBlendYears = 5.0;
const _frequencyCount = 64;
const _elementCount = 6;
const _secularCount = 6;
const _amplitudeDegree = 2;
const _coefficientRows = 390;
const _segmentBytes =
    16 + _frequencyCount * 4 + _coefficientRows * _elementCount * 4;
const _centaurStartJd = 625295.0;
const _centaurTickDays = 0.125 * _julianYearDays;
const _centaurTickCount = 48000;
const _centaurRecordBytes = 98;
const _centaurBlendFraction = 0.2;

/// A minor body supported by the lightweight model.
enum Asteroid {
  ceres('ceres'),
  pallas('pallas'),
  juno('juno'),
  vesta('vesta'),
  eros('eros'),
  lilith1181('lilith_1181'),
  chiron('chiron'),
  pholus('pholus'),
  nessus('nessus');

  const Asteroid(this.id);

  /// Stable identifier shared with the JavaScript package and data fixtures.
  final String id;
}

/// Descriptive metadata and conservative regression limits for the model.
final class AsteroidModelInfo {
  const AsteroidModelInfo({
    required this.bodies,
    required this.intervalYears,
    required this.frame,
    required this.center,
    required this.unit,
    required this.model,
    required this.continuity,
    required this.positionErrorBudgetKm,
  });

  final List<Asteroid> bodies;
  final List<int> intervalYears;
  final String frame;
  final String center;
  final String unit;
  final String model;
  final String continuity;
  final Map<Asteroid, double> positionErrorBudgetKm;
}

/// Metadata describing the published asteroid model.
final asteroidModelInfo = AsteroidModelInfo(
  bodies: List<Asteroid>.unmodifiable(Asteroid.values),
  intervalYears: List<int>.unmodifiable(const [-3000, 3000]),
  frame: 'J2000 mean/dynamical ecliptic and equinox',
  center: 'Sun',
  unit: 'AU',
  model: 'segmented Poisson elements and adaptive Cartesian Chebyshev fits',
  continuity: 'quintic boundary correction',
  positionErrorBudgetKm: Map<Asteroid, double>.unmodifiable(const {
    Asteroid.ceres: 100000.0,
    Asteroid.pallas: 450000.0,
    Asteroid.juno: 600000.0,
    Asteroid.vesta: 75000.0,
    Asteroid.eros: 200000.0,
    Asteroid.lilith1181: 100000.0,
    Asteroid.chiron: 10000.0,
    Asteroid.pholus: 10000.0,
    Asteroid.nessus: 10000.0,
  }),
);

final ByteData _stableData = ByteData.sublistView(
  base64Decode(stableAsteroidDataBase64),
);
final ByteData _centaurData = ByteData.sublistView(
  base64Decode(centaurAsteroidDataBase64),
);

({bool centaur, int index}) _descriptor(Asteroid body) {
  final index = body.index;
  return index < 6
      ? (centaur: false, index: index)
      : (centaur: true, index: index - 6);
}

double _checkedYear(double jdTT) {
  if (!jdTT.isFinite) {
    throw ArgumentError.value(jdTT, 'jdTT', 'must be finite');
  }
  final year = 2000 + (jdTT - _j2000) / _julianYearDays;
  if (year < _startYear || year > _endYear) {
    throw RangeError(
      'asteroid model supports astronomical years '
      '${_startYear.toInt()} through ${_endYear.toInt()}',
    );
  }
  return year;
}

double _coefficient(ByteData view, int base, int row, int element) {
  final offset =
      base + 16 + _frequencyCount * 4 + (row * _elementCount + element) * 4;
  return view.getFloat32(offset, Endian.little);
}

List<double> _evaluateSegmentElements(
  int bodyIndex,
  int segmentIndex,
  double jdTT,
) {
  final base = (bodyIndex * _segmentsPerBody + segmentIndex) * _segmentBytes;
  final epoch = _stableData.getFloat64(base, Endian.little);
  final halfSpan = _stableData.getFloat64(base + 8, Endian.little);
  final normalized = (jdTT - epoch) / halfSpan;
  final years = (jdTT - epoch) / _julianYearDays;
  final elements = List<double>.filled(_elementCount, 0);

  var power = 1.0;
  for (var row = 0; row < _secularCount; row++) {
    for (var element = 0; element < _elementCount; element++) {
      elements[element] +=
          power * _coefficient(_stableData, base, row, element);
    }
    power *= normalized;
  }

  var envelope = 1.0;
  for (var degree = 0; degree <= _amplitudeDegree; degree++) {
    final cosineRow = _secularCount + degree * 2 * _frequencyCount;
    final sineRow = cosineRow + _frequencyCount;
    for (
      var frequencyIndex = 0;
      frequencyIndex < _frequencyCount;
      frequencyIndex++
    ) {
      final frequency = _stableData.getFloat32(
        base + 16 + frequencyIndex * 4,
        Endian.little,
      );
      final phase = 2 * math.pi * years * frequency;
      final cosine = math.cos(phase);
      final sine = math.sin(phase);
      for (var element = 0; element < _elementCount; element++) {
        elements[element] +=
            envelope *
            (_coefficient(
                      _stableData,
                      base,
                      cosineRow + frequencyIndex,
                      element,
                    ) *
                    cosine +
                _coefficient(
                      _stableData,
                      base,
                      sineRow + frequencyIndex,
                      element,
                    ) *
                    sine);
      }
    }
    envelope *= normalized;
  }
  return elements;
}

double _smootherstep(double value) {
  final x = value.clamp(0.0, 1.0);
  return x * x * x * (x * (x * 6 - 15) + 10);
}

List<double> _correctedBoundaryPosition(
  List<double> raw,
  List<double> ownAtBoundary,
  List<double> otherAtBoundary,
  double distance,
  double width,
) {
  final weight = 1 - _smootherstep(distance / width);
  return List<double>.generate(
    3,
    (index) =>
        raw[index] +
        weight * (otherAtBoundary[index] - ownAtBoundary[index]) / 2,
    growable: false,
  );
}

List<double> _stableIcrfPosition(int bodyIndex, double jdTT, double year) {
  final segmentIndex = ((year - _startYear) / _segmentYears).floor().clamp(
    0,
    _segmentsPerBody - 1,
  );
  final raw = _elementsToPosition(
    _evaluateSegmentElements(bodyIndex, segmentIndex, jdTT),
  );
  final segmentStartYear = _startYear + segmentIndex * _segmentYears;
  final distanceFromStart = year - segmentStartYear;
  if (segmentIndex > 0 && distanceFromStart < _stableBlendYears) {
    final boundaryJd = _j2000 + (segmentStartYear - 2000) * _julianYearDays;
    final own = _elementsToPosition(
      _evaluateSegmentElements(bodyIndex, segmentIndex, boundaryJd),
    );
    final other = _elementsToPosition(
      _evaluateSegmentElements(bodyIndex, segmentIndex - 1, boundaryJd),
    );
    return _correctedBoundaryPosition(
      raw,
      own,
      other,
      distanceFromStart,
      _stableBlendYears,
    );
  }
  final distanceFromEnd = segmentStartYear + _segmentYears - year;
  if (segmentIndex + 1 < _segmentsPerBody &&
      distanceFromEnd < _stableBlendYears) {
    final boundaryJd =
        _j2000 + (segmentStartYear + _segmentYears - 2000) * _julianYearDays;
    final own = _elementsToPosition(
      _evaluateSegmentElements(bodyIndex, segmentIndex, boundaryJd),
    );
    final other = _elementsToPosition(
      _evaluateSegmentElements(bodyIndex, segmentIndex + 1, boundaryJd),
    );
    return _correctedBoundaryPosition(
      raw,
      own,
      other,
      distanceFromEnd,
      _stableBlendYears,
    );
  }
  return raw;
}

List<double> _elementsToPosition(List<double> elements) {
  final semiMajorAxis = elements[0];
  final eccentricity = elements[1];
  final inclination = elements[2];
  final ascendingNode = elements[3];
  final periapsis = elements[4];
  final meanAnomaly = elements[5];
  final trueAnomaly = asteroidTrueAnomaly(meanAnomaly, eccentricity);
  final radius = asteroidOrbitalRadius(
    semiMajorAxis,
    eccentricity,
    trueAnomaly,
  );
  final xOrbit = radius * math.cos(trueAnomaly);
  final yOrbit = radius * math.sin(trueAnomaly);
  final cosineNode = math.cos(ascendingNode);
  final sineNode = math.sin(ascendingNode);
  final cosineInclination = math.cos(inclination);
  final sineInclination = math.sin(inclination);
  final cosinePeriapsis = math.cos(periapsis);
  final sinePeriapsis = math.sin(periapsis);
  return [
    (cosineNode * cosinePeriapsis -
                sineNode * sinePeriapsis * cosineInclination) *
            xOrbit +
        (-cosineNode * sinePeriapsis -
                sineNode * cosinePeriapsis * cosineInclination) *
            yOrbit,
    (sineNode * cosinePeriapsis +
                cosineNode * sinePeriapsis * cosineInclination) *
            xOrbit +
        (-sineNode * sinePeriapsis +
                cosineNode * cosinePeriapsis * cosineInclination) *
            yOrbit,
    sinePeriapsis * sineInclination * xOrbit +
        cosinePeriapsis * sineInclination * yOrbit,
  ];
}

int _centaurBodyRecordOffset(int bodyIndex) {
  var records = 0;
  for (var index = 0; index < bodyIndex; index++) {
    records += centaurAsteroidCounts[index];
  }
  return records;
}

({int index, int offset, int startTick, int endTick}) _centaurRecord(
  int bodyIndex,
  int index,
) {
  final count = centaurAsteroidCounts[bodyIndex];
  final bodyRecordOffset = _centaurBodyRecordOffset(bodyIndex);
  final offset = (bodyRecordOffset + index) * _centaurRecordBytes;
  final startTick = _centaurData.getUint16(offset, Endian.little);
  final endTick = index + 1 < count
      ? _centaurData.getUint16(offset + _centaurRecordBytes, Endian.little)
      : _centaurTickCount;
  return (index: index, offset: offset, startTick: startTick, endTick: endTick);
}

({int index, int offset, int startTick, int endTick}) _findCentaurRecord(
  int bodyIndex,
  double jdTT,
) {
  final count = centaurAsteroidCounts[bodyIndex];
  final bodyOffset = _centaurBodyRecordOffset(bodyIndex) * _centaurRecordBytes;
  final targetTick = (jdTT - _centaurStartJd) / _centaurTickDays;
  var low = 0;
  var high = count;
  while (low + 1 < high) {
    final middle = (low + high) >>> 1;
    final tick = _centaurData.getUint16(
      bodyOffset + middle * _centaurRecordBytes,
      Endian.little,
    );
    if (tick <= targetTick) {
      low = middle;
    } else {
      high = middle;
    }
  }
  return _centaurRecord(bodyIndex, low);
}

double _centaurChebyshev(int offset, double x) {
  var b1 = 0.0;
  var b2 = 0.0;
  for (var degree = 7; degree >= 1; degree--) {
    final coefficient = _centaurData.getFloat32(
      offset + degree * 4,
      Endian.little,
    );
    final b0 = 2 * x * b1 - b2 + coefficient;
    b2 = b1;
    b1 = b0;
  }
  return x * b1 - b2 + _centaurData.getFloat32(offset, Endian.little);
}

List<double> _evaluateCentaurRecord(
  ({int index, int offset, int startTick, int endTick}) record,
  double jdTT,
) {
  final start = _centaurStartJd + record.startTick * _centaurTickDays;
  final end = _centaurStartJd + record.endTick * _centaurTickDays;
  final x = (2 * jdTT - start - end) / (end - start);
  return [
    _centaurChebyshev(record.offset + 2, x),
    _centaurChebyshev(record.offset + 34, x),
    _centaurChebyshev(record.offset + 66, x),
  ];
}

List<double> _correctCentaurBoundary(
  int bodyIndex,
  ({int index, int offset, int startTick, int endTick}) record,
  List<double> raw,
  int adjacentIndex,
  int boundaryTick,
  double distance,
) {
  final adjacent = _centaurRecord(bodyIndex, adjacentIndex);
  final boundaryJd = _centaurStartJd + boundaryTick * _centaurTickDays;
  final own = _evaluateCentaurRecord(record, boundaryJd);
  final other = _evaluateCentaurRecord(adjacent, boundaryJd);
  final adjacentSpan = adjacent.endTick - adjacent.startTick;
  final ownSpan = record.endTick - record.startTick;
  final width =
      math.min(ownSpan, adjacentSpan) *
      _centaurTickDays *
      _centaurBlendFraction;
  return _correctedBoundaryPosition(raw, own, other, distance, width);
}

List<double> _centaurIcrfPosition(int bodyIndex, double jdTT) {
  final record = _findCentaurRecord(bodyIndex, jdTT);
  final raw = _evaluateCentaurRecord(record, jdTT);
  final count = centaurAsteroidCounts[bodyIndex];
  final start = _centaurStartJd + record.startTick * _centaurTickDays;
  final end = _centaurStartJd + record.endTick * _centaurTickDays;
  if (record.index > 0) {
    final adjacent = _centaurRecord(bodyIndex, record.index - 1);
    final width =
        math.min(
          record.endTick - record.startTick,
          adjacent.endTick - adjacent.startTick,
        ) *
        _centaurTickDays *
        _centaurBlendFraction;
    if (jdTT - start < width) {
      return _correctCentaurBoundary(
        bodyIndex,
        record,
        raw,
        record.index - 1,
        record.startTick,
        jdTT - start,
      );
    }
  }
  if (record.index + 1 < count) {
    final adjacent = _centaurRecord(bodyIndex, record.index + 1);
    final width =
        math.min(
          record.endTick - record.startTick,
          adjacent.endTick - adjacent.startTick,
        ) *
        _centaurTickDays *
        _centaurBlendFraction;
    if (end - jdTT < width) {
      return _correctCentaurBoundary(
        bodyIndex,
        record,
        raw,
        record.index + 1,
        record.endTick,
        end - jdTT,
      );
    }
  }
  return raw;
}

List<double> _asteroidIcrfPosition(Asteroid body, double jdTT) {
  final descriptor = _descriptor(body);
  final year = _checkedYear(jdTT);
  return descriptor.centaur
      ? _centaurIcrfPosition(descriptor.index, jdTT)
      : _stableIcrfPosition(descriptor.index, jdTT, year);
}

/// Returns the geometric heliocentric position in fixed mean-J2000 ecliptic
/// axes, in astronomical units.
///
/// [jdTT] is a Julian day on the TT time scale. The model supports
/// astronomical years -3000 through 3000.
List<double> asteroidHeliocentricPosition(Asteroid body, double jdTT) =>
    List<double>.unmodifiable(
      icrfEquatorialToJ2000Ecliptic(_asteroidIcrfPosition(body, jdTT)),
    );

/// Returns the geometric geocentric position in fixed mean-J2000 ecliptic
/// axes, in astronomical units.
///
/// [accuracy] selects the Earth ephemeris used for the geocentric subtraction;
/// it does not change the asteroid model itself.
List<double> asteroidGeocentricPosition(
  Asteroid body,
  double jdTT, {
  Accuracy accuracy = Accuracy.accurate,
}) {
  final asteroid = asteroidHeliocentricPosition(body, jdTT);
  final earth = earthHeliocentricPosition(jdTT, accuracy: accuracy);
  return List<double>.unmodifiable([
    asteroid[0] - earth[0],
    asteroid[1] - earth[1],
    asteroid[2] - earth[2],
  ]);
}
