# 第三方来源说明

`asteroid_ephemeris_lite` 内置的紧凑拟合系数由作者的 [`ephemeris-data`](https://github.com/RedSC1/ephemeris-data) 项目所发布的规范小天体向量生成。该数据集结合 NASA/JPL 小天体 SPK，以及官方内核覆盖区间之外由项目生成的连续数值积分扩展。pub 包只包含拟合后的系数，不包含 SPK 文件或规范样本数组。

- JPL 小天体内核档案：<https://naif.jpl.nasa.gov/pub/naif/generic_kernels/spk/asteroids/>
- JPL Horizons：<https://ssd.jpl.nasa.gov/horizons/>
- `ephemeris-data` 衍生资料采用 Apache License 2.0：<https://www.apache.org/licenses/LICENSE-2.0>

Ceres、Pallas、Juno、Vesta 在发布范围内使用 JPL `sb441-n16` 样本。Eros 约 1550～2650 年使用 JPL `sb441-n373s`。1181 Lilith、Chiron、Pholus、Nessus 约 1799～2101 年使用 JPL Horizons SPK。上述官方区间之外采用项目生成的数值积分扩展，不应描述为 JPL 直接星历。

Dart 运行时求值器、拟合表示、边界连续性修正、API、文档和测试由本项目实现，按 MPL-2.0 发布。数值模型和生成系数载荷移植自同样采用 MPL-2.0 的 [`asteroid-ephemeris-lite`](https://github.com/RedSC1/js-ephemeris-lite/tree/main/packages/asteroids)。
