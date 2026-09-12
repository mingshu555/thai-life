# 泰生活 (Thai Life)

原生 iOS 泰语学习应用 — 安静记忆，生活实用。

## 概述

面向在泰国生活和旅游的中文母语者。聚焦日常高频泰语词汇、词块、实用短句和微型情景对话，使用 FSRS 自适应遗忘模型和 AI 语音发音。

## 技术栈

- **平台**: iOS 17+，原生 SwiftUI
- **数据**: SwiftData + CloudKit（iCloud 同步）
- **排程**: FSRS-6（swift-fsrs）
- **音频**: Google Cloud Text-to-Speech（应用内离线播放）
- **内容**: 14 个生活/旅游主题，1,200 个记忆单元

## 项目结构

```
thai-life/
├── project.yml                  # XcodeGen 配置
├── ThaiLife/
│   ├── App/                     # 应用入口、容器、根导航
│   ├── Domain/                  # 内容模型、学习模型
│   ├── Data/                    # 内容仓库、验证器、学习存储
│   ├── Scheduling/              # FSRS 排程器、学习队列构建
│   ├── Audio/                   # 音频播放服务
│   ├── Design/                  # 主题色、泰文文本组件
│   ├── Features/
│   │   ├── Today/               # 今日页（中枢）
│   │   ├── Catalog/             # 课程浏览
│   │   ├── Review/              # 复习会话 + 翻卡
│   │   ├── Progress/            # 进度统计
│   │   └── Settings/            # 设置页
│   └── Resources/
│       ├── Content/             # 内容包 JSON
│       └── Audio/               # 音频资产
├── ThaiLifeTests/               # 单元测试
├── tools/                       # 内容生成、音频生成、验证
└── docs/                        # 文档
```

## 快速开始

### 前置条件

- Xcode 16+（App Store 安装）
- Python 3.10+（内容生成和验证）
- Google Cloud 账号（音频生成，可选）

### 生成 Xcode 项目

```bash
cd thai-life
xcodegen generate
open ThaiLife.xcodeproj
```

### 运行测试

```bash
xcodebuild -project ThaiLife.xcodeproj -scheme ThaiLife \
  -destination 'platform=iOS Simulator,name=iPhone 16' test
```

### 内容验证

例句中文的编辑入口是 `tools/example_content.json`；
`tools/example_content_coverage.json` 固定 654 条例句 ID 与分类计数。
`items.json` 和 `content-manifest.json` 都是生成产物，禁止手工修订。

```bash
# 编辑并审核 tools/example_content.json 后，受保护地生成产物
python3 tools/generate_content.py
# 生成器会在源文件、coverage、example/segments 和审校状态无效时 fail closed
python3 tools/validate_content.py
```

`exampleMeaning` 必须是完整、自然的简体中文整句，不能由
`segments[].gloss` 拼接生成。本任务只修订 654 条 `exampleMeaning`；既有 `example`
泰文文本及所有 `segments` 顺序、`thai`、`gloss` 必须保持不变。内容生成后还应运行 Swift
Bundle 内容测试，确认总量 1,200、例句 654 条、固定分类计数和 manifest checksum。

### 音频生成（需要 Google 凭据）

```bash
python3 -m venv .venv
.venv/bin/pip install -r tools/requirements.txt
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
.venv/bin/python tools/generate_audio.py
.venv/bin/python tools/generate_audio_manifest.py
```

## 功能

- ✅ 今日中枢：到期复习、新词额度、预计用时
- ✅ 实体翻卡：正面线索 → 滑动翻面 → 四档评分
- ✅ 泰文点读：点击任意泰文播放 AI 发音（无扬声器图标）
- ✅ FSRS-6 自适应间隔
- ✅ 到期优先 + 积压保护
- ✅ 14 个生活/旅游主题，1,200 个记忆单元
- ✅ 词 → 词块 → 短句 → 对话学习阶梯
- ✅ iCloud 同步（不可变日志合并）
- ✅ 离线可用（内容包 + 音频本地）
- ✅ 简体中文界面
- ✅ 动态字体 + VoiceOver 无障碍

## 配置

- 目标记忆率：70%-97%（默认 90%）
- 慢速发音：0.75×
- 每日新词上限：可自定义

## 许可

本项目仅供个人学习使用。
