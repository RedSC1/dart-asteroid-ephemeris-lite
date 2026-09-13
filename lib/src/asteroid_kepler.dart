import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

const maxAsteroidExpansionEccentricity = 0.42;
const _harmonicCount = 16;
const _eccentricityDegree = 10;
const _coefficientWidth = _eccentricityDegree + 1;

const _packedCoefficients =
    'MivUPsK/0j73KFi7dwkGunP7hzeaiw42lMsfNPEeojKVjgYxWBuDL6PJ6y3glaE9l2fVPRU3yTxGp1u6sKvHuGh5SzarWZg0evMUMphkqTAnzSYvdHOhLWh+vDxQ/As9S4lWPONX6jp2SCC5hRtSt/nxOzWxi0sz+dmRrx2ChS7NWYQtHZcDPKuOUDzyJsk7QbnOOh8d7Tglfs63Hte0taCRHTQBJPIxiT+sr8icaKy5+Eo7SqOnOwWbOTsO5YA6hso3OZEy5TX7HXO23VXYs4i76zJBQWAwa0/QrhLGpjr4wQ07czqsOkXdDzruARY5gpSMN2R8sLXU1gK1bwrUMFrlnjG6ekwueSwPOtaZeDqUgCE6hSqZOQuHyDjsd503cBCTNXiRu7TusHuz2K04MSAuQTDj2305PwHgOVAfmTlObx85q/dzOIv6fTfZ3A82tyMQs4xnibOAE8qxNmlHMFWo5jhDK045MK4SOWUdpDge4Qw4Q90wN2pvETaZvEs0fy0Cs3ylJ7LktM6vxq5VOAABwTjE0Y04zwUoOEarnTei4+I2fpzqNRDLkjRgn88xAMT8sf/1rrARF8k33jU3OItBCjiQoqs3XfUsN/A9ijaBAag1rpaNNMO/8TJOkyqxevS3sKS1Pzd88a8338WHNzA9LzceO7s2BcYiNgSUXzXxNWU0JjwYMwba5jAKTWKwgMS4NuahKjdyNAY3gAOzNrzdSDbIHLs1vZkNNdiUJzQNKw8zyXmJMWBKR69hvDM2x+GmNjRthTYiEzc2ySnWNYRkUzWqMK00vTPlM+nS6DISt6AxISaoL2s+sDUcaSQ24lcFNiiAuzVeXGM1fcbrNNtuTjTNhpUzkwetMuTqlDHjdRowrAYuNdYDozUo4oU19lhANSin8DRCN4I0eEvxM3dtPDOyzHEyIFhzMRRoLDA=';

final List<double> _coefficients = () {
  final bytes = base64Decode(_packedCoefficients);
  final view = ByteData.sublistView(bytes);
  return List<double>.generate(
    bytes.lengthInBytes ~/ 4,
    (index) => view.getFloat32(index * 4, Endian.little),
    growable: false,
  );
}();

double _chebyshev(int offset, double x) {
  var b1 = 0.0, b2 = 0.0;
  for (var index = _eccentricityDegree; index >= 1; index--) {
    final b0 = 2 * x * b1 - b2 + _coefficients[offset + index];
    b2 = b1;
    b1 = b0;
  }
  return x * b1 - b2 + _coefficients[offset];
}

double asteroidTrueAnomaly(double meanAnomaly, double eccentricity) {
  if (!meanAnomaly.isFinite ||
      !eccentricity.isFinite ||
      eccentricity < 0 ||
      eccentricity > maxAsteroidExpansionEccentricity + 2.220446049250313e-16) {
    throw RangeError(
      'eccentricity is outside the lightweight asteroid expansion domain',
    );
  }
  final limited = math.min(eccentricity, maxAsteroidExpansionEccentricity);
  final x = 2 * limited / maxAsteroidExpansionEccentricity - 1;
  final sinMean = math.sin(meanAnomaly), cosMean = math.cos(meanAnomaly);
  var sinHarmonic = sinMean, cosHarmonic = cosMean, correction = 0.0;
  for (var harmonic = 0; harmonic < _harmonicCount; harmonic++) {
    correction += _chebyshev(harmonic * _coefficientWidth, x) * sinHarmonic;
    final nextSin = sinHarmonic * cosMean + cosHarmonic * sinMean;
    cosHarmonic = cosHarmonic * cosMean - sinHarmonic * sinMean;
    sinHarmonic = nextSin;
  }
  return meanAnomaly + correction;
}

double asteroidOrbitalRadius(
  double semiMajorAxisAu,
  double eccentricity,
  double trueAnomaly,
) =>
    semiMajorAxisAu *
    (1 - eccentricity * eccentricity) /
    (1 + eccentricity * math.cos(trueAnomaly));
