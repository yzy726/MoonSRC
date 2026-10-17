# MoonSRC 0.1.0 本地初验

用户授权按 goal.md 完成初验，并在本次会话明确选择「仅本地，不发布 Mooncakes」。
最终 20 条检查命令全部退出 0；native、js、wasm-gc 各 126 项测试通过。

因此远端公开仓库、Mooncakes 发布/注册表安装不计为已完成；本地包和独立消费验证
替代本次范围内的安装闭环，版本保留 0.1.0。

| goal.md 初验项 | 本地证据 |
|---|---|
| 固定支持矩阵、单双声道与整数时钟 | model/api_matrix/stream 测试，长流精确帧数 |
| 真实抗混叠 FIR | internal/filter、quality_test，独立 Python 测量和 raw f64 |
| 任意块与有限输出容量 | 1 帧、127 帧、固定种子与极小输出缓冲差分 |
| finish/reset、异常与边界 | stream/PCM/WAV 测试，含 15 项以上错误/状态场景 |
| 一次性 API 复用流式核心 | api.mbt，所有矩阵场景与分块输出一致 |
| native WAV CLI | 12 个端到端流程，含独立直接 sinc 参考 |
| 至少 5 个示例 | evidence/examples.json，库与 CLI WAV 字节一致 |
| ≥60 个确定性场景 | 70 个单独矩阵测试，加其余行为、错误与质量测试 |
| 质量门槛 | 通带误差 +0.00000124766 dB；混叠相对 -110.608 dB |
| 1 分钟/10 分钟内部存储有界 | 相同配置均 393 Double、193 帧峰值；实际 RSS 单列 |
| 三后端检查/构建/测试 | 各 126/126 项通过；evidence/final_checks.json |
| 公共 API 与本地包消费 | evidence/consumer.json：独立项目 native/js/wasm-gc |
| 文档、许可证、来源、CI | README、docs、LICENSE、THIRD_PARTY、ci.yml |
| Git 每步提交且身份正确 | 本地提交历史；作者/提交者均 yzy726，无 push |

频率方法与公差见 QUALITY；资源/计时方法见 BENCHMARKS；输入边界见 SCOPE/SECURITY。
`evidence/final_checks.json` 记录交付时命令、退出码、测试数和工具链。
本地可执行包由 `moon package` 生成到 `_build/publish/Ag108-MoonSRC-0.1.0.zip`。

保留的限制：仅一种质量配置；未测全频段/外部库对照；未计数运行时每次对象分配，
不承诺零分配；仅本机 Windows native 有 OS 实测；CI 已配置但尚未远端运行；
Mooncakes 发布、注册表安装和公开仓库元数据仍按用户要求暂缓。
