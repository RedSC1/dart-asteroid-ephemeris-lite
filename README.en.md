# asteroid_ephemeris_lite

[简体中文](https://github.com/RedSC1/dart-asteroid-ephemeris-lite/blob/main/README.md) | [English](https://github.com/RedSC1/dart-asteroid-ephemeris-lite/blob/main/README.en.md)

A lightweight asteroid ephemeris package for Dart and Flutter. It provides heliocentric and geocentric geometric positions for nine minor bodies in fixed mean-J2000 ecliptic axes. Results are three-dimensional vectors in AU. The implementation is pure Dart and supports Dart VM and Dart Web.

This package is ported from [`asteroid-ephemeris-lite`](https://www.npmjs.com/package/asteroid-ephemeris-lite). It uses [`ephemeris_lite`](https://pub.dev/packages/ephemeris_lite) for coordinate conversion and Earth positions. Asteroid coefficients are distributed separately so applications that only need the astronomy and calendar core do not download them.

## Installation

```yaml
dependencies:
  ephemeris_lite: ^1.1.0
  asteroid_ephemeris_lite: ^1.0.0
```

Run `dart pub get`, or `flutter pub get` in a Flutter project.

## Usage

```dart
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
  print(ceresFromSun);
  print(chironFromEarth);
}
```

The complete runnable source is available in [`example/main.dart`](https://github.com/RedSC1/dart-asteroid-ephemeris-lite/blob/main/example/main.dart).

Supported bodies are Ceres, Pallas, Juno, Vesta, Eros, asteroid 1181 Lilith, Chiron, Pholus, and Nessus. `Asteroid.lilith1181` means asteroid 1181 and is unrelated to the lunar-apogee point sometimes called Black Moon Lilith.

## Time and coordinates

- Input is a finite Julian day on the TT time scale. The supported interval is astronomical years -3000 through 3000.
- Output is an AU vector in fixed mean-J2000 ecliptic and equinox axes.
- The heliocentric function is Sun-centered. The geocentric function subtracts the Earth model selected by `accuracy`.
- `accuracy` changes only the Earth model used for geocentric subtraction, not the asteroid model.
- Results are geometric positions without light time, aberration, gravitational deflection, precession-nutation, or topocentric parallax.
- Offline source samples use TDB. The millisecond-scale periodic TT-TDB difference is far below this compact model's error budget.

## Models and accuracy

Six moderate-eccentricity bodies use segmented Poisson fits of osculating elements. Three centaurs use adaptive Cartesian Chebyshev fits. A quintic correction near each segment boundary keeps positions continuous. The public API does not provide asteroid velocities and makes no analytic velocity claim.

The following results were observed on independent cross-epoch samples relative to the offline reference vectors. They are not strict bounds for arbitrary instants. `asteroidModelInfo.positionErrorBudgetKm` contains more conservative regression limits.

| Body | 3D position RMS | Maximum 3D position | Maximum direction error |
| --- | ---: | ---: | ---: |
| Ceres | 14,835 km | 50,379 km | 26.94″ |
| Pallas | 24,994 km | 98,847 km | 72.48″ |
| Juno | 46,907 km | 232,321 km | 158.24″ |
| Vesta | 13,181 km | 34,484 km | 21.77″ |
| Eros | 19,662 km | 95,804 km | 113.08″ |
| 1181 Lilith | 7,649 km | 44,878 km | 26.75″ |
| Chiron | 557 km | 2,185 km | 0.31″ |
| Pholus | 590 km | 3,665 km | 0.48″ |
| Nessus | 496 km | 915 km | 0.09″ |

These models suit approximate positions, visualization, and candidate-event screening in size-constrained applications. Use a suitable JPL SPK or another validated numerical ephemeris for astrometry, occultation prediction, spacecraft navigation, or work requiring kilometre-level guarantees.

## Data provenance and long-range limits

- Ceres, Pallas, Juno, and Vesta use JPL `sb441-n16` samples throughout the published interval.
- Eros uses JPL `sb441-n373s` approximately from 1550 to 2650; dates outside that interval use continuous project-generated numerical integrations.
- Asteroid 1181 Lilith, Chiron, Pholus, and Nessus use JPL Horizons SPKs approximately from 1799 to 2101; dates outside that interval use extensions from the same offline data project.

Results outside the stated official SPK intervals must not be described as direct JPL ephemerides. Long-range uncertainty also grows through initial-orbit uncertainty, dynamical-model limits, and chaotic amplification during close encounters.

## License and attribution

[MPL-2.0](https://github.com/RedSC1/dart-asteroid-ephemeris-lite/blob/main/LICENSE) · [Third-party notices](https://github.com/RedSC1/dart-asteroid-ephemeris-lite/blob/main/THIRD_PARTY_NOTICES.md) · [中文第三方声明](https://github.com/RedSC1/dart-asteroid-ephemeris-lite/blob/main/THIRD_PARTY_NOTICES.zh-CN.md)
