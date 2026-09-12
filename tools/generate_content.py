#!/usr/bin/env python3
"""Generate the complete 1,200-unit Thai learning content pack.

Categories and target counts:
  basics        160
  social         90
  numbers       110
  food_dining   130
  shopping       80
  home_living    90
  transport     100
  phone_network  60
  health         80
  safety         50
  weather_leisure 70
  airport        50
  hotel          60
  local_errands  70
Total: 1,200
"""

import json
import hashlib
import unicodedata
import os
import re
import sys
import tempfile
from datetime import date, datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXAMPLE_SOURCE_PATH = ROOT / "tools" / "example_content.json"
EXAMPLE_COVERAGE_PATH = ROOT / "tools" / "example_content_coverage.json"
CHUNK_BREAKDOWN_PATH = ROOT / "tools" / "chunk_breakdowns.json"
DIALOGUE_BREAKDOWN_PATH = ROOT / "tools" / "dialogue_breakdowns.json"
WORD_BREAKDOWN_PATH = ROOT / "tools" / "word_breakdowns.json"
CORE_FUNCTION_PATH = ROOT / "tools" / "core_function_words.json"
EXTRA_EXAMPLE_CATEGORIES = {"core_function"}
WORD_BREAKDOWN_DENIED_IDS = {
    "basics-word-001",
    "social-word-001",
    "airport-word-003",
    "airport-word-011",
    "airport-word-018",
    "airport-word-025",
    "airport-word-043",
    "hotel-word-003",
    "phone_network-word-015",
    "phone_network-word-035",
}
CONTENT_OUTPUT_PATH = ROOT / "ThaiLife" / "Resources" / "Content" / "items.json"
CONTENT_MANIFEST_PATH = ROOT / "ThaiLife" / "Resources" / "Content" / "content-manifest.json"

EXPECTED_EXAMPLE_CATEGORY_COUNTS = {
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
    "local_errands": 50,
}

KNOWN_SEGMENT_LABEL_RESIDUE = ("礼貌语气词", "语气词", "…的是")
EXAMPLE_FIELDS = {"example", "exampleMeaning", "segments"}
GENERATED_CONTENT_FIELDS = EXAMPLE_FIELDS | {"chunkBreakdown", "dialogueBreakdown", "wordBreakdown"}
PRESERVED_BASELINE_FIELDS = {"contentVersion"}

# ── Content database ──────────────────────────────────────────────────

CONTENT_DB = {
    "basics": {
        "words": [
            ("สวัสดี", "sà-wàt-dii", "你好/再见", "通用问候语", ["greeting"]),
            ("ครับ", "khráp", "男性礼貌语气词", "男说话者句尾表达礼貌，亦可单独作回答（是/好的）", ["polite"]),
            ("ค่ะ", "khâ", "女性礼貌语气词", "女说话者句尾表达礼貌，陈述/回答时使用", ["polite"]),
            ("ขอบคุณ", "khɔ̀ɔp-khun", "谢谢", "", ["polite"]),
            ("ขอโทษ", "khɔ̌ɔ-thôot", "对不起/打扰一下", "", ["polite"]),
            ("ไม่เป็นไร", "mâi-pen-rai", "没关系/不用谢", "万能回应词", ["polite"]),
            ("ใช่", "châi", "是的/对", "", ["affirm"]),
            ("ไม่ใช่", "mâi-châi", "不是", "", ["negation"]),
            ("ได้", "dâi", "可以/能", "", ["modal"]),
            ("ไม่ได้", "mâi-dâi", "不可以/不能", "", ["modal"]),
            ("เอา", "ao", "要/拿", "", ["verb"]),
            ("ไม่เอา", "mâi-ao", "不要", "", ["verb"]),
            ("มี", "mii", "有", "", ["verb"]),
            ("ไม่มี", "mâi-mii", "没有", "", ["verb"]),
            ("เป็น", "pen", "是/会(技能)", "", ["verb"]),
            ("ไม่เป็น", "mâi-pen", "不是/不会", "", ["verb"]),
            ("ไป", "pai", "去", "", ["verb"]),
            ("มา", "maa", "来", "", ["verb"]),
            ("ทำ", "tham", "做", "", ["verb"]),
            ("กิน", "kin", "吃", "", ["verb"]),
            ("ดื่ม", "dʉ̀ʉm", "喝", "", ["verb"]),
            ("นอน", "nɔɔn", "睡", "", ["verb"]),
            ("ตื่น", "tʉ̀ʉn", "醒/起床", "", ["verb"]),
            ("อาบน้ำ", "àap-náam", "洗澡", "", ["verb"]),
            ("พูด", "phûut", "说/讲", "", ["verb"]),
            ("ฟัง", "fang", "听", "", ["verb"]),
            ("ดู", "duu", "看", "", ["verb"]),
            ("อ่าน", "àan", "读", "", ["verb"]),
            ("เขียน", "khǐan", "写", "", ["verb"]),
            ("คิด", "khít", "想/认为", "", ["verb"]),
            ("รู้", "rúu", "知道", "", ["verb"]),
            ("ไม่รู้", "mâi-rúu", "不知道", "", ["verb"]),
            ("เข้าใจ", "khâo-cai", "理解/明白", "", ["verb"]),
            ("ไม่เข้าใจ", "mâi-khâo-cai", "不理解", "", ["verb"]),
            ("ชอบ", "chɔ̂ɔp", "喜欢", "", ["verb"]),
            ("ไม่ชอบ", "mâi-chɔ̂ɔp", "不喜欢", "", ["verb"]),
            ("รัก", "rák", "爱", "", ["verb"]),
            ("อยาก", "yàak", "想要", "", ["modal"]),
            ("ต้อง", "tɔ̂ŋ", "必须", "", ["modal"]),
            ("จะ", "cà", "将要", "", ["modal"]),
        ],
        "chunks": [
            ("ขอโทษนะครับ", "khɔ̌ɔ-thôot ná khráp", "打扰一下(男)", "", ["polite"]),
            ("ขอโทษนะคะ", "khɔ̌ɔ-thôot ná khá", "打扰一下(女)", "", ["polite"]),
            ("ขอบคุณมากครับ", "khɔ̀ɔp-khun mâak khráp", "非常感谢(男)", "", ["polite"]),
            ("ขอบคุณมากค่ะ", "khɔ̀ɔp-khun mâak khâ", "非常感谢(女)", "", ["polite"]),
            ("ไม่เป็นไรครับ", "mâi-pen-rai khráp", "没关系(男)", "", ["polite"]),
            ("ได้ไหม", "dâi mǎi", "可以吗", "", ["question"]),
            ("ได้ครับ", "dâi khráp", "可以(男)", "", ["response"]),
            ("ไม่ได้ครับ", "mâi-dâi khráp", "不可以(男)", "", ["response"]),
            ("เอาไหม", "ao mǎi", "要吗", "", ["question"]),
            ("มีไหม", "mii mǎi", "有吗", "", ["question"]),
            ("ไปไหน", "pai nǎi", "去哪里", "", ["question"]),
            ("มาไหน", "maa nǎi", "从哪里来", "", ["question"]),
            ("กินอะไร", "kin à-rai", "吃什么", "", ["question"]),
            ("อร่อยไหม", "à-rɔ̀i mǎi", "好吃吗", "", ["question"]),
            ("แพงไหม", "phɛɛŋ mǎi", "贵吗", "", ["question"]),
            ("เข้าใจไหม", "khâo-cai mǎi", "明白吗", "", ["question"]),
            ("พูดไทยได้ไหม", "phûut thai dâi mǎi", "会说泰语吗", "", ["question"]),
            ("พูดช้าๆหน่อย", "phûut cháa-cháa nɔ̀i", "请说慢一点", "", ["request"]),
            ("อีกครั้งนะครับ", "ìik khráŋ ná khráp", "再说一次(男)", "", ["request"]),
            ("ช่วยหน่อยครับ", "chûai nɔ̀i khráp", "帮帮忙(男)", "", ["request"]),
        ],
        "sentences": [
            ("สวัสดีครับ ผมชื่อ...", "sà-wàt-dii khráp phǒm chʉ̂ʉ...", "你好，我叫...(男)", "", ["greeting"]),
            ("สวัสดีค่ะ ฉันชื่อ...", "sà-wàt-dii khâ chǎn chʉ̂ʉ...", "你好，我叫...(女)", "", ["greeting"]),
            ("ยินดีที่ได้รู้จักครับ", "yin-dii thîi dâi rúu-càk khráp", "很高兴认识你(男)", "", ["greeting"]),
            ("ยินดีที่ได้รู้จักค่ะ", "yin-dii thîi dâi rúu-càk khâ", "很高兴认识你(女)", "", ["greeting"]),
            ("ขอโทษครับ ผมพูดไทยได้นิดหน่อย", "khɔ̌ɔ-thôot khráp phǒm phûut thai dâi nít-nɔ̀i", "对不起，我只会说一点泰语(男)", "", ["intro"]),
            ("ขอโทษค่ะ ฉันพูดไทยได้นิดหน่อย", "khɔ̌ɔ-thôot khâ chǎn phûut thai dâi nít-nɔ̀i", "对不起，我只会说一点泰语(女)", "", ["intro"]),
            ("ช่วยพูดภาษาอังกฤษได้ไหมครับ", "chûai phûut phaa-sǎa ang-krìt dâi mǎi khráp", "能说英语吗(男)", "", ["request"]),
            ("ช่วยเขียนให้หน่อยได้ไหมครับ", "chûai khǐan hâi nɔ̀i dâi mǎi khráp", "能帮我写一下吗(男)", "", ["request"]),
            ("ขอโทษครับ ไม่เข้าใจครับ", "khɔ̌ɔ-thôot khráp mâi-khâo-cai khráp", "对不起，我不明白(男)", "", ["response"]),
            ("รอสักครู่ครับ", "rɔɔ sàk-khrûu khráp", "请稍等一下(男)", "", ["request"]),
            ("ขอบคุณมากครับสำหรับความช่วยเหลือ", "khɔ̀ɔp-khun mâak khráp sǎm-ràp khwaam-chûai-lʉ̌ʉa", "非常感谢你的帮助(男)", "", ["polite"]),
            ("ขอโทษครับ ผมไม่รู้", "khɔ̌ɔ-thôot khráp phǒm mâi-rúu", "对不起，我不知道(男)", "", ["response"]),
            ("ไม่เป็นไร ไม่ต้องเกรงใจ", "mâi-pen-rai mâi-tɔ̂ŋ kreeŋ-cai", "没关系，不用客气", "", ["polite"]),
            ("ขอถามหน่อยครับ", "khɔ̌ɔ thǎam nɔ̀i khráp", "请问一下(男)", "", ["request"]),
            ("คุณพูดไทยเก่งมาก", "khun phûut thai kèŋ mâak", "你泰语说得很好", "", ["compliment"]),
            ("ช่วยสอนผมพูดไทยหน่อยครับ", "chûai sɔ̌ɔn phǒm phûut thai nɔ̀i khráp", "请教我说泰语(男)", "", ["request"]),
            ("ขอโทษครับ ผมมาสาย", "khɔ̌ɔ-thôot khráp phǒm maa sǎai", "对不起，我迟到了(男)", "", ["apology"]),
            ("เดี๋ยวผมกลับมานะครับ", "dǐao phǒm klàp maa ná khráp", "我马上回来(男)", "", ["info"]),
            ("คุณชื่ออะไรครับ", "khun chʉ̂ʉ à-rai khráp", "你叫什么名字(男)", "", ["question"]),
            ("ผมมาจากประเทศจีนครับ", "phǒm maa càak prà-thêet ciin khráp", "我来自中国(男)", "", ["intro"]),
        ],
        "dialogues": [
            ("A: สวัสดีครับ\nB: สวัสดีค่ะ", "A: 你好\nB: 你好", "基本问候对话", ["greeting"]),
            ("A: คุณชื่ออะไรครับ\nB: ผมชื่อหลี่หมิงครับ\nA: ยินดีที่ได้รู้จักครับ", "A: 你叫什么名字\nB: 我叫李明\nA: 很高兴认识你", "自我介绍对话", ["intro"]),
            ("A: พูดไทยได้ไหมครับ\nB: ได้นิดหน่อยครับ\nA: เก่งมากครับ", "A: 会说泰语吗\nB: 会一点点\nA: 很厉害", "语言能力对话", ["language"]),
            ("A: ขอบคุณมากครับ\nB: ไม่เป็นไรค่ะ", "A: 非常感谢\nB: 不用客气", "道谢应答对话", ["polite"]),
            ("A: ขอโทษครับ\nB: ไม่เป็นไรครับ", "A: 对不起\nB: 没关系", "道歉应答对话", ["apology"]),
        ],
    },
}

# We'll generate the remaining categories progressively.
# For now, define the structure for all 14 categories.

def make_id(cat: str, typ: str, idx: int) -> str:
    return f"{cat}-{typ}-{idx:03d}"

def make_audio_id(cat: str, typ: str, idx: int) -> str:
    return f"audio-{cat}-{typ}-{idx:03d}"

def generate_basics() -> list:
    """Generate ~160 items for 开口基础."""
    items = []
    idx = 0
    # Words
    for i, (th, rom, zh, note, tags) in enumerate(CONTENT_DB["basics"]["words"]):
        idx = i + 1
        items.append({
            "id": make_id("basics", "word", idx),
            "kind": "word",
            "category": "basics",
            "tags": tags + ["core"],
            "thai": th,
            "romanization": rom,
            "meaningZhHans": zh,
            "usageNote": note,
            "frequencyTier": 1,
            "audioID": make_audio_id("basics", "word", idx),
            "prerequisiteIDs": [],
            "relatedIDs": [],
            "example": "",
            "segments": [],
            "sourceID": "author-yaohuix",
            "contentVersion": 1
        })
    # Chunks (prerequisites = root words)
    word_count = len(items)
    for i, (th, rom, zh, note, tags) in enumerate(CONTENT_DB["basics"]["chunks"]):
        idx = word_count + i + 1
        items.append({
            "id": make_id("basics", "chunk", i + 1),
            "kind": "chunk",
            "category": "basics",
            "tags": tags + ["phrase"],
            "thai": th,
            "romanization": rom,
            "meaningZhHans": zh,
            "usageNote": note,
            "frequencyTier": 2,
            "audioID": make_audio_id("basics", "chunk", i + 1),
            "prerequisiteIDs": [make_id("basics", "word", 1)],  # สวัสดี
            "relatedIDs": [],
            "example": "",
            "segments": [],
            "sourceID": "author-yaohuix",
            "contentVersion": 1
        })
    # Sentences
    chunk_base = len(items) - len(CONTENT_DB["basics"]["chunks"])
    for i, (th, rom, zh, note, tags) in enumerate(CONTENT_DB["basics"]["sentences"]):
        items.append({
            "id": make_id("basics", "sent", i + 1),
            "kind": "sentence",
            "category": "basics",
            "tags": tags + ["sentence"],
            "thai": th,
            "romanization": rom,
            "meaningZhHans": zh,
            "usageNote": note,
            "frequencyTier": 3,
            "audioID": make_audio_id("basics", "sent", i + 1),
            "prerequisiteIDs": [make_id("basics", "chunk", 1)],
            "relatedIDs": [],
            "example": "",
            "segments": [],
            "sourceID": "author-yaohuix",
            "contentVersion": 1,
            "stepIndex": i + 1
        })
    # Dialogues
    for i, (th, zh, note, tags) in enumerate(CONTENT_DB["basics"]["dialogues"]):
        items.append({
            "id": make_id("basics", "dial", i + 1),
            "kind": "dialogue",
            "category": "basics",
            "tags": tags + ["dialogue"],
            "thai": th,
            "romanization": "",
            "meaningZhHans": zh,
            "usageNote": note,
            "frequencyTier": 4,
            "audioID": make_audio_id("basics", "dial", i + 1),
            "prerequisiteIDs": [make_id("basics", "sent", 1)],
            "relatedIDs": [],
            "example": "",
            "segments": [],
            "sourceID": "author-yaohuix",
            "contentVersion": 1,
            "stepIndex": i + 1
        })
    return items

def generate_social() -> list:
    """Generate ~90 items for 社交与人际."""
    words = [
        ("ครอบครัว", "khrɔ̂ɔp-khrua", "家庭", "", ["family"]),
        ("พ่อ", "phɔ̂ɔ", "爸爸", "", ["family"]),
        ("แม่", "mɛ̂ɛ", "妈妈", "", ["family"]),
        ("ลูก", "lûuk", "孩子", "", ["family"]),
        ("พี่", "phîi", "哥哥/姐姐", "对同辈中年长者的亲切尊称", ["family"]),
        ("น้อง", "nɔ́ɔŋ", "弟弟/妹妹", "对同辈中年幼者的亲切称呼", ["family"]),
        ("เพื่อน", "phʉ̂ʉan", "朋友", "", ["social"]),
        ("แฟน", "fɛɛn", "男/女朋友", "", ["social"]),
        ("สามี", "sǎa-mii", "丈夫", "", ["family"]),
        ("ภรรยา", "phan-rá-yaa", "妻子", "", ["family"]),
        ("ชื่อ", "chʉ̂ʉ", "名字", "", ["identity"]),
        ("นามสกุล", "naam-sà-kun", "姓氏", "", ["identity"]),
        ("อายุ", "aa-yú", "年龄", "", ["identity"]),
        ("ประเทศ", "prà-thêet", "国家", "", ["identity"]),
        ("คน", "khon", "人", "", ["general"]),
        ("ผู้ชาย", "phûu-chaai", "男人", "", ["gender"]),
        ("ผู้หญิง", "phûu-yǐŋ", "女人", "", ["gender"]),
        ("เด็ก", "dèk", "小孩", "", ["age"]),
        ("ผู้ใหญ่", "phûu-yài", "大人", "", ["age"]),
        ("สบายดี", "sà-baai-dii", "舒服/安好", "回答问候“สบายดีไหม”（你好吗）时使用", ["greeting"]),
        ("ดีใจ", "dii-cai", "高兴", "", ["emotion"]),
        ("เสียใจ", "sǐa-cai", "伤心", "", ["emotion"]),
        ("เหนื่อย", "nʉ̀ai", "累", "", ["emotion"]),
        ("หิว", "hǐw", "饿", "", ["physical"]),
        ("ง่วง", "ŋûaŋ", "困", "", ["physical"]),
        ("สนุก", "sà-nùk", "好玩/有趣", "", ["emotion"]),
        ("สวย", "sǔai", "漂亮", "", ["description"]),
        ("หล่อ", "lɔ̀ɔ", "帅", "", ["description"]),
        ("น่ารัก", "nâa-rák", "可爱", "", ["description"]),
        ("ใจดี", "cai-dii", "好心/善良", "", ["character"]),
        ("ขี้เกียจ", "khîi-kìat", "懒", "", ["character"]),
        ("ทำงาน", "tham-ŋaan", "工作", "", ["activity"]),
        ("เรียน", "rian", "学习", "", ["activity"]),
        ("เล่น", "lên", "玩", "", ["activity"]),
        ("พัก", "phák", "休息", "", ["activity"]),
        ("เที่ยว", "thîaw", "旅游/出去玩", "", ["activity"]),
        ("ถ่ายรูป", "thàai-rûup", "拍照", "", ["activity"]),
        ("คุย", "khui", "聊天", "", ["social"]),
        ("เจอ", "cəə", "遇到/见面", "", ["social"]),
        ("ช่วย", "chûai", "帮助", "", ["social"]),
    ]
    chunks = [
        ("คุณสบายดีไหมครับ", "khun sà-baai-dii mǎi khráp", "你好吗(男)", "", ["greeting"]),
        ("สบายดีครับ แล้วคุณล่ะครับ", "sà-baai-dii khráp lɛ́ɛo khun lâ khráp", "我很好，你呢(男)", "", ["greeting"]),
        ("ยินดีที่ได้รู้จัก", "yin-dii thîi dâi rúu-càk", "很高兴认识你", "", ["social"]),
        ("คิดถึงนะ", "khít-thʉ̌ŋ ná", "想你哦", "", ["emotion"]),
        ("แล้วเจอกัน", "lɛ́ɛo cəə kan", "回头见", "", ["social"]),
        ("โชคดีนะครับ", "chôok-dii ná khráp", "祝你好运(男)", "", ["social"]),
        ("ขอให้สนุกนะ", "khɔ̌ɔ hâi sà-nùk ná", "祝你玩得开心", "", ["social"]),
        ("ขอให้หายเร็วๆ", "khɔ̌ɔ hâi hǎai reo-reo", "祝你早日康复", "", ["social"]),
        ("กินข้าวหรือยัง", "kin khâao rʉ̌ʉ yaŋ", "吃饭了吗", "泰式问候", ["greeting"]),
        ("ไปเที่ยวด้วยกันไหม", "pai thîaw dûai kan mǎi", "一起去玩吗", "", ["invitation"]),
    ]
    sentences = [
        ("คุณทำงานอะไรครับ", "khun tham-ŋaan à-rai khráp", "你做什么工作(男)", "", ["question"]),
        ("ผมเป็นครูครับ", "phǒm pen khruu khráp", "我是老师(男)", "", ["response"]),
        ("ฉันทำงานที่โรงพยาบาลค่ะ", "chǎn tham-ŋaan thîi rooŋ-phá-yaa-baan khâ", "我在医院工作(女)", "", ["info"]),
        ("ครอบครัวผมมีสี่คน", "khrɔ̂ɔp-khrua phǒm mii sìi khon", "我家有四口人", "", ["info"]),
        ("ดีใจที่ได้เจอคุณ", "dii-cai thîi dâi cəə khun", "很高兴见到你", "", ["emotion"]),
        ("วันนี้สนุกมากครับ", "wan-níi sà-nùk mâak khráp", "今天很开心(男)", "", ["emotion"]),
        ("ขอโทษที่มาสายครับ", "khɔ̌ɔ-thôot thîi maa sǎai khráp", "抱歉迟到了(男)", "", ["apology"]),
        ("คุณน่ารักมาก", "khun nâa-rák mâak", "你很可爱", "", ["compliment"]),
        ("ขอให้เดินทางปลอดภัย", "khɔ̌ɔ hâi dəən-thaaŋ plɔ̀ɔt-phai", "祝你一路平安", "", ["social"]),
        ("ฝากความคิดถึงไปถึงครอบครัวด้วยนะ", "fàak khwaam-khít-thʉ̌ŋ pai thʉ̌ŋ khrɔ̂ɔp-khrua dûai ná", "代我向家人问好", "", ["social"]),
    ]
    dialogues = [
        ("A: กินข้าวหรือยัง\nB: ยังเลย ไปกินด้วยกันไหม\nA: ได้เลยครับ", "A: 吃饭了吗\nB: 还没，一起去吃吗\nA: 好啊", "泰式问候对话", ["greeting"]),
        ("A: ขอโทษที่มาสายครับ\nB: ไม่เป็นไรค่ะ เพิ่งมาถึงเหมือนกัน", "A: 抱歉迟到了\nB: 没关系，我也刚到", "道歉应答对话", ["apology"]),
        ("A: คุณทำงานอะไรครับ\nB: เป็นครูสอนภาษาอังกฤษครับ\nA: เก่งจังเลยครับ", "A: 你做什么工作\nB: 我是英语老师\nA: 真厉害啊", "职业介绍对话", ["work"]),
    ]
    return build_category("social", words, chunks, sentences, dialogues)

def generate_numbers() -> list:
    """Generate ~110 items for 数字、时间与数量."""
    words = [
        ("ศูนย์", "sǔun", "零", "", ["number"]),
        ("หนึ่ง", "nʉ̀ŋ", "一", "", ["number"]),
        ("สอง", "sɔ̌ɔŋ", "二", "", ["number"]),
        ("สาม", "sǎam", "三", "", ["number"]),
        ("สี่", "sìi", "四", "", ["number"]),
        ("ห้า", "hâa", "五", "", ["number"]),
        ("หก", "hòk", "六", "", ["number"]),
        ("เจ็ด", "cèt", "七", "", ["number"]),
        ("แปด", "pɛ̀ɛt", "八", "", ["number"]),
        ("เก้า", "kâo", "九", "", ["number"]),
        ("สิบ", "sìp", "十", "", ["number"]),
        ("ร้อย", "rɔ́ɔi", "百", "", ["number"]),
        ("พัน", "phan", "千", "", ["number"]),
        ("หมื่น", "mʉ̀ʉn", "万", "", ["number"]),
        ("แสน", "sɛ̌ɛn", "十万", "", ["number"]),
        ("ล้าน", "láan", "百万", "", ["number"]),
        ("วัน", "wan", "天/日", "", ["time"]),
        ("เดือน", "dʉan", "月", "", ["time"]),
        ("ปี", "pii", "年", "", ["time"]),
        ("วันนี้", "wan-níi", "今天", "", ["time"]),
        ("พรุ่งนี้", "phrûŋ-níi", "明天", "", ["time"]),
        ("เมื่อวาน", "mʉ̂ʉa-waan", "昨天", "", ["time"]),
        ("มะรืนนี้", "má-rʉʉn-níi", "后天", "", ["time"]),
        ("เช้า", "cháo", "早上", "", ["time"]),
        ("กลางวัน", "klaaŋ-wan", "白天/中午", "", ["time"]),
        ("เย็น", "yen", "傍晚", "", ["time"]),
        ("กลางคืน", "klaaŋ-khʉʉn", "晚上/夜里", "", ["time"]),
        ("ชั่วโมง", "chûa-mooŋ", "小时", "", ["time"]),
        ("นาที", "naa-thii", "分钟", "", ["time"]),
        ("ตอนนี้", "tɔɔn-níi", "现在", "", ["time"]),
        ("เมื่อไหร่", "mʉ̂ʉa-rài", "什么时候", "", ["question"]),
        ("กี่โมง", "kìi-mooŋ", "几点", "", ["question"]),
        ("ราคา", "raa-khaa", "价格", "", ["money"]),
        ("บาท", "bàat", "铢(货币)", "", ["money"]),
        ("สตางค์", "sà-taaŋ", "分(货币)", "", ["money"]),
        ("ฟรี", "frii", "免费", "", ["money"]),
        ("จ่าย", "càai", "付钱", "", ["money"]),
        ("เงิน", "ŋən", "钱", "", ["money"]),
        ("ราคาเท่าไหร่", "raa-khaa thâo-rài", "多少钱", "", ["question"]),
        ("แพง", "phɛɛŋ", "贵", "", ["money"]),
    ]
    chunks = [
        ("สิบเอ็ด", "sìp-èt", "十一", "", ["number"]),
        ("ยี่สิบ", "yîi-sìp", "二十", "", ["number"]),
        ("หนึ่งร้อย", "nʉ̀ŋ-rɔ́ɔi", "一百", "", ["number"]),
        ("สองร้อย", "sɔ̌ɔŋ-rɔ́ɔi", "二百", "", ["number"]),
        ("ครึ่งชั่วโมง", "khrʉ̂ŋ chûa-mooŋ", "半小时", "", ["time"]),
        ("อีกเดี๋ยว", "ìik dǐao", "一会儿/马上", "", ["time"]),
        ("ทุกวัน", "thúk-wan", "每天", "", ["time"]),
        ("อาทิตย์หน้า", "aa-thít nâa", "下周", "", ["time"]),
        ("เดือนหน้า", "dʉan nâa", "下个月", "", ["time"]),
        ("ปีหน้า", "pii nâa", "明年", "", ["time"]),
        ("กี่บาท", "kìi bàat", "多少铢", "", ["question"]),
        ("แพงเกินไป", "phɛɛŋ kəən-pai", "太贵了", "", ["money"]),
        ("ลดราคา", "lót raa-khaa", "降价", "", ["money"]),
        ("ส่วนลด", "sùan-lót", "折扣", "", ["money"]),
        ("เก็บเงิน", "kèp ŋən", "收钱/存钱", "", ["money"]),
    ]
    sentences = [
        ("วันนี้วันที่เท่าไหร่", "wan-níi wan-thîi thâo-rài", "今天几号", "", ["question"]),
        ("ตอนนี้กี่โมงแล้ว", "tɔɔn-níi kìi-mooŋ lɛ́ɛo", "现在几点了", "", ["question"]),
        ("อีกกี่นาทีถึงจะถึง", "ìik kìi naa-thii thʉ̌ŋ cà thʉ̌ŋ", "还有几分钟到", "", ["question"]),
        ("ราคาเท่าไหร่ครับ", "raa-khaa thâo-rài khráp", "多少钱(男)", "", ["question"]),
        ("ขอคิดเงินหน่อยครับ", "khɔ̌ɔ khít ŋən nɔ̀i khráp", "请结账(男)", "", ["request"]),
        ("อันนี้ราคาเท่าไหร่", "an-níi raa-khaa thâo-rài", "这个多少钱", "", ["question"]),
        ("ลดได้ไหมครับ", "lót dâi mǎi khráp", "能便宜点吗(男)", "", ["question"]),
        ("ขอใบเสร็จด้วยครับ", "khɔ̌ɔ bai-sèt dûai khráp", "请给我收据(男)", "", ["request"]),
        ("มีทอนไหมครับ", "mii thɔɔn mǎi khráp", "有零钱找吗(男)", "", ["question"]),
        ("ขอคิดเป็นเงินไทยบาทนะครับ", "khɔ̌ɔ khít pen ŋən thai bàat ná khráp", "请用泰铢结算(男)", "", ["request"]),
    ]
    return build_category("numbers", words, chunks, sentences, [])

EXTRA_FOOD_DINING_WORDS = [
    ("มะม่วง", "má-mûang", "芒果", ["fruit"]),
    ("ทุเรียน", "thú-rian", "榴莲", ["fruit"]),
    ("มังคุด", "mang-khút", "山竹", ["fruit"]),
    ("เงาะ", "ngó", "红毛丹", ["fruit"]),
    ("มะพร้าว", "má-phráao", "椰子", ["fruit"]),
    ("แตงโม", "taeng-mo", "西瓜", ["fruit"]),
    ("สับปะรด", "sàp-pà-rót", "菠萝", ["fruit"]),
    ("ลำไย", "lam-yai", "龙眼", ["fruit"]),
    ("กล้วย", "glûai", "香蕉", ["fruit"]),
    ("ส้ม", "sôm", "橙子／橘子", ["fruit"]),
    ("ชาไทย", "chaa-thai", "泰奶／泰式奶茶", ["drink"]),
    ("น้ำมะพร้าว", "náam-má-phráao", "椰子水", ["drink"]),
    ("น้ำอัดลม", "náam-àt-lom", "汽水", ["drink"]),
    ("นมเย็น", "nom-yen", "泰式粉红奶", ["drink"]),
    ("โกโก้", "koo-gôo", "可可", ["drink"]),
    ("น้ำชา", "náam-chaa", "茶水", ["drink"]),
    ("ข้าวเหนียวมะม่วง", "khâao-nǐao-má-mûang", "芒果糯米饭", ["dessert"]),
    ("ต้มข่าไก่", "tôm-khàa-kài", "椰奶鸡汤", ["dish"]),
]

FOOD_DINING_BASE_FOOD_WORD_IDS = [
    "food_dining-word-001", "food_dining-word-003", "food_dining-word-005",
    "food_dining-word-006", "food_dining-word-007", "food_dining-word-008",
    "food_dining-word-009", "food_dining-word-010",
]
FOOD_DINING_FRUIT_WORD_IDS = [
    "food_dining-word-004",
    "food_dining-word-060", "food_dining-word-061", "food_dining-word-062",
    "food_dining-word-063", "food_dining-word-064", "food_dining-word-065",
    "food_dining-word-066", "food_dining-word-067", "food_dining-word-068",
    "food_dining-word-069",
]
FOOD_DINING_DRINK_WORD_IDS = [
    "food_dining-word-002", "food_dining-word-030", "food_dining-word-031",
    "food_dining-word-032", "food_dining-word-033", "food_dining-word-034",
    "food_dining-word-035", "food_dining-word-070", "food_dining-word-071",
    "food_dining-word-072", "food_dining-word-073", "food_dining-word-074",
    "food_dining-word-075",
]

def reorder_food_dining_items(items: list[dict]) -> list[dict]:
    food_items = [item for item in items if item["category"] == "food_dining"]
    food_by_id = {item["id"]: item for item in food_items}
    section_ids = (
        FOOD_DINING_BASE_FOOD_WORD_IDS
        + FOOD_DINING_FRUIT_WORD_IDS
        + FOOD_DINING_DRINK_WORD_IDS
    )
    missing_ids = [item_id for item_id in section_ids if item_id not in food_by_id]
    if missing_ids:
        raise ValueError(f"food-dining ordering IDs are missing: {missing_ids}")
    section_id_set = set(section_ids)
    ordered_food = [food_by_id[item_id] for item_id in section_ids]
    ordered_food.extend(item for item in food_items if item["id"] not in section_id_set)
    first_food_index = next(
        index for index, item in enumerate(items) if item["category"] == "food_dining"
    )
    non_food_items = [item for item in items if item["category"] != "food_dining"]
    return non_food_items[:first_food_index] + ordered_food + non_food_items[first_food_index:]

def append_extra_food_dining_words(items: list[dict]) -> list[dict]:
    existing = {item["thai"] for item in items}
    next_index = max(int(item["id"].rsplit("-", 1)[-1]) for item in items if item["id"].startswith("food_dining-word-")) + 1
    for offset, (thai, romanization, meaning, tags) in enumerate(EXTRA_FOOD_DINING_WORDS):
        if thai in existing:
            continue
        index = next_index + offset
        items.append({
            "id": f"food_dining-word-{index:03d}",
            "kind": "word",
            "category": "food_dining",
            "tags": ["food_dining"] + tags,
            "thai": thai,
            "romanization": romanization,
            "meaningZhHans": meaning,
            "usageNote": "",
            "frequencyTier": 1,
            "audioID": f"audio-food_dining-word-{index:03d}",
            "prerequisiteIDs": [],
            "relatedIDs": [],
            "example": "",
            "segments": [],
            "sourceID": "author-yaohuix",
            "contentVersion": 1,
        })
    return reorder_food_dining_items(items)

GOOGLE_MAPS_WORDS = [
    # 道路与路口 (Roads & Intersections)
    ("ถนน", "thà-nǒn", "道路/大街", ["road", "map"], "地图最常见道路前缀，常简写为 ถ."),
    ("ซอย", "sɔɔi", "巷/弄", ["road", "map"], "主干道分支出的巷弄，常简写为 ซ."),
    ("แยก", "yɛ̂ɛk", "交叉路口/路口", ["intersection", "map"], "指道路交叉口，地名中极常见"),
    ("สี่แยก", "sìi-yɛ̂ɛk", "十字路口", ["intersection", "map"], "四条道路交汇的十字路口"),
    ("สามแยก", "sǎam-yɛ̂ɛk", "三岔路口/T字路口", ["intersection", "map"], "三条道路交汇或丁字路口"),
    ("ทางแยก", "thaaŋ-yɛ̂ɛk", "岔路/分岔口", ["intersection", "map"], "道路分流或岔道口"),
    ("วงเวียน", "woŋ-wian", "环岛/转盘", ["intersection", "map"], "环状交叉路口（如วงเวียนใหญ่大罗斗圈）"),
    ("ตรอก", "trɔ̀ɔk", "窄巷/小弄", ["road", "map"], "比ซอย更窄的小巷弄"),
    ("ทางด่วน", "thaaŋ-dùan", "高速公路", ["road", "map"], "城市快速路或城际收费高速"),
    ("ทางคู่ขนาน", "thaaŋ-khûu-khà-nǎan", "辅道/侧道", ["road", "map"], "主干道两侧并行辅道"),
    ("ทางออก", "thaaŋ-ɔ̀ɔk", "出口", ["direction", "map"], "高速匝道、停车场或设施出口（Exit）"),
    ("ทางเข้า", "thaaŋ-khâo", "入口", ["direction", "map"], "设施或通道入口（Entrance）"),
    ("สะพาน", "sà-phaan", "桥", ["landmark", "map"], "桥梁，常出现在跨河或立交地名中"),
    ("สะพานลอย", "sà-phaan-lɔɔi", "人行天桥/立交桥", ["landmark", "map"], "过街人行天桥或高架桥"),
    ("จุดกลับรถ", "cùt-klàp-rót", "掉头点/调头处", ["direction", "map"], "道路掉头开口（U-turn）"),
    ("ทางตัน", "thaaŋ-tan", "死胡同/尽头路", ["road", "map"], "巷弄尽头不通（Dead End）"),

    # 地图常见地点与地标 (Map Landmarks & Places)
    ("วัด", "wát", "寺庙", ["landmark", "map"], "泰国最常见地标（如 วัดพระแก้ว 玉佛寺）"),
    ("ตลาด", "tà-làat", "市场/菜市", ["landmark", "place"], "传统集市或生鲜市场"),
    ("ตลาดนัด", "tà-làat-nát", "市集/夜市", ["landmark", "place"], "定期露天市集、周末夜市"),
    ("ตลาดน้ำ", "tà-làat-náam", "水上市场", ["landmark", "place"], "特色水上集市（Floating Market）"),
    ("ห้าง", "hâaŋ", "商场/百货", ["place", "shopping"], "大型购物中心、百货商场口语简称"),
    ("ซูเปอร์มาร์เก็ต", "suu-pə̂ə-maa-kèt", "超市", ["place", "shopping"], "大型超级市场（Supermarket）"),
    ("ร้านสะดวกซื้อ", "ráan-sà-dùak-sʉ́ʉ", "便利店", ["place", "shopping"], "如 7-Eleven 等便利店"),
    ("ร้านขายยา", "ráan-khǎai-yaa", "药店/药房", ["facility", "map"], "药店标识（Pharmacy）"),
    ("ร้านอาหาร", "ráan-aa-hǎan", "餐厅/饭馆", ["place", "food"], "各类正餐餐馆"),
    ("ร้านกาแฟ", "ráan-kaa-fɛɛ", "咖啡店", ["place", "food"], "咖啡饮品店（Cafe）"),
    ("ร้านนวด", "ráan-nûat", "按摩店", ["place", "leisure"], "泰式按摩与水疗店（Massage）"),
    ("โรงแรม", "rooŋ-rɛɛm", "酒店/宾馆", ["place", "lodging"], "标准酒店或星级饭店"),
    ("ที่พัก", "thîi-phák", "住宿/民宿", ["place", "lodging"], "青旅、客栈或度假住宿点"),
    ("ปั๊มน้ำมัน", "pám-nám-man", "加油站", ["facility", "map"], "汽车加油站服务区"),
    ("สถานี", "sà-thǎa-nii", "车站/站", ["transit", "map"], "轨道交通BTS/MRT站点"),
    ("สถานีรถไฟ", "sà-thǎa-nii rót-fai", "火车站", ["transit", "map"], "城际铁路线火车站"),
    ("สถานีขนส่ง", "sà-thǎa-nii khǒn-sòŋ", "长途客运站", ["transit", "map"], "长途大巴汽车总站"),
    ("ท่าเรือ", "thâa-rʉa", "码头/客运码头", ["transit", "map"], "公交船或渡轮客船码头（Pier）"),
    ("ป้ายรถเมล์", "pâai-rót-mee", "公交车站", ["transit", "map"], "路边公交停靠站（Bus stop）"),
    ("จุดชมวิว", "cùt-chom-wiu", "观景点/观景台", ["attraction", "map"], "自然风景观景台（Viewpoint）"),
    ("สวนสาธารณะ", "sǔan-sǎa-thaa-rá-ná", "公园", ["place", "leisure"], "城市公共绿地公园"),
    ("ชายหาด", "chaai-hàat", "海滩/沙滩", ["attraction", "map"], "海滨沙滩景点（Beach）"),
    ("โรงพยาบาล", "rooŋ-phá-yaa-baan", "医院", ["facility", "medical"], "综合医院，常简写为 รพ."),
    ("สถานทูต", "sà-thǎan-thûut", "大使馆", ["facility", "map"], "领事机构与外国使馆（Embassy）"),
    ("อาคาร", "aa-khaan", "大厦/大楼", ["landmark", "map"], "写字楼或商业大厦名称"),
    ("ที่จอดรถ", "thîi-cɔ̀ɔt-rót", "停车场", ["facility", "map"], "停车专用场所（Parking）"),

    # 地图状态与导航词汇 (Map Navigation & Business Status)
    ("เปิดอยู่", "pə̀ət-yùu", "营业中", ["status", "map"], "商家当前处于营业状态（Open）"),
    ("ปิดอยู่", "pìt-yùu", "已打烊/歇业", ["status", "map"], "商家当前处于歇业状态（Closed）"),
    ("เปิด 24 ชั่วโมง", "pə̀ət yîi-sìp-sìi chûa-mooŋ", "24小时营业", ["status", "map"], "全天不打烊（Open 24 hours）"),
    ("แผนที่", "phɛ̌ɛn-thîi", "地图", ["tool", "map"], "地图应用及图纸"),
    ("ค้นหา", "khón-hǎa", "搜索/查找", ["action", "map"], "地图搜索与查找功能"),
    ("เส้นทาง", "sên-thaaŋ", "路线/导航路线", ["navigation", "map"], "路线规划（Directions / Route）"),
    ("ตำแหน่งปัจจุบัน", "tam-nɛ̀ɛŋ pàt-cù-ban", "当前位置", ["navigation", "map"], "实时定位（Current location）"),
    ("จุดหมาย", "cùt-mǎai", "目的地", ["navigation", "map"], "导航终点（Destination）"),
]

# High-frequency Bangkok destinations. Proper names stay intact unless the
# written form contains a useful, independently meaningful place-word layer.
GOOGLE_MAPS_LANDMARK_IDS = {f"google_maps-word-{index:03d}" for index in range(51, 63)}

GOOGLE_MAPS_LANDMARKS = [
    {
        "thai": "สุขุมวิท",
        "romanization": "sù-khǔm-wít",
        "meaning": "素坤逸（Sukhumvit）",
        "tags": ["landmark", "bangkok", "place_name"],
        "usage_note": "曼谷热门商圈与主干道，地图中常见 Sukhumvit 路及其周边地点。",
        "segments": [],
    },
    {
        "thai": "สยาม",
        "romanization": "sà-yǎam",
        "meaning": "暹罗（Siam）",
        "tags": ["landmark", "bangkok", "shopping", "place_name"],
        "usage_note": "曼谷市中心热门商圈，常指 Siam BTS 站及周边商场。",
        "segments": [],
    },
    {
        "thai": "พระบรมมหาราชวัง",
        "romanization": "phrá-bɔɔ-rom-ma-maa-hǎa-râat-cha-waŋ",
        "meaning": "大皇宫（Grand Palace）",
        "tags": ["landmark", "bangkok", "attraction", "place_name"],
        "usage_note": "曼谷最重要的历史景点之一；地图搜索时使用完整地名。",
        "segments": [],
    },
    {
        "thai": "วัดพระแก้ว",
        "romanization": "wát-phrá-kɛ̂ɛo",
        "meaning": "玉佛寺（Temple of the Emerald Buddha）",
        "tags": ["landmark", "bangkok", "temple", "place_name"],
        "usage_note": "位于大皇宫范围内的著名寺庙；วัด 是寺庙，พระแก้ว 是玉佛。",
        "segments": [
            {"thai": "วัด", "gloss": "寺庙"},
            {"thai": "พระแก้ว", "gloss": "玉佛"},
        ],
    },
    {
        "thai": "วัดอรุณ",
        "romanization": "wát-a-run",
        "meaning": "郑王庙/黎明寺（Wat Arun）",
        "tags": ["landmark", "bangkok", "temple", "place_name"],
        "usage_note": "湄南河沿岸地标；วัด 是寺庙，อรุณ 是黎明。",
        "segments": [
            {"thai": "วัด", "gloss": "寺庙"},
            {"thai": "อรุณ", "gloss": "黎明"},
        ],
    },
    {
        "thai": "วัดโพธิ์",
        "romanization": "wát-phôo",
        "meaning": "卧佛寺（Wat Pho）",
        "tags": ["landmark", "bangkok", "temple", "place_name"],
        "usage_note": "大皇宫附近的著名寺庙；วัด 是寺庙，โพธิ์ 是菩提树。",
        "segments": [
            {"thai": "วัด", "gloss": "寺庙"},
            {"thai": "โพธิ์", "gloss": "菩提树"},
        ],
    },
    {
        "thai": "ถนนข้าวสาร",
        "romanization": "thà-nǒn-khâao-sǎan",
        "meaning": "考山路（Khao San Road）",
        "tags": ["landmark", "bangkok", "road", "place_name"],
        "usage_note": "背包客热门街区；ถนน 是道路，ข้าวสาร 是大米。",
        "segments": [
            {"thai": "ถนน", "gloss": "道路"},
            {"thai": "ข้าวสาร", "gloss": "大米"},
        ],
    },
    {
        "thai": "ตลาดนัดจตุจักร",
        "romanization": "tà-làat-nát-jà-tù-jàk",
        "meaning": "乍都乍周末市场（Chatuchak Weekend Market）",
        "tags": ["landmark", "bangkok", "market", "place_name"],
        "usage_note": "曼谷著名周末市场；ตลาดนัด 是市集，จตุจักร 是乍都乍专名。",
        "segments": [
            {"thai": "ตลาดนัด", "gloss": "市集"},
            {"thai": "จตุจักร", "gloss": "乍都乍"},
        ],
    },
    {
        "thai": "เยาวราช",
        "romanization": "yao-wá-râat",
        "meaning": "耀华力路/曼谷唐人街（Yaowarat）",
        "tags": ["landmark", "bangkok", "food", "place_name"],
        "usage_note": "曼谷唐人街及其美食街区的常用地名。",
        "segments": [],
    },
    {
        "thai": "ไอคอนสยาม",
        "romanization": "ai-khon-sà-yǎam",
        "meaning": "ICONSIAM 商场",
        "tags": ["landmark", "bangkok", "shopping", "place_name"],
        "usage_note": "湄南河沿岸热门大型商场；ไอคอน 是 Icon 的音译，สยาม 是暹罗。",
        "segments": [
            {"thai": "ไอคอน", "gloss": "Icon（标志/品牌名）"},
            {"thai": "สยาม", "gloss": "暹罗"},
        ],
    },
    {
        "thai": "สนามหลวง",
        "romanization": "sà-nǎam-lǔang",
        "meaning": "皇家田广场（Sanam Luang）",
        "tags": ["landmark", "bangkok", "attraction", "place_name"],
        "usage_note": "大皇宫前的历史广场；สนาม 是场地，หลวง 是王室/皇家。",
        "segments": [
            {"thai": "สนาม", "gloss": "场地"},
            {"thai": "หลวง", "gloss": "皇家"},
        ],
    },
    {
        "thai": "ศาลท้าวมหาพรหม",
        "romanization": "sǎan-tháao-má-haa-phrom",
        "meaning": "四面佛/爱侣湾神坛（Erawan Shrine）",
        "tags": ["landmark", "bangkok", "temple", "place_name"],
        "usage_note": "曼谷市中心著名的四面佛神坛；ศาล 是神坛，ท้าวมหาพรหม 是大梵天神。",
        "segments": [
            {"thai": "ศาล", "gloss": "神坛"},
            {"thai": "ท้าวมหาพรหม", "gloss": "大梵天神"},
        ],
    },
]

def append_google_maps_words(items: list[dict]) -> list[dict]:
    records = [
        {
            "thai": thai,
            "romanization": romanization,
            "meaning": meaning,
            "tags": tags,
            "usage_note": usage_note,
            "segments": [],
        }
        for thai, romanization, meaning, tags, usage_note in GOOGLE_MAPS_WORDS
    ] + GOOGLE_MAPS_LANDMARKS

    for offset, record in enumerate(records, start=1):
        item = {
            "id": f"google_maps-word-{offset:03d}",
            "kind": "word",
            "category": "google_maps",
            "tags": ["google_maps"] + record["tags"],
            "thai": record["thai"],
            "romanization": record["romanization"],
            "meaningZhHans": record["meaning"],
            "usageNote": record["usage_note"],
            "frequencyTier": 1,
            "audioID": f"audio-google_maps-word-{offset:03d}",
            "prerequisiteIDs": [],
            "relatedIDs": [],
            "example": "",
            "segments": record["segments"],
            "sourceID": "author-yaohuix",
            "contentVersion": 1,
            "stepIndex": offset,
        }
        items.append(item)
    return items

def load_core_function_words(path: Path = CORE_FUNCTION_PATH) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def append_core_function_words(items: list[dict]) -> list[dict]:
    source = load_core_function_words()
    records = source.get("items")
    if (
        source.get("schemaVersion") != 1
        or source.get("locale") != "zh-Hans"
        or not isinstance(records, list)
        or source.get("recordCount") != len(records)
    ):
        raise ValueError("invalid core function word source metadata")

    seen = set()
    for offset, record in enumerate(records, start=1):
        thai = record["thai"]
        if thai in seen:
            raise ValueError(f"duplicate core function headword: {thai}")
        seen.add(thai)
        example = record.get("example") or ""
        item = {
            "id": f"core_function-word-{offset:03d}",
            "kind": "word",
            "category": "core_function",
            "tags": list(record.get("tags") or ["core_function"]),
            "thai": thai,
            "romanization": record["romanization"],
            "meaningZhHans": record["meaningZhHans"],
            "usageNote": record.get("usageNote") or "",
            "frequencyTier": 1,
            "audioID": f"audio-core_function-word-{offset:03d}",
            "prerequisiteIDs": [],
            "relatedIDs": [],
            "example": example,
            "segments": list(record.get("segments") or []),
            "sourceID": "author-yaohuix",
            "contentVersion": 1,
            "stepIndex": offset,
        }
        if str(example).strip():
            item["exampleMeaning"] = record["exampleMeaning"]
        items.append(item)
    return items

def generate_food_dining() -> list:
    """Generate ~130 items for 饮食与点餐."""
    words = [
        ("ข้าว", "khâao", "饭/米饭", "", ["food"]),
        ("น้ำ", "náam", "水", "", ["drink"]),
        ("ผัก", "phàk", "蔬菜", "", ["food"]),
        ("ผลไม้", "phǒn-lá-mái", "水果", "", ["food"]),
        ("เนื้อ", "nʉ́ʉa", "肉", "", ["food"]),
        ("หมู", "mǔu", "猪肉", "", ["food"]),
        ("ไก่", "kài", "鸡肉", "", ["food"]),
        ("ปลา", "plaa", "鱼", "", ["food"]),
        ("กุ้ง", "kûŋ", "虾", "", ["food"]),
        ("ไข่", "khài", "蛋", "", ["food"]),
        ("เผ็ด", "phèt", "辣", "", ["taste"]),
        ("หวาน", "wǎan", "甜", "", ["taste"]),
        ("เปรี้ยว", "prîao", "酸", "", ["taste"]),
        ("เค็ม", "khem", "咸", "", ["taste"]),
        ("ขม", "khǒm", "苦", "", ["taste"]),
        ("จืด", "cʉ̀ʉt", "淡", "", ["taste"]),
        ("อร่อย", "à-rɔ̀i", "好吃", "", ["taste"]),
        ("ไม่อร่อย", "mâi-à-rɔ̀i", "不好吃", "", ["taste"]),
        ("ร้านอาหาร", "ráan-aa-hǎan", "餐厅", "", ["place"]),
        ("เมนู", "mee-nuu", "菜单", "", ["dining"]),
        ("สั่ง", "sàŋ", "点(菜)", "", ["dining"]),
        ("จาน", "caan", "盘子", "", ["utensil"]),
        ("ช้อน", "chɔ́ɔn", "勺子", "", ["utensil"]),
        ("ส้อม", "sɔ̂ɔm", "叉子", "", ["utensil"]),
        ("ตะเกียบ", "tà-kìap", "筷子", "", ["utensil"]),
        ("แก้ว", "kɛ̂ɛo", "杯子", "", ["utensil"]),
        ("ขวด", "khùat", "瓶子", "", ["container"]),
        ("มังสวิรัติ", "maŋ-sà-wí-rát", "素食", "", ["diet"]),
        ("เจ", "cee", "斋/纯素", "", ["diet"]),
        ("น้ำแข็ง", "nám-khɛ̌ŋ", "冰", "", ["drink"]),
        ("น้ำเปล่า", "nám-plàao", "白水/纯水", "", ["drink"]),
        ("ชา", "chaa", "茶", "", ["drink"]),
        ("กาแฟ", "kaa-fɛɛ", "咖啡", "", ["drink"]),
        ("เบียร์", "bia", "啤酒", "", ["drink"]),
        ("น้ำผลไม้", "nám-phǒn-lá-mái", "果汁", "", ["drink"]),
        ("น้ำตาล", "nám-taan", "糖", "", ["condiment"]),
        ("เกลือ", "klʉa", "盐", "", ["condiment"]),
        ("พริก", "phrík", "辣椒", "", ["condiment"]),
        ("น้ำปลา", "nám-plaa", "鱼露", "", ["condiment"]),
        ("ซอส", "sɔ́ɔt", "酱汁", "", ["condiment"]),
        ("ผัด", "phàt", "炒", "", ["cooking"]),
        ("ทอด", "thɔ̂ɔt", "炸", "", ["cooking"]),
        ("ต้ม", "tôm", "煮", "", ["cooking"]),
        ("ย่าง", "yâaŋ", "烤", "", ["cooking"]),
        ("นึ่ง", "nʉ̂ŋ", "蒸", "", ["cooking"]),
        ("ปิ้ง", "pîŋ", "烧烤", "", ["cooking"]),
        ("ส้มตำ", "sôm-tam", "青木瓜沙拉", "", ["dish"]),
        ("ต้มยำกุ้ง", "tôm-yam-kûŋ", "冬阴功虾汤", "", ["dish"]),
        ("ผัดไทย", "phàt-thai", "泰式炒面", "", ["dish"]),
        ("ข้าวผัด", "khâao-phàt", "炒饭", "", ["dish"]),
        ("แกงเขียวหวาน", "kɛɛŋ-khǐao-wǎan", "绿咖喱", "", ["dish"]),
        ("ผัดกะเพรา", "phàt-kà-phrao", "打抛/九层塔炒肉", "", ["dish"]),
        ("สุกี้", "sù-kîi", "泰式火锅", "", ["dish"]),
        ("ของหวาน", "khɔ̌ɔŋ-wǎan", "甜点", "", ["food"]),
        ("ไอศกรีม", "ai-sà-kriim", "冰淇淋", "", ["food"]),
        ("น้ำจิ้ม", "nám-cîm", "蘸酱", "", ["condiment"]),
        ("มะนาว", "má-naao", "青柠", "", ["food"]),
        ("ไม่ใส่ผงชูรส", "mâi sài phǒŋ-chuu-rót", "不加味精", "", ["diet"]),
        ("ขอโทษ", "khɔ̌ɔ-thôot", "对不起", "", ["dining"]),
    ]
    chunks = [
        ("เอาเมนูหน่อยครับ", "ao mee-nuu nɔ̀i khráp", "请给我菜单(男)", "", ["dining"]),
        ("สั่งอาหารหน่อยครับ", "sàŋ aa-hǎan nɔ̀i khráp", "请点餐(男)", "", ["dining"]),
        ("คิดเงินด้วยครับ", "khít ŋən dûai khráp", "请结账(男)", "", ["dining"]),
        ("เอากลับบ้าน", "ao klàp bâan", "打包带走", "", ["dining"]),
        ("กินที่นี่", "kin thîi-nîi", "在这里吃", "", ["dining"]),
        ("ไม่เอาผัก", "mâi ao phàk", "不要蔬菜", "", ["diet"]),
        ("ไม่เผ็ด", "mâi phèt", "不辣", "", ["taste"]),
        ("เผ็ดน้อย", "phèt nɔ́ɔi", "微辣", "", ["taste"]),
        ("เผ็ดมาก", "phèt mâak", "很辣", "", ["taste"]),
        ("เอาใหญ่", "ao yài", "要大份", "", ["dining"]),
        ("เอาเล็ก", "ao lék", "要小份", "", ["dining"]),
        ("ขอน้ำเปล่าครับ", "khɔ̌ɔ nám-plàao khráp", "请给我白水(男)", "", ["drink"]),
        ("น้ำแข็งด้วยครับ", "nám-khɛ̌ŋ dûai khráp", "还要冰(男)", "", ["drink"]),
        ("ขอช้อนส้อมด้วย", "khɔ̌ɔ chɔ́ɔn sɔ̂ɔm dûai", "请给我刀叉", "", ["dining"]),
        ("ขอตะเกียบด้วย", "khɔ̌ɔ tà-kìap dûai", "请给我筷子", "", ["dining"]),
        ("ขอถุงด้วยครับ", "khɔ̌ɔ thǔŋ dûai khráp", "请给我袋子(男)", "", ["dining"]),
        ("กินเผ็ดได้ไหม", "kin phèt dâi mǎi", "能吃辣吗", "", ["question"]),
        ("อาหารทะเล", "aa-hǎan-thá-lee", "海鲜", "", ["food"]),
        ("มื้อเช้า", "mʉ́ʉ-cháo", "早餐", "", ["meal"]),
        ("มื้อกลางวัน", "mʉ́ʉ-klaaŋ-wan", "午餐", "", ["meal"]),
    ]
    sentences = [
        ("ขอเมนูหน่อยครับ", "khɔ̌ɔ mee-nuu nɔ̀i khráp", "请给我看菜单(男)", "", ["dining"]),
        ("ขอสั่งอาหารหน่อยครับ", "khɔ̌ɔ sàŋ aa-hǎan nɔ̀i khráp", "我要点餐(男)", "", ["dining"]),
        ("เอาอันนี้กับอันนี้ครับ", "ao an-níi kàp an-níi khráp", "要这个和这个(男)", "", ["dining"]),
        ("ไม่เอาเผ็ดนะครับ", "mâi ao phèt ná khráp", "请不要放辣(男)", "", ["diet"]),
        ("ขอน้ำเปล่าหนึ่งขวดครับ", "khɔ̌ɔ nám-plàao nʉ̀ŋ khùat khráp", "请给我一瓶白水(男)", "", ["drink"]),
        ("อันนี้คืออะไรครับ", "an-níi khʉʉ à-rai khráp", "这是什么(男)", "", ["question"]),
        ("อันนี้เผ็ดไหมครับ", "an-níi phèt mǎi khráp", "这个辣吗(男)", "", ["question"]),
        ("อร่อยมากครับ", "à-rɔ̀i mâak khráp", "很好吃(男)", "", ["compliment"]),
        ("กินไม่หมดครับ", "kin mâi mòt khráp", "吃不完(男)", "", ["dining"]),
        ("ขอห่อกลับบ้านครับ", "khɔ̌ɔ hɔ̀ɔ klàp bâan khráp", "请打包(男)", "", ["dining"]),
        ("เก็บตังค์ด้วยครับ", "kèp taŋ dûai khráp", "请收钱/结账(男)", "", ["dining"]),
        ("คิดเงินกี่บาทครับ", "khít ŋən kìi bàat khráp", "多少钱(男)", "", ["dining"]),
        ("ขอใบเสร็จด้วยครับ", "khɔ̌ɔ bai-sèt dûai khráp", "请给我收据(男)", "", ["dining"]),
        ("มีที่ว่างไหมครับ", "mii thîi wâaŋ mǎi khráp", "有空位吗(男)", "", ["dining"]),
        ("จองไว้แล้วครับ", "cɔɔŋ wái lɛ́ɛo khráp", "已经预订了(男)", "", ["dining"]),
    ]
    dialogues = [
        ("A: กี่คนครับ\nB: สองคนครับ\nA: เชิญทางนี้ครับ", "A: 几位\nB: 两位\nA: 这边请", "入座对话", ["dining"]),
        ("A: รับอะไรดีครับ\nB: เอาผัดไทยกับน้ำเปล่าครับ\nA: เผ็ดไหมครับ\nB: ไม่เผ็ดครับ", "A: 来点什么\nB: 要泰式炒面和白水\nA: 辣吗\nB: 不辣", "点餐对话", ["dining"]),
        ("A: คิดเงินครับ\nB: ทั้งหมดสองร้อยบาทครับ\nA: นี่ครับ ไม่ต้องทอนครับ", "A: 结账\nB: 一共两百铢\nA: 给你，不用找了", "结账对话", ["dining"]),
    ]
    return build_category("food_dining", words, chunks, sentences, dialogues)

def generate_shopping() -> list:
    """Generate ~80 items for 购物与付款."""
    words = [
        ("ซื้อ", "sʉ́ʉ", "买", "", ["action"]),
        ("ขาย", "khǎai", "卖", "", ["action"]),
        ("ของ", "khɔ̌ɔŋ", "东西/物品", "", ["general"]),
        ("เสื้อ", "sʉ̂ʉa", "衣服/上衣", "", ["clothing"]),
        ("กางเกง", "kaaŋ-keeŋ", "裤子", "", ["clothing"]),
        ("กระโปรง", "krà-prooŋ", "裙子", "", ["clothing"]),
        ("รองเท้า", "rɔɔŋ-tháo", "鞋子", "", ["clothing"]),
        ("ถุงเท้า", "thǔŋ-tháo", "袜子", "", ["clothing"]),
        ("หมวก", "mùak", "帽子", "", ["clothing"]),
        ("กระเป๋า", "krà-pǎo", "包/袋子", "", ["accessory"]),
        ("แว่นตา", "wɛ̂n-taa", "眼镜", "", ["accessory"]),
        ("นาฬิกา", "naa-lí-kaa", "手表", "", ["accessory"]),
        ("สี", "sǐi", "颜色", "", ["attribute"]),
        ("สีแดง", "sǐi-dɛɛŋ", "红色", "", ["color"]),
        ("สีเขียว", "sǐi-khǐao", "绿色", "", ["color"]),
        ("สีฟ้า", "sǐi-fáa", "蓝色", "", ["color"]),
        ("สีขาว", "sǐi-khǎao", "白色", "", ["color"]),
        ("สีดำ", "sǐi-dam", "黑色", "", ["color"]),
        ("สีเหลือง", "sǐi-lʉ̌aŋ", "黄色", "", ["color"]),
        ("สีชมพู", "sǐi-chom-phuu", "粉色", "", ["color"]),
        ("ใหญ่", "yài", "大", "", ["size"]),
        ("เล็ก", "lék", "小", "", ["size"]),
        ("ยาว", "yaao", "长", "", ["size"]),
        ("สั้น", "sân", "短", "", ["size"]),
        ("คับ", "kháp", "紧", "", ["size"]),
        ("หลวม", "lǔam", "松", "", ["size"]),
        ("พอดี", "phɔɔ-dii", "刚好", "", ["size"]),
        ("ลอง", "lɔɔŋ", "试", "", ["action"]),
        ("เปลี่ยน", "plìan", "换", "", ["action"]),
        ("คืน", "khʉʉn", "退回", "", ["action"]),
        ("ลด", "lót", "减/降", "", ["action"]),
        ("ขนาด", "khà-nàat", "尺寸", "", ["attribute"]),
        ("เบอร์", "bəə", "号码/尺码", "", ["attribute"]),
        ("ราคา", "raa-khaa", "价格", "", ["money"]),
        ("ตลาด", "tà-làat", "市场", "", ["place"]),
        ("ห้าง", "hâaŋ", "商场", "", ["place"]),
        ("ร้าน", "ráan", "店", "", ["place"]),
        ("ซูเปอร์มาร์เก็ต", "suu-pə̂ə-maa-kèt", "超市", "", ["place"]),
        ("ของฝาก", "khɔ̌ɔŋ-fàak", "纪念品/伴手礼", "", ["gift"]),
        ("ถุง", "thǔŋ", "袋子", "", ["container"]),
    ]
    chunks = [
        ("ขอลองหน่อย", "khɔ̌ɔ lɔɔŋ nɔ̀i", "请让我试一下", "", ["request"]),
        ("ใส่ได้ไหม", "sài dâi mǎi", "能穿/戴吗", "", ["question"]),
        ("ใหญ่ไป", "yài pai", "太大了", "", ["size"]),
        ("เล็กไป", "lék pai", "太小了", "", ["size"]),
        ("พอดีเลย", "phɔɔ-dii ləəi", "刚好", "", ["size"]),
        ("มีไซส์ใหญ่กว่านี้ไหม", "mii sai yài kwàa níi mǎi", "有更大的尺码吗", "", ["question"]),
        ("ลดได้ไหม", "lót dâi mǎi", "能便宜点吗", "", ["question"]),
        ("แพงไป", "phɛɛŋ pai", "太贵了", "", ["price"]),
        ("เอาอันนี้", "ao an-níi", "要这个", "", ["action"]),
        ("ไม่เอาอันนี้", "mâi ao an-níi", "不要这个", "", ["action"]),
        ("จ่ายเงินตรงไหน", "càai ŋən troŋ nǎi", "在哪里付款", "", ["question"]),
        ("จ่ายด้วยบัตร", "càai dûai bàt", "刷卡付款", "", ["payment"]),
        ("เงินสด", "ŋən-sòt", "现金", "", ["payment"]),
        ("โอนเงิน", "oon ŋən", "转账", "", ["payment"]),
        ("สแกนจ่าย", "sà-kɛɛn càai", "扫码支付", "", ["payment"]),
        ("ใบเสร็จ", "bai-sèt", "收据", "", ["receipt"]),
        ("ขอถุงหน่อย", "khɔ̌ɔ thǔŋ nɔ̀i", "请给我袋子", "", ["request"]),
        ("เปลี่ยนได้ไหม", "plìan dâi mǎi", "能换吗", "", ["question"]),
        ("คืนของได้ไหม", "khʉʉn khɔ̌ɔŋ dâi mǎi", "能退货吗", "", ["question"]),
        ("ของหมด", "khɔ̌ɔŋ mòt", "卖完了", "", ["info"]),
    ]
    sentences = [
        ("ขอดูอันนี้หน่อยครับ", "khɔ̌ɔ duu an-níi nɔ̀i khráp", "请给我看看这个(男)", "", ["request"]),
        ("ขอลองใส่หน่อยได้ไหมครับ", "khɔ̌ɔ lɔɔŋ sài nɔ̀i dâi mǎi khráp", "能试穿一下吗(男)", "", ["request"]),
        ("มีสีอื่นไหมครับ", "mii sǐi ʉ̀ʉn mǎi khráp", "有其他颜色吗(男)", "", ["question"]),
        ("อันนี้ราคาเท่าไหร่ครับ", "an-níi raa-khaa thâo-rài khráp", "这个多少钱(男)", "", ["question"]),
        ("ลดหน่อยได้ไหมครับ", "lót nɔ̀i dâi mǎi khráp", "能便宜一点吗(男)", "", ["question"]),
        ("ขอคิดเงินหน่อยครับ", "khɔ̌ɔ khít ŋən nɔ̀i khráp", "请结账(男)", "", ["request"]),
        ("จ่ายด้วยเงินสดครับ", "càai dûai ŋən-sòt khráp", "用现金付款(男)", "", ["payment"]),
        ("สแกนจ่ายได้ไหมครับ", "sà-kɛɛn càai dâi mǎi khráp", "可以扫码支付吗(男)", "", ["question"]),
        ("ขอใบเสร็จด้วยครับ", "khɔ̌ɔ bai-sèt dûai khráp", "请给我收据(男)", "", ["request"]),
        ("ใหญ่ไปครับ มีเล็กกว่านี้ไหม", "yài pai khráp mii lék kwàa níi mǎi", "太大了，有小一点的吗(男)", "", ["question"]),
    ]
    return build_category("shopping", words, chunks, sentences, [])

def generate_home_living() -> list:
    """Generate ~90 items for 家与日常生活."""
    words = [
        ("บ้าน", "bâan", "家/房子", "", ["place"]),
        ("ห้อง", "hɔ̂ɔŋ", "房间", "", ["place"]),
        ("ห้องนอน", "hɔ̂ɔŋ-nɔɔn", "卧室", "", ["room"]),
        ("ห้องน้ำ", "hɔ̂ɔŋ-náam", "卫生间", "", ["room"]),
        ("ห้องครัว", "hɔ̂ɔŋ-khrua", "厨房", "", ["room"]),
        ("ห้องนั่งเล่น", "hɔ̂ɔŋ-nâŋ-lên", "客厅", "", ["room"]),
        ("ประตู", "prà-tuu", "门", "", ["object"]),
        ("หน้าต่าง", "nâa-tàaŋ", "窗户", "", ["object"]),
        ("โต๊ะ", "tó", "桌子", "", ["furniture"]),
        ("เก้าอี้", "kâo-îi", "椅子", "", ["furniture"]),
        ("เตียง", "tiaŋ", "床", "", ["furniture"]),
        ("ตู้", "tûu", "柜子", "", ["furniture"]),
        ("ตู้เย็น", "tûu-yen", "冰箱", "", ["appliance"]),
        ("ทีวี", "thii-wii", "电视", "", ["appliance"]),
        ("แอร์", "ɛɛ", "空调", "", ["appliance"]),
        ("พัดลม", "phát-lom", "电风扇", "", ["appliance"]),
        ("ไมโครเวฟ", "mai-khroo-wéep", "微波炉", "", ["appliance"]),
        ("เครื่องซักผ้า", "khrʉ̂aŋ-sák-phâa", "洗衣机", "", ["appliance"]),
        ("ไฟ", "fai", "灯/电/火", "", ["utility"]),
        ("น้ำ", "náam", "水", "", ["utility"]),
        ("ไฟดับ", "fai-dàp", "停电", "", ["problem"]),
        ("น้ำไม่ไหล", "náam-mâi-lǎi", "停水", "", ["problem"]),
        ("เปิด", "pə̀ət", "开", "", ["action"]),
        ("ปิด", "pìt", "关", "", ["action"]),
        ("ทำความสะอาด", "tham-khwaam-sà-àat", "打扫卫生", "", ["action"]),
        ("ซักผ้า", "sák-phâa", "洗衣服", "", ["action"]),
        ("รีดผ้า", "rîit-phâa", "熨衣服", "", ["action"]),
        ("ล้างจาน", "láaŋ-caan", "洗碗", "", ["action"]),
        ("กวาด", "kwàat", "扫", "", ["action"]),
        ("ถู", "thǔu", "拖/擦", "", ["action"]),
        ("เช็ด", "chét", "擦", "", ["action"]),
        ("ทิ้งขยะ", "thíŋ-khà-yà", "扔垃圾", "", ["action"]),
        ("เพื่อนบ้าน", "phʉ̂ʉan-bâan", "邻居", "", ["people"]),
        ("เช่า", "châo", "租", "", ["housing"]),
        ("ซื้อบ้าน", "sʉ́ʉ bâan", "买房", "", ["housing"]),
        ("ค่าเช่า", "khâa-châo", "租金", "", ["money"]),
        ("ค่าไฟ", "khâa-fai", "电费", "", ["money"]),
        ("ค่าน้ำ", "khâa-náam", "水费", "", ["money"]),
        ("เน็ต", "nèt", "网络", "", ["utility"]),
        ("ไวไฟ", "wai-fai", "Wi-Fi", "", ["utility"]),
        ("ร้อน", "rɔ́ɔn", "热", "", ["condition"]),
        ("หนาว", "nǎao", "冷", "", ["condition"]),
        ("เหม็น", "měn", "臭", "", ["condition"]),
        ("สะอาด", "sà-àat", "干净", "", ["condition"]),
        ("สกปรก", "sòk-kà-pròk", "脏", "", ["condition"]),
    ]
    chunks = [
        ("เปิดไฟหน่อย", "pə̀ət fai nɔ̀i", "请开灯", "", ["request"]),
        ("ปิดไฟหน่อย", "pìt fai nɔ̀i", "请关灯", "", ["request"]),
        ("เปิดแอร์หน่อย", "pə̀ət ɛɛ nɔ̀i", "请开空调", "", ["request"]),
        ("ปิดแอร์หน่อย", "pìt ɛɛ nɔ̀i", "请关空调", "", ["request"]),
        ("ไฟดับแล้ว", "fai dàp lɛ́ɛo", "停电了", "", ["info"]),
        ("ไม่มีน้ำใช้", "mâi mii náam chái", "没水用了", "", ["info"]),
        ("เน็ตไม่ดี", "nèt mâi dii", "网络不好", "", ["info"]),
        ("แอร์ไม่เย็น", "ɛɛ mâi yen", "空调不冷", "", ["problem"]),
        ("น้ำรั่ว", "náam rûa", "漏水", "", ["problem"]),
        ("ท่อตัน", "thɔ̂ɔ tan", "管道堵塞", "", ["problem"]),
        ("ทำความสะอาดห้อง", "tham khwaam sà-àat hɔ̂ɔŋ", "打扫房间", "", ["action"]),
        ("เช่าเดือนละเท่าไหร่", "châo dʉan lá thâo-rài", "月租多少钱", "", ["question"]),
        ("อยู่ชั้นไหน", "yùu chán nǎi", "住几楼", "", ["question"]),
        ("มีที่จอดรถไหม", "mii thîi cɔ̀ɔt rót mǎi", "有停车位吗", "", ["question"]),
        ("ห้องว่างไหม", "hɔ̂ɔŋ wâaŋ mǎi", "有空房吗", "", ["question"]),
        ("สัญญาเช่า", "sǎn-yaa châo", "租赁合同", "", ["document"]),
        ("เงินมัดจำ", "ŋən mát-cam", "押金", "", ["money"]),
        ("ค่าไฟเท่าไหร่", "khâa fai thâo-rài", "电费多少", "", ["question"]),
        ("ค่าน้ำเท่าไหร่", "khâa náam thâo-rài", "水费多少", "", ["question"]),
        ("ขอไวไฟหน่อย", "khɔ̌ɔ wai-fai nɔ̀i", "请给我Wi-Fi密码", "", ["request"]),
    ]
    sentences = [
        ("ค่าเช่าห้องนี้เดือนละเท่าไหร่ครับ", "khâa-châo hɔ̂ɔŋ níi dʉan lá thâo-rài khráp", "这个房间月租多少钱(男)", "", ["question"]),
        ("รวมค่าน้ำค่าไฟหรือยังครับ", "ruam khâa-náam khâa-fai rʉ̌ʉ yaŋ khráp", "包含水电费了吗(男)", "", ["question"]),
        ("มีอินเทอร์เน็ตไหมครับ", "mii in-thəə-nèt mǎi khráp", "有网络吗(男)", "", ["question"]),
        ("แอร์ไม่เย็นครับ ช่วยมาดูหน่อย", "ɛɛ mâi yen khráp chûai maa duu nɔ̀i", "空调不冷，麻烦来看看(男)", "", ["request"]),
        ("ประตูปิดไม่สนิทครับ", "prà-tuu pìt mâi sà-nìt khráp", "门关不紧(男)", "", ["problem"]),
        ("ขอยืมกุญแจสำรองหน่อยครับ", "khɔ̌ɔ yʉʉm kùn-cɛɛ sǎm-rɔɔŋ nɔ̀i khráp", "请借我备用钥匙(男)", "", ["request"]),
        ("วันนี้มีคนมาทำความสะอาดไหมครับ", "wan-níi mii khon maa tham-khwaam-sà-àat mǎi khráp", "今天有人来打扫吗(男)", "", ["question"]),
        ("ทิ้งขยะไว้ตรงไหนครับ", "thíŋ khà-yà wái troŋ nǎi khráp", "垃圾扔在哪里(男)", "", ["question"]),
        ("เช็คเอาท์กี่โมงครับ", "chék-ao thîi kìi mooŋ khráp", "几点退房(男)", "", ["question"]),
        ("ขอต่อสัญญาเช่าครับ", "khɔ̌ɔ tɔ̀ɔ sǎn-yaa châo khráp", "请续租(男)", "", ["request"]),
    ]
    return build_category("home_living", words, chunks, sentences, [])

def generate_transport() -> list:
    """Generate ~100 items for 交通与问路."""
    words = [
        ("รถ", "rót", "车", "", ["vehicle"]),
        ("รถไฟฟ้า", "rót-fai-fáa", "轻轨/天铁", "", ["transit"]),
        ("รถไฟ", "rót-fai", "火车", "", ["transit"]),
        ("รถเมล์", "rót-mee", "公交车", "", ["transit"]),
        ("รถไฟฟ้าใต้ดิน", "rót-fai-fáa-tâi-din", "地铁", "", ["transit"]),
        ("แท็กซี่", "thɛ́k-sîi", "出租车", "", ["vehicle"]),
        ("มอเตอร์ไซค์", "mɔɔ-təə-sai", "摩托车", "", ["vehicle"]),
        ("ตุ๊กตุ๊ก", "túk-túk", "突突车", "", ["vehicle"]),
        ("สองแถว", "sɔ̌ɔŋ-thɛ̌ɛo", "双条车", "", ["vehicle"]),
        ("เรือ", "rʉa", "船", "", ["vehicle"]),
        ("เครื่องบิน", "khrʉ̂aŋ-bin", "飞机", "", ["vehicle"]),
        ("จักรยาน", "càk-krà-yaan", "自行车", "", ["vehicle"]),
        ("เดิน", "dəən", "走/步行", "", ["action"]),
        ("เลี้ยว", "líau", "转", "", ["direction"]),
        ("ตรงไป", "troŋ-pai", "直走", "", ["direction"]),
        ("ซ้าย", "sáai", "左", "", ["direction"]),
        ("ขวา", "khwǎa", "右", "", ["direction"]),
        ("ข้างหน้า", "khâaŋ-nâa", "前面", "", ["direction"]),
        ("ข้างหลัง", "khâaŋ-lǎŋ", "后面", "", ["direction"]),
        ("ใกล้", "klâi", "近", "", ["distance"]),
        ("ไกล", "klai", "远", "", ["distance"]),
        ("ถึง", "thʉ̌ŋ", "到达", "", ["action"]),
        ("ออก", "ɔ̀ɔk", "出/离开", "", ["action"]),
        ("เข้า", "khâo", "进", "", ["action"]),
        ("ลง", "loŋ", "下", "", ["action"]),
        ("ขึ้น", "khʉ̂n", "上", "", ["action"]),
        ("กลับ", "klàp", "回", "", ["action"]),
        ("จอด", "cɔ̀ɔt", "停", "", ["action"]),
        ("เร็ว", "reo", "快", "", ["speed"]),
        ("ช้า", "cháa", "慢", "", ["speed"]),
        ("ถนน", "thà-nǒn", "道路", "", ["place"]),
        ("ซอย", "sɔɔi", "巷/弄", "", ["place"]),
        ("ป้ายรถเมล์", "pâai-rót-mee", "公交站", "", ["place"]),
        ("สถานี", "sà-thǎa-nii", "车站/站", "", ["place"]),
        ("สนามบิน", "sà-nǎam-bin", "机场", "", ["place"]),
        ("ทางด่วน", "thaaŋ-dùan", "高速公路", "", ["place"]),
        ("สะพาน", "sà-phaan", "桥", "", ["place"]),
        ("ไฟแดง", "fai-dɛɛŋ", "红灯", "", ["traffic"]),
        ("ไฟเขียว", "fai-khǐao", "绿灯", "", ["traffic"]),
        ("รถติด", "rót-tìt", "堵车", "", ["traffic"]),
        ("ตั๋ว", "tǔa", "票", "", ["ticket"]),
        ("ค่าโดยสาร", "khâa-dooi-sǎan", "车费/票价", "", ["money"]),
        ("มิเตอร์", "mí-tə̂ə", "计价器", "", ["equipment"]),
        ("แผนที่", "phɛ̌ɛn-thîi", "地图", "", ["tool"]),
        ("จีพีเอส", "cii-phii-ès", "GPS导航", "", ["tool"]),
        ("ทาง", "thaaŋ", "路/方向", "", ["general"]),
        ("ที่นั่ง", "thîi-nâŋ", "座位", "", ["general"]),
        ("คนขับ", "khon-khàp", "司机", "", ["people"]),
        ("ผู้โดยสาร", "phûu-dooi-sǎan", "乘客", "", ["people"]),
        ("กระเป๋าเดินทาง", "krà-pǎo-dəən-thaaŋ", "行李箱", "", ["luggage"]),
    ]
    chunks = [
        ("ไปยังไง", "pai yaŋ-ŋai", "怎么去", "", ["question"]),
        ("อยู่ที่ไหน", "yùu thîi-nǎi", "在哪里", "", ["question"]),
        ("ไกลไหม", "klai mǎi", "远吗", "", ["question"]),
        ("ใช้เวลานานไหม", "chái wee-laa naan mǎi", "要多久", "", ["question"]),
        ("ไปทางไหน", "pai thaaŋ nǎi", "往哪边走", "", ["question"]),
        ("เลี้ยวซ้าย", "líau sáai", "左转", "", ["direction"]),
        ("เลี้ยวขวา", "líau khwǎa", "右转", "", ["direction"]),
        ("ตรงไปเรื่อยๆ", "troŋ-pai rʉ̂ai-rʉ̂ai", "一直走", "", ["direction"]),
        ("กลับรถ", "klàp rót", "掉头", "", ["direction"]),
        ("จอดตรงนี้", "cɔ̀ɔt troŋ-níi", "停在这里", "", ["direction"]),
        ("ถึงแล้ว", "thʉ̌ŋ lɛ́ɛo", "到了", "", ["info"]),
        ("ยังไม่ถึง", "yaŋ mâi thʉ̌ŋ", "还没到", "", ["info"]),
        ("ไปส่งที่...", "pai sòŋ thîi...", "送去...", "", ["request"]),
        ("เปิดมิเตอร์", "pə̀ət mí-tə̂ə", "请打表", "", ["request"]),
        ("เท่าไหร่", "thâo-rài", "多少钱", "", ["question"]),
        ("ค่ารถเท่าไหร่", "khâa-rót thâo-rài", "车费多少钱", "", ["question"]),
        ("รถติดมาก", "rót tìt mâak", "堵车很严重", "", ["info"]),
        ("ขึ้นทางด่วน", "khʉ̂n thaaŋ-dùan", "上高速", "", ["direction"]),
        ("ลงทางด่วน", "loŋ thaaŋ-dùan", "下高速", "", ["direction"]),
        ("ทางด่วนกี่บาท", "thaaŋ-dùan kìi bàat", "高速费多少", "", ["question"]),
    ]
    sentences = [
        ("ไปสนามบินยังไงครับ", "pai sà-nǎam-bin yaŋ-ŋai khráp", "怎么去机场(男)", "", ["question"]),
        ("สถานีรถไฟฟ้าอยู่ที่ไหนครับ", "sà-thǎa-nii rót-fai-fáa yùu thîi-nǎi khráp", "轻轨站在哪里(男)", "", ["question"]),
        ("ไปซอยนี้เท่าไหร่ครับ", "pai sɔɔi níi thâo-rài khráp", "去这个巷子多少钱(男)", "", ["question"]),
        ("ช่วยเปิดมิเตอร์หน่อยครับ", "chûai pə̀ət mí-tə̂ə nɔ̀i khráp", "请打表(男)", "", ["request"]),
        ("เลี้ยวซ้ายตรงไฟแดงนะครับ", "líau sáai troŋ fai-dɛɛŋ ná khráp", "在红灯那里左转(男)", "", ["direction"]),
        ("จอดตรงนี้ครับ", "cɔ̀ɔt troŋ-níi khráp", "停这里(男)", "", ["request"]),
        ("รถติดไหมครับ", "rót tìt mǎi khráp", "堵车吗(男)", "", ["question"]),
        ("ใช้เวลาประมาณกี่นาทีครับ", "chái wee-laa prà-maan kìi naa-thii khráp", "大概需要多少分钟(男)", "", ["question"]),
        ("ขึ้นรถเมล์สายไหนครับ", "khʉ̂n rót-mee sǎai nǎi khráp", "坐几路公交车(男)", "", ["question"]),
        ("ขอลงตรงนี้ครับ", "khɔ̌ɔ loŋ troŋ-níi khráp", "请让我在这里下车(男)", "", ["request"]),
    ]
    return build_category("transport", words, chunks, sentences, [])

def generate_phone_network() -> list:
    """Generate ~60 items for 手机、网络与服务."""
    words = [
        ("โทรศัพท์", "thoo-rá-sàp", "电话", "", ["device"]),
        ("มือถือ", "mʉʉ-thʉ̌ʉ", "手机", "", ["device"]),
        ("ซิม", "sim", "SIM卡", "", ["telecom"]),
        ("เบอร์", "bəə", "号码", "", ["telecom"]),
        ("โทร", "thoo", "打电话", "", ["action"]),
        ("รับ", "ráp", "接", "", ["action"]),
        ("วาง", "waaŋ", "挂", "", ["action"]),
        ("ข้อความ", "khɔ̂ɔ-khwaam", "短信/消息", "", ["telecom"]),
        ("ไลน์", "laai", "LINE(通讯软件)", "", ["app"]),
        ("เฟซบุ๊ก", "féet-búk", "Facebook", "", ["app"]),
        ("เน็ต", "nèt", "网络", "", ["telecom"]),
        ("ไวไฟ", "wai-fai", "Wi-Fi", "", ["telecom"]),
        ("รหัส", "rá-hàt", "密码", "", ["telecom"]),
        ("สัญญาณ", "sǎn-yaan", "信号", "", ["telecom"]),
        ("แบตเตอรี่", "bɛ̀t-təə-rîi", "电池", "", ["device"]),
        ("ที่ชาร์จ", "thîi-cháat", "充电器", "", ["device"]),
        ("ปลั๊ก", "plák", "插头", "", ["device"]),
        ("สายชาร์จ", "sǎai-cháat", "充电线", "", ["device"]),
        ("พาวเวอร์แบงค์", "phao-wə̂ə-bɛŋ", "充电宝", "", ["device"]),
        ("หูฟัง", "hǔu-fang", "耳机", "", ["device"]),
        ("เน็ตช้า", "nèt cháa", "网速慢", "", ["problem"]),
        ("เน็ตหลุด", "nèt lùt", "断网", "", ["problem"]),
        ("เติมเงิน", "təəm ŋən", "充值", "", ["action"]),
        ("เติมเน็ต", "təəm nèt", "充流量", "", ["action"]),
        ("โปร", "proo", "套餐/优惠", "", ["telecom"]),
        ("รายเดือน", "raai-dʉan", "月租", "", ["telecom"]),
        ("บัตรเติมเงิน", "bàt təəm ŋən", "充值卡", "", ["telecom"]),
        ("เหมา", "mǎo", "一口价", "", ["telecom"]),
        ("ไม่จำกัด", "mâi-cam-kàt", "不限量", "", ["telecom"]),
        ("หมด", "mòt", "用完", "", ["telecom"]),
        ("บริการ", "bɔɔ-rí-kaan", "服务", "", ["general"]),
        ("ลูกค้า", "lûuk-kháa", "顾客", "", ["general"]),
        ("พนักงาน", "phá-nák-ŋaan", "工作人员", "", ["people"]),
        ("คอลเซ็นเตอร์", "khɔɔl-sen-tə̂ə", "客服中心", "", ["service"]),
        ("เคาน์เตอร์", "kháo-tə̂ə", "柜台", "", ["place"]),
        ("คิว", "khiw", "排队号", "", ["service"]),
        ("รอ", "rɔɔ", "等待", "", ["action"]),
        ("คิวต่อไป", "khiw tɔ̀ɔ-pai", "下一个", "", ["service"]),
        ("อีกกี่คิว", "ìik kìi khiw", "还有几个号", "", ["question"]),
        ("ฝากข้อความ", "fàak khɔ̂ɔ-khwaam", "留言", "", ["action"]),
    ]
    chunks = [
        ("ขอไวไฟหน่อย", "khɔ̌ɔ wai-fai nɔ̀i", "请给我Wi-Fi", "", ["request"]),
        ("รหัสไวไฟอะไร", "rá-hàt wai-fai à-rai", "Wi-Fi密码是什么", "", ["question"]),
        ("เน็ตไม่ดี", "nèt mâi dii", "网络不好", "", ["info"]),
        ("ไม่มีสัญญาณ", "mâi mii sǎn-yaan", "没信号", "", ["info"]),
        ("แบตจะหมด", "bɛ̀t cà mòt", "快没电了", "", ["info"]),
        ("ขอชาร์จแบตหน่อย", "khɔ̌ɔ cháat bɛ̀t nɔ̀i", "请让我充下电", "", ["request"]),
        ("เติมเงินหน่อย", "təəm ŋən nɔ̀i", "请充值", "", ["request"]),
        ("เติมกี่บาท", "təəm kìi bàat", "充多少铢", "", ["question"]),
        ("เบอร์อะไร", "bəə à-rai", "什么号码", "", ["question"]),
        ("ขอเบอร์หน่อย", "khɔ̌ɔ bəə nɔ̀i", "请给我号码", "", ["request"]),
        ("โทรกลับนะ", "thoo klàp ná", "请回电", "", ["request"]),
        ("ฝากข้อความได้ไหม", "fàak khɔ̂ɔ-khwaam dâi mǎi", "能留言吗", "", ["question"]),
        ("เปลี่ยนซิม", "plìan sim", "换SIM卡", "", ["action"]),
        ("ซิมใหม่", "sim mài", "新SIM卡", "", ["telecom"]),
        ("ซิมนักท่องเที่ยว", "sim nák-thɔ̂ɔŋ-thîaw", "游客SIM卡", "", ["telecom"]),
        ("เล่นเน็ตได้ไหม", "lên nèt dâi mǎi", "能上网吗", "", ["question"]),
        ("โทรฟรี", "thoo frii", "免费通话", "", ["telecom"]),
        ("มีโปรไหม", "mii proo mǎi", "有套餐吗", "", ["question"]),
        ("เหมาเน็ต", "mǎo nèt", "流量包", "", ["telecom"]),
        ("วันนี้หมด", "wan-níi mòt", "今天用完", "", ["info"]),
    ]
    sentences = [
        ("ขอซื้อซิมการ์ดหน่อยครับ", "khɔ̌ɔ sʉ́ʉ sim-káat nɔ̀i khráp", "请给我买张SIM卡(男)", "", ["request"]),
        ("ซิมนักท่องเที่ยวราคาเท่าไหร่ครับ", "sim nák-thɔ̂ɔŋ-thîaw raa-khaa thâo-rài khráp", "游客SIM卡多少钱(男)", "", ["question"]),
        ("ช่วยเติมเงินหน่อยครับ", "chûai təəm ŋən nɔ̀i khráp", "请帮我充值(男)", "", ["request"]),
        ("มีโปรเน็ตไม่จำกัดไหมครับ", "mii proo nèt mâi-cam-kàt mǎi khráp", "有无限流量套餐吗(男)", "", ["question"]),
        ("ขอไวไฟรหัสหน่อยครับ", "khɔ̌ɔ wai-fai rá-hàt nɔ̀i khráp", "请给我Wi-Fi密码(男)", "", ["request"]),
        ("มือถือไม่มีสัญญาณครับ", "mʉʉ-thʉ̌ʉ mâi mii sǎn-yaan khráp", "手机没信号(男)", "", ["problem"]),
        ("ที่ชาร์จมือถือมีไหมครับ", "thîi-cháat mʉʉ-thʉ̌ʉ mii mǎi khráp", "有手机充电器吗(男)", "", ["question"]),
        ("ขอเบอร์ติดต่อหน่อยครับ", "khɔ̌ɔ bəə tìt-tɔ̀ɔ nɔ̀i khráp", "请给我联系电话(男)", "", ["request"]),
        ("เน็ตหลุดบ่อยมากครับ", "nèt lùt bɔ̀i mâak khráp", "网络经常断(男)", "", ["problem"]),
        ("เปลี่ยนซิมต้องใช้เอกสารอะไรบ้างครับ", "plìan sim tɔ̂ŋ chái èek-kà-sǎan à-rai bâaŋ khráp", "换SIM卡需要什么证件(男)", "", ["question"]),
    ]
    return build_category("phone_network", words, chunks, sentences, [])

# ── Helper ────────────────────────────────────────────────────────────

def build_category(cat: str, words: list, chunks: list, sentences: list, dialogues: list = None) -> list:
    items = []
    idx = 0
    for i, (th, rom, zh, note, tags) in enumerate(words):
        idx = i + 1
        items.append({
            "id": make_id(cat, "word", idx),
            "kind": "word",
            "category": cat,
            "tags": tags,
            "thai": th,
            "romanization": rom,
            "meaningZhHans": zh,
            "usageNote": note,
            "frequencyTier": 1,
            "audioID": make_audio_id(cat, "word", idx),
            "prerequisiteIDs": [],
            "relatedIDs": [],
            "example": "",
            "segments": [],
            "sourceID": "author-yaohuix",
            "contentVersion": 1
        })
    word_count = len(items)
    for i, (th, rom, zh, note, tags) in enumerate(chunks):
        cid = i + 1
        prereqs = [make_id(cat, "word", min(i + 1, word_count))]
        items.append({
            "id": make_id(cat, "chunk", cid),
            "kind": "chunk",
            "category": cat,
            "tags": tags,
            "thai": th,
            "romanization": rom,
            "meaningZhHans": zh,
            "usageNote": note,
            "frequencyTier": 2,
            "audioID": make_audio_id(cat, "chunk", cid),
            "prerequisiteIDs": prereqs,
            "relatedIDs": [],
            "example": "",
            "segments": [],
            "sourceID": "author-yaohuix",
            "contentVersion": 1
        })
    for i, (th, rom, zh, note, tags) in enumerate(sentences):
        sid = i + 1
        prereqs = [make_id(cat, "chunk", min(i + 1, len(chunks)))] if chunks else [make_id(cat, "word", 1)]
        items.append({
            "id": make_id(cat, "sent", sid),
            "kind": "sentence",
            "category": cat,
            "tags": tags,
            "thai": th,
            "romanization": rom,
            "meaningZhHans": zh,
            "usageNote": note,
            "frequencyTier": 3,
            "audioID": make_audio_id(cat, "sent", sid),
            "prerequisiteIDs": prereqs,
            "relatedIDs": [],
            "example": "",
            "segments": [],
            "sourceID": "author-yaohuix",
            "contentVersion": 1,
            "stepIndex": sid
        })
    if dialogues:
        for i, (th, zh, note, tags) in enumerate(dialogues):
            did = i + 1
            prereqs = [make_id(cat, "sent", min(i + 1, len(sentences)))] if sentences else [make_id(cat, "word", 1)]
            items.append({
                "id": make_id(cat, "dial", did),
                "kind": "dialogue",
                "category": cat,
                "tags": tags,
                "thai": th,
                "romanization": "",
                "meaningZhHans": zh,
                "usageNote": note,
                "frequencyTier": 4,
                "audioID": make_audio_id(cat, "dial", did),
                "prerequisiteIDs": prereqs,
                "relatedIDs": [],
                "example": "",
                "segments": [],
                "sourceID": "author-yaohuix",
                "contentVersion": 1,
                "stepIndex": did
            })
    return items


# Generate remaining categories with structured data below
def generate_health() -> list:
    """Generate ~80 items for 身体、健康与药店."""
    words = [
        ("หมอ", "mɔ̌ɔ", "医生", "", ["profession"]),
        ("พยาบาล", "phá-yaa-baan", "护士", "", ["profession"]),
        ("โรงพยาบาล", "rooŋ-phá-yaa-baan", "医院", "", ["place"]),
        ("คลินิก", "khli-nìk", "诊所", "", ["place"]),
        ("ร้านขายยา", "ráan-khǎai-yaa", "药店", "", ["place"]),
        ("ยา", "yaa", "药", "", ["medical"]),
        ("ยาแก้ปวด", "yaa-kɛ̂ɛ-pùat", "止痛药", "", ["medical"]),
        ("ยาแก้แพ้", "yaa-kɛ̂ɛ-phɛ́ɛ", "抗过敏药", "", ["medical"]),
        ("ยาลดไข้", "yaa-lót-khâi", "退烧药", "", ["medical"]),
        ("ยาแก้ไอ", "yaa-kɛ̂ɛ-ai", "止咳药", "", ["medical"]),
        ("ยาแก้ท้องเสีย", "yaa-kɛ̂ɛ-thɔ́ɔŋ-sǐa", "止泻药", "", ["medical"]),
        ("ปวด", "pùat", "疼", "", ["symptom"]),
        ("เจ็บ", "cèp", "痛/受伤", "", ["symptom"]),
        ("ไข้", "khâi", "发烧", "", ["symptom"]),
        ("ไอ", "ai", "咳嗽", "", ["symptom"]),
        ("หวัด", "wàt", "感冒", "", ["illness"]),
        ("แพ้", "phɛ́ɛ", "过敏", "", ["condition"]),
        ("ท้องเสีย", "thɔ́ɔŋ-sǐa", "拉肚子", "", ["symptom"]),
        ("ท้องผูก", "thɔ́ɔŋ-phùuk", "便秘", "", ["symptom"]),
        ("เวียนหัว", "wian-hǔa", "头晕", "", ["symptom"]),
        ("อาเจียน", "aa-cian", "呕吐", "", ["symptom"]),
        ("เป็นลม", "pen-lom", "晕倒", "", ["symptom"]),
        ("เลือด", "lʉ̂at", "血", "", ["body"]),
        ("หัว", "hǔa", "头", "", ["body"]),
        ("ท้อง", "thɔ́ɔŋ", "肚子", "", ["body"]),
        ("คอ", "khɔɔ", "喉咙", "", ["body"]),
        ("ตา", "taa", "眼睛", "", ["body"]),
        ("หู", "hǔu", "耳朵", "", ["body"]),
        ("จมูก", "cà-mùuk", "鼻子", "", ["body"]),
        ("ปาก", "pàak", "嘴", "", ["body"]),
        ("ฟัน", "fan", "牙齿", "", ["body"]),
        ("มือ", "mʉʉ", "手", "", ["body"]),
        ("เท้า", "tháo", "脚", "", ["body"]),
        ("ขา", "khǎa", "腿", "", ["body"]),
        ("แขน", "khɛ̌ɛn", "手臂", "", ["body"]),
        ("หลัง", "lǎŋ", "背", "", ["body"]),
        ("หัวใจ", "hǔa-cai", "心脏", "", ["body"]),
        ("โรค", "rôok", "疾病", "", ["medical"]),
        ("ประกัน", "prà-kan", "保险", "", ["insurance"]),
        ("นัด", "nát", "预约", "", ["medical"]),
        ("ตรวจ", "trùat", "检查", "", ["medical"]),
        ("ผ่าตัด", "phàa-tàt", "手术", "", ["medical"]),
        ("ฉีดยา", "chìit-yaa", "打针", "", ["medical"]),
        ("แผล", "phlɛ̌ɛ", "伤口", "", ["medical"]),
        ("ผ้าพันแผล", "phâa-phan-phlɛ̌ɛ", "绷带", "", ["medical"]),
        ("ปลาสเตอร์", "plàat-sà-tə̂ə", "创可贴", "", ["medical"]),
        ("อาหารเสริม", "aa-hǎan-sə̌əm", "保健品", "", ["medical"]),
        ("ครีมกันแดด", "khriim-kan-dɛ̀ɛt", "防晒霜", "", ["product"]),
        ("ยากันยุง", "yaa-kan-yuŋ", "驱蚊药", "", ["product"]),
        ("สบู่", "sà-bùu", "肥皂", "", ["product"]),
    ]
    chunks = [
        ("ปวดหัว", "pùat hǔa", "头疼", "", ["symptom"]),
        ("ปวดท้อง", "pùat thɔ́ɔŋ", "肚子疼", "", ["symptom"]),
        ("เจ็บคอ", "cèp khɔɔ", "喉咙痛", "", ["symptom"]),
        ("เป็นหวัด", "pen wàt", "感冒了", "", ["illness"]),
        ("เป็นไข้", "pen khâi", "发烧了", "", ["symptom"]),
        ("ไม่สบาย", "mâi sà-baai", "不舒服", "", ["symptom"]),
        ("ไปหาหมอ", "pai hǎa mɔ̌ɔ", "去看医生", "", ["action"]),
        ("ไปโรงพยาบาล", "pai rooŋ-phá-yaa-baan", "去医院", "", ["action"]),
        ("ขอยาแก้ปวด", "khɔ̌ɔ yaa kɛ̂ɛ pùat", "请给我止痛药", "", ["request"]),
        ("แพ้อาหาร", "phɛ́ɛ aa-hǎan", "食物过敏", "", ["condition"]),
        ("แพ้ยา", "phɛ́ɛ yaa", "药物过敏", "", ["condition"]),
        ("กินยาพร้อมอาหาร", "kin yaa phrɔ́ɔm aa-hǎan", "饭后吃药", "", ["instruction"]),
        ("ก่อนอาหาร", "kɔ̀ɔn aa-hǎan", "饭前", "", ["timing"]),
        ("หลังอาหาร", "lǎŋ aa-hǎan", "饭后", "", ["timing"]),
        ("วันละกี่ครั้ง", "wan lá kìi khráŋ", "一天几次", "", ["question"]),
        ("ครั้งละกี่เม็ด", "khráŋ lá kìi mét", "一次几粒", "", ["question"]),
        ("มีไข้ไหม", "mii khâi mǎi", "发烧吗", "", ["question"]),
        ("ตรวจเลือด", "trùat lʉ̂at", "验血", "", ["medical"]),
        ("เอกซเรย์", "èk-sà-ree", "X光", "", ["medical"]),
        ("นอนโรงพยาบาล", "nɔɔn rooŋ-phá-yaa-baan", "住院", "", ["medical"]),
    ]
    sentences = [
        ("ผมปวดหัวมากครับ", "phǒm pùat hǔa mâak khráp", "我头疼得厉害(男)", "", ["symptom"]),
        ("ฉันไม่สบายค่ะ ไปหาหมอหน่อย", "chǎn mâi sà-baai khâ pai hǎa mɔ̌ɔ nɔ̀i", "我不舒服，去看下医生(女)", "", ["action"]),
        ("มีไข้ไหมครับ", "mii khâi mǎi khráp", "发烧吗(男)", "", ["question"]),
        ("เมื่อคืนอาเจียนสองครั้งครับ", "mʉ̂ʉa-khʉʉn aa-cian sɔ̌ɔŋ khráŋ khráp", "昨晚吐了两次(男)", "", ["info"]),
        ("ผมแพ้อาหารทะเลครับ", "phǒm phɛ́ɛ aa-hǎan-thá-lee khráp", "我对海鲜过敏(男)", "", ["info"]),
        ("ขอยาแก้ปวดหัวหน่อยครับ", "khɔ̌ɔ yaa-kɛ̂ɛ-pùat-hǔa nɔ̀i khráp", "请给我头痛药(男)", "", ["request"]),
        ("ยานี้กินวันละกี่ครั้งครับ", "yaa níi kin wan lá kìi khráŋ khráp", "这个药一天吃几次(男)", "", ["question"]),
        ("มีนัดหมอตอนบ่ายสองครับ", "mii nát mɔ̌ɔ tɔɔn bàai sɔ̌ɔŋ khráp", "下午两点约了医生(男)", "", ["info"]),
        ("ช่วยเรียกรถพยาบาลหน่อยครับ", "chûai rîak rót-phá-yaa-baan nɔ̀i khráp", "请帮忙叫救护车(男)", "", ["emergency"]),
        ("นี่คือยาที่ผมกินประจำครับ", "nîi khʉʉ yaa thîi phǒm kin prà-cam khráp", "这是我常吃的药(男)", "", ["info"]),
    ]
    return build_category("health", words, chunks, sentences, [])

def generate_safety() -> list:
    """Generate ~50 items for 安全与紧急求助."""
    words = [
        ("ตำรวจ", "tam-rùat", "警察", "", ["people"]),
        ("สถานีตำรวจ", "sà-thǎa-nii-tam-rùat", "警察局", "", ["place"]),
        ("รถพยาบาล", "rót-phá-yaa-baan", "救护车", "", ["vehicle"]),
        ("รถดับเพลิง", "rót-dàp-phləəŋ", "消防车", "", ["vehicle"]),
        ("ช่วยด้วย", "chûai dûai", "救命", "", ["emergency"]),
        ("อันตราย", "an-tà-raai", "危险", "", ["warning"]),
        ("ระวัง", "rá-waŋ", "小心", "", ["warning"]),
        ("ไฟไหม้", "fai-mâi", "火灾", "", ["emergency"]),
        ("น้ำท่วม", "náam-thûam", "水灾", "", ["disaster"]),
        ("แผ่นดินไหว", "phɛ̀n-din-wǎi", "地震", "", ["disaster"]),
        ("อุบัติเหตุ", "ù-bàt-hèet", "事故", "", ["emergency"]),
        ("ขโมย", "khà-mooi", "小偷/偷盗", "", ["crime"]),
        ("หาย", "hǎai", "丢失/不见了", "", ["problem"]),
        ("หลงทาง", "lǒŋ-thaaŋ", "迷路", "", ["problem"]),
        ("ฉุกเฉิน", "chùk-chə̌ən", "紧急", "", ["emergency"]),
        ("ขอความช่วยเหลือ", "khɔ̌ɔ khwaam-chûai-lʉ̌ʉa", "请求帮助", "", ["emergency"]),
        ("โทร", "thoo", "打电话", "", ["action"]),
        ("เบอร์ฉุกเฉิน", "bəə chùk-chə̌ən", "紧急号码", "", ["info"]),
        ("หนังสือเดินทาง", "nǎŋ-sʉ̌ʉ-dəən-thaaŋ", "护照", "", ["document"]),
        ("บัตรประชาชน", "bàt-prà-chaa-chon", "身份证", "", ["document"]),
        ("สถานทูต", "sà-thǎan-thûut", "大使馆", "", ["place"]),
        ("กงสุล", "koŋ-sǔn", "领事", "", ["people"]),
        ("ล่าม", "lâam", "翻译", "", ["people"]),
        ("ประกันภัย", "prà-kan-phai", "保险", "", ["insurance"]),
        ("เคลม", "khleem", "理赔", "", ["insurance"]),
        ("ของหาย", "khɔ̌ɔŋ hǎai", "东西丢了", "", ["problem"]),
        ("กระเป๋าหาย", "krà-pǎo hǎai", "包丢了", "", ["problem"]),
        ("มือถือหาย", "mʉʉ-thʉ̌ʉ hǎai", "手机丢了", "", ["problem"]),
        ("ทำหาย", "tham hǎai", "弄丢了", "", ["problem"]),
        ("เจอ", "cəə", "找到", "", ["action"]),
        ("หา", "hǎa", "找", "", ["action"]),
        ("ใบแจ้งความ", "bai-cɛ̂ɛŋ-khwaam", "报案单", "", ["document"]),
        ("แจ้งความ", "cɛ̂ɛŋ khwaam", "报案", "", ["action"]),
        ("หลักฐาน", "làk-thǎan", "证据", "", ["document"]),
        ("พยาน", "phá-yaan", "证人", "", ["people"]),
        ("กล้องวงจรปิด", "klɔ̂ɔŋ-woŋ-cɔɔn-pìt", "监控摄像头", "", ["equipment"]),
        ("ปิด", "pìt", "关/锁", "", ["action"]),
        ("ล็อค", "lɔ́k", "锁", "", ["action"]),
        ("กุญแจ", "kùn-cɛɛ", "钥匙", "", ["object"]),
        ("ประตู", "prà-tuu", "门", "", ["object"]),
        ("ทางออก", "thaaŋ-ɔ̀ɔk", "出口", "", ["place"]),
        ("ทางเข้า", "thaaŋ-khâo", "入口", "", ["place"]),
        ("บันไดหนีไฟ", "ban-dai-nǐi-fai", "消防通道", "", ["place"]),
        ("ห้าม", "hâam", "禁止", "", ["warning"]),
        ("ห้ามเข้า", "hâam khâo", "禁止进入", "", ["warning"]),
        ("ห้ามสูบบุหรี่", "hâam sùup-bù-rìi", "禁止吸烟", "", ["warning"]),
        ("อันตรายสูง", "an-tà-raai sǔuŋ", "高度危险", "", ["warning"]),
        ("ทางลัด", "thaaŋ lát", "捷径", "", ["general"]),
        ("อย่า", "yàa", "不要(禁止)", "", ["warning"]),
        ("อย่าเข้าไป", "yàa khâo pai", "不要进去", "", ["warning"]),
    ]
    chunks = [
        ("ช่วยด้วย!", "chûai dûai!", "救命!", "", ["emergency"]),
        ("โทรหาตำรวจ", "thoo hǎa tam-rùat", "打电话报警", "", ["emergency"]),
        ("เรียกรถพยาบาล", "rîak rót-phá-yaa-baan", "叫救护车", "", ["emergency"]),
        ("ไฟไหม้!", "fai-mâi!", "着火了!", "", ["emergency"]),
        ("มีอุบัติเหตุ", "mii ù-bàt-hèet", "有事故", "", ["emergency"]),
        ("ผมหลงทาง", "phǒm lǒŋ thaaŋ", "我迷路了(男)", "", ["problem"]),
        ("ของผมหาย", "khɔ̌ɔŋ phǒm hǎai", "我的东西丢了(男)", "", ["problem"]),
        ("พาสปอร์ตหาย", "pháat-sà-pɔ̀ɔt hǎai", "护照丢了", "", ["problem"]),
        ("มีคนขโมย", "mii khon khà-mooi", "有小偷", "", ["crime"]),
        ("ถูกขโมย", "thùuk khà-mooi", "被偷了", "", ["crime"]),
        ("ไปสถานีตำรวจ", "pai sà-thǎa-nii tam-rùat", "去警察局", "", ["action"]),
        ("แจ้งความหน่อย", "cɛ̂ɛŋ khwaam nɔ̀i", "请报案", "", ["request"]),
        ("ต้องการล่าม", "tɔ̂ŋ-kaan lâam", "需要翻译", "", ["request"]),
        ("ขอความช่วยเหลือหน่อย", "khɔ̌ɔ khwaam-chûai-lʉ̌ʉa nɔ̀i", "请帮帮忙", "", ["request"]),
        ("ติดต่อสถานทูต", "tìt-tɔ̀ɔ sà-thǎan-thûut", "联系大使馆", "", ["action"]),
        ("ระวังอันตราย", "rá-waŋ an-tà-raai", "小心危险", "", ["warning"]),
        ("ห้ามเข้าไป", "hâam khâo pai", "禁止进入", "", ["warning"]),
        ("ทางออกอยู่ไหน", "thaaŋ-ɔ̀ɔk yùu nǎi", "出口在哪", "", ["question"]),
        ("เกิดอะไรขึ้น", "kə̀ət à-rai khʉ̂n", "发生什么事", "", ["question"]),
        ("ปลอดภัยไหม", "plɔ̀ɔt-phai mǎi", "安全吗", "", ["question"]),
    ]
    sentences = [
        ("ช่วยด้วยครับ มีคนขโมยกระเป๋าผม", "chûai dûai khráp mii khon khà-mooi krà-pǎo phǒm", "救命，有人偷了我的包(男)", "", ["emergency"]),
        ("โทรหาตำรวจหน่อยครับ", "thoo hǎa tam-rùat nɔ̀i khráp", "请报警(男)", "", ["emergency"]),
        ("หนังสือเดินทางหายครับ", "nǎŋ-sʉ̌ʉ-dəən-thaaŋ hǎai khráp", "护照丢了(男)", "", ["problem"]),
        ("ผมต้องการล่ามภาษาจีนครับ", "phǒm tɔ̂ŋ-kaan lâam phaa-sǎa ciin khráp", "我需要中文翻译(男)", "", ["request"]),
        ("ช่วยพาผมไปสถานีตำรวจหน่อยครับ", "chûai phaa phǒm pai sà-thǎa-nii tam-rùat nɔ̀i khráp", "请带我去警察局(男)", "", ["request"]),
        ("อยู่นี่อันตรายไหมครับ", "yùu nîi an-tà-raai mǎi khráp", "这里安全吗(男)", "", ["question"]),
        ("ทางออกฉุกเฉินอยู่ที่ไหนครับ", "thaaŋ-ɔ̀ɔk chùk-chə̌ən yùu thîi-nǎi khráp", "紧急出口在哪里(男)", "", ["question"]),
        ("ขอเบอร์ติดต่อตำรวจหน่อยครับ", "khɔ̌ɔ bəə tìt-tɔ̀ɔ tam-rùat nɔ̀i khráp", "请给我警察的联系电话(男)", "", ["request"]),
        ("มีคนเจ็บตรงนี้ครับ", "mii khon cèp troŋ-níi khráp", "这里有人受伤(男)", "", ["emergency"]),
        ("ประกันผมอยู่ที่ไหนครับ", "prà-kan phǒm yùu thîi-nǎi khráp", "我的保险在哪里(男)", "", ["question"]),
    ]
    return build_category("safety", words, chunks, sentences, [])

def generate_weather_leisure() -> list:
    """Generate ~70 items for 天气、休闲与生活习惯."""
    words = [
        ("อากาศ", "aa-kàat", "天气", "", ["weather"]),
        ("ร้อน", "rɔ́ɔn", "热", "", ["weather"]),
        ("หนาว", "nǎao", "冷", "", ["weather"]),
        ("ฝน", "fǒn", "雨", "", ["weather"]),
        ("ฝนตก", "fǒn-tòk", "下雨", "", ["weather"]),
        ("แดด", "dɛ̀ɛt", "阳光", "", ["weather"]),
        ("ลม", "lom", "风", "", ["weather"]),
        ("ชื้น", "chʉ́ʉn", "潮湿", "", ["weather"]),
        ("แห้ง", "hɛ̂ɛŋ", "干燥", "", ["weather"]),
        ("ร้อนมาก", "rɔ́ɔn mâak", "很热", "", ["weather"]),
        ("หนาวมาก", "nǎao mâak", "很冷", "", ["weather"]),
        ("ร่ม", "rôm", "伞", "", ["object"]),
        ("แว่นกันแดด", "wɛ̂n-kan-dɛ̀ɛt", "太阳镜", "", ["object"]),
        ("กีฬา", "kii-laa", "体育", "", ["activity"]),
        ("วิ่ง", "wîŋ", "跑步", "", ["activity"]),
        ("ว่ายน้ำ", "wâai-náam", "游泳", "", ["activity"]),
        ("ปีนเขา", "piin-khǎo", "爬山", "", ["activity"]),
        ("ตกปลา", "tòk-plaa", "钓鱼", "", ["activity"]),
        ("กอล์ฟ", "kɔ́ɔp", "高尔夫", "", ["sport"]),
        ("ฟุตบอล", "fút-bɔn", "足球", "", ["sport"]),
        ("มวยไทย", "muai-thai", "泰拳", "", ["sport"]),
        ("โยคะ", "yoo-khá", "瑜伽", "", ["activity"]),
        ("ฟิตเนส", "fít-nèt", "健身房", "", ["place"]),
        ("สวน", "sǔan", "公园", "", ["place"]),
        ("ทะเล", "thá-lee", "大海", "", ["place"]),
        ("ชายหาด", "chaai-hàat", "海滩", "", ["place"]),
        ("ภูเขา", "phuu-khǎo", "山", "", ["place"]),
        ("น้ำตก", "nám-tòk", "瀑布", "", ["place"]),
        ("เกาะ", "kɔ̀", "岛", "", ["place"]),
        ("วัด", "wát", "寺庙", "", ["place"]),
        ("ตลาดนัด", "tà-làat-nát", "集市/夜市", "", ["place"]),
        ("นวด", "nûat", "按摩", "", ["activity"]),
        ("สปา", "sà-paa", "SPA", "", ["place"]),
        ("ทำบุญ", "tham-bun", "做功德/布施", "", ["culture"]),
        ("ใส่บาตร", "sài-bàat", "布施(给僧人)", "", ["culture"]),
        ("พระ", "phrá", "僧人/佛像", "", ["culture"]),
        ("วันหยุด", "wan-yùt", "假日", "", ["time"]),
        ("วันนักขัตฤกษ์", "wan-nák-khàt-tà-rʉ̀ʉk", "公共假日", "", ["time"]),
        ("เทศกาล", "thêet-sà-kaan", "节日", "", ["culture"]),
        ("สงกรานต์", "sǒŋ-kraan", "宋干节/泼水节", "", ["culture"]),
        ("ลอยกระทง", "lɔɔi-krà-thoŋ", "水灯节", "", ["culture"]),
        ("ปีใหม่", "pii-mài", "新年", "", ["culture"]),
        ("ตรุษจีน", "trùt-ciin", "春节", "", ["culture"]),
        ("ดนตรี", "don-trii", "音乐", "", ["art"]),
        ("เพลง", "phleeŋ", "歌曲", "", ["art"]),
        ("หนัง", "nǎŋ", "电影", "", ["art"]),
        ("ละคร", "lá-khɔɔn", "戏剧", "", ["art"]),
        ("หนังสือ", "nǎŋ-sʉ̌ʉ", "书", "", ["object"]),
        ("หนังสือพิมพ์", "nǎŋ-sʉ̌ʉ-phim", "报纸", "", ["object"]),
        ("สัตว์เลี้ยง", "sàt-líang", "宠物", "", ["animal"]),
    ]
    chunks = [
        ("วันนี้อากาศดี", "wan-níi aa-kàat dii", "今天天气好", "", ["weather"]),
        ("อากาศร้อนมาก", "aa-kàat rɔ́ɔn mâak", "天气很热", "", ["weather"]),
        ("ฝนจะตกไหม", "fǒn cà tòk mǎi", "会下雨吗", "", ["question"]),
        ("ฝนตกหนัก", "fǒn tòk nàk", "下大雨", "", ["weather"]),
        ("ไปทะเล", "pai thá-lee", "去海边", "", ["activity"]),
        ("ไปเดินเล่น", "pai dəən lên", "去散步", "", ["activity"]),
        ("ไปดูหนัง", "pai duu nǎŋ", "去看电影", "", ["activity"]),
        ("ไปช้อปปิ้ง", "pai chɔ́p-pîŋ", "去购物", "", ["activity"]),
        ("ไปเที่ยวด้วยกัน", "pai thîaw dûai kan", "一起去玩", "", ["invitation"]),
        ("นวดหน่อย", "nûat nɔ̀i", "按摩一下", "", ["request"]),
        ("นวดไทย", "nûat thai", "泰式按摩", "", ["activity"]),
        ("นวดน้ำมัน", "nûat nám-man", "精油按摩", "", ["activity"]),
        ("นวดเท้า", "nûat tháo", "足底按摩", "", ["activity"]),
        ("ขอใบราคาหน่อย", "khɔ̌ɔ bai raa-khaa nɔ̀i", "请给我价目表", "", ["request"]),
        ("กี่ชั่วโมง", "kìi chûa-mooŋ", "几个小时", "", ["question"]),
        ("ชั่วโมงละเท่าไหร่", "chûa-mooŋ lá thâo-rài", "每小时多少钱", "", ["question"]),
        ("มีโปรไหม", "mii proo mǎi", "有优惠吗", "", ["question"]),
        ("จองไว้หรือยัง", "cɔɔŋ wái rʉ̌ʉ yaŋ", "预订了吗", "", ["question"]),
        ("คนละครึ่ง", "khon lá khrʉ̂ŋ", "各付一半/AA制", "", ["money"]),
        ("เลี้ยงเอง", "líang eeŋ", "我请客", "", ["social"]),
    ]
    return build_category("weather_leisure", words, chunks, [], [])

def generate_airport() -> list:
    """Generate ~50 items for 机场与入境."""
    words = [
        ("สนามบิน", "sà-nǎam-bin", "机场", "", ["place"]),
        ("ตั๋วเครื่องบิน", "tǔa-khrʉ̂aŋ-bin", "机票", "", ["document"]),
        ("เช็คอิน", "chék-in", "值机/办理登机", "", ["action"]),
        ("โหลดกระเป๋า", "lòot krà-pǎo", "托运行李", "", ["action"]),
        ("กระเป๋าถือ", "krà-pǎo-thʉ̌ʉ", "手提行李", "", ["luggage"]),
        ("กระเป๋าเดินทาง", "krà-pǎo-dəən-thaaŋ", "行李箱", "", ["luggage"]),
        ("น้ำหนักเกิน", "nám-nàk kəən", "超重", "", ["luggage"]),
        ("ขึ้นเครื่อง", "khʉ̂n khrʉ̂aŋ", "登机", "", ["action"]),
        ("ลงเครื่อง", "loŋ khrʉ̂aŋ", "下飞机", "", ["action"]),
        ("เครื่องลง", "khrʉ̂aŋ loŋ", "飞机降落", "", ["info"]),
        ("ดีเลย์", "dii-lee", "延误", "", ["problem"]),
        ("ยกเลิก", "yók-lə̂ək", "取消", "", ["problem"]),
        ("ประตูขึ้นเครื่อง", "prà-tuu khʉ̂n khrʉ̂aŋ", "登机口", "", ["place"]),
        ("ผู้โดยสาร", "phûu-dooi-sǎan", "乘客", "", ["people"]),
        ("เที่ยวบิน", "thîaw-bin", "航班", "", ["info"]),
        ("หมายเลขเที่ยวบิน", "mǎai-lêek thîaw-bin", "航班号", "", ["info"]),
        ("หนังสือเดินทาง", "nǎŋ-sʉ̌ʉ-dəən-thaaŋ", "护照", "", ["document"]),
        ("วีซ่า", "wii-sâa", "签证", "", ["document"]),
        ("ตรวจคนเข้าเมือง", "trùat-khon-khâo-mʉaŋ", "入境检查", "", ["process"]),
        ("ศุลกากร", "sǔn-lá-kaa-kɔɔn", "海关", "", ["place"]),
        ("สำแดง", "sǎm-dɛɛŋ", "申报", "", ["action"]),
        ("ของต้องห้าม", "khɔ̌ɔŋ tɔ̂ŋ hâam", "违禁品", "", ["warning"]),
        ("ภาษี", "phaa-sǐi", "税", "", ["money"]),
        ("ปลอดภาษี", "plɔ̀ɔt-phaa-sǐi", "免税", "", ["money"]),
        ("ดิวตี้ฟรี", "diw-tîi-frii", "免税店", "", ["place"]),
        ("แลกเงิน", "lɛ̂ɛk ŋən", "换钱", "", ["action"]),
        ("อัตราแลกเปลี่ยน", "àt-traa-lɛ̂ɛk-plìan", "汇率", "", ["money"]),
        ("ค่าเงิน", "khâa-ŋən", "币值", "", ["money"]),
        ("เงินบาท", "ŋən bàat", "泰铢", "", ["money"]),
        ("เงินดอลลาร์", "ŋən dɔn-lâa", "美元", "", ["money"]),
        ("เงินหยวน", "ŋən yǔan", "人民币", "", ["money"]),
        ("แลกเงินที่ไหน", "lɛ̂ɛk ŋən thîi nǎi", "去哪里换钱", "", ["question"]),
        ("เรทเท่าไหร่", "réet thâo-rài", "汇率多少", "", ["question"]),
        ("รถเข็น", "rót-khěn", "推车", "", ["equipment"]),
        ("ทางออก", "thaaŋ-ɔ̀ɔk", "出口", "", ["place"]),
        ("ทางเข้า", "thaaŋ-khâo", "入口", "", ["place"]),
        ("รอรับ", "rɔɔ ráp", "接机", "", ["action"]),
        ("ไปส่ง", "pai sòŋ", "送机", "", ["action"]),
        ("ชั้น", "chán", "楼层", "", ["general"]),
        ("ห้องน้ำ", "hɔ̂ɔŋ-náam", "卫生间", "", ["place"]),
        ("ที่สูบบุหรี่", "thîi sùup-bù-rìi", "吸烟区", "", ["place"]),
        ("ร้านอาหาร", "ráan-aa-hǎan", "餐厅", "", ["place"]),
        ("เคาน์เตอร์", "kháo-tə̂ə", "柜台", "", ["place"]),
        ("สัมภาระ", "sǎm-phaa-rá", "行李(正式)", "", ["luggage"]),
        ("สายพาน", "sǎai-phaan", "传送带", "", ["equipment"]),
        ("ไปรับกระเป๋า", "pai ráp krà-pǎo", "去取行李", "", ["action"]),
        ("หาย", "hǎai", "丢失", "", ["problem"]),
        ("เสียหาย", "sǐa-hǎai", "损坏", "", ["problem"]),
        ("ร้องเรียน", "rɔ́ɔŋ-rian", "投诉", "", ["action"]),
        ("ข้อมูล", "khɔ̂ɔ-muun", "信息", "", ["general"]),
    ]
    chunks = [
        ("เช็คอินกี่โมง", "chék-in kìi mooŋ", "几点值机", "", ["question"]),
        ("โหลดกระเป๋ากี่ใบ", "lòot krà-pǎo kìi bai", "托运几个行李", "", ["question"]),
        ("น้ำหนักเกินไหม", "nám-nàk kəən mǎi", "超重了吗", "", ["question"]),
        ("ประตูไหน", "prà-tuu nǎi", "哪个登机口", "", ["question"]),
        ("ดีเลย์กี่ชั่วโมง", "dii-lee kìi chûa-mooŋ", "延误几小时", "", ["question"]),
        ("เครื่องออกกี่โมง", "khrʉ̂aŋ ɔ̀ɔk kìi mooŋ", "几点起飞", "", ["question"]),
        ("ถึงกี่โมง", "thʉ̌ŋ kìi mooŋ", "几点到", "", ["question"]),
        ("เปลี่ยนตั๋วได้ไหม", "plìan tǔa dâi mǎi", "能改票吗", "", ["question"]),
        ("ยกเลิกตั๋ว", "yók-lə̂ək tǔa", "退票", "", ["action"]),
        ("คืนเงินได้ไหม", "khʉʉn ŋən dâi mǎi", "能退款吗", "", ["question"]),
        ("ขอที่นั่งริมหน้าต่าง", "khɔ̌ɔ thîi-nâŋ rim nâa-tàaŋ", "请给我靠窗座位", "", ["request"]),
        ("ขอที่นั่งริมทางเดิน", "khɔ̌ɔ thîi-nâŋ rim thaaŋ-dəən", "请给我靠过道座位", "", ["request"]),
        ("สำแดงของ", "sǎm-dɛɛŋ khɔ̌ɔŋ", "申报物品", "", ["action"]),
        ("ไม่มีอะไรต้องสำแดง", "mâi mii à-rai tɔ̂ŋ sǎm-dɛɛŋ", "没有要申报的", "", ["info"]),
        ("ผ่านศุลกากร", "phàan sǔn-lá-kaa-kɔɔn", "通过海关", "", ["process"]),
        ("ตรวจหนังสือเดินทาง", "trùat nǎŋ-sʉ̌ʉ-dəən-thaaŋ", "检查护照", "", ["process"]),
        ("ขอวีซ่า", "khɔ̌ɔ wii-sâa", "申请签证", "", ["action"]),
        ("ต่อวีซ่า", "tɔ̀ɔ wii-sâa", "续签", "", ["action"]),
        ("หมดอายุ", "mòt-aa-yú", "过期", "", ["status"]),
        ("แลกเงินที่ไหน", "lɛ̂ɛk ŋən thîi nǎi", "在哪里换钱", "", ["question"]),
    ]
    return build_category("airport", words, chunks, [], [])

def generate_hotel() -> list:
    """Generate ~60 items for 酒店与景点."""
    words = [
        ("โรงแรม", "rooŋ-rɛɛm", "酒店", "", ["place"]),
        ("ห้องพัก", "hɔ̂ɔŋ-phák", "客房", "", ["room"]),
        ("เช็คอิน", "chék-in", "入住", "", ["action"]),
        ("เช็คเอาท์", "chék-ao", "退房", "", ["action"]),
        ("จอง", "cɔɔŋ", "预订", "", ["action"]),
        ("สำรอง", "sǎm-rɔɔŋ", "预留", "", ["action"]),
        ("ห้องว่าง", "hɔ̂ɔŋ wâaŋ", "空房", "", ["status"]),
        ("ห้องเต็ม", "hɔ̂ɔŋ tem", "满房", "", ["status"]),
        ("ห้องเตียงเดี่ยว", "hɔ̂ɔŋ tiaŋ dìaw", "单人房", "", ["room"]),
        ("ห้องเตียงคู่", "hɔ̂ɔŋ tiaŋ khûu", "双人房", "", ["room"]),
        ("ห้องสวีท", "hɔ̂ɔŋ sà-wìit", "套房", "", ["room"]),
        ("อาหารเช้า", "aa-hǎan cháo", "早餐", "", ["meal"]),
        ("รวมอาหารเช้า", "ruam aa-hǎan cháo", "含早餐", "", ["amenity"]),
        ("สระว่ายน้ำ", "sà-wâai-náam", "游泳池", "", ["amenity"]),
        ("ฟิตเนส", "fít-nèt", "健身房", "", ["amenity"]),
        ("ที่จอดรถ", "thîi cɔ̀ɔt rót", "停车场", "", ["amenity"]),
        ("ฟรีไวไฟ", "frii wai-fai", "免费Wi-Fi", "", ["amenity"]),
        ("เครื่องปรับอากาศ", "khrʉ̂aŋ-pràp-aa-kàat", "空调", "", ["amenity"]),
        ("ทีวี", "thii-wii", "电视", "", ["amenity"]),
        ("ตู้เย็น", "tûu-yen", "冰箱", "", ["amenity"]),
        ("ผ้าเช็ดตัว", "phâa-chét-tua", "毛巾", "", ["amenity"]),
        ("สบู่", "sà-bùu", "肥皂", "", ["amenity"]),
        ("แชมพู", "chɛɛm-phuu", "洗发水", "", ["amenity"]),
        ("ห้องน้ำ", "hɔ̂ɔŋ-náam", "卫生间", "", ["room"]),
        ("น้ำร้อน", "nám-rɔ́ɔn", "热水", "", ["amenity"]),
        ("น้ำไม่ร้อน", "náam mâi rɔ́ɔn", "没有热水", "", ["problem"]),
        ("ไฟไม่ติด", "fai mâi tìt", "灯不亮", "", ["problem"]),
        ("แอร์ไม่เย็น", "ɛɛ mâi yen", "空调不冷", "", ["problem"]),
        ("กุญแจห้อง", "kùn-cɛɛ hɔ̂ɔŋ", "房间钥匙", "", ["object"]),
        ("คีย์การ์ด", "khii-káat", "房卡", "", ["object"]),
        ("ฝากกระเป๋า", "fàak krà-pǎo", "寄存行李", "", ["action"]),
        ("รูมเซอร์วิส", "ruum-səə-wìt", "客房服务", "", ["service"]),
        ("ทำความสะอาด", "tham-khwaam-sà-àat", "打扫", "", ["service"]),
        ("เปลี่ยนผ้า", "plìan phâa", "换床单", "", ["service"]),
        ("ใบเสร็จ", "bai-sèt", "收据", "", ["document"]),
        ("ใบจอง", "bai-cɔɔŋ", "预订确认", "", ["document"]),
        ("ยกเลิก", "yók-lə̂ək", "取消", "", ["action"]),
        ("คืนเงิน", "khʉʉn ŋən", "退款", "", ["money"]),
        ("มัดจำ", "mát-cam", "押金", "", ["money"]),
        ("ค่าห้อง", "khâa hɔ̂ɔŋ", "房费", "", ["money"]),
        ("ค่าบริการ", "khâa bɔɔ-rí-kaan", "服务费", "", ["money"]),
        ("ภาษี", "phaa-sǐi", "税", "", ["money"]),
        ("แผนกต้อนรับ", "phà-nɛ̀ɛk tɔ̂ɔn-ráp", "前台", "", ["place"]),
        ("พนักงาน", "phá-nák-ŋaan", "工作人员", "", ["people"]),
        ("ผู้จัดการ", "phûu-càt-kaan", "经理", "", ["people"]),
        ("รีวิว", "rii-wíu", "评价", "", ["general"]),
        ("ดาว", "daao", "星级", "", ["rating"]),
        ("ที่พัก", "thîi-phák", "住宿", "", ["general"]),
        ("โฮสเทล", "hóos-tel", "青年旅社", "", ["place"]),
        ("รีสอร์ท", "rii-sɔ̀ɔt", "度假村", "", ["place"]),
    ]
    chunks = [
        ("มีห้องว่างไหม", "mii hɔ̂ɔŋ wâaŋ mǎi", "有空房吗", "", ["question"]),
        ("จองห้องไว้แล้ว", "cɔɔŋ hɔ̂ɔŋ wái lɛ́ɛo", "已经预订了", "", ["info"]),
        ("คืนนี้กี่บาท", "khʉʉn níi kìi bàat", "今晚多少钱", "", ["question"]),
        ("รวมอาหารเช้าไหม", "ruam aa-hǎan cháo mǎi", "含早餐吗", "", ["question"]),
        ("เช็คเอาท์กี่โมง", "chék-ao kìi mooŋ", "几点退房", "", ["question"]),
        ("ขอดูห้องก่อน", "khɔ̌ɔ duu hɔ̂ɔŋ kɔ̀ɔn", "先看看房间", "", ["request"]),
        ("ขอเปลี่ยนห้อง", "khɔ̌ɔ plìan hɔ̂ɔŋ", "请换房间", "", ["request"]),
        ("ฝากกระเป๋าได้ไหม", "fàak krà-pǎo dâi mǎi", "能寄存行李吗", "", ["question"]),
        ("เช็คเอาท์ช้าหน่อย", "chék-ao cháa nɔ̀i", "延迟退房", "", ["request"]),
        ("ขอยืมที่ชาร์จ", "khɔ̌ɔ yʉʉm thîi-cháat", "请借充电器", "", ["request"]),
        ("ทำความสะอาดห้องหน่อย", "tham khwaam sà-àat hɔ̂ɔŋ nɔ̀i", "请打扫房间", "", ["request"]),
        ("ขอผ้าเช็ดตัวเพิ่ม", "khɔ̌ɔ phâa-chét-tua phə̂əm", "请加毛巾", "", ["request"]),
        ("น้ำไม่ร้อน", "náam mâi rɔ́ɔn", "没有热水", "", ["problem"]),
        ("แอร์เสีย", "ɛɛ sǐa", "空调坏了", "", ["problem"]),
        ("ทีวีไม่ติด", "thii-wii mâi tìt", "电视打不开", "", ["problem"]),
        ("ประตูเปิดไม่ได้", "prà-tuu pə̀ət mâi dâi", "门打不开", "", ["problem"]),
        ("ลืมกุญแจในห้อง", "lʉʉm kùn-cɛɛ nai hɔ̂ɔŋ", "钥匙忘在房间里了", "", ["problem"]),
        ("มีรูมเซอร์วิสไหม", "mii ruum-səə-wìt mǎi", "有客房服务吗", "", ["question"]),
        ("ขอใบเสร็จด้วย", "khɔ̌ɔ bai-sèt dûai", "请给我收据", "", ["request"]),
        ("ยกเลิกการจอง", "yók-lə̂ək kaan-cɔɔŋ", "取消预订", "", ["action"]),
    ]
    return build_category("hotel", words, chunks, [], [])

def generate_local_errands() -> list:
    """Generate ~70 items for 本地办事."""
    words = [
        ("ธนาคาร", "thá-naa-khaan", "银行", "", ["place"]),
        ("ไปรษณีย์", "prai-sà-nii", "邮局", "", ["place"]),
        ("ร้านตัดผม", "ráan-tàt-phǒm", "理发店", "", ["place"]),
        ("ร้านซักรีด", "ráan-sák-rîit", "洗衣店", "", ["place"]),
        ("ร้านสะดวกซื้อ", "ráan-sà-dùak-sʉ́ʉ", "便利店", "", ["place"]),
        ("เซเว่น", "see-wên", "7-11便利店", "", ["place"]),
        ("บัตร", "bàt", "卡", "", ["object"]),
        ("บัตรเครดิต", "bàt-khree-dìt", "信用卡", "", ["money"]),
        ("บัตรเดบิต", "bàt-dee-bìt", "借记卡", "", ["money"]),
        ("เอทีเอ็ม", "ee-thii-em", "ATM取款机", "", ["machine"]),
        ("กดเงิน", "kòt ŋən", "取钱", "", ["action"]),
        ("ฝากเงิน", "fàak ŋən", "存钱", "", ["action"]),
        ("โอนเงิน", "oon ŋən", "转账", "", ["action"]),
        ("บัญชี", "ban-chii", "账户", "", ["banking"]),
        ("สมุดบัญชี", "sà-mùt-ban-chii", "存折", "", ["document"]),
        ("ดอกเบี้ย", "dɔ̀ɔk-bìa", "利息", "", ["money"]),
        ("ค่าธรรมเนียม", "khâa-tham-niam", "手续费", "", ["money"]),
        ("เปิดบัญชี", "pə̀ət ban-chii", "开户", "", ["action"]),
        ("ปิดบัญชี", "pìt ban-chii", "销户", "", ["action"]),
        ("เซ็น", "sen", "签字", "", ["action"]),
        ("ลายเซ็น", "laai-sen", "签名", "", ["document"]),
        ("เอกสาร", "èek-kà-sǎan", "文件/证件", "", ["document"]),
        ("สำเนา", "sǎm-nao", "复印件", "", ["document"]),
        ("หนังสือรับรอง", "nǎŋ-sʉ̌ʉ-ráp-rɔɔŋ", "证明书", "", ["document"]),
        ("ทะเบียนบ้าน", "thá-bian-bâan", "户口本", "", ["document"]),
        ("ใบขับขี่", "bai-khàp-khìi", "驾照", "", ["document"]),
        ("ทำ", "tham", "做/办理", "", ["action"]),
        ("ติดต่อ", "tìt-tɔ̀ɔ", "联系/办理", "", ["action"]),
        ("ยื่น", "yʉ̂ʉn", "提交", "", ["action"]),
        ("กรอก", "krɔ̀ɔk", "填写", "", ["action"]),
        ("แบบฟอร์ม", "bɛ̀ɛp-fɔɔm", "表格", "", ["document"]),
        ("รอคิว", "rɔɔ khiw", "排队等待", "", ["action"]),
        ("บัตรคิว", "bàt khiw", "号码牌", "", ["object"]),
        ("แผนก", "phà-nɛ̀ɛk", "部门", "", ["office"]),
        ("ช่าง", "châaŋ", "技师/工匠", "", ["profession"]),
        ("ช่างไฟ", "châaŋ fai", "电工", "", ["profession"]),
        ("ช่างประปา", "châaŋ prà-paa", "水管工", "", ["profession"]),
        ("ช่างแอร์", "châaŋ ɛɛ", "空调师傅", "", ["profession"]),
        ("ซ่อม", "sɔ̂ɔm", "修理", "", ["action"]),
        ("เสีย", "sǐa", "坏了", "", ["problem"]),
        ("พัง", "phaŋ", "坏了/崩塌", "", ["problem"]),
        ("ใช้ไม่ได้", "chái mâi dâi", "不能用", "", ["problem"]),
        ("ยังไม่เสร็จ", "yaŋ mâi sèt", "还没好", "", ["status"]),
        ("เสร็จแล้ว", "sèt lɛ́ɛo", "好了/完成了", "", ["status"]),
        ("อีกนานไหม", "ìik naan mǎi", "还要很久吗", "", ["question"]),
        ("เสร็จเมื่อไหร่", "sèt mʉ̂ʉa-rài", "什么时候好", "", ["question"]),
        ("ราคาเท่าไหร่", "raa-khaa thâo-rài", "价格多少", "", ["question"]),
        ("แพงไป", "phɛɛŋ pai", "太贵了", "", ["price"]),
        ("ถูก", "thùuk", "便宜", "", ["price"]),
        ("ประกัน", "prà-kan", "保修", "", ["service"]),
    ]
    chunks = [
        ("เปิดบัญชีหน่อย", "pə̀ət ban-chii nɔ̀i", "请开户", "", ["request"]),
        ("กดเงินหน่อย", "kòt ŋən nɔ̀i", "请取钱", "", ["request"]),
        ("โอนเงินหน่อย", "oon ŋən nɔ̀i", "请转账", "", ["request"]),
        ("กรอกแบบฟอร์ม", "krɔ̀ɔk bɛ̀ɛp-fɔɔm", "填写表格", "", ["action"]),
        ("เซ็นตรงนี้", "sen troŋ-níi", "在这里签字", "", ["direction"]),
        ("ขอสำเนาด้วย", "khɔ̌ɔ sǎm-nao dûai", "请给我复印件", "", ["request"]),
        ("รอคิวที่ไหน", "rɔɔ khiw thîi nǎi", "在哪里排队", "", ["question"]),
        ("คิวที่เท่าไหร่", "khiw thîi thâo-rài", "排到几号了", "", ["question"]),
        ("อีกกี่คิว", "ìik kìi khiw", "还有几个号", "", ["question"]),
        ("ซ่อมหน่อย", "sɔ̂ɔm nɔ̀i", "请修理", "", ["request"]),
        ("เสียแล้ว", "sǐa lɛ́ɛo", "已经坏了", "", ["info"]),
        ("ใช้งานไม่ได้", "chái ŋaan mâi dâi", "不能正常使用", "", ["problem"]),
        ("ซ่อมได้ไหม", "sɔ̂ɔm dâi mǎi", "能修吗", "", ["question"]),
        ("ซ่อมเมื่อไหร่เสร็จ", "sɔ̂ɔm mʉ̂ʉa-rài sèt", "什么时候能修好", "", ["question"]),
        ("ค่าใช้จ่ายเท่าไหร่", "khâa-chái-càai thâo-rài", "费用多少", "", ["question"]),
        ("มีประกันไหม", "mii prà-kan mǎi", "有保修吗", "", ["question"]),
        ("ตัดผมหน่อย", "tàt phǒm nɔ̀i", "请理发", "", ["request"]),
        ("ตัดสั้น", "tàt sân", "剪短", "", ["specification"]),
        ("เอาไว้ยาว", "ao wái yaao", "留着/不要剪短", "", ["specification"]),
        ("สระผมด้วย", "sà phǒm dûai", "还要洗头", "", ["request"]),
    ]
    return build_category("local_errands", words, chunks, [], [])

# ── Main ──────────────────────────────────────────────────────────────

CATEGORY_MAP = {
    "basics": ("开口基础", generate_basics, 160),
    "social": ("社交与人际", generate_social, 90),
    "numbers": ("数字、时间与数量", generate_numbers, 110),
    "food_dining": ("饮食与点餐", generate_food_dining, 130),
    "shopping": ("购物与付款", generate_shopping, 80),
    "home_living": ("家与日常生活", generate_home_living, 90),
    "transport": ("交通与问路", generate_transport, 100),
    "phone_network": ("手机、网络与服务", generate_phone_network, 60),
    "health": ("身体、健康与药店", generate_health, 80),
    "safety": ("安全与紧急求助", generate_safety, 50),
    "weather_leisure": ("天气、休闲与生活习惯", generate_weather_leisure, 70),
    "airport": ("机场与入境", generate_airport, 50),
    "hotel": ("酒店与景点", generate_hotel, 60),
    "local_errands": ("本地办事", generate_local_errands, 70),
}

def generate_base_items() -> list[dict]:
    all_items = []
    for cat_key, (name, generator, target) in CATEGORY_MAP.items():
        items = generator()
        items = pad_or_trim(items, target, cat_key)
        count = len(items)
        status = "✓" if count == target else f"✗ (expected {target}, got {count})"
        print(f"  {name}: {count} items {status}")
        all_items.extend(items)

    total = len(all_items)
    print(f"\nTotal: {total} items")
    if total != 1200:
        print(f"ERROR: Expected 1200, got {total}", file=sys.stderr)
        raise ValueError(f"Expected 1200 items, got {total}")
    print("✓ Count matches expected 1200")
    return all_items

def load_authored_supplements() -> dict[str, list[dict]]:
    """Load reviewed, static sentence supplements for categories below target size."""
    path = Path(__file__).with_name("content_supplements.json")
    with path.open(encoding="utf-8") as file:
        return json.load(file)


AUTHORED_SUPPLEMENTS = load_authored_supplements()


def pad_or_trim(items: list, target: int, cat: str) -> list:
    """Reach target size using only reviewed content; never generate placeholders."""
    diff = target - len(items)
    if diff == 0:
        return items
    if diff > 0:
        supplements = AUTHORED_SUPPLEMENTS.get(cat, [])
        if len(supplements) != diff:
            raise ValueError(
                f"{cat} requires {diff} reviewed supplements, found {len(supplements)}"
            )
        for supplement in supplements:
            sid = len(items) + 1
            items.append({
                "id": make_id(cat, "sent", sid),
                "kind": "sentence",
                "category": cat,
                "tags": ["sentence"],
                "thai": supplement["thai"],
                "romanization": supplement["romanization"],
                "meaningZhHans": supplement["meaningZhHans"],
                "usageNote": "",
                "frequencyTier": 3,
                "audioID": make_audio_id(cat, "sent", sid),
                "prerequisiteIDs": [items[0]["id"]] if items else [],
                "relatedIDs": [],
                "example": "",
                "segments": [],
                "sourceID": "author-yaohuix",
                "contentVersion": 1,
                "stepIndex": sid,
            })
    else:
        items = items[:target]
    return items


def load_example_source(path: Path = EXAMPLE_SOURCE_PATH) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def load_example_coverage(path: Path = EXAMPLE_COVERAGE_PATH) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def load_chunk_breakdowns(path: Path = CHUNK_BREAKDOWN_PATH) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def _normalized_text(value: str) -> str:
    return "".join(value.split())


def _normalized_example_meaning(value: str) -> str:
    value = re.sub(r"\([^)]*\)", "", value)
    return _normalized_text(value)


def _require_exact_keys(value: dict, allowed: set[str], label: str) -> None:
    actual = set(value)
    if actual != allowed:
        missing = sorted(allowed - actual)
        unknown = sorted(actual - allowed)
        raise ValueError(f"{label} fields mismatch; missing={missing}, unknown={unknown}")


def _validate_chunk_breakdown_layer(
    record_id: str, layer: str, segments: object, chunk_text: str
) -> None:
    if not isinstance(segments, list) or not segments:
        raise ValueError(f"{record_id}: {layer} must be a non-empty list")
    for segment in segments:
        if not isinstance(segment, dict):
            raise ValueError(f"{record_id}: invalid {layer} segment")
        _require_exact_keys(segment, {"thai", "gloss"}, f"{layer} segment {record_id}")
        if (
            not isinstance(segment.get("thai"), str)
            or not segment["thai"].strip()
            or not isinstance(segment.get("gloss"), str)
            or not segment["gloss"].strip()
        ):
            raise ValueError(f"{record_id}: invalid {layer} segment")
    if _normalized_text("".join(segment["thai"] for segment in segments)) != _normalized_text(chunk_text):
        raise ValueError(f"{record_id}: {layer} does not reconstruct chunk")


def validate_chunk_breakdowns(source: dict, base_items: list[dict]) -> dict[str, dict]:
    _require_exact_keys(source, {"schemaVersion", "locale", "recordCount", "items"}, "chunk breakdown source")
    if (
        source.get("schemaVersion") != 1
        or source.get("locale") != "zh-Hans"
        or source.get("recordCount") != 215
    ):
        raise ValueError("invalid chunk breakdown source metadata")

    chunks_by_id = {item["id"]: item for item in base_items if item["kind"] == "chunk"}
    records = source.get("items")
    if not isinstance(records, list):
        raise ValueError("chunk breakdown source items must be a list")
    ids = [record.get("id") if isinstance(record, dict) else None for record in records]
    if (
        not all(isinstance(record_id, str) for record_id in ids)
        or ids != sorted(ids)
        or len(ids) != len(set(ids))
        or set(ids) != set(chunks_by_id)
    ):
        raise ValueError("chunk breakdown IDs do not match generated chunk IDs")

    breakdowns_by_id = {}
    for record in records:
        _require_exact_keys(
            record,
            {"id", "combinations", "minimal"},
            f"chunk breakdown record {record['id']}",
        )
        record_id = record["id"]
        target_chunk = chunks_by_id[record_id]["thai"]
        _validate_chunk_breakdown_layer(record_id, "combinations", record["combinations"], target_chunk)
        _validate_chunk_breakdown_layer(record_id, "minimal", record["minimal"], target_chunk)
        breakdowns_by_id[record_id] = {
            "combinations": record["combinations"],
            "minimal": record["minimal"],
        }
    return breakdowns_by_id


def apply_chunk_breakdowns(items: list[dict], breakdowns_by_id: dict[str, dict]) -> list[dict]:
    import copy

    output = copy.deepcopy(items)
    for item in output:
        if item["kind"] == "chunk":
            breakdown = breakdowns_by_id[item["id"]]
            item["chunkBreakdown"] = {
                "combinations": copy.deepcopy(breakdown["combinations"]),
                "minimal": copy.deepcopy(breakdown["minimal"]),
            }
        else:
            item.pop("chunkBreakdown", None)
    return output


def load_word_breakdowns(path: Path = WORD_BREAKDOWN_PATH) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def _layer_refines(combinations: list, minimal: list) -> bool:
    rest = [_normalized_text(segment["thai"]) for segment in minimal]
    for combo in combinations:
        target = _normalized_text(combo["thai"])
        acc = ""
        used = 0
        while used < len(rest) and acc != target:
            acc += rest[used]
            used += 1
            if len(acc) > len(target):
                return False
        if acc != target:
            return False
        rest = rest[used:]
    return rest == []


def _find_headword_span(segments: list, headword: str) -> list | None:
    target = _normalized_text(headword)
    for start in range(len(segments)):
        acc = ""
        for end in range(start, len(segments)):
            thai = segments[end].get("thai") if isinstance(segments[end], dict) else ""
            acc += _normalized_text(str(thai))
            if acc == target:
                return segments[start : end + 1]
            if len(acc) > len(target):
                break
    return None


def _validate_word_breakdown_layer(record_id: str, layer: str, segments: object, word_text: str) -> None:
    if not isinstance(segments, list) or len(segments) < 2:
        raise ValueError(f"{record_id}: {layer} must contain at least 2 segments")
    for segment in segments:
        if not isinstance(segment, dict):
            raise ValueError(f"{record_id}: invalid {layer} segment")
        _require_exact_keys(segment, {"thai", "gloss"}, f"{layer} segment {record_id}")
        if (
            not isinstance(segment.get("thai"), str)
            or not segment["thai"].strip()
            or not isinstance(segment.get("gloss"), str)
            or not segment["gloss"].strip()
        ):
            raise ValueError(f"{record_id}: invalid {layer} segment")
    if _normalized_text("".join(segment["thai"] for segment in segments)) != _normalized_text(word_text):
        raise ValueError(f"{record_id}: {layer} does not reconstruct word")


def _validate_word_example_coupling(record_id: str, item: dict, combinations: list) -> None:
    example = item.get("example") or ""
    if not str(example).strip():
        return
    headword = item["thai"]
    if _normalized_text(headword) not in _normalized_text(str(example)):
        raise ValueError(f"{record_id}: example does not contain headword")
    segments = item.get("segments") or []
    if any(
        isinstance(segment, dict) and _normalized_text(segment.get("thai", "")) == _normalized_text(headword)
        for segment in segments
    ):
        raise ValueError(f"{record_id}: example still treats headword as one segment")
    span = _find_headword_span(segments, headword)
    if span is None:
        raise ValueError(f"{record_id}: example segments do not cover headword")
    if [segment["thai"] for segment in span] != [combo["thai"] for combo in combinations]:
        raise ValueError(f"{record_id}: example headword span thai does not match combinations")
    if [segment["gloss"] for segment in span] != [combo["gloss"] for combo in combinations]:
        raise ValueError(f"{record_id}: example headword span gloss does not match combinations")


def validate_word_breakdowns(source: dict, items: list[dict]) -> dict[str, dict]:
    _require_exact_keys(source, {"schemaVersion", "locale", "recordCount", "items"}, "word breakdown source")
    records = source.get("items")
    if (
        source.get("schemaVersion") != 1
        or source.get("locale") != "zh-Hans"
        or not isinstance(records, list)
        or source.get("recordCount") != len(records)
    ):
        raise ValueError("invalid word breakdown source metadata")

    words_by_id = {item["id"]: item for item in items if item.get("kind") == "word"}
    ids = [record.get("id") if isinstance(record, dict) else None for record in records]
    if not all(isinstance(record_id, str) for record_id in ids) or ids != sorted(ids) or len(ids) != len(set(ids)):
        raise ValueError("word breakdown IDs must be unique and sorted")
    for record_id in ids:
        if record_id not in words_by_id:
            raise ValueError(f"unknown word breakdown ID: {record_id}")
        if record_id in WORD_BREAKDOWN_DENIED_IDS:
            raise ValueError(f"word breakdown ID is on the deny list: {record_id}")

    breakdowns_by_id: dict[str, dict] = {}
    for record in records:
        _require_exact_keys(record, {"id", "combinations", "minimal"}, f"word breakdown record {record['id']}")
        record_id = record["id"]
        target_word = words_by_id[record_id]["thai"]
        _validate_word_breakdown_layer(record_id, "combinations", record["combinations"], target_word)
        _validate_word_breakdown_layer(record_id, "minimal", record["minimal"], target_word)
        if not _layer_refines(record["combinations"], record["minimal"]):
            raise ValueError(f"{record_id}: minimal does not refine combinations")
        _validate_word_example_coupling(record_id, words_by_id[record_id], record["combinations"])
        breakdowns_by_id[record_id] = {
            "combinations": record["combinations"],
            "minimal": record["minimal"],
        }
    return breakdowns_by_id


def apply_word_breakdowns(items: list[dict], breakdowns_by_id: dict[str, dict]) -> list[dict]:
    import copy

    output = copy.deepcopy(items)
    for item in output:
        if item["kind"] == "word" and item["id"] in breakdowns_by_id:
            breakdown = breakdowns_by_id[item["id"]]
            item["wordBreakdown"] = {
                "combinations": copy.deepcopy(breakdown["combinations"]),
                "minimal": copy.deepcopy(breakdown["minimal"]),
            }
        else:
            item.pop("wordBreakdown", None)
    return output


def load_dialogue_breakdowns(path: Path = DIALOGUE_BREAKDOWN_PATH) -> dict:
    with path.open(encoding="utf-8") as file:
        return json.load(file)


def _validate_dialogue_segments(record_id: str, turn_index: int, segments: object, text: str) -> None:
    if not isinstance(segments, list) or not segments:
        raise ValueError(f"{record_id}: dialogue turn {turn_index} segments must be non-empty")
    for segment in segments:
        if not isinstance(segment, dict):
            raise ValueError(f"{record_id}: invalid dialogue segment")
        _require_exact_keys(segment, {"thai", "gloss"}, f"dialogue segment {record_id}")
        if not isinstance(segment.get("thai"), str) or not segment["thai"].strip() or not isinstance(segment.get("gloss"), str) or not segment["gloss"].strip():
            raise ValueError(f"{record_id}: invalid dialogue segment")
    if _normalized_text("".join(segment["thai"] for segment in segments)) != _normalized_text(text):
        raise ValueError(f"{record_id}: dialogue turn {turn_index} segments do not reconstruct Thai")


def validate_dialogue_breakdowns(source: dict, base_items: list[dict]) -> dict[str, list[dict]]:
    _require_exact_keys(source, {"schemaVersion", "locale", "recordCount", "items"}, "dialogue breakdown source")
    records = source.get("items")
    if source.get("schemaVersion") != 1 or source.get("locale") != "zh-Hans" or not isinstance(records, list) or source.get("recordCount") != len(records):
        raise ValueError("invalid dialogue breakdown source metadata")
    dialogues = {item["id"]: item for item in base_items if item["kind"] == "dialogue"}
    ids = [record.get("id") if isinstance(record, dict) else None for record in records]
    if ids != sorted(ids) or len(ids) != len(set(ids)) or set(ids) != set(dialogues):
        raise ValueError("dialogue breakdown IDs do not match generated dialogue IDs")
    result = {}
    for record in records:
        _require_exact_keys(record, {"id", "turns"}, f"dialogue breakdown record {record['id']}")
        turns = record["turns"]
        item = dialogues[record["id"]]
        thai_lines = item["thai"].split("\n")
        meaning_lines = item["meaningZhHans"].split("\n")
        if not isinstance(turns, list) or not turns or len(turns) != len(thai_lines) or len(turns) != len(meaning_lines):
            raise ValueError(f"{record['id']}: dialogue turn count mismatch")
        for index, turn in enumerate(turns):
            _require_exact_keys(turn, {"speaker", "thai", "meaningZhHans", "segments"}, f"dialogue turn {record['id']}")
            if not all(isinstance(turn[key], str) and turn[key].strip() for key in ("speaker", "thai", "meaningZhHans")):
                raise ValueError(f"{record['id']}: invalid dialogue turn")
            prefix = f"{turn['speaker']}:"
            if not thai_lines[index].startswith(prefix) or not meaning_lines[index].startswith(prefix):
                raise ValueError(f"{record['id']}: dialogue speaker mismatch")
            if unicodedata.normalize("NFC", thai_lines[index][len(prefix):].strip()) != unicodedata.normalize("NFC", turn["thai"]).strip() or unicodedata.normalize("NFC", meaning_lines[index][len(prefix):].strip()) != unicodedata.normalize("NFC", turn["meaningZhHans"]).strip():
                raise ValueError(f"{record['id']}: dialogue line mismatch")
            _validate_dialogue_segments(record["id"], index, turn["segments"], turn["thai"])
        result[record["id"]] = turns
    return result


def apply_dialogue_breakdowns(items: list[dict], breakdowns_by_id: dict[str, list[dict]]) -> list[dict]:
    import copy
    output = copy.deepcopy(items)
    for item in output:
        if item["kind"] == "dialogue":
            item["dialogueBreakdown"] = copy.deepcopy(breakdowns_by_id[item["id"]])
        else:
            item.pop("dialogueBreakdown", None)
    return output


def _baseline_payload(source: dict) -> list[dict]:
    return [
        {"id": record["id"], "example": record["example"], "segments": record["segments"]}
        for record in source["items"]
    ]


def _validate_coverage(coverage: dict) -> list[str]:
    _require_exact_keys(
        coverage,
        {"schemaVersion", "recordCount", "categoryCounts", "expectedIDs", "baselineExampleSegmentsSHA256"},
        "example coverage",
    )
    if coverage.get("schemaVersion") != 1:
        raise ValueError("example coverage schemaVersion must be 1")
    if coverage.get("recordCount") != 654:
        raise ValueError("example coverage recordCount must be 654")
    if coverage.get("categoryCounts") != EXPECTED_EXAMPLE_CATEGORY_COUNTS:
        raise ValueError("example coverage categoryCounts do not match the fixed contract")

    expected_ids = coverage.get("expectedIDs")
    if not isinstance(expected_ids, list) or len(expected_ids) != 654:
        raise ValueError("example coverage expectedIDs must contain exactly 654 IDs")
    if expected_ids != sorted(expected_ids) or len(set(expected_ids)) != len(expected_ids):
        raise ValueError("example coverage expectedIDs must be unique and sorted")
    category_counts = {}
    for expected_id in expected_ids:
        category = expected_id.rsplit("-", 2)[0]
        category_counts[category] = category_counts.get(category, 0) + 1
    if category_counts != EXPECTED_EXAMPLE_CATEGORY_COUNTS:
        raise ValueError("example coverage expectedIDs category distribution is invalid")
    return expected_ids


def _validate_segments(record: dict) -> None:
    segments = record.get("segments")
    if not isinstance(segments, list) or not segments:
        raise ValueError(f"{record.get('id', '<unknown>')}: segments must be non-empty")
    for segment in segments:
        if not isinstance(segment, dict):
            raise ValueError(f"{record.get('id', '<unknown>')}: invalid segment")
        _require_exact_keys(segment, {"thai", "gloss"}, f"segment {record.get('id', '<unknown>')}")
        if (
            not isinstance(segment.get("thai"), str)
            or not segment["thai"].strip()
            or not isinstance(segment.get("gloss"), str)
            or not segment["gloss"].strip()
        ):
            raise ValueError(f"{record.get('id', '<unknown>')}: invalid segment")
    if _normalized_text("".join(segment["thai"] for segment in segments)) != _normalized_text(record["example"]):
        raise ValueError(f"{record['id']}: segments do not reconstruct example")


def validate_example_source(source: dict, coverage: dict, base_items: list[dict]) -> None:
    _require_exact_keys(source, {"schemaVersion", "locale", "recordCount", "items"}, "example source")
    if source.get("schemaVersion") != 1:
        raise ValueError("example source schemaVersion must be 1")
    if source.get("locale") != "zh-Hans":
        raise ValueError("example source locale must be zh-Hans")
    if source.get("recordCount") != 654:
        raise ValueError("example source recordCount must be 654")

    expected_ids = _validate_coverage(coverage)
    records = source.get("items")
    if not isinstance(records, list) or len(records) != 654:
        raise ValueError("example source must contain exactly 654 records")
    ids = [record.get("id") for record in records]
    if ids != sorted(ids) or len(set(ids)) != len(ids):
        raise ValueError("example source IDs must be unique and sorted")
    if ids != expected_ids:
        raise ValueError("example source IDs do not match coverage expectedIDs")

    base_by_id = {item["id"]: item for item in base_items}
    if len(base_by_id) < 1200:
        raise ValueError("base content is missing generated IDs")

    for record in records:
        _require_exact_keys(
            record,
            {"id", "example", "exampleMeaning", "segments", "review"},
            f"example record {record.get('id', '<unknown>')}",
        )
        record_id = record.get("id")
        if record_id not in base_by_id:
            raise ValueError(f"unknown example source ID: {record_id}")
        if not isinstance(record.get("example"), str) or not record["example"].strip():
            raise ValueError(f"{record_id}: example must be non-empty")
        if not isinstance(record.get("exampleMeaning"), str) or not record["exampleMeaning"].strip():
            raise ValueError(f"{record_id}: exampleMeaning must be non-empty")
        review = record.get("review")
        if not isinstance(review, dict):
            raise ValueError(f"{record_id}: review must be an object")
        _require_exact_keys(review, {"status", "reviewedBy", "reviewedAt"}, f"review {record_id}")
        if review.get("status") != "approved":
            raise ValueError(f"{record_id}: review.status must be approved")
        if not review.get("reviewedBy") or not review.get("reviewedAt"):
            raise ValueError(f"{record_id}: review metadata is incomplete")
        reviewed_at = review["reviewedAt"]
        try:
            parsed_date = date.fromisoformat(reviewed_at)
        except (TypeError, ValueError) as error:
            raise ValueError(f"{record_id}: review.reviewedAt must be a real YYYY-MM-DD date") from error
        if parsed_date.isoformat() != reviewed_at:
            raise ValueError(f"{record_id}: review.reviewedAt must be a real YYYY-MM-DD date")
        if any(label in record["exampleMeaning"] for label in KNOWN_SEGMENT_LABEL_RESIDUE):
            raise ValueError(f"{record_id}: exampleMeaning contains segment-label residue")
        _validate_segments(record)

        gloss_text = "".join(segment["gloss"] for segment in record["segments"])
        if _normalized_example_meaning(record["exampleMeaning"]) == _normalized_example_meaning(gloss_text):
            raise ValueError(f"{record_id}: exampleMeaning is a mechanical gloss concatenation")

    baseline_bytes = json.dumps(
        _baseline_payload(source), ensure_ascii=False, separators=(",", ":")
    ).encode("utf-8")
    expected_baseline_hash = coverage.get("baselineExampleSegmentsSHA256")
    if hashlib.sha256(baseline_bytes).hexdigest() != expected_baseline_hash:
        raise ValueError("example/segments baseline checksum mismatch")


def apply_example_overlay(base_items: list[dict], source: dict, coverage: dict) -> list[dict]:
    import copy

    output = copy.deepcopy(base_items)
    source_by_id = {record["id"]: record for record in source["items"]}
    for item in output:
        record = source_by_id.get(item["id"])
        if record is None:
            continue
        item["example"] = record["example"]
        item["exampleMeaning"] = record["exampleMeaning"]
        item["segments"] = copy.deepcopy(record["segments"])
    return output


def apply_existing_baseline_metadata(base_items: list[dict], current_items: list[dict]) -> list[dict]:
    import copy

    base_by_id = {item["id"]: item for item in base_items}
    current_by_id = {item["id"]: item for item in current_items}
    merged = []
    for generated in base_items:
        current = current_by_id.get(generated["id"])
        if current is None:
            if generated["id"] not in GOOGLE_MAPS_LANDMARK_IDS:
                raise ValueError(f"current content baseline is missing generated base ID: {generated['id']}")
            # These explicitly reviewed landmark records are the intentional
            # append-only content change in this generation.
            merged.append(copy.deepcopy(generated))
            continue
        for key in (set(generated) | set(current)) - GENERATED_CONTENT_FIELDS - PRESERVED_BASELINE_FIELDS:
            if generated.get(key) != current.get(key):
                raise ValueError(f"unexpected current content drift: {generated['id']} field {key}")
        preserved = copy.deepcopy(generated)
        preserved["example"] = copy.deepcopy(current.get("example", ""))
        preserved["segments"] = copy.deepcopy(current.get("segments", []))
        for key in PRESERVED_BASELINE_FIELDS:
            if key in current:
                preserved[key] = copy.deepcopy(current[key])
        merged.append(preserved)
    return merged


def _validate_generated_output(items: list[dict], source: dict, coverage: dict) -> None:
    expected_ids = set(_validate_coverage(coverage))
    output_by_id = {item["id"]: item for item in items}
    for item in items:
        has_example = bool((item.get("example") or "").strip())
        has_example_meaning = bool((item.get("exampleMeaning") or "").strip())
        if has_example != has_example_meaning:
            raise ValueError(f"generated example/exampleMeaning pair is incomplete: {item['id']}")
        if has_example and not item.get("segments"):
            raise ValueError(f"generated example has no segments: {item['id']}")
    example_ids = {
        item["id"]
        for item in items
        if item.get("example") and item.get("category") not in EXTRA_EXAMPLE_CATEGORIES
    }
    if example_ids != expected_ids:
        raise ValueError("generated example IDs do not match coverage expectedIDs")
    source_by_id = {record["id"]: record for record in source["items"]}
    for record_id in expected_ids:
        item = output_by_id[record_id]
        record = source_by_id[record_id]
        if item.get("example") != record["example"]:
            raise ValueError(f"generated example drifted: {record_id}")
        if item.get("exampleMeaning") != record["exampleMeaning"]:
            raise ValueError(f"generated exampleMeaning drifted: {record_id}")
        if item.get("segments") != record["segments"]:
            raise ValueError(f"generated segments drifted: {record_id}")
    overlay_meanings = sum(
        bool(item.get("exampleMeaning"))
        for item in items
        if item.get("category") not in EXTRA_EXAMPLE_CATEGORIES
    )
    if overlay_meanings != 654:
        raise ValueError("generated content must contain exactly 654 exampleMeaning values")


def serialize_generated_items(items: list[dict]) -> bytes:
    return (json.dumps(items, ensure_ascii=False, indent=2) + "\n").encode("utf-8")


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=path.parent, prefix=f".{path.name}.", delete=False) as temp:
        temp.write(data)
        temporary_path = Path(temp.name)
    os.replace(temporary_path, path)


def generate_to_paths(source: dict, coverage: dict, output_root: Path = ROOT) -> None:
    base_items = generate_base_items()
    validate_example_source(source, coverage, base_items)
    baseline_path = output_root / "ThaiLife" / "Resources" / "Content" / "items.json"
    if not baseline_path.exists():
        raise ValueError(f"current content baseline is missing: {baseline_path}")
    with baseline_path.open(encoding="utf-8") as baseline_file:
        current_items = json.load(baseline_file)
    base_items = apply_existing_baseline_metadata(base_items, current_items)
    base_items = append_extra_food_dining_words(base_items)
    base_items = append_google_maps_words(base_items)
    base_items = append_core_function_words(base_items)
    chunk_source = load_chunk_breakdowns()
    breakdowns_by_id = validate_chunk_breakdowns(chunk_source, base_items)
    dialogue_source = load_dialogue_breakdowns()
    dialogue_breakdowns_by_id = validate_dialogue_breakdowns(dialogue_source, base_items)
    output_items = apply_example_overlay(base_items, source, coverage)
    output_items = apply_chunk_breakdowns(output_items, breakdowns_by_id)
    output_items = apply_dialogue_breakdowns(output_items, dialogue_breakdowns_by_id)
    word_source = load_word_breakdowns()
    word_breakdowns_by_id = validate_word_breakdowns(word_source, output_items)
    output_items = apply_word_breakdowns(output_items, word_breakdowns_by_id)

    items_bytes = serialize_generated_items(output_items)
    checksum = hashlib.sha256(items_bytes).hexdigest()
    manifest = {
        "version": 1,
        "itemCount": len(output_items),
        "generatedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "checksumSHA256": checksum,
    }
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8")

    content_dir = output_root / "ThaiLife" / "Resources" / "Content"
    _atomic_write(content_dir / "items.json", items_bytes)
    _atomic_write(content_dir / "content-manifest.json", manifest_bytes)
    print(f"\nWrote {content_dir / 'items.json'}")
    print(f"Wrote {content_dir / 'content-manifest.json'}")
    print(f"SHA-256: {checksum}")


def main():
    source = load_example_source()
    coverage = load_example_coverage()
    generate_to_paths(source, coverage)


if __name__ == "__main__":
    main()
