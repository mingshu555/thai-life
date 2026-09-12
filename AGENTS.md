# AGENTS.md — Thai Life 项目级 Agent 指令

## 音频处理规范（必须遵守）

### 1. 例句是完整句子

- `ContentItem.example` 必须作为一整条例句处理。
- `segments` 只用于界面中的词块拆解，禁止用 `segments[].thai` 或 `segments[].gloss` 逐词拼接例句文本、中文翻译或语音。
- 例句中文必须是自然的整句翻译，禁止直接连接词块释义生成 `exampleMeaning`。

### 2. 例句音频命名

- 主词/词块音频 ID：使用内容中的 `audioID`。
- 例句音频 ID：固定使用：

```text
<audioID>-example
```

例如：

```text
audio-basics-word-022-example.mp3
```

音频文件必须位于：

```text
ThaiLife/Resources/Audio/
```

### 3. Google Cloud TTS 生成规则

- Google Cloud TTS 必须接收完整的 `example` 字符串，一次生成整句音频。
- 必须使用真正的 MP3 编码：

```python
texttospeech.AudioEncoding.MP3
```

当前 Google Cloud TTS 枚举中 `MP3` 的值是 `2`；`3` 是 `OGG_OPUS`，禁止把 `OGG_OPUS` 内容保存为 `.mp3` 扩展名。
- 生成后必须使用 `file` 或 `ffprobe` 检查容器格式确实是 MPEG MP3，不能只根据文件扩展名判断。
- 生成文件必须采用临时文件写入后 `os.replace` 的原子替换方式，避免留下半成品。
- 当前内容包有 654 条非空例句；完整资源包当前应包含 1200 个主音频 + 654 个例句音频 = 1854 个 MP3。

常用命令：

```bash
# 只生成完整例句音频
.venv/bin/python tools/generate_audio.py --examples-only --force

# 生成并审计音频 manifest
.venv/bin/python tools/generate_audio_manifest.py

# 内容校验
python3 tools/validate_content.py
```

### 4. App 播放优先级

例句播放必须经过 `AudioPlaybackService.playSentence(audioID:text:)`：

1. 优先从 App Bundle 的 `Audio/<audioID>-example.mp3` 使用 `AVAudioPlayer` 播放。
2. 音频缺失、格式错误或无法解码时，回退到一次完整的 `AVSpeechSynthesizer` 泰语 utterance。
3. 回退语音也必须接收完整 `example`，禁止按 segment 逐个播放。
4. 主词播放和例句播放必须使用不同的 audio ID，不能让例句复用主词音频。

### 5. 凭据安全

- Google Cloud 服务账号 JSON 只允许保存在项目目录之外，例如：

```text
~/.config/thailife/google-tts.json
```

- 通过环境变量提供凭据：

```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/google-tts.json"
```

- 禁止把凭据复制到仓库、写入源码、写入日志、提交 Git 或发送到聊天中。
- 运行生成器时只输出文件 ID、进度和错误摘要，不输出密钥内容。

### 6. 音频变更后的验证

任何音频管线或播放逻辑变更后，必须至少验证：

```bash
python3 tools/validate_content.py
python3 tools/generate_audio_manifest.py
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -configuration Debug \
  -destination 'id=<connected-device-udid>' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build
```

并确认：

- 例句 MP3 数量正确；
- manifest 没有 missing、orphan、wrong-format 或 undecodable 音频；
- 构建产物的 `ThaiLife.app/Audio/` 包含例句 MP3；
- 真机安装后可启动；
- 点击例句播放的是整句资源，而不是系统 TTS 回退。
