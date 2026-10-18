# MoonSRC 0.1.0

纯 MoonBit 的流式音频采样率转换库。使用带抗混叠低通的多相 Blackman sinc FIR，
支持交错 PCM、有限输出缓冲区和明确的 `finish` 语义。

本版本已完成**本地初验**，尚未发布 Mooncakes。
本地记录见 [本地验收](docs/LOCAL_ACCEPTANCE.md)，远端验证见
[GitHub Actions](https://github.com/yzy726/MoonSRC/actions/workflows/ci.yml)。

## 支持范围

| 维度 | 0.1.0 |
|---|---|
| 比率 | 44100↔48000、48000↔16000 Hz；16000/44100/48000 同速率直通 |
| 声道 | 1 或 2，交错排列 |
| 样本 | 有限 Double；核心不截幅，拒绝 NaN/Infinity |
| 核心后端 | native、JavaScript、wasm-gc，均有本机运行证据 |
| WAV | RIFF/WAVE PCM16LE；native CLI；其他编码明确拒绝 |
| 边界 | 两端零延拓；非同速率有 96 输入帧前瞻 |

最终输出帧数为 `ceil(N * output_rate / input_rate)`。帧数乘以声道数才是样本数。
同速率路径逐样本保持原值；库的浮点输出没有 PCM16 量化。

## 从源码验证

需要 MoonBit、native C 编译器、Node.js 和 Python 3.10+。本机使用 Moon
0.1.20260920、moonc 0.10.14+7d59c7ec9；CI 固定对应官方工具链。
本项目无第三方 Mooncakes 依赖。源码目录下运行：

```sh
moon fmt --check
moon check --target native --deny-warn
moon test --target native --deny-warn
moon test --target js --deny-warn
moon test --target wasm-gc --deny-warn
python scripts/e2e.py
python scripts/quality.py
python scripts/run_examples.py
python scripts/bounded_stream.py
python scripts/consumer.py
```

`consumer.py` 用 `moon package` 生成 ZIP，解压到全新工作区，通过临时 `moon.work`
让独立项目依赖本地包，并在三个后端运行。它不发布，也不从注册表安装。
未来发布后的 Mooncakes 安装命令需在实际发布后另行核验。

## 库调用

消费项目的 `moon.pkg`：

```mbt nocheck
///|
import {
  "Ag108/MoonSRC",
}
```

一次性处理复用同一个流式引擎：

```mbt check
///|
test "readme/minimal stereo conversion" {
  let config = @MoonSRC.Config::new(44100, 48000, 2).unwrap()
  let input = Array::make(882, 0.25) // 441 stereo frames
  let output = @MoonSRC.resample(config, input[:]).unwrap()
  assert_eq(output.length(), 960) // 480 stereo frames
}
```

流式调用先创建 `@MoonSRC.Resampler::new(config)`，用 `process(input_view, output_buffer)`
返回的 `consumed_frames` 推进输入，用 `produced_frames` 读取输出。
输入耗尽后反复 `finish(output_buffer)`，直到 `is_finished()`。
`output_buffer` 是调用者提供的 `FixedArray[Double]`，长度必须对齐完整声道帧。
可运行循环见 [分块示例](examples/chunked_equivalence/main.mbt) 和
[消费项目验证程序](scripts/consumer.py)。错误、背压与重置见 [流式契约](docs/STREAMING.md)。

## WAV CLI

```sh
moon run --target native cmd/main -- --help
moon run --target native cmd/main -- fixture _build/input.wav --rate 44100 --channels 2 --frames 441
moon run --target native cmd/main -- convert _build/input.wav _build/output.wav --rate 48000
```

输出为 480 帧双声道 48 kHz PCM16 WAV，并报告输入/输出帧、前瞻和截幅数。
输出路径必须不存在；重复运行请换一个新路径。输入 WAV 最多 33,554,476 字节，
一次性转换最多 16,777,216 输出样本。长音频请使用分块库 API。
PCM16 写入显式饱和并采用离零舍入，详见 [范围与量化](docs/SCOPE.md)。

## 五个示例

```sh
moon run --target native examples/memory_44100_to_48000
moon run --target native examples/speech_48000_to_16000
moon run --target native examples/chunked_equivalence
moon run --target native examples/channel_isolation
moon run --target native examples/wav_convert -- _build/example_input.wav _build/example_output.wav
```

示例分别观察 4410→4800 帧、通带/混叠测量、三种分块结果一致、右声道严格静音、
以及实际 WAV 文件的 441→480 帧转换。语音示例使用可复现的合成语音频带信号，
不包含私人录音。`python scripts/run_examples.py` 自动使用新的临时路径验证全部示例。

## 质量与资源实测

48→16 kHz、0.5 幅度、1 秒正弦，裁去两端各 256 输出帧后，独立 Python 分析得到：
1 kHz 通带误差约 `0.00000125 dB`；12 kHz 输入在输出中折叠到 4 kHz 的分量，
比通带低约 `110.61 dB`。这是这组固定信号的结果，不代表全频段阻带保证。
见 [质量方法和原始数据](docs/QUALITY.md)。

48→16 kHz 单声道 1 分钟与 10 分钟的固定采样存储均为 393 个 Double，
历史峰值均为 193 帧。过程对象可能分配，未承诺实时零分配。
设备、原始时间、RSS 与局限见 [基准](docs/BENCHMARKS.md)。

算法说明：[ALGORITHM](docs/ALGORITHM.md)；测试：[TESTING](docs/TESTING.md)；
输入边界：[SECURITY](docs/SECURITY.md)；来源：[THIRD_PARTY](THIRD_PARTY.md)；
AI 辅助说明：[AI_USAGE](AI_USAGE.md)。许可为 Apache-2.0，见 [LICENSE](LICENSE)。
