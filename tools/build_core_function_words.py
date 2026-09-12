#!/usr/bin/env python3
"""Build tools/core_function_words.json from the function-word handbook."""

from __future__ import annotations

import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HANDBOOK_PATH = Path(__file__).with_name("core_function_handbook.md")
OUTPUT_PATH = Path(__file__).with_name("core_function_words.json")

THAI_RE = re.compile(r"[\u0E00-\u0E7Fๆ]+")

SKIP_SECONDARY = {
    26: {"อยู่"},
    52: {"กับ"},
    55: {"เพราะว่า"},
    57: {"ก็"},
    58: {"ก็"},
    63: {"ไป"},
}

LAYER_TAGS = [
    (6, "layer1", "口语骨架"),
    (24, "layer2", "疑问否定"),
    (38, "layer3", "时态助动词"),
    (51, "layer4", "介词从句"),
    (59, "layer5", "连词关联"),
    (72, "layer6", "程度副词"),
    (79, "layer7", "趋向补语"),
    (89, "layer8", "句末语气"),
]

ROMANIZATION = {
    "เป็น": "pen",
    "คือ": "khʉʉ",
    "มี": "mii",
    "อยู่": "yùu",
    "นี่": "nîi",
    "นั่น": "nân",
    "โน่น": "nôon",
    "นี้": "níi",
    "นั้น": "nán",
    "โน้น": "nóon",
    "อะไร": "à-rai",
    "ที่ไหน": "thîi-nǎi",
    "ตรงไหน": "trong-nǎi",
    "เมื่อไหร่": "mʉ̂a-rài",
    "กี่โมง": "kìi-mooŋ",
    "ใคร": "khrai",
    "ทำไม": "tham-mai",
    "ยังไง": "yaŋ-ŋai",
    "เท่าไหร่": "thâo-rài",
    "กี่": "kìi",
    "อันไหน": "an-nǎi",
    "คนไหน": "khon-nǎi",
    "ไหม": "mǎi",
    "มั้ย": "mái",
    "หรือยัง": "rʉ̌ʉ-yaŋ",
    "ยัง": "yaŋ",
    "ใช่ไหม": "châi-mǎi",
    "ใช่มั้ย": "châi-mái",
    "หรือเปล่า": "rʉ̌ʉ-plàao",
    "ป่าว": "pàao",
    "ไม่": "mâi",
    "ไม่ได้": "mâi-dâi",
    "อย่า": "yàa",
    "ห้าม": "hâam",
    "ไม่ต้อง": "mâi-tɔ̂ŋ",
    "ไม่ค่อย": "mâi-khɔ̂i",
    "จะ": "cà",
    "กำลัง": "kam-laŋ",
    "แล้ว": "lɛ́ɛo",
    "เคย": "kəəi",
    "เพิ่ง": "phə̂ŋ",
    "เพิ่งจะ": "phə̂ŋ-cà",
    "ไว้": "wái",
    "ซะ": "sá",
    "เสีย": "sǐa",
    "ได้": "dâi",
    "ต้อง": "tɔ̂ŋ",
    "น่า": "nâa",
    "น่าจะ": "nâa-cà",
    "อยาก": "yàak",
    "อยากได้": "yàak-dâi",
    "ขอ": "khɔ̌ɔ",
    "ช่วย": "chûai",
    "ลอง": "lɔɔŋ",
    "ที่": "thîi",
    "ของ": "khɔ̌ɔŋ",
    "ให้": "hâi",
    "ว่า": "wâa",
    "โดน": "doon",
    "ถูก": "thùuk",
    "กับ": "kàp",
    "จาก": "càak",
    "ถึง": "thʉ̌ŋ",
    "ใน": "nai",
    "บน": "bon",
    "ใต้": "tâi",
    "นอก": "nɔ̂ɔk",
    "ด้วย": "dûai",
    "ตาม": "taam",
    "เกี่ยวกับ": "kìao-kàp",
    "อัน": "an",
    "และ": "lɛ́",
    "หรือ": "rʉ̌ʉ",
    "แต่": "tɛ̀ɛ",
    "แต่ว่า": "tɛ̀ɛ-wâa",
    "เพราะ": "phrɔ́",
    "ก็เลย": "kɔ̂-ləəi",
    "แล้วก็": "lɛ́ɛo-kɔ̂",
    "พอ": "phɔɔ",
    "ถ้า": "thâa",
    "ไม่งั้น": "mâi-ŋán",
    "ไม่อย่างนั้น": "mâi-yàaŋ-nán",
    "มาก": "mâak",
    "โคตร": "khôot",
    "หน่อย": "nɔ̀i",
    "นิดหน่อย": "nít-nɔ̀i",
    "เกินไป": "kəən-pai",
    "ค่อนข้าง": "khɔ̂n-khâaŋ",
    "เกือบ": "kʉ̀ap",
    "แทบ": "thɛ́ɛp",
    "อีก": "ìik",
    "เดียว": "diao",
    "เดียวกัน": "diao-kan",
    "เดี๋ยว": "dǐao",
    "แป๊บเดียว": "páɛp-diao",
    "เอง": "eeŋ",
    "กัน": "kan",
    "ค่อย": "khɔ̂i",
    "เลย": "ləəi",
    "บ่อยๆ": "bɔ̀i-bɔ̀i",
    "เสมอ": "sà-məə",
    "ขึ้น": "khʉ̂n",
    "ลง": "loŋ",
    "เข้า": "khâo",
    "ออก": "ɔ̀ɔk",
    "ไป": "pai",
    "มา": "maa",
    "ทัน": "than",
    "ติด": "tìt",
    "นะ": "ná",
    "สิ": "sì",
    "ดิ": "dì",
    "หรอก": "rɔ̂ɔk",
    "มั้ง": "máŋ",
    "เถอะ": "thə̀ə",
    "เหอะ": "hə̀ə",
    "เนี่ย": "nîa",
    "ไง": "ŋai",
    "ไงล่ะ": "ŋai-là",
    "อ่ะ": "à",
    "เหรอ": "rɔ̌ɔ",
    "หรอ": "rɔɔ",
    "จ้า": "câa",
    "จ้ะ": "câ",
}

MEANINGS = {
    "เป็น": "是 / 会 / 充当",
    "คือ": "是 / 即是 / 定义",
    "มี": "有 / 存在",
    "อยู่": "在 / 居住 / 进行体",
    "นี่": "这（独立指示）",
    "นั่น": "那（独立指示）",
    "โน่น": "远处那（独立指示）",
    "นี้": "这个（后置修饰）",
    "นั้น": "那个（后置修饰）",
    "โน้น": "远处那个（后置修饰）",
    "อะไร": "什么",
    "ที่ไหน": "在哪里",
    "ตรงไหน": "哪个位置",
    "เมื่อไหร่": "什么时候",
    "กี่โมง": "几点",
    "ใคร": "谁",
    "ทำไม": "为什么",
    "ยังไง": "怎么 / 怎么样",
    "เท่าไหร่": "多少钱 / 多少",
    "กี่": "多少个",
    "อันไหน": "哪一个",
    "คนไหน": "哪个人",
    "ไหม": "吗",
    "มั้ย": "吗（口语）",
    "หรือยัง": "……了吗",
    "ยัง": "还 / 还没",
    "ใช่ไหม": "对吧 / 是不是",
    "ใช่มั้ย": "对吧（口语）",
    "หรือเปล่า": "是不是 / 有没有",
    "ป่าว": "吗 / 没有吗（口语）",
    "ไม่": "不",
    "ไม่ได้": "没有 / 没做 / 不能",
    "อย่า": "别 / 不要",
    "ห้าม": "严禁 / 禁止",
    "ไม่ต้อง": "不用 / 不必",
    "ไม่ค่อย": "不太 / 不怎么",
    "จะ": "将要 / 打算 / 会",
    "กำลัง": "正在",
    "แล้ว": "已经 / 了 / 然后",
    "เคย": "曾经 / 过",
    "เพิ่ง": "刚刚 / 才",
    "เพิ่งจะ": "刚刚才",
    "ไว้": "预先准备 / 留着",
    "ซะ": "彻底做掉 / 催促",
    "เสีย": "完成 / 惋惜",
    "ได้": "能 / 可以 / 得到",
    "ต้อง": "必须 / 得",
    "น่า": "应该 / 令人……",
    "น่าจะ": "大概会 / 应该会",
    "อยาก": "想做",
    "อยากได้": "想要",
    "ขอ": "请求 / 请给我",
    "帮助": "帮助",
    "ช่วย": "帮助 / 麻烦 / 请协助",
    "ลอง": "尝试 / 试试看",
    "ที่": "在…… / ……的 / 第",
    "ของ": "的 / 东西",
    "ให้": "给 / 让 / 替",
    "ว่า": "说 / 以为 / that",
    "โดน": "被 / 挨",
    "ถูก": "被 / 正确 / 便宜",
    "กับ": "和 / 跟 / 对……",
    "จาก": "从 / 离",
    "ถึง": "到 / 到达 / 提到",
    "ใน": "在……里",
    "บน": "在……上",
    "ใต้": "在……下",
    "นอก": "在……外",
    "ด้วย": "也 / 一起 / 用",
    "ตาม": "顺着 / 按照 / 跟着",
    "เกี่ยวกับ": "关于 / 有关",
    "อัน": "个 / 这个 / 所……的",
    "และ": "和 / 并且",
    "หรือ": "或者 / 还是",
    "แต่": "但是 / 不过",
    "แต่ว่า": "但是说 / 不过",
    "เพราะ": "因为",
    "ก็เลย": "所以就",
    "แล้วก็": "然后 / 还有",
    "พอ": "一……就……",
    "ถ้า": "如果……就……",
    "ไม่งั้น": "不然的话",
    "ไม่อย่างนั้น": "否则",
    "มาก": "很 / 非常",
    "โคตร": "超级 / 极度",
    "หน่อย": "一点点 / 请……一下",
    "นิดหน่อย": "一点点",
    "เกินไป": "太……了",
    "ค่อนข้าง": "比较 / 相当",
    "เกือบ": "几乎 / 差点",
    "แทบ": "几乎 / 简直",
    "อีก": "再 / 又 / 另外",
    "เดียว": "单一 / 仅仅",
    "เดียวกัน": "相同 / 同一个",
    "เดี๋ยว": "马上 / 待会儿",
    "แป๊บเดียว": "一小会儿",
    "เอง": "自己 / 亲自 / 而已",
    "กัน": "互相 / 一起",
    "ค่อย": "稍后再 / 慢慢",
    "เลย": "完全 / 直接 / 就",
    "บ่อยๆ": "经常",
    "เสมอ": "常常 / 总是",
    "ขึ้น": "上 / 增多 / 变好",
    "ลง": "下 / 减少 / 记下",
    "เข้า": "进 / 靠近",
    "ออก": "出 / 向外 / 想出",
    "ไป": "去 / 离开",
    "มา": "来 / 靠近",
    "ทัน": "赶得上 / 来得及",
    "ติด": "卡住 / 堵车 / 迷上",
    "นะ": "提醒 / 叮嘱 / 亲近",
    "สิ": "催促 / 确认",
    "ดิ": "催促（口语）",
    "หรอก": "才不呢 / 安慰反驳",
    "มั้ง": "大概吧 / 吧",
    "เถอะ": "吧 / 干脆……吧",
    "เหอะ": "吧（口语）",
    "เนี่ย": "强调 / 到底……",
    "ไง": "看吧 / 就是嘛",
    "ไงล่ะ": "看吧 / 就是这样",
    "อ่ะ": "停顿 / 撒娇",
    "เหรอ": "吗（反问 / 意外）",
    "หรอ": "吗（口语反问）",
    "จ้า": "亲切答应",
    "จ้ะ": "亲切语气（短）",
}

FALLBACK_EXAMPLES = {
    "โน่น": {
        "example": "โน่นอะไร",
        "exampleMeaning": "那（远处）是什么？",
        "segments": [{"thai": "โน่น", "gloss": "远处那"}, {"thai": "อะไร", "gloss": "什么"}],
    },
    "โน้น": {
        "example": "คนโน้นเป็นใคร",
        "exampleMeaning": "远处那个人是谁？",
        "segments": [
            {"thai": "คน", "gloss": "人"},
            {"thai": "โน้น", "gloss": "远处那个"},
            {"thai": "เป็น", "gloss": "是"},
            {"thai": "ใคร", "gloss": "谁"},
        ],
    },
    "ใช่มั้ย": {
        "example": "คุณเป็นคนจีนใช่มั้ย",
        "exampleMeaning": "你是中国人对吧？",
        "segments": [
            {"thai": "คุณ", "gloss": "你"},
            {"thai": "เป็น", "gloss": "是"},
            {"thai": "คนจีน", "gloss": "中国人"},
            {"thai": "ใช่", "gloss": "是"},
            {"thai": "มั้ย", "gloss": "吗"},
        ],
    },
    "เพิ่งจะ": {
        "example": "เพิ่งจะรู้เรื่อง",
        "exampleMeaning": "刚刚才得知这件事。",
        "segments": [
            {"thai": "เพิ่ง", "gloss": "刚刚"},
            {"thai": "จะ", "gloss": "才"},
            {"thai": "รู้", "gloss": "知道"},
            {"thai": "เรื่อง", "gloss": "事情"},
        ],
    },
    "ใต้": {
        "example": "อยู่ใต้โต๊ะ",
        "exampleMeaning": "在桌子下面。",
        "segments": [
            {"thai": "อยู่", "gloss": "在"},
            {"thai": "ใต้", "gloss": "下面"},
            {"thai": "โต๊ะ", "gloss": "桌子"},
        ],
    },
    "นอก": {
        "example": "อยู่นอกบ้าน",
        "exampleMeaning": "在房子外面。",
        "segments": [
            {"thai": "อยู่", "gloss": "在"},
            {"thai": "นอก", "gloss": "外面"},
            {"thai": "บ้าน", "gloss": "房子"},
        ],
    },
    "แต่ว่า": {
        "example": "อยากไปแต่ว่าไม่มีเวลา",
        "exampleMeaning": "想去但是没时间。",
        "segments": [
            {"thai": "อยากไป", "gloss": "想去"},
            {"thai": "แต่", "gloss": "但是"},
            {"thai": "ว่า", "gloss": "说"},
            {"thai": "ไม่มีเวลา", "gloss": "没有时间"},
        ],
    },
    "ไม่อย่างนั้น": {
        "example": "รีบไปไม่อย่างนั้นสายนะ",
        "exampleMeaning": "快点去，否则要迟到了哦。",
        "segments": [
            {"thai": "รีบไป", "gloss": "快点去"},
            {"thai": "ไม่", "gloss": "不"},
            {"thai": "อย่าง", "gloss": "样"},
            {"thai": "นั้น", "gloss": "那样"},
            {"thai": "สาย", "gloss": "迟到"},
            {"thai": "นะ", "gloss": "语气词"},
        ],
    },
    "เกินไป": {
        "example": "แพงเกินไป",
        "exampleMeaning": "太贵了。",
        "segments": [
            {"thai": "แพง", "gloss": "贵"},
            {"thai": "เกิน", "gloss": "超过"},
            {"thai": "ไป", "gloss": "去"},
        ],
    },
    "แทบ": {
        "example": "แทบสายแล้ว",
        "exampleMeaning": "差点就迟到了。",
        "segments": [
            {"thai": "แทบ", "gloss": "几乎"},
            {"thai": "สาย", "gloss": "迟到"},
            {"thai": "แล้ว", "gloss": "了"},
        ],
    },
    "เสมอ": {
        "example": "มาที่นี่เสมอไหม",
        "exampleMeaning": "你总是来这里吗？",
        "segments": [
            {"thai": "มา", "gloss": "来"},
            {"thai": "ที่นี่", "gloss": "这里"},
            {"thai": "เสมอ", "gloss": "总是"},
            {"thai": "ไหม", "gloss": "吗"},
        ],
    },
    "ไงล่ะ": {
        "example": "บอกแล้วไงล่ะ",
        "exampleMeaning": "我早就跟你说过了嘛！",
        "segments": [
            {"thai": "บอก", "gloss": "说"},
            {"thai": "แล้ว", "gloss": "已经"},
            {"thai": "ไง", "gloss": "看吧"},
            {"thai": "ล่ะ", "gloss": "语气"},
        ],
    },
    "จ้ะ": {
        "example": "ขอบคุณจ้ะ",
        "exampleMeaning": "谢谢啦！",
        "segments": [
            {"thai": "ขอบคุณ", "gloss": "谢谢"},
            {"thai": "จ้ะ", "gloss": "亲切语气词"},
        ],
    },
}

COMPOUND_SPLITS = {
    "ไม่ได้": [("ไม่", "不"), ("ได้", "能/得")],
    "ไม่ต้อง": [("ไม่", "不"), ("ต้อง", "必须")],
    "ไม่ค่อย": [("ไม่", "不"), ("ค่อย", "怎么/再")],
    "เกี่ยวกับ": [("เกี่ยว", "关联"), ("กับ", "和/对")],
    "ที่ไหน": [("ที่", "在/的"), ("ไหน", "哪")],
    "ตรงไหน": [("ตรง", "位置"), ("ไหน", "哪")],
    "เมื่อไหร่": [("เมื่อ", "当/时"), ("ไหร่", "何")],
    "กี่โมง": [("กี่", "多少"), ("โมง", "点钟")],
    "เท่าไหร่": [("เท่า", "等量"), ("ไหร่", "何")],
    "อันไหน": [("อัน", "个"), ("ไหน", "哪")],
    "คนไหน": [("คน", "人"), ("ไหน", "哪")],
    "หรือยัง": [("หรือ", "还是"), ("ยัง", "还")],
    "ใช่ไหม": [("ใช่", "是"), ("ไหม", "吗")],
    "ใช่มั้ย": [("ใช่", "是"), ("มั้ย", "吗")],
    "หรือเปล่า": [("หรือ", "还是"), ("เปล่า", "空/否")],
    "อยากได้": [("อยาก", "想"), ("ได้", "得到")],
    "น่าจะ": [("น่า", "应该"), ("จะ", "会")],
    "เพิ่งจะ": [("เพิ่ง", "刚刚"), ("จะ", "将")],
    "แล้วก็": [("แล้ว", "然后"), ("ก็", "就")],
    "ไม่งั้น": [("ไม่", "不"), ("งั้น", "那样")],
    "ไม่อย่างนั้น": [("ไม่", "不"), ("อย่าง", "样"), ("นั้น", "那样")],
    "นิดหน่อย": [("นิด", "一点"), ("หน่อย", "一下")],
    "เกินไป": [("เกิน", "超过"), ("ไป", "去")],
    "เดียวกัน": [("เดียว", "同一"), ("กัน", "互相")],
    "แป๊บเดียว": [("แป๊บ", "片刻"), ("เดียว", "仅仅")],
    "แต่ว่า": [("แต่", "但是"), ("ว่า", "说")],
    "ก็เลย": [("ก็", "就"), ("เลย", "便")],
    "ไงล่ะ": [("ไง", "看吧"), ("ล่ะ", "语气")],
}


def layer_for(entry_num: int) -> tuple[str, str]:
    for max_num, tag, label in LAYER_TAGS:
        if entry_num <= max_num:
            return tag, label
    raise ValueError(f"no layer for entry {entry_num}")


def strip_md(value: str) -> str:
    value = value.strip()
    value = re.sub(r"\*\*([^*]+)\*\*", r"\1", value)
    value = re.sub(r"`([^`]+)`", r"\1", value)
    return value.strip()


def extract_headwords(title: str) -> list[str]:
    parens = re.findall(r"\(([^)]*[\u0E00-\u0E7F][^)]*)\)", title)
    source = parens[-1] if parens else title
    words: list[str] = []
    for bit in re.split(r"/|\.\.\.", source):
        words.extend(THAI_RE.findall(bit))
    seen: set[str] = set()
    unique: list[str] = []
    for word in words:
        if word not in seen:
            seen.add(word)
            unique.append(word)
    return unique


def parse_segments(raw: str) -> list[dict[str, str]]:
    segments: list[dict[str, str]] = []
    index = 0
    while True:
        start = raw.find("`", index)
        if start < 0:
            break
        end = raw.find("`", start + 1)
        if end < 0:
            break
        thai = raw[start + 1 : end]
        cursor = end + 1
        while cursor < len(raw) and raw[cursor].isspace():
            cursor += 1
        if cursor >= len(raw) or raw[cursor] != "(":
            index = end + 1
            continue
        depth = 0
        pos = cursor
        in_backtick = False
        while pos < len(raw):
            char = raw[pos]
            if char == "`":
                in_backtick = not in_backtick
            elif not in_backtick:
                if char == "(":
                    depth += 1
                elif char == ")":
                    depth -= 1
                    if depth == 0:
                        pos += 1
                        break
            pos += 1
        gloss = simplify_gloss(raw[cursor + 1 : pos - 1])
        if thai.strip() and gloss:
            segments.append({"thai": thai, "gloss": gloss})
        index = pos
    return segments


def simplify_gloss(value: str) -> str:
    value = re.sub(r"`[^`]+`", "", value)
    value = value.replace("；", ";").split(";")[0]
    if "：" in value:
        value = value.split("：")[-1]
    elif ":" in value:
        value = value.split(":")[-1]
    value = re.sub(r"\s+", "", value)
    return value.strip(" 。，,")


def expand_compounds(segments: list[dict[str, str]]) -> list[dict[str, str]]:
    expanded: list[dict[str, str]] = []
    for segment in segments:
        parts = COMPOUND_SPLITS.get(segment["thai"])
        if parts:
            expanded.extend({"thai": thai, "gloss": gloss} for thai, gloss in parts)
        else:
            expanded.append(segment)
    return expanded


def normalized(value: str) -> str:
    return "".join(value.split())


def extract_examples(body: str) -> list[dict[str, object]]:
    examples: list[dict[str, object]] = []
    lines = body.splitlines()
    index = 0
    while index < len(lines):
        line = lines[index]
        match = re.search(r"\*\*例句\*\*[：:]\s*`([^`]+)`", line)
        if not match:
            index += 1
            continue
        example = match.group(1).strip()
        if re.search(r"[\u4e00-\u9fff]", example):
            index += 1
            continue
        if " / " in example:
            example = example.split(" / ", 1)[0].strip()
        breakdown = ""
        meaning = ""
        look = index + 1
        while look < len(lines) and look <= index + 6:
            current = lines[look]
            if "**例句**" in current:
                break
            split_match = re.search(r"\*\*拆解\*\*[：:]\s*(.+)", current)
            if split_match and not breakdown:
                breakdown = split_match.group(1).strip()
            meaning_match = re.search(r"\*\*译文\*\*[：:]\s*(.+)", current)
            if meaning_match and not meaning:
                meaning = strip_md(meaning_match.group(1))
            look += 1
        if example and breakdown and meaning:
            segments = expand_compounds(parse_segments(breakdown))
            examples.append(
                {
                    "example": example,
                    "exampleMeaning": meaning.rstrip("。") + "。",
                    "segments": segments,
                }
            )
        index += 1
    return examples


def first_definition(body: str) -> str:
    for line in body.splitlines()[1:]:
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#") or stripped.startswith("* **拼读"):
            continue
        if stripped.startswith("####"):
            continue
        value = strip_md(stripped).lstrip("* ").strip()
        if value:
            return value
    return ""


def choose_example(headword: str, examples: list[dict[str, object]]) -> dict[str, object] | None:
    for record in examples:
        if normalized(headword) in normalized(str(record["example"])):
            segments = record["segments"]
            reconstructed = "".join(segment["thai"] for segment in segments)
            if normalized(reconstructed) != normalized(str(record["example"])):
                continue
            if not segments:
                continue
            return record
    return None


def handbook_entries() -> list[tuple[int, str, str]]:
    text = HANDBOOK_PATH.read_text(encoding="utf-8")
    start = text.find("# 第 1 层：口语骨架词")
    end = text.find("### 1. 20 大超高频")
    if start < 0 or end < 0:
        raise ValueError("cannot locate handbook word body")
    body = text[start:end]
    parts = re.split(r"\n(?=### \d+\. )", body)
    entries: list[tuple[int, str, str]] = []
    for part in parts:
        match = re.match(r"### (\d+)\. (.+)", part)
        if not match:
            continue
        entries.append((int(match.group(1)), match.group(2).strip(), part))
    if len(entries) != 89:
        raise ValueError(f"expected 89 handbook entries, got {len(entries)}")
    return entries


def build_records() -> list[dict[str, object]]:
    records: list[dict[str, object]] = []
    seen: set[str] = set()
    missing_rom: list[str] = []
    missing_meaning: list[str] = []
    no_example: list[str] = []
    for number, title, body in handbook_entries():
        layer_tag, layer_label = layer_for(number)
        examples = extract_examples(body)
        usage = first_definition(body)
        skip = SKIP_SECONDARY.get(number, set())
        for thai in extract_headwords(title):
            if thai in skip or thai in seen:
                continue
            seen.add(thai)
            if thai not in ROMANIZATION:
                missing_rom.append(thai)
                continue
            if thai not in MEANINGS:
                missing_meaning.append(thai)
                continue
            chosen = choose_example(thai, examples) or FALLBACK_EXAMPLES.get(thai)
            record: dict[str, object] = {
                "thai": thai,
                "romanization": ROMANIZATION[thai],
                "meaningZhHans": MEANINGS[thai],
                "usageNote": usage,
                "tags": ["core_function", layer_tag, layer_label],
                "entryNumber": number,
            }
            if chosen:
                record["example"] = chosen["example"]
                record["exampleMeaning"] = chosen["exampleMeaning"]
                record["segments"] = chosen["segments"]
            else:
                record["example"] = ""
                record["segments"] = []
                no_example.append(thai)
            records.append(record)
    if missing_rom or missing_meaning:
        raise ValueError(f"missing romanization={missing_rom} meaning={missing_meaning}")
    return records


def main() -> None:
    records = build_records()
    payload = {
        "schemaVersion": 1,
        "locale": "zh-Hans",
        "source": "core_function_handbook.md",
        "recordCount": len(records),
        "items": records,
    }
    OUTPUT_PATH.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    with_example = sum(1 for record in records if record.get("example"))
    print(f"Wrote {OUTPUT_PATH}")
    print(f"cards={len(records)} with_example={with_example} without={len(records) - with_example}")
    print("without examples:", [record["thai"] for record in records if not record.get("example")])


if __name__ == "__main__":
    main()
