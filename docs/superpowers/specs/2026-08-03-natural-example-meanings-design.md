# 654 条例句自然中文翻译设计

**日期**: 2026-08-03  
**状态**: 已确认，待实现  
**范围**: 仅修复 654 条 `exampleMeaning` 的内容来源、生成覆盖关系、质量校验与验收流程。

## 1. 背景与问题

当前 `ThaiLife/Resources/Content/items.json` 是 App 运行时读取的内容产物，包含 1,200 条内容，其中 654 条 `kind == "word"` 条目有非空 `example`、`segments` 和 `exampleMeaning`。这些例句字段目前没有独立的可维护来源。

历史提交曾直接把 654 条由 `segments[].gloss` 机械连接得到的中文写入 `items.json`。现有 `tools/generate_content.py` 生成基础内容时会为条目写入空的 `example` 和 `segments`，随后直接覆盖 `items.json` 与 `content-manifest.json`。因此，单独修改 `items.json` 不能持久保存修订；下一次运行内容生成器会丢失例句、拆解和翻译。

现有 Python 与 Swift 校验器的机械翻译检测只覆盖“规范化后与全部 gloss 完全相等”的下限场景，不能证明中文自然度，也不能保证生成器不会覆盖人工修订。

## 2. 目标与非目标

### 2.1 目标

1. 为 654 条例句建立唯一、稳定、可审计的内容源。
2. 让生成器在写出 `items.json` 前严格应用例句源，并在源覆盖不完整或不一致时失败。
3. 明确 `exampleMeaning` 是独立的整句中文翻译，禁止从 `segments[].gloss` 推导。
4. 保留例句原文与拆解，确保内容重生成不会丢失现有 `example` 和 `segments`。
5. 通过 Python 生成期校验、Swift Bundle 校验和人工审校共同保证内容质量。
6. 明确 `items.json` 与 `content-manifest.json` 是生成产物，避免后续直接手改产物。

### 2.2 非目标

- 不修改 `ContentItem` 的字段模型。
- 不修改卡片 UI、音频播放优先级、TTS 生成规则或音频资源。
- 不把模型/API 调用作为正式的运行时翻译路径。
- 不以单一禁词规则代替 654 条逐条自然度审校。
- 不在本设计中处理与例句中文翻译无关的内容重构。

## 3. 内容源与所有权

### 3.1 唯一可维护源

新增 `tools/example_content.json`，作为 654 条例句相关字段的唯一可维护源。`items.json` 只作为生成产物，不再作为人工修订入口。

源文件的每条记录必须显式保存 `example`、`exampleMeaning` 和 `segments`。`segments` 虽然只用于界面拆解，但也必须进入源文件，因为基础生成器当前会将其初始化为空；只保存翻译而不保存拆解仍会造成数据丢失。

本任务是“只修中文翻译”的内容修订：迁移时必须从当前 `items.json` 逐字段保存 654 条既有 `example` 泰文文本，以及每条 `segments` 的顺序、`thai` 和 `gloss`。这些泰文文本和拆解/释义在本任务中不得改写、合并、拆分或重新分词；只有 `exampleMeaning` 允许被逐条改为自然中文。生成器 overlay 也必须校验这两个基线字段未发生漂移，而不是把源文件当作重新创作例句或拆解的入口。

`exampleMeaning` 必须独立编写为自然的简体中文整句。生成器只能复制该字段，禁止使用以下字段计算或拼接它：

- `segments[].thai`
- `segments[].gloss`
- `meaningZhHans`
- 任意词典映射、规则模板或运行时翻译结果

当前已有的机械翻译只能作为迁移时的参考输入，不能直接视为已审核内容，也不能在未经修订时标记为 `approved`。

### 3.2 源文件 schema

源文件采用稳定、可审阅的 JSON 结构：

```json
{
  "schemaVersion": 1,
  "locale": "zh-Hans",
  "recordCount": 654,
  "items": [
    {
      "id": "basics-word-005",
      "example": "ขอโทษครับ ห้องน้ำอยู่ที่ไหนครับ",
      "exampleMeaning": "不好意思，请问洗手间在哪里？",
      "segments": [
        { "thai": "ขอโทษ", "gloss": "对不起/打扰" },
        { "thai": "ครับ", "gloss": "礼貌语气词(男)" },
        { "thai": "ห้องน้ำ", "gloss": "卫生间" },
        { "thai": "อยู่", "gloss": "在" },
        { "thai": "ที่ไหน", "gloss": "哪里" },
        { "thai": "ครับ", "gloss": "礼貌语气词(男)" }
      ],
      "review": {
        "status": "approved",
        "reviewedBy": "author-yaohuix",
        "reviewedAt": "2026-08-03"
      }
    }
  ]
}
```

字段规则如下：

| 字段 | 规则 |
| --- | --- |
| `schemaVersion` | 必须为整数 `1`。未知版本直接失败。 |
| `locale` | 必须为 `zh-Hans`。本设计不引入其他翻译语言。 |
| `recordCount` | 必须为 `654`，且等于 `items` 实际记录数。 |
| `items` | 必须为数组，按 `id` 的稳定字典序排列。 |
| `id` | 必须唯一，并且必须属于生成后的 1,200 条基础内容。初始 654 条 ID 集合作为已确认的覆盖基线固定在校验中；源文件不能通过替换 ID 来悄悄改变覆盖范围。 |
| `example` | 非空完整泰语句子；保留原有句间空格。 |
| `exampleMeaning` | 非空自然简体中文整句；不得是词块释义的机械连接。 |
| `segments` | 非空对象数组；每个对象必须有非空 `thai` 与 `gloss`。 |
| `review.status` | 必须为 `approved` 才能进入正式生成；未审核或其他状态直接失败。 |
| `review.reviewedBy` | 非空审校人标识。模型或脚本不能单独作为最终审校人。 |
| `review.reviewedAt` | 固定为 `YYYY-MM-DD` 日期字符串。 |

源文件不允许重复 ID、未知字段导致的隐式覆盖、缺失记录或额外记录。源数据的格式化方式应保持稳定，便于逐条 review 和 Git diff 审计。

### 3.3 654 条覆盖基线工件

为使“初始 654 条”成为可验证契约，而不是只存在于文字描述中，新增并提交一次性基线工件 `tools/example_content_coverage.json`。该文件从当前基线 `items.json` 以只读方式提取后按 `id` 排序，随后固定保存；正常内容生成不得重写它。

其结构为：

```json
{
  "schemaVersion": 1,
  "recordCount": 654,
  "categoryCounts": {
    "basics": 40,
    "social": 40,
    "numbers": 40,
    "food_dining": 59,
    "shopping": 40,
    "home_living": 45,
    "transport": 50,
    "phone_network": 40,
    "health": 50,
    "safety": 50,
    "weather_leisure": 50,
    "airport": 50,
    "hotel": 50,
    "local_errands": 50
  },
  "expectedIDs": [
    "airport-word-001",
    "airport-word-002"
  ]
}
```

示例中的 `expectedIDs` 仅展示格式；实际工件必须包含完整、无重复的 654 个 ID。`categoryCounts` 必须固定为：`basics=40`、`social=40`、`numbers=40`、`food_dining=59`、`shopping=40`、`home_living=45`、`transport=50`、`phone_network=40`、`health=50`、`safety=50`、`weather_leisure=50`、`airport=50`、`hotel=50`、`local_errands=50`。

Python 校验必须同时检查：

1. `example_content.json` 的 ID 集合与 `example_content_coverage.json.expectedIDs` 完全相等。
2. 源文件实际记录数与 coverage 工件的 `recordCount` 都为 654。
3. 按 ID 前缀推导的分类数量与 coverage 工件的 `categoryCounts` 完全相等。
4. overlay 后产物的例句 ID 集合仍与 coverage 工件完全相等。

这样，删除、增加或替换任意一个例句 ID 都会触发缺失/额外 ID 错误；改变分类分布也会触发 category count 错误。若未来确实要调整覆盖范围，必须显式更新该基线工件并进行独立内容审阅，不得由普通生成流程自动漂移。

### 3.4 审校状态规则

654 条翻译必须先完成自然中文修订，再逐条确认 `review.status == "approved"`。不得先把旧的机械翻译整体迁移到源文件并标记为 approved，再把修订作为后续工作。

模型可以用于提出候选翻译、标记疑似问题或辅助分组，但最终的 `approved` 必须对应人工审校确认。审校至少检查：句意、中文语序、疑问/否定、礼貌表达、数量与时间、专名、男女说话者信息以及中文标点。

## 4. 严格生成与 overlay 顺序

生成器必须遵循以下不可变顺序：

1. 由 `tools/generate_content.py` 生成 14 个分类的基础内容。
2. 执行 `pad_or_trim`，得到完整的 1,200 条基础内容。
3. 加载 `tools/example_content.json` 和 `tools/example_content_coverage.json`。
4. 在内存中严格校验源 schema、coverage 工件、审校状态、ID 覆盖、字段完整性和 segment 重组关系。
5. 按 `id` 将源记录 overlay 到基础内容，复制 `example`、`exampleMeaning` 和 `segments`；同时确认 `example` 及 `segments` 与当前迁移基线逐字段一致，只有 `exampleMeaning` 可以是修订后的值。
6. 对 overlay 后的完整内容执行产物校验，包括源与产物逐字段一致性及 coverage 工件规定的 654 条覆盖数量。
7. 原子写出最终 `ThaiLife/Resources/Content/items.json`。
8. 基于最终 `items.json` 的实际内容计算并写出 `content-manifest.json`。

overlay 必须发生在写入 `items.json` 之前；不得先写基础产物再用另一个脚本补丁。生成器不得包含任何自动翻译逻辑，也不得在源字段缺失时回退到 `segments[].gloss`、旧 `items.json` 或默认模板。

生成失败时必须停止并返回明确错误，不能写出部分内容或用空字段继续生成。实现可以通过临时文件加原子替换保护产物，但不得以静默降级代替失败。

## 5. 654 条 fail-closed coverage gate

源文件和 overlay 后产物都必须通过以下硬闸门：

### 5.1 源文件闸门

- `schemaVersion == 1`。
- `locale == "zh-Hans"`。
- `recordCount == 654`，且等于实际 `items` 数量。
- 654 个 ID 无重复、按稳定字典序排列，并与 `tools/example_content_coverage.json.expectedIDs` 完全相等；分类数量必须与该工件的固定 `categoryCounts` 完全相等。
- 每个 ID 都存在于生成后的 1,200 条基础内容中。
- 每条都有非空 `example`、`exampleMeaning` 和 `segments`。
- 每条 `example` 与 `segments` 必须逐字段保留当前基线值；本任务不得改变泰文例句文本或拆解/释义。
- `segments[].thai` 在仅忽略空白差异的情况下，必须重组为完整 `example`；不得删除标点、任意字符或通过模糊匹配放宽规则。
- 每条 `review.status == "approved"`，且审校人和日期完整。
- `exampleMeaning` 不得包含已知拆解标签残留，例如 `礼貌语气词`、`语气词` 或 `…的是`。
- `exampleMeaning` 规范化后不得与全部 `segments[].gloss` 的连接结果相等。

### 5.2 overlay 后产物闸门

- 总内容数必须为 1,200，分类数量保持既有契约。
- 有且只有 654 条内容的 `example` 非空。
- 有 `example` 的每条内容必须有非空 `exampleMeaning` 和 `segments`。
- 无 `example` 的内容不得残留 `exampleMeaning` 或例句 `segments`。
- 产物中的 654 个例句 ID 必须与源文件及 `tools/example_content_coverage.json` 完全相等，且分类分布匹配固定 category counts。
- 产物中每条例句的 `example`、`exampleMeaning`、`segments` 必须与源文件对应记录逐字段一致；其中 `example` 和 `segments` 还必须与当前迁移基线一致。任何覆盖、顺序错位、拆解改写或遗漏都失败。
- 产物继续通过现有 schema、关系、重复文本、segment 结构和机械拼接检查。
- `content-manifest.json` 必须基于最终 `items.json` 重新计算，不能沿用旧 checksum。

这些条件任一失败，生成器都必须 fail closed；不得生成一个看似可用但只包含部分翻译的 `items.json`。

## 6. Python 与 Swift 校验职责

### 6.1 Python 内容工具

Python 工具拥有开发期内容源和生成过程的完整上下文，负责：

- 解析并校验 `tools/example_content.json` 与 `tools/example_content_coverage.json` 的 schema。
- 校验 654 条固定 ID 覆盖、排序、category counts、字段完整性和审校状态。
- 校验 `segments[].thai` 与完整 `example` 的重组关系。
- 校验 `example` 与 `segments` 相对当前迁移基线逐字段不变。
- 执行严格 overlay，并校验 overlay 后内容与源逐字段一致。
- 校验 `example` 与 `exampleMeaning` 的成对存在关系。
- 保留并扩展机械 gloss 拼接检测。
- 基于最终内容写出 manifest，并验证 manifest checksum 对应最终产物。
- 在临时目录或纯函数层完成确定性测试，确保相同输入得到相同内容与 checksum。

Python 校验可以读取开发期源文件；它是防止源缺失、生成覆盖和覆盖范围漂移的第一道闸门。

### 6.2 Swift `ContentValidator`

Swift 运行时只看到 App Bundle 内的 `items.json`，不应依赖 `tools/example_content.json`。Swift 负责：

- 校验 Bundle 内容的基本 schema、必填字段、ID/关系和 segment 结构。
- 校验 Bundle 内恰好有 654 条非空 `example` 与 `exampleMeaning`，以及它们的成对关系。
- 保留规范化后完整 gloss 连接相等时的 `mechanicalExampleMeaning` 硬错误。
- 确保例句的 segment 泰文仍能重组为完整例句。

Swift 校验不能声称已证明中文自然度，也不应尝试在运行时读取源文件、调用模型或重新生成翻译。自然度由源文件的逐条人工审校和 Python 生成期的源/产物一致性共同保证。

## 7. 测试设计

### 7.1 Python 源与生成测试

至少覆盖以下失败和成功场景：

1. `recordCount` 缺失、错误或与实际记录数不一致时失败。
2. `schemaVersion`、`locale` 不匹配时失败。
3. 缺少一条、增加一条、重复 ID 或未知 ID 时失败。
4. `example_content_coverage.json` 缺少、损坏、ID 集合不相等或 category counts 不相等时失败。
5. ID 顺序不稳定时失败或在加载时明确拒绝；不能产生不可审计的随机输出。
6. `example`、`exampleMeaning`、`segments` 任一为空时失败。
7. `review.status` 不是 `approved` 或审校字段缺失时失败。
8. `example` 或 `segments` 与当前基线不一致时失败；只允许 `exampleMeaning` 发生翻译修订。
9. `segments[].thai` 无法在仅忽略空白的条件下重组 `example` 时失败。
10. 由 gloss 机械连接得到的 `exampleMeaning` 失败。
11. 自然整句翻译（例如 `你从哪里来？`）通过，且不因与部分 gloss 共享词语而误报。
12. overlay 后输出与源记录逐字段不一致时失败。
13. 连续两次在临时目录生成时，最终内容序列化结果和 checksum 一致。
14. 生成器不会在源校验失败时写出新的 `items.json` 或 manifest。

### 7.2 Swift 单元与 Bundle 验收测试

1. 机械 gloss 拼接的例句翻译触发 `mechanicalExampleMeaning`。
2. 自然整句翻译通过基础校验。
3. 有 `example` 但缺 `exampleMeaning`，或反向缺失时失败。
4. 例句 segment 文本无法重组完整 `example` 时失败。
5. 加载 Bundle 后总条目数为 1,200，非空 `example`、`exampleMeaning` 均为 654，且 ID 集合与 `example_content_coverage.json` 基线一致。
6. Bundle 的例句分类数量匹配固定 category counts。
7. Bundle 的 `content-manifest.json` checksum 对应最终 `items.json`。
8. 现有内容关系、分类数量和基础字段测试继续通过。

### 7.3 人工内容验收

自动规则只能发现结构错误和已知机械伪影，不能替代自然度判断。654 条必须逐条审校并保留审校记录，按分类覆盖以下重点：

- 陈述、问句、否定与请求。
- 男性/女性礼貌表达，以及中文中是否应自然呈现说话者信息。
- 时间、日期、年龄、价格、数量和单位。
- 地名、人名及其他专名的稳定译法。
- 餐饮、交通、住宿、健康、安全等场景中的口语自然度。
- 中文标点、停顿和整句可读性。

所有 654 条在通过上述人工审校并确认自然翻译后，才允许进入 `approved` 状态和正式产物。

## 8. README 与生成产物规则

README 和内容创作文档必须明确以下维护流程：

```text
编辑 tools/example_content.json
→ 运行内容生成器生成 items.json 与 content-manifest.json
→ 运行 Python 内容校验
→ 运行 Swift/Bundle 内容测试
```

维护规则：

- `tools/example_content.json` 是例句字段的编辑入口。
- `ThaiLife/Resources/Content/items.json` 是生成产物，禁止手工修订。
- `ThaiLife/Resources/Content/content-manifest.json` 是由最终 `items.json` 计算的生成产物，禁止手工修订。
- 不得在生成器、Swift UI 或运行时通过 `segments[].gloss` 生成 `exampleMeaning`。
- 任何内容生成命令都必须经过源 schema 和 654 coverage gate；不能提供绕过闸门的“快速生成”路径。
- 文档中的命令顺序不得把“先运行会覆盖内容的生成器”描述为可选的日常校验步骤；生成必须明确依赖源文件并紧接校验。

## 9. 实施顺序与验收条件

实现按以下最小顺序进行：

1. 从当前 `items.json` 只读提取 654 条例句的 `id`、`example` 和 `segments`，建立 `tools/example_content_coverage.json` 的固定 ID/category-count 基线，并建立 `tools/example_content.json` 的迁移骨架。
2. 保持迁移得到的 `example` 与 `segments` 逐字段不变，只逐条重写自然中文 `exampleMeaning`，完成审校字段；旧机械翻译不得直接标记 approved。
3. 为 `generate_content.py` 增加 coverage 工件加载、严格校验和 overlay，确保基础生成不会清空例句数据。
4. 扩展 Python 校验和 Swift 测试，覆盖源/产物一致性、固定 ID/category-count 契约、654 coverage gate 与机械拼接回归。
5. 更新 README 和内容创作文档，明确生成产物规则。
6. 在临时目录验证生成确定性，再执行项目既定的内容、Bundle 和构建验收。

本问题只有在以下条件全部满足后才算完成：

- 654 条 `exampleMeaning` 已逐条修正为自然简体中文整句。
- 654 条全部通过人工审校，并且只有修正后的翻译才能标记 `review.status == "approved"`。
- 源文件 schema、固定 ID 集合、segment 重组和审校状态全部通过 fail-closed gate。
- 重生成后的 `items.json` 与源文件的 654 条例句字段逐字段一致，没有任何机械拼接或静默覆盖。
- Python 内容校验、Swift 内容校验、Bundle acceptance 和确定性测试全部通过。
- README 已明确源文件、生成产物和禁止手改规则。

## 10. 风险与取舍

| 风险 | 缓解措施 |
| --- | --- |
| 只修改 `items.json`，未来重生成时全部丢失 | 将例句数据放入独立源，并在生成前严格 overlay。 |
| 只保存 `exampleMeaning`，重生成时丢失 segments | 源记录同时保存 `example`、`exampleMeaning`、`segments`。 |
| 只增强 exact gloss 检测，漏掉词序直译或部分拼接 | 将机械检查作为硬错误下限，并要求 654 条逐条人工审校。 |
| 模型候选翻译不稳定或含语义错误 | 模型只能辅助，`approved` 必须由人工确认。 |
| 源文件覆盖范围悄悄漂移 | 固定 654 条 ID 基线，并执行缺失/额外/未知 ID 的 fail-closed 校验。 |
| 产物与 manifest 不一致 | 只从最终 `items.json` 计算 manifest，并在 Python 与 Bundle 层校验 checksum。 |

本设计优先保证可重复生成、可审计来源和失败可见性，而不是提供一个自动判断中文自然度的单一算法。
