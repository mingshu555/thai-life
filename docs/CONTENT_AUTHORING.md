# 泰生活内容创作指南 (Content Authoring Guide)

## 内容范围

本内容包服务于泰国日常生活与旅游应急场景，不是课程、考试或论文阅读工具。

**明确排除：**
- 学术泰语、考试备考词汇
- 新闻时事、文学作品、专业行业术语
- 歌词内容（不导入 quant_ai_web/docs/thai-learning/ 中的歌词文件）
- 宗教经文、政治言论

## 学习阶梯

每个核心概念按以下阶梯生长：
`单词 → 词块/搭配 → 实用短句 → 微型情景对话`

示例：
`น้ำ`（水） → `น้ำเปล่า`（白水） → `ขอน้ำเปล่าหนึ่งขวดครับ`（请给我一瓶白水） → 餐厅两轮微对话

## 分类与目标数量

| 分类 | 内容重点 | 目标单元数 |
| --- | --- | ---: |
| basics (开口基础) | 礼貌、问答、肯定否定、常用动词、指代、连接与语气 | 160 |
| social (社交与人际) | 问候、自我介绍、家人朋友、心情、邀请、感谢与道歉 | 90 |
| numbers (数字、时间与数量) | 数字、日期、星期、时间、年龄、价格、重量、地址 | 110 |
| food_dining (饮食与点餐) | 食材、口味、餐具、饮料、点单、忌口与结账 | 130 |
| shopping (购物与付款) | 商品、尺码、颜色、试用、价格、现金/扫码与退换 | 80 |
| home_living (家与日常生活) | 房屋、家具、清洁、洗衣、用水用电、邻里 | 90 |
| transport (交通与问路) | 步行、公交、地铁、打车、摩托车、方向、堵车 | 100 |
| phone_network (手机、网络与服务) | SIM 卡、流量、Wi-Fi、充电、电话、快递、预约 | 60 |
| health (身体、健康与药店) | 身体部位、症状、常见药、看诊、过敏与饮食限制 | 80 |
| safety (安全与紧急求助) | 警察、丢失、危险、紧急联络、求助与说明情况 | 50 |
| weather_leisure (天气、休闲与生活习惯) | 天气、运动、娱乐、美容、宠物、日常安排 | 70 |
| airport (机场与入境) | 护照、行李、安检、登机、入境问答、换汇 | 50 |
| hotel (酒店与景点) | 订房、入住退房、房间问题、门票、拍照与游览 | 60 |
| local_errands (本地办事) | 银行、诊所、理发、维修、政府窗口、租赁沟通 | 70 |
| google_maps (Google地图常用词) | 道路、巷弄、路口、交通设施、常见地标、热门景点地名、地图状态与导航 | 62 |
| core_function (核心功能词) | 口语骨架、疑问否定、时态助动词、介词连词、程度语气等超高频功能词 | 124 |

合计：**1,404 个记忆单元**（1,200 基础 + 18 饮食点餐扩展 + 62 Google地图常用词 + 124 核心功能词专项）

## 内容格式

每个条目的 JSON 结构：
```json
{
  "id": "basics-word-001",
  "kind": "word|chunk|sentence|dialogue",
  "category": "basics",
  "tags": ["greeting", "polite"],
  "thai": "สวัสดี",
  "romanization": "sà-wàt-dii",
  "meaningZhHans": "你好/再见",
  "usageNote": "通用问候语",
  "frequencyTier": 1,
  "audioID": "audio-basics-word-001",
  "prerequisiteIDs": [],
  "relatedIDs": ["basics-word-002"],
  "example": "สวัสดีครับ",
  "exampleMeaning": "你好（男）",
  "segments": [],
  "sourceID": "author-yaohuix",
  "contentVersion": 1
}
```

## 字段规则

- `id`: 永久稳定，格式为 `{category}-{kind}-{序号}`
- `kind`: 必须是 word/chunk/sentence/dialogue 之一
- `category`: 必须是已登记分类之一（含 google_maps、core_function 专项）
- `tags`: 至少一个标签，描述场景或属性
- `thai`: 泰文文本，不可为空
- `romanization`: 规范拉丁转写（对话类型可为空字符串）
- `meaningZhHans`: 简体中文自然含义，不可为空
- `frequencyTier`: 0-5，1 为最高频核心词
- `audioID`: 格式为 `audio-{category}-{kind}-{序号}`
- `prerequisiteIDs`: 前置学习条目 ID 列表；不能自引用；不能形成循环
- `relatedIDs`: 关联条目 ID 列表（易混词、近义词等）
- `exampleMeaning`: `example` 的整句自然中文翻译；不能由词块 gloss 直接拼接
- `segments`: 长句的词块拆解；当条目有 `example` 时，片段拆解的是例句，不是 `thai` 主词；没有 `example` 时片段 text 拼接必须等于 thai
- `sourceID`: 内容来源标识；本项目使用 "author-yaohuix"

## 例句内容源与生成产物

- 654 条例句的唯一编辑入口是 `tools/example_content.json`。
- `tools/example_content_coverage.json` 是固定的覆盖契约，保存完整 `expectedIDs`、分类计数和例句/拆解基线 checksum；普通生成流程不得重写它。
- `ThaiLife/Resources/Content/items.json` 与 `content-manifest.json` 是生成产物，禁止手工修订。
- 维护顺序必须是：编辑并审核 source → 运行受保护的 `tools/generate_content.py` → 运行 `tools/validate_content.py` → 运行 Swift/Bundle 内容测试。
- source 或 coverage 无效、ID 不完整、审校状态不是 `approved`、例句拆解漂移或翻译疑似机械拼接时，生成器必须 fail closed，不能写出部分产物。
- `reviewedBy` 必须透明标注实际审校方式；AI 辅助翻译不得伪造人工审校身份。

## 词汇优先级

不是机械的词频 Top N，而是：
`语料频率 × 口语实用性 × 可组合性 × 当前学习阶段`

同一个词只设置一个主归属分类，然后在其他场景的短句中复用。

## 来源与署名

- 所有内容由项目作者创建并审核
- sourceID 统一使用 "author-yaohuix"
- 若采用开放内容，必须在 sourceID 中保存许可、作者/来源和署名要求
- 不得使用 Manao、Forvo 或其他受限应用的文本、音频、图片、品牌或课程结构

## 例句翻译与发音

- `example` 是一条完整、自然的泰语句子；`segments` 只用于界面中的词块拆解，不能用来拼接例句翻译或合成语音。
- `exampleMeaning` 必须是整句的自然简体中文翻译，不得将 `segments[].gloss` 直接连接生成。
- 本翻译修订范围只允许改变 `exampleMeaning` 和审校元数据；既有 `example` 泰文文本以及 `segments` 的顺序、`thai`、`gloss` 必须逐字段保留。
- 问句使用自然的中文问号，不能保留“礼貌语气词”等拆解标签、逐词直译顺序或罗马拼音。
- 例句点击发音时，必须把完整的 `example` 作为一次 TTS utterance 播放；不能逐个 segment 播放，否则会丢失泰语的连读、重音和句子停顿。
