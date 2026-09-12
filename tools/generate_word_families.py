#!/usr/bin/env python3
"""
Generate root word families (词根/前缀词族卡片) dataset for ThaiLife.
Scans items.json for common Thai root words / prefixes and outputs bundled word_families.json.
"""

import json
import os
import sys

CONTENT_PATH = "ThaiLife/Resources/Content/items.json"
OUTPUT_PATH = "ThaiLife/Resources/Content/word_families.json"

ROOT_DEFINITIONS = [
    {
        "id": "family-mai",
        "rootThai": "ไม่",
        "rootRomanization": "mài",
        "rootMeaningZhHans": "不 (否定前缀)",
        "usageNote": "泰语中最核心的否定词，置于动词、形容词或助动词前表示否定。",
        "category": "basics",
        "rootAudioID": ""  # Single word TTS for "ไม่"
    },
    {
        "id": "family-kho",
        "rootThai": "ขอ",
        "rootRomanization": "khɔ̌ɔ",
        "rootMeaningZhHans": "请 / 要 / 索取",
        "usageNote": "泰语最高频的礼貌索取前缀，点餐、购物及寻求帮助时置于句首。",
        "category": "basics",
        "rootAudioID": ""  # Single word TTS for "ขอ"
    },
    {
        "id": "family-thii",
        "rootThai": "ที่",
        "rootRomanization": "thîi",
        "rootMeaningZhHans": "场所 / 设施 / 地方",
        "usageNote": "名词性前缀，后接动作或用途词汇，构成各类公共场所或设施名称。",
        "category": "local_errands",
        "rootAudioID": ""  # Single word TTS for "ที่"
    },
    {
        "id": "family-nam",
        "rootThai": "น้ำ",
        "rootRomanization": "náam",
        "rootMeaningZhHans": "水 / 液体",
        "usageNote": "常用于名词前构成各类饮品、水体及与水相关的设施名称。",
        "category": "food_dining",
        "rootAudioID": "audio-food_dining-word-002"
    },
    {
        "id": "family-rot",
        "rootThai": "รถ",
        "rootRomanization": "rót",
        "rootMeaningZhHans": "车 / 车辆",
        "usageNote": "表示各类陆上交通工具，后面加修饰词表示具体车种。",
        "category": "transport",
        "rootAudioID": "audio-transport-word-001"
    },
    {
        "id": "family-hong",
        "rootThai": "ห้อง",
        "rootRomanization": "hɔ̂ɔŋ",
        "rootMeaningZhHans": "房间 / 空间",
        "usageNote": "表示各类特定用途的房间或建筑物内部空间。",
        "category": "hotel",
        "rootAudioID": "audio-home_living-word-002"
    },
    {
        "id": "family-puat",
        "rootThai": "ปวด",
        "rootRomanization": "pùat",
        "rootMeaningZhHans": "疼 / 疼痛",
        "usageNote": "健康与就医高频词根，后接身体器官名称表示具体疼痛部位。",
        "category": "health",
        "rootAudioID": "audio-health-word-012"
    },
    {
        "id": "family-pen",
        "rootThai": "เป็น",
        "rootRomanization": "pen",
        "rootMeaningZhHans": "患病 / 处于...状态",
        "usageNote": "描述身体健康状况或罹患具体病症时的前缀动词。",
        "category": "health",
        "rootAudioID": "audio-basics-word-015"
    },
    {
        "id": "family-chaang",
        "rootThai": "ช่าง",
        "rootRomanization": "châang",
        "rootMeaningZhHans": "师傅 / 维修工",
        "usageNote": "职业前缀，后面接维修领域或专业，表示各类专业技术工种。",
        "category": "home_living",
        "rootAudioID": "audio-local_errands-word-035"
    },
    {
        "id": "family-krapao",
        "rootThai": "กระเป๋า",
        "rootRomanization": "krà-pǎo",
        "rootMeaningZhHans": "包 / 行李 / 袋子",
        "usageNote": "随身物品与出行词根，表示各类包具、手袋及行李。",
        "category": "airport",
        "rootAudioID": "audio-shopping-word-010"
    },
    {
        "id": "family-tuu",
        "rootThai": "ตู้",
        "rootRomanization": "tûu",
        "rootMeaningZhHans": "柜 / 箱 / 自动机",
        "usageNote": "家具与自助设施前缀，用于各类柜子及自助服务终端。",
        "category": "home_living",
        "rootAudioID": "audio-home_living-word-012"
    },
    {
        "id": "family-wan",
        "rootThai": "วัน",
        "rootRomanization": "wan",
        "rootMeaningZhHans": "天 / 日 / 星期",
        "usageNote": "时间相关词根，常用于表示日期、节日及特定日子。",
        "category": "numbers",
        "rootAudioID": "audio-numbers-word-017"
    },
    {
        "id": "family-bai",
        "rootThai": "ใบ",
        "rootRomanization": "bai",
        "rootMeaningZhHans": "单据 / 证件 / 叶片",
        "usageNote": "作为量词或前缀，常用于各类票据、证书、执照及卡片。",
        "category": "shopping",
        "rootAudioID": ""  # Single word TTS for "ใบ"
    },
    {
        "id": "family-kin",
        "rootThai": "กิน",
        "rootRomanization": "kin",
        "rootMeaningZhHans": "吃 / 饮食",
        "usageNote": "口语中最常用的“吃”字，构词丰富，涵盖日常各种就餐表达。",
        "category": "food_dining",
        "rootAudioID": "audio-basics-word-020"
    },
    {
        "id": "family-phat",
        "rootThai": "ผัด",
        "rootRomanization": "phàt",
        "rootMeaningZhHans": "炒 / 炒菜",
        "usageNote": "烹饪动词，后面接食材构成各类泰式炒菜名。",
        "category": "food_dining",
        "rootAudioID": "audio-food_dining-word-041"
    }
]

def main():
    if not os.path.exists(CONTENT_PATH):
        print(f"Error: {CONTENT_PATH} not found.")
        sys.exit(1)

    with open(CONTENT_PATH, "r", encoding="utf-8") as f:
        items = json.load(f)

    result_families = []

    for root_def in ROOT_DEFINITIONS:
        root_thai = root_def["rootThai"]
        matching_members = []
        seen_thai = set()

        words_and_chunks = [i for i in items if i.get("kind") in ["word", "chunk"]]
        sentences = [i for i in items if i.get("kind") not in ["word", "chunk"]]

        for item in words_and_chunks + sentences:
            thai = item.get("thai", "")
            if thai.startswith(root_thai) and thai != root_thai:
                if thai not in seen_thai and len(thai) <= 25:
                    seen_thai.add(thai)
                    matching_members.append({
                        "id": item["id"],
                        "thai": item["thai"],
                        "romanization": item.get("romanization", ""),
                        "meaningZhHans": item.get("meaningZhHans", ""),
                        "audioID": item.get("audioID", "")
                    })

        matching_members.sort(key=lambda x: len(x["thai"]))
        top_members = matching_members[:10]

        family_data = {
            "id": root_def["id"],
            "rootThai": root_def["rootThai"],
            "rootRomanization": root_def["rootRomanization"],
            "rootMeaningZhHans": root_def["rootMeaningZhHans"],
            "rootAudioID": root_def.get("rootAudioID", ""),
            "usageNote": root_def["usageNote"],
            "category": root_def["category"],
            "itemCount": len(top_members),
            "items": top_members
        }
        result_families.append(family_data)
        print(f"Family {root_def['rootThai']} ({root_def['rootMeaningZhHans']}): rootAudioID = '{family_data['rootAudioID']}'")

    with open(OUTPUT_PATH, "w", encoding="utf-8") as f:
        json.dump(result_families, f, ensure_ascii=False, indent=2)

    print(f"\nSuccessfully regenerated {len(result_families)} word families to {OUTPUT_PATH}")

if __name__ == "__main__":
    main()
