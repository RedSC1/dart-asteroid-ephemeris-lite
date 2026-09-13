# Third-party notices

`asteroid_ephemeris_lite` contains compact fitted coefficients generated from the canonical minor-body vectors published by the author's [`ephemeris-data`](https://github.com/RedSC1/ephemeris-data) project. That dataset combines NASA/JPL small-body SPKs with project-generated numerical extensions outside the official kernel intervals. The pub package contains only fitted coefficients, not SPK files or canonical sample arrays.

- JPL small-body kernel archive: <https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/asteroids/>
- JPL Horizons: <https://ssd.jpl.nasa.gov/horizons/>
- `ephemeris-data` derived material is available under Apache License 2.0: <https://www.apache.org/licenses/LICENSE-2.0>

Ceres, Pallas, Juno, and Vesta use JPL `sb441-n16` samples throughout the published interval. Eros uses JPL `sb441-n373s` approximately from 1550 to 2650. Asteroid 1181 Lilith, Chiron, Pholus, and Nessus use JPL Horizons SPKs approximately from 1799 to 2101. Dates outside those stated intervals use project-generated numerical extensions and must not be described as direct JPL ephemerides.

The Dart runtime evaluator, fitted representation, boundary-continuity correction, API, documentation, and tests are project-generated and distributed under the package's MPL-2.0 license. The numerical model and generated coefficient payload are ported from [`asteroid-ephemeris-lite`](https://github.com/RedSC1/js-ephemeris-lite/tree/main/packages/asteroids), also distributed under MPL-2.0.
