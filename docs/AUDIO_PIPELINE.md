# Thai Life 音频管线 (Audio Pipeline)

## 概述

泰生活应用使用 Google Cloud Text-to-Speech 批量生成 AI 泰语发音。
音频文件在构建时生成并随应用包发布，运行时离线播放。

## 前置条件

1. **Google Cloud 项目**：需要启用了 Text-to-Speech API 的 GCP 项目。
2. **服务账号**：创建具有 `roles/cloudtts.user` 权限的服务账号，下载 JSON 密钥。
3. **凭据隔离**：
   - **凭据绝不**提交到 Git、打包到应用、记录到日志或输入到 iPhone 应用。
   - 仅设置在构建环境的 `GOOGLE_APPLICATION_CREDENTIALS` 环境变量中。
4. **Python 依赖**：
   ```bash
   python3 -m venv .venv
   .venv/bin/pip install -r tools/requirements.txt
   ```

## 生成流程

```bash
# 1. 设置凭据（一次性，不提交）
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"

# 2. 先生成 654 条完整例句音频（推荐）
.venv/bin/python tools/generate_audio.py --examples-only --force

# 3. 如需替换全部主词/词块占位音频，再执行：
.venv/bin/python tools/generate_audio.py --force

# 4. 生成音频清单（校验 SHA-256、字节数、时长）
.venv/bin/python tools/generate_audio_manifest.py

# 5. 试听审计（抽查 20 条，检查声调、停顿、句边界）
# 手动流程：在 Resources/Audio/ 中随机选取 20 个 MP3 播放
```

## 干运行

```bash
.venv/bin/python tools/generate_audio.py --dry-run
```
将打印将要生成的音频 ID 和对应文本，不实际调用 API。

## 声线与设置

- **语言**：th-TH（泰语）
- **声线**：th-TH-Standard-A（女性标准声线）
- **编码**：MP3
- **语速**：1.0（正常语速）
- **效果**：应用内设置提供 0.75× 慢速复听（由 AVFAudio 调整播放速率）

## 音频清单格式

```json
{
  "version": 1,
  "audioCount": 1854,
  "generatedAt": "2026-07-30T00:00:00Z",
  "entries": [
    {
      "audioID": "audio-basics-word-001-example",
      "relativePath": "Audio/audio-basics-word-001-example.mp3",
      "sha256": "abc123...",
      "byteCount": 12345,
      "durationSeconds": 1.5
    }
  ]
}
```

## 审计检查点

1. 所有 `items.json` 中的 `audioID` 和每个非空 `example` 的 `<audioID>-example` 都必须有对应 MP3 文件。
2. 无孤儿文件（有 MP3 但 items.json 中无对应条目）。
3. 所有 MP3 可解码、时长在合理范围（词 0.5-3s，句 2-10s）。
4. 抽查 20 条：
   - 声调正确（泰语 5 个声调清晰可辨）
   - 词块边界停顿自然
   - 长句在短语边界自然换气
5. 发现异常时修改文本/更换声线，重新生成对应条目。

## AI 合成语音标识

应用内标注"AI 合成语音"，不将其描述为真人录音。

## 离线播放

音频随应用包发布到 `ThaiLife/Resources/Audio/`，运行时：
- `AudioPlaybackService` 优先从 `Bundle.main` 解析完整例句 MP3
- 生成的例句使用 `AVAudioPlayer` 本地播放
- 例句 MP3 缺失时，回退到一次完整的 iOS `AVSpeechSynthesizer` utterance
- 运行时绝不发起网络请求
