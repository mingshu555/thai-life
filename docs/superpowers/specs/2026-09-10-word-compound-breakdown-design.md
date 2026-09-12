# 单词复合词双层拆解设计

**日期：** 2026-09-10  
**状态：** 已完成设计，待用户审阅后进入实施

## 背景

Chunk 已有独立的 `chunkBreakdown` 双层拆解。`kind == word` 的复合词仍整词展示。例句 `segments` 也常把整个主词当成一块，例如：

- `airport-word-019` `ตรวจคนเข้าเมือง`（入境检查）
- `airport-word-016` `หมายเลขเที่ยวบิน`（航班号）

现有 `segments` 语义不能改变：有例句时，它只表示完整例句的视觉词块拆解；例句音频必须始终按整句播放。单词主词的双层拆解必须使用独立字段，不能复用 `chunkBreakdown`，也不能把主词拆解写进例句 `segments` 的语义里。

## 目标

1. 为所有可拆的复合词提供人工审核的两层拆解：组合层与最小词级层。
2. 仅在课程浏览和学习/复习的**卡背**显示这两层；卡正面保持现有题目样式。
3. 有拆解的单词，其**自己的**例句词块必须按组合层切开主词，禁止再把整个主词当作一段。
4. 主词音频、例句文本、例句中文、例句音频管线保持不变。
5. 将 `wordBreakdown` 纳入生成与校验；失败则 fail-closed。

## 非目标

- 不改变卡正面、课程列表行、词族卡。
- 不为拆解片段新增或绑定独立 MP3。
- 不修改 `example`、`exampleMeaning` 或 `audioID-example` 音频。
- 不改写其它条目（句子卡、其它词、对话）里出现的同一长词。
- 不要求 734 个单词全拆。
- 不依靠自动分词推导泰语边界。
- 不复用或放宽 `chunkBreakdown` 的既有不变量。

## 内容模型

复用现有 Swift 形状，不新增第二种双层结构：

```swift
struct ChunkBreakdown: Codable, Sendable, Hashable {
    let combinations: [PhraseSegment]
    let minimal: [PhraseSegment]
}
```

`ContentItem` 新增可选字段：

```swift
let wordBreakdown: ChunkBreakdown?
```

JSON 字段名必须是 `wordBreakdown`，不得写入 `chunkBreakdown`。

示例：

```json
"wordBreakdown": {
  "combinations": [
    { "thai": "หมายเลข", "gloss": "号码" },
    { "thai": "เที่ยวบิน", "gloss": "航班" }
  ],
  "minimal": [
    { "thai": "หมาย", "gloss": "标记" },
    { "thai": "เลข", "gloss": "数字" },
    { "thai": "เที่ยว", "gloss": "趟；班次" },
    { "thai": "บิน", "gloss": "飞" }
  ]
}
```

`combinations` 是自然语义单位或固定搭配。`minimal` 是最小可解释词级单位，不是按音节硬切。两层片段都必须按主词泰文的原始顺序排列。

允许两层完全相同，例如 `ทางออก` → `ทาง` + `ออก`。不允许任一层只有 1 段。

### 层间一致性

最小层必须是组合层的细化：从左到右，每个组合片段的 `thai`（去空格）必须等于一段连续最小片段 `thai` 的拼接。不能出现两层边界错位。

### 收录规则

源文件是白名单，不覆盖全部单词。收录当且仅当能写出至少两段、对学习者有复用价值的复合词。不按字符长度一刀切。

必须收录的典型条目：

| ID | 主词 | 组合层 | 最小层 |
| --- | --- | --- | --- |
| airport-word-019 | ตรวจคนเข้าเมือง | ตรวจ 检查 + คนเข้าเมือง 入境 | ตรวจ / คน / เข้า / เมือง |
| airport-word-016 | หมายเลขเที่ยวบิน | หมายเลข 号码 + เที่ยวบิน 航班 | หมาย / เลข / เที่ยว / บิน |
| airport-word-013 | ประตูขึ้นเครื่อง | ประตู 门 + ขึ้นเครื่อง 登机 | ประตู / ขึ้น / เครื่อง |
| airport-word-017 | หนังสือเดินทาง | หนังสือ 证件/书 + เดินทาง 旅行 | หนังสือ / เดิน / ทาง |

短复合词同样收录，例如 `น้ำเปล่า`、`ทางออก`、`สนามบิน`。

禁止收录（音译整词或拆了没有学习价值的化石词），并在校验中用拒绝列表按 ID 兜住：

- `basics-word-001` สวัสดี
- `social-word-001` ครอบครัว
- `airport-word-003` เช็คอิน
- `airport-word-011` ดีเลย์
- `airport-word-018` วีซ่า
- `airport-word-025` ดิวตี้ฟรี
- `airport-word-043` เคาน์เตอร์
- `hotel-word-003` เช็คอิน
- `phone_network-word-015` แบตเตอรี่
- `phone_network-word-035` เคาน์เตอร์

拒绝列表只防这些已知整词被误拆；其它条目仍靠人工审核，不自动分词。

没有例句的复合词只要可拆，仍可有 `wordBreakdown`；此时只显示主词双层拆解，不触发例句词块规则。

## 内容源与生成

新增唯一人工审核源文件：

```text
tools/word_breakdowns.json
```

模式与 `tools/chunk_breakdowns.json` 相同：

```json
{
  "schemaVersion": 1,
  "locale": "zh-Hans",
  "recordCount": 1,
  "items": [
    {
      "id": "airport-word-016",
      "combinations": [
        { "thai": "หมายเลข", "gloss": "号码" },
        { "thai": "เที่ยวบิน", "gloss": "航班" }
      ],
      "minimal": [
        { "thai": "หมาย", "gloss": "标记" },
        { "thai": "เลข", "gloss": "数字" },
        { "thai": "เที่ยว", "gloss": "趟；班次" },
        { "thai": "บิน", "gloss": "飞" }
      ]
    }
  ]
}
```

上面的 `recordCount: 1` 只说明字段含义；真实源文件的 `recordCount` 必须等于当时收录的复合词条数，不能写死为 1。

`recordCount` 必须等于 `items.length`。ID 必须唯一且按字符串升序。不把某个固定数字写死进生成器；白名单可以在后续内容修订中增长，但每一次生成都必须自洽。

`items.json` 与 `content-manifest.json` 仍为生成产物，禁止手工修订。

例句词块的唯一编辑入口仍是 `tools/example_content.json`。本改动只允许改有 `wordBreakdown` 的单词自己的 `segments` 以及对应审校元数据；禁止改 `example` 和 `exampleMeaning`。

因为 `segments` 变化会改变 `baselineExampleSegmentsSHA256`，必须在审阅后一次性更新 `tools/example_content_coverage.json` 里的该 checksum。禁止改 `expectedIDs`、`recordCount`、`categoryCounts`。被改过 `segments` 的例句记录必须把 `review.status` 保持为 `approved`，`reviewedAt` 更新为实际修订日，`reviewedBy` 如实标注，不得伪造人工审校身份。

`tools/generate_content.py` 的职责：

1. 加载并模式校验 `word_breakdowns.json`。
2. 验证所有 ID 都存在且 `kind == word`，无未知 ID、无重复 ID。
3. 校验两层还原、最少 2 段、层间细化、拒绝列表。
4. 若该词有例句，校验其例句词块覆盖主词的连续片段等于组合层。
5. 将 `wordBreakdown` 合并进生成的 `items.json`；非 word 或未收录的 word 不得带该字段。
6. 继续用临时文件 + `os.replace` 原子写入 `items.json` 和 `content-manifest.json`。
7. 对最终 `items.json` 原始字节计算 SHA-256 并写入 manifest。

`GENERATED_CONTENT_FIELDS` 必须包含 `wordBreakdown`。

## 例句词块规则

只约束「有 `wordBreakdown` 且有非空 `example`」的那条单词记录。

设 `headword` 为该词 `thai` 去空格。必须：

1. 例句去空格后包含 `headword` 作为连续子串。
2. 存在一段连续 `segments[i...j]`，其 `thai` 拼接去空格后等于 `headword`。
3. 该连续片段的 `thai` 序列必须与 `combinations` 的 `thai` 序列完全一致。
4. 该连续片段的 `gloss` 序列必须与 `combinations` 的 `gloss` 序列完全一致。
5. 任何一段 `segment.thai` 去空格后都不得等于 `headword`。
6. 全部 `segments` 拼接去空格后仍等于完整 `example`。

因此例句「词块拆解」按组合层切开主词，不拆到最小层。

主词在句中也可，例如 `ขอหนังสือเดินทางด้วยครับ` 的覆盖片段必须是 `หนังสือ` + `เดินทาง`。

找不到覆盖片段、覆盖片段粗于组合层、或仍把主词当一段，生成器和校验器都必须失败。不得从 `wordBreakdown` 自动改写 `example_content.json`。

其它条目里即使出现同一长词，本规格也不改它们的 `segments`。

## 音频

- 点按完整主词：现有 `AudioPlaybackService.play(audioID:thaiText:)`，使用该词 `audioID`。
- 点按完整例句：现有 `playSentence(audioID:text:)`，音频 ID 为 `<audioID>-example`，文本为完整 `example`。
- 点按拆解行或例句词块：只把该段 `thai` 交给现有 `onTapSegment`；不拼词块、不播例句音频、不新增 MP3。
- 禁止用 `OGG_OPUS` 冒充 MP3；本改动不调用 Google Cloud TTS。

## UI 与交互

只改卡背。`CardFront`、翻转动画、评分按钮、列表行均不显示拆解。

有 `wordBreakdown` 的单词卡背顺序固定为：

1. 完整主词（点按播主词音频）
2. 中文释义
3. 用法提示（若有）
4. 组合拆解 / 最小拆解
5. 例句与例句中文（若有）
6. 例句「词块拆解」（若有 `segments`）

课程浏览与学习/复习必须共用现有 `CardBack`，两处背面一致。

`ChunkBreakdownView` / `ChunkBreakdownPresentation` 扩展为：

- `kind == chunk` 读取 `chunkBreakdown`
- `kind == word` 读取 `wordBreakdown`
- 其它 kind 不显示该组件

标题仍为「组合拆解」「最小拆解」。现有 chunk 卡背不得回退。

当前 `CardBack` 用 `else if` 让 chunk 拆解和例句 `segments` 互斥。单词必须同时显示两者：先主词双层拆解，再例句词块。Chunk 仍只显示双层拆解，不因此多出空的例句词块区。

无 `wordBreakdown` 的单词卡背完全保持现状。

## 校验

Python 生成器、`tools/validate_content.py` 和 Swift `ContentValidator` 必须执行同一组规则：

1. 只有 `kind == word` 可以有 `wordBreakdown`；chunk 以外的旧规则不变，非 chunk 仍不得有 `chunkBreakdown`。
2. 未收录的 word 必须缺少该字段，不得为空对象。
3. `combinations` 与 `minimal` 均至少 2 个片段；每段 `thai`、`gloss` 非空，且只有这两个键。
4. 两层去空格拼接后都必须等于主词 `thai`。
5. 最小层必须细化组合层。
6. 源文件 ID 唯一、升序、全部为已有 word；`recordCount` 等于条目数。
7. 拒绝列表中的 ID 不得出现在源文件中。
8. 有拆解且有例句时，执行上一节全部例句词块规则。
9. `content-manifest.json` 的 `itemCount` 与 SHA-256 必须与生成的 `items.json` 字节一致。

验证失败必须明确报错并阻止不完整内容包进入 App；不得静默缺层或自动补段。

## 测试与验收

### Python

为 `word_breakdowns.json` 与生成结果增加失败用例：

- 未知、重复、非 word、未排序 ID
- 空层、单段层、空释义、多余字段
- 任一层不能还原主词
- 最小层不能细化组合层
- 拒绝列表中的词被收录
- 例句仍把主词当一段，或覆盖片段不等于组合层
- 非 word 带 `wordBreakdown`
- 例句 `example` / `exampleMeaning` 被改动
- coverage 的 `expectedIDs` 被改动，或未更新 `baselineExampleSegmentsSHA256`

运行：

```bash
python3 -m tools.test_content_pipeline
python3 tools/validate_content.py
```

### Swift

- `ContentValidator`：合法 `wordBreakdown` 通过；上述无效内容被拒绝；chunk 规则不受影响。
- 视图测试：有拆解的单词卡背同时渲染两层拆解和例句词块；无拆解单词卡、chunk 卡、卡正面保持原行为。

### 完整验证

```bash
python3 tools/validate_content.py
python3 tools/generate_audio_manifest.py
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test
```

本改动不修改音频资源或播放实现，不触发音频重新生成；既有音频测试必须保持通过。`generate_audio_manifest.py` 仅确认没有新的 missing / orphan / wrong-format / undecodable。

## 成功标准

- 卡正面仍只显示题目，不出现拆解。
- 可拆复合词的卡背同时显示组合层和最小层，且两层都能还原主词。
- 这些词自己的例句词块按组合层切开主词，不再出现整词一段。
- 点击例句仍播放完整例句 MP3 或整句泰语回退，不按词块逐段播。
- App 初始化通过内容校验；manifest SHA-256 与 `items.json` 字节一致。
- Python 与 iOS 测试套件通过。
