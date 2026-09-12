# 饮食与点餐水果、饮料 Google 发音修复设计

**日期：** 2026-08-20  
**状态：** 设计已获用户确认，待实现

## 背景

「饮食与点餐」中新增的水果和饮料词条已经进入内容包，但对应主词音频没有统一使用 Google Cloud Text-to-Speech 生成的 MP3。用户还反馈点击泰文文本时不能可靠播放发音。

本次修复只针对新增的水果、饮料词条和它们所在的泰文点击播放路径，不改变其它课程的内容、复习和收藏行为。

## 已确认范围

- 水果：`food_dining-word-060` 至 `food_dining-word-069`
- 饮料：`food_dining-word-070` 至 `food_dining-word-075`
- 共 16 个主词音频，不包含例句音频，因为这些词条当前没有例句。
- Google 凭据直接从项目外的下载目录通过 `GOOGLE_APPLICATION_CREDENTIALS` 使用，不复制进仓库、不写入日志或源码。
- 完成验证后，必须构建、安装并启动到用户的 iPhone 17 Pro Max 真机。

## 目标

1. 为上述 16 个 `audioID` 重新生成真正的 Google MP3 音频。
2. 确保内容卡片点击泰文时通过对应 `audioID` 播放 Bundle 音频，而不是错误音频或系统回退语音。
3. 保留现有点击整行进入卡片、翻卡和左右滑动等行为；点击泰文的播放区域不能破坏导航手势。
4. 为音频生成和播放路径补充自动化测试与资源审计。
5. 在 iPhone 17 Pro Max 上完成安装启动验证。

## 非目标

- 不修改水果和饮料的泰语、中文释义或分类排序。
- 不新增例句，不按 segments 拼接任何例句或语音。
- 不把 Google 服务账号凭据复制到项目目录。
- 不把所有历史音频无差别重新生成。
- 不改变菜单数据模型、图片资源或复习系统；菜单文字播放仅在已有菜单卡片需要点击播放的地方接入统一播放服务。

## 设计方案

### 1. 音频生成

扩展现有音频生成流程，使其能够对明确的 `audioID` 目标集合执行强制重生成，目标集合固定为 060–075 的 16 个主词音频。每次请求：

- 从 `items.json` 读取完整的 `thai` 字符串；
- 使用 Google Cloud TTS `th-TH` 语音和 `texttospeech.AudioEncoding.MP3`；
- 先写入同目录临时文件，再使用 `os.replace` 原子替换目标文件；
- 日志只输出音频 ID、进度和错误摘要，不输出凭据内容。

不生成 `-example` 文件，也不使用 segments 的 gloss 或片段文本作为输入。

### 2. 播放路径

继续以 `AudioPlaybackService.play(audioID:thaiText:)` 为统一入口：

1. 优先查找 App Bundle 中对应的 `Audio/<audioID>.mp3`；
2. 文件缺失、格式错误或无法解码时，才回退到一次完整泰语系统语音；
3. 播放请求的 `audioID` 必须来自当前条目的内容数据，禁止写死或复用其它词条 ID。

普通饮食与点餐内容卡片中的泰文主词使用可点击的 `ThaiText`（或等价的统一组件），确保视觉文本本身是播放命中区域。若菜单卡片展示泰文菜名，也复用同一播放服务；翻卡手势仍由卡片容器处理，不能让播放手势触发错误的卡片切换。

### 3. 测试与资源审计

增加或调整测试以覆盖：

- 060–075 的 16 个条目存在且 `audioID` 唯一；
- 每个条目的 Bundle 音频路径为对应 ID；
- 点击泰文调用对应 ID 和完整泰文文本；
- 音频 manifest 不报告 missing、orphan、wrong-format 或 undecodable；
- 生成器使用 MP3 枚举，并支持原子替换。

测试不得依赖真实 Google 凭据；API 生成仅在本地资源生成步骤执行。

## 验收标准

### 音频

- `ThaiLife/Resources/Audio/` 中存在 16 个目标 MP3；
- `file` 或 `ffprobe` 确认它们是真正的 MPEG MP3 容器；
- 目标音频由 Google TTS 生成流程重新生成，App Bundle 中包含最新文件；
- manifest 审计无缺失、孤立、错误格式或不可解码资源。

### App 行为

- 在饮食与点餐列表点击水果或饮料的泰文，可播放对应 Google 音频；
- 在详情/卡片页面点击相同泰文，仍播放相同 `audioID` 的 Bundle 音频；
- 音频缺失时仅作为异常回退到完整系统 TTS，不按词块逐段播放；
- 卡片翻面、左右切换、返回和收藏行为不回归。

### 验证命令

```bash
python3 tools/validate_content.py
.venv/bin/python tools/generate_audio_manifest.py
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -configuration Debug \
  -destination 'id=00008150-000229AA2199401C' \
  -allowProvisioningUpdates \
  -allowProvisioningDeviceRegistration \
  build
```

构建成功后，将产物安装到 UDID 为 `00008150-000229AA2199401C` 的 iPhone 17 Pro Max，并使用 `xcrun devicectl` 启动确认。
