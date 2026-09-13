import 'package:asteroid_ephemeris_lite/asteroid_ephemeris_lite.dart';
import 'package:ephemeris_lite/ephemeris_lite.dart';

void main() {
  const jdTT = 2451545.0;
  final ceresFromSun = asteroidHeliocentricPosition(Asteroid.ceres, jdTT);
  final chironFromEarth = asteroidGeocentricPosition(
    Asteroid.chiron,
    jdTT,
    accuracy: Accuracy.accurate,
  );
  print('Ceres heliocentric J2000 [AU]: $ceresFromSun');
  print('Chiron geocentric J2000 [AU]: $chironFromEarth');
}
