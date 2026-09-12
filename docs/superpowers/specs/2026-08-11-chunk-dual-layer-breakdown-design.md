# Chunk 双层拆解设计

**日期：** 2026-08-11  
**状态：** 已完成设计，待用户审阅后进入实施

## 背景

Thai Life 内容包中有 1,200 条内容，其中 215 条的 `kind` 为 `chunk`。现有所有 chunk 的 `segments` 均为空，因此课程浏览和复习卡无法为短语提供拆解辅助。

现有 `segments` 的含义不能改变：对于带例句的内容，它表示完整例句的视觉词块拆解，且例句音频必须始终按照完整句播放。chunk 的双层拆解必须使用独立字段，不能复用或改变例句 `segments` 的语义。

## 目标

1. 为全部 215 条 chunk 提供经过审核的两层拆解：自然组合层与最小词级层。
2. 在课程浏览详情和学习/复习卡背面始终显示两层拆解。
3. 保持完整 chunk 的主音频播放；拆解仅作为视觉理解辅助。
4. 将拆解数据纳入生成与校验流程，防止缺失、错配或 manifest 漂移进入 App。

## 非目标

- 不在课程列表行显示双层拆解。
- 不为拆解片段增加或播放单独音频。
- 不修改例句 `segments`、例句文本、例句中文或例句音频管线。
- 不依靠自动分词推导泰语组合边界。

## 内容模型

新增可 Codable 解码的模型：

```swift
struct ChunkBreakdown: Codable, Sendable, Equatable {
    let combinations: [PhraseSegment]
    let minimal: [PhraseSegment]
}
```

`ContentItem` 新增可选字段：

```swift
let chunkBreakdown: ChunkBreakdown?
```

示例：

```json
"chunkBreakdown": {
  "combinations": [
    { "thai": "ขอโทษ", "gloss": "抱歉／打扰一下" },
    { "thai": "นะ", "gloss": "语气缓和词" },
    { "thai": "ครับ", "gloss": "男性礼貌词" }
  ],
  "minimal": [
    { "thai": "ขอ", "gloss": "请求／请" },
    { "thai": "โทษ", "gloss": "过错；抱歉" },
    { "thai": "นะ", "gloss": "语气缓和词" },
    { "thai": "ครับ", "gloss": "男性礼貌词" }
  ]
}
```

`combinations` 以自然语义单位和固定搭配为主；`minimal` 给出最小可解释词级单位。每层中的片段按完整泰文的原始顺序排列。

## 内容源与生成

新增唯一的人工审核源文件：

```text
tools/chunk_breakdowns.json
```

文件保存 215 条 chunk 的 ID、组合层和最小层。`items.json` 和 `content-manifest.json` 仍为生成产物，禁止人工编辑。

`tools/generate_content.py` 的职责：

1. 加载并模式校验 `chunk_breakdowns.json`。
2. 验证其 ID 与所有 `kind == "chunk"` 的内容一一对应。
3. 将双层拆解合并到生成的 `items.json`。
4. 使用临时文件和原子替换写入 `items.json` 及 `content-manifest.json`。
5. 对最终 `items.json` 的原始字节计算 SHA-256 并写入 manifest。

## 内容与运行时校验

Python 生成器、`tools/validate_content.py` 和 Swift `ContentValidator` 必须一致执行以下规则：

1. 每个 chunk 必须有非空的 `chunkBreakdown`，且 `combinations` 与 `minimal` 均至少包含一个片段。
2. 每一个非 chunk 条目都不得携带 `chunkBreakdown`。
3. 两层片段的 `thai` 串接后，忽略空格必须分别严格等于 `ContentItem.thai`。
4. 每一个片段的 `thai` 和 `gloss` 必须非空。
5. 源文件内 ID 必须唯一、无未知 ID、无遗漏 ID；覆盖数量必须等于 215。
6. `content-manifest.json` 的 `itemCount` 与 SHA-256 必须与生成的 `items.json` 精确匹配。

验证失败必须明确报错并阻止不完整内容包被作为有效资源使用；不采用静默隐藏或单层降级。

## UI 与交互

新增共享 SwiftUI 组件 `ChunkBreakdownView`，供 `CardBack` 复用。因此以下两种路径的视觉和行为一致：

1. 从课程列表点击条目后进入的课程浏览卡背面。
2. 正常学习/复习流程中的卡背面。

仅当当前条目是 chunk 时展示组件。它位于完整泰文、中文释义和用法提示之后；chunk 当前没有例句，因此双层拆解将直接构成主要辅助解释区域。

固定且始终展开的布局：

```text
组合拆解
<组合泰文>  <中文释义>
...

最小拆解
<最小词泰文> <中文释义>
...
```

- 泰文片段采用现有词块区域相同的强调色与粗体风格；中文释义为次级文本。
- 每个片段一行，长文本允许自动换行；卡背面保留滚动能力。
- 不添加展开/收起交互。
- 点击完整泰文继续调用既有主词播放逻辑，使用 `audioID` 对应的完整 chunk MP3。
- 拆解行不产生分段播放，亦不调用例句播放接口。
- 非 chunk 卡片继续沿用现有例句和 `segments` 展示逻辑。

## 测试与验收

### Python

- 为 manifest 与 chunk 拆解源增加失败用例：缺失、未知或重复 ID、空层、空释义、任一层不能重建完整泰文、非 chunk 含拆解、校验和不匹配。
- 运行：

```bash
python3 -m tools.test_content_pipeline
python3 tools/validate_content.py
```

### Swift

- `ContentValidator`：有效双层拆解通过；上述无效内容被拒绝。
- 内容验收：加载后的内容包含 215 条带双层拆解的 chunk。
- 视图测试：chunk 卡背面同时渲染“组合拆解”和“最小拆解”；普通词条与例句内容保持原行为。

### 完整验证

```bash
xcodebuild -project ThaiLife.xcodeproj \
  -scheme ThaiLife \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro Max' \
  test
```

由于本改动不修改任何音频资源或播放实现，不触发音频重新生成；但既有音频测试必须保持通过。

## 成功标准

- 课程浏览与复习卡背面的每一条 chunk 都同时显示组合层和最小词层。
- 两层均有自然、非空的中文释义，并可重建完整泰文。
- App 初始化通过内容校验；manifest 的 SHA-256 与 `items.json` 字节完全一致。
- 完整 Python 和 iOS 测试套件通过。
