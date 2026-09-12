# 卡片反面例句 + 拆解 + 发音

**日期**: 2026-07-31
**状态**: 设计中
**相关模块**: ContentModels, FlipCardView, AudioPlaybackService

## 目标

复习卡片翻面后，在中文释义下方展示一条高频实用例句，整句可点击发音；复杂例句展开「句子拆解」，每个词块独立显示泰文+中文并分别可点击发音。

## 数据层

### 字段复用

`ContentItem` 已有字段，无需新增：

| 字段 | 用途 |
|------|------|
| `example: String?` | 例句泰文。单词类词条填空，句子类词条可为空（自身即是句子） |
| `segments: [PhraseSegment]` | 例句拆解词块。每个 `PhraseSegment` 含 `thai`、`gloss` |

### AI 内容生成

- 覆盖主题：basics / family / airport / 餐饮点菜 / 购物砍价 / 看病就医
- 策略：先产 ~100 条高频场景句，复用覆盖多数单词；余下单词单独补例句
- 每个例句附带 segments 拆解（分词 + 中文释义）
- 每个单词的 `example` 指向关联例句泰文
- 生成工具：Python 脚本调用 AI API，写入 `items.json`

### 规则

- `kind == "word"` 且 `frequencyTier <= 3`（高频词）→ 必须填 `example` 和 `segments`
- `kind == "word"` 且 `frequencyTier > 3` → 可选填
- `kind == "sentence"` 或 `"chunk"` → `example` 留空，自身 `segments` 填拆解
- `kind == "dialogue"` → 保持不变

## UI 层

### 卡片反面（CardBack）新增区域

在中国释义和 usageNote 之间插入：

```
┌─────────────────────────────────┐
│  📝 例句                         │
│  ฉันหิวข้าวมากเลย  [🔊 点击发音]    │  ← 整句 tappable
│                                 │
│  ▸ 句子拆解                      │  ← 可折叠，仅展示
│    ฉัน    │ 我                    │
│    หิว    │ 饿                    │
│    ข้าว   │ 饭                    │
│    มากเลย │ 非常                  │
└─────────────────────────────────┘
```

### 交互

- 整句点击 → `AudioPlaybackService.play(audioID:, thaiText: example)` → TTS 朗读整句
- 「句子拆解」默认折叠，点击展开（`DisclosureGroup`），仅展示词块+释义，**不可单独发音**
- 无例句时该区域不显示

### 条件显示

- `example` 不为空 → 显示例句区
- `segments` 不为空 → 显示「句子拆解」
- 两者皆空 → 该区域整个不渲染（与现有卡片背面一致）

## 实现步骤

1. **AI 内容生成脚本** — `tools/generate_examples.py`，调用 AI API 批量生成例句 + segments，写入 `items.json`
2. **CardBack UI** — 在 `FlipCardView.swift` 的 `CardBack.body` 中插入例句 + segments 视图
3. **发音接入** — 例句整句 tappable 接入 `onTapThai`，拆解词块仅展示不发音
4. **测试** — 验证例句/segments 为空时不崩溃、验证点击发音触发正确 TTS

## 不涉及

- 不修改 `ContentItem` 数据模型（字段已存在）
- 不修改 `AudioPlaybackService`（刚重构完，API 不变）
- 不修改 FSRS 复习调度逻辑
- 不新增复习方向
