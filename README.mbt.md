# MoonSRC

纯 MoonBit 的流式音频采样率转换库。使用带抗混叠低通的多相 Blackman sinc FIR，
支持交错 PCM、调用者输出缓冲区和明确的 `finish` 语义。

当前源码版本 **0.2.0**。功能、测试与测量方法见 [测试说明](docs/TESTING.md)。
远端构建状态见 [GitHub Actions](https://github.com/yzy726/MoonSRC/actions/workflows/ci.yml)；Mooncakes 由维护者发布。

## 支持范围

| 维度 | 0.2.0 功能 |
|---|---|
| 速率 | 整数 8000..192000 Hz；最多 4096 精确相位、1,048,576 个系数，超预算返回 ResourceLimit |
| 声道 | 1..8，交错排列，各声道独立；不做声道重映射 |
| 质量 | LowLatency / Balanced（默认）/ HighQuality |
| 样本 | 有限 Double；核心不截幅，拒绝 NaN/Infinity |
| 核心后端 | native、JavaScript、wasm-gc，三个后端均实际构建和测试 |
| WAV | PCM16LE / IEEE float32；多声道 extensible；native 文件 CLI |
| 边界 | 两端零延拓；同速率精确直通、零前瞻 |

最终输出帧数为 `ceil(N * output_rate / input_rate)`，样本数为帧数乘以声道数。
部分互质速率虽然位于范围内，仍会因精确相位表预算被拒绝。
非同速率前瞻为 `R = 基础半径 * max(1, ceil(Fin/(3*Fout)))` 输入帧：
三档基础半径分别为 32/96/192，截止系数为 .90/.94/.97。
在 48→16 kHz 时前瞻分别约为 0.667/2/4 ms。见 [质量报告](docs/QUALITY.md)。

## 从源码验证

需要 MoonBit、native C 编译器、Node.js 和 Python 3.10+。本机为 Moon
0.1.20260920、moonc 0.10.14+7d59c7ec9、Node 22.19.0、Python 3.13.5。
无额外第三方 Mooncakes 运行依赖。在源码目录执行：

```sh
moon fmt --check
moon check --target native --deny-warn --warn-list +73
moon build --target native --deny-warn
moon test --target native --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
python scripts/e2e.py
python scripts/quality.py
python scripts/run_examples.py
python scripts/bounded_stream.py
python scripts/consumer.py
```

`consumer.py` 将当前 `moon package` ZIP 解压到隔离工作区，验证三个后端的公开 API。
`python scripts/consumer.py --registry-version 0.1.0` 真正从 Mooncakes 安装已发布版本，
运行旧版兼容场景。后者不包含新 API；0.2.0 注册表安装验证需待发布后执行。

## 库调用

源码工作区或安装对应版本后的消费项目 `moon.pkg`：

```mbt nocheck
///|
import {
  "Ag108/MoonSRC",
}
```

一次性处理复用相同流式引擎：

```mbt check
///|
test "readme/minimal stereo conversion" {
  let config = @MoonSRC.Config::new(44100, 48000, 2).unwrap()
  let input = Array::make(882, 0.25) // 441 stereo frames
  let output = @MoonSRC.resample(config, input[:]).unwrap()
  assert_eq(output.length(), 960) // 480 stereo frames
}
```

`Config::new` 保持 Balanced 默认；`Config::with_quality(44100,16000,8,HighQuality)`
选择新档位。`resample_into(config,input,output_buffer)` 写入调用者的 `FixedArray[Double]`，
返回完整输出帧数，保留未使用的数组尾部。

流式调用创建 `Resampler::new(config)`，用 `process` 的 `consumed_frames` 推进输入、
用 `produced_frames` 读取输出；输入结束后反复 `finish`，直到 `is_finished()`。
缓冲区长度须对齐完整声道帧，输入与输出不能共用同一存储。
见 [分块示例](examples/chunked_equivalence/main.mbt)、[流式契约](docs/STREAMING.md)
及 [0.1.0 升级说明](docs/MIGRATION.md)。

## WAV CLI

```sh
moon run --target native cmd/main -- --help
moon run --target native cmd/main -- fixture _build/input.wav --rate 44100 --channels 6 --frames 441 --format float32
moon run --target native cmd/main -- convert _build/input.wav _build/output.wav --rate 48000 --quality high --format float32
```

结果为 480 帧、6 声道、48 kHz float32 WAV。输入格式自动识别；默认输出仍为 PCM16、
质量为 Balanced。输出路径必须不存在，重复运行请换新路径。
WAV 最多 33,554,476 字节；整段转换最多 16,777,216 输出样本，长流使用分块 API。
PCM16 显式饱和、离零舍入并计数；float32 不按 ±1 截幅，拒绝转换后成为无穷的值。
见 [格式与资源边界](docs/SCOPE.md)。

## 九个示例

```sh
moon run --target native examples/memory_44100_to_48000
moon run --target native examples/speech_48000_to_16000
moon run --target native examples/chunked_equivalence
moon run --target native examples/channel_isolation
moon run --target native examples/wav_convert -- _build/example_input.wav _build/example_output.wav
moon run --target native examples/multichannel_6ch
moon run --target native examples/quality_tradeoff
moon run --target native examples/bounded_stream
moon run --target native examples/consumer_from_mooncakes
```

分别验证帧数、合成语音频带、分块一致性、声道隔离、实际 WAV、六声道逐通道对照、
同一 WAV 三档测量、60 秒有界流和公开接口消费。最后一个在源码树运行时使用本地库；
`consumer.py --registry-version 0.1.0` 才是注册表安装验证。
`python scripts/run_examples.py` 用新临时路径运行全部示例并比较库与 CLI 的文件字节。
全部信号由项目生成，没有私人录音。

## 质量与资源实测

48→16 kHz、幅度 0.5、1 秒信号、两端各裁 256 输出帧的独立投影结果：

| 档位 | 1 kHz 幅度误差，dB | 12 kHz 混叠相对值，dB | 混叠上限，dB |
|---|---:|---:|---:|
| low | +9.084903752e-06 | -91.785047 | -45 |
| balanced | +1.247659545e-06 | -110.608188 | -50 |
| high | +1.336351203e-07 | -127.051823 | -70 |

三档 1 kHz 幅度误差均小于 0.5 dB。混叠相对值以 1 kHz 输出为基准。
123 个频率点、27 个 DC/脉冲场景、原始输出和限制见 [QUALITY](docs/QUALITY.md)；
这些测量不构成全频段保证。

48→16 kHz 单声道 1/10 分钟处理的固定存储分别为 137/393/777 个 Double（三档），
同档不随总时长增长。对象分配和进程 RSS 单独报告，不承诺硬实时或零分配。
[基准](docs/BENCHMARKS.md) 保留初始化、重复计时、完整速率/声道矩阵和外部对照。

算法：[ALGORITHM](docs/ALGORITHM.md)；测试：[TESTING](docs/TESTING.md)；
输入边界：[SECURITY](docs/SECURITY.md)；来源：[THIRD_PARTY](THIRD_PARTY.md)；
AI 辅助：[AI_USAGE](AI_USAGE.md)。许可为 [Apache-2.0](LICENSE)。
