#!/usr/bin/env python3
"""Expand Thai menu cards to 56 items with accurate breakdowns, images, and audio."""

import hashlib
import json
import os
import re
import subprocess
import time
import urllib.parse
import urllib.request
import unicodedata

MENU_JSON_PATH = "ThaiLife/Resources/Content/thai_menu_reference.json"
AUDIO_DIR = "ThaiLife/Resources/Audio"
IMAGE_DIR = "ThaiLife/Resources/ThaiMenu"
ATTRIBUTIONS_PATH = "ThaiLife/Resources/Attributions/thai-menu-assets.md"

CARDS = [
    # 1. Pad Thai
    {
        "id": "pad-thai",
        "category": "米饭与面食",
        "thai": "ผัดไทย",
        "meaningZhHans": "泰式炒粉",
        "audioID": "audio-food_dining-word-049",
        "imageAssetID": "pad-thai",
        "searchQuery": "Pad Thai",
        "breakdown": {
            "combinations": [
                {"thai": "ผัด", "glossZhHans": "炒；翻炒"},
                {"thai": "ไทย", "glossZhHans": "泰国的；泰式的"}
            ],
            "minimal": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ไทย", "glossZhHans": "泰国的"}
            ]
        }
    },
    # 2. Tom Yum Kung
    {
        "id": "tom-yum-kung",
        "category": "汤与咖喱",
        "thai": "ต้มยำกุ้ง",
        "meaningZhHans": "冬阴功虾汤",
        "audioID": "audio-food_dining-word-048",
        "imageAssetID": "tom-yum",
        "searchQuery": "Tom Yum",
        "breakdown": {
            "combinations": [
                {"thai": "ต้มยำ", "glossZhHans": "冬阴功汤"},
                {"thai": "กุ้ง", "glossZhHans": "虾"}
            ],
            "minimal": [
                {"thai": "ต้ม", "glossZhHans": "煮；汤"},
                {"thai": "ยำ", "glossZhHans": "酸辣拌味"},
                {"thai": "กุ้ง", "glossZhHans": "虾"}
            ]
        }
    },
    # 3. Green Curry
    {
        "id": "green-curry",
        "category": "汤与咖喱",
        "thai": "แกงเขียวหวาน",
        "meaningZhHans": "绿咖喱",
        "audioID": "audio-food_dining-word-051",
        "imageAssetID": "green-curry",
        "searchQuery": "Green Curry Thai",
        "breakdown": {
            "combinations": [
                {"thai": "แกง", "glossZhHans": "咖喱；汤菜"},
                {"thai": "เขียว", "glossZhHans": "绿色的"},
                {"thai": "หวาน", "glossZhHans": "甜的"}
            ],
            "minimal": [
                {"thai": "แกง", "glossZhHans": "咖喱菜"},
                {"thai": "เขียว", "glossZhHans": "绿色"},
                {"thai": "หวาน", "glossZhHans": "甜"}
            ]
        }
    },
    # 4. Som Tam
    {
        "id": "som-tam",
        "category": "烧烤与小吃",
        "thai": "ส้มตำ",
        "meaningZhHans": "青木瓜沙拉",
        "audioID": "audio-food_dining-word-047",
        "imageAssetID": "som-tam",
        "searchQuery": "Som Tam",
        "breakdown": {
            "combinations": [
                {"thai": "ส้ม", "glossZhHans": "酸的；酸味"},
                {"thai": "ตำ", "glossZhHans": "捣；舂拌"}
            ],
            "minimal": [
                {"thai": "ส้ม", "glossZhHans": "酸味"},
                {"thai": "ตำ", "glossZhHans": "捣拌"}
            ]
        }
    },
    # 5. Mango Sticky Rice
    {
        "id": "mango-sticky-rice",
        "category": "饮料与甜品",
        "thai": "ข้าวเหนียวมะม่วง",
        "meaningZhHans": "芒果糯米饭",
        "audioID": "audio-food_dining-word-076",
        "imageAssetID": "mango-sticky",
        "searchQuery": "Mango Sticky Rice",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าวเหนียว", "glossZhHans": "糯米饭"},
                {"thai": "มะม่วง", "glossZhHans": "芒果"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "เหนียว", "glossZhHans": "黏的；糯的"},
                {"thai": "มะม่วง", "glossZhHans": "芒果"}
            ]
        }
    },
    # 6. Thai Milk Tea
    {
        "id": "thai-milk-tea",
        "category": "饮料与甜品",
        "thai": "ชาไทย",
        "meaningZhHans": "泰奶；泰式奶茶",
        "audioID": "audio-food_dining-word-070",
        "imageAssetID": "thai-milk-tea",
        "searchQuery": "Cha yen Thai tea",
        "breakdown": {
            "combinations": [
                {"thai": "ชา", "glossZhHans": "茶"},
                {"thai": "ไทย", "glossZhHans": "泰国的；泰式的"}
            ],
            "minimal": [
                {"thai": "ชา", "glossZhHans": "茶"},
                {"thai": "ไทย", "glossZhHans": "泰式的"}
            ]
        }
    },
    # 7. Coconut Water
    {
        "id": "coconut-water",
        "category": "饮料与甜品",
        "thai": "น้ำมะพร้าว",
        "meaningZhHans": "椰子水",
        "audioID": "audio-food_dining-word-071",
        "imageAssetID": "coconut-water",
        "searchQuery": "Coconut drink",
        "breakdown": {
            "combinations": [
                {"thai": "น้ำ", "glossZhHans": "水"},
                {"thai": "มะพร้าว", "glossZhHans": "椰子"}
            ],
            "minimal": [
                {"thai": "น้ำ", "glossZhHans": "水"},
                {"thai": "มะพร้าว", "glossZhHans": "椰子"}
            ]
        }
    },
    # 8. Khao Man Gai
    {
        "id": "khao-man-gai",
        "category": "米饭与面食",
        "thai": "ข้าวมันไก่",
        "meaningZhHans": "海南鸡饭",
        "audioID": "thai-menu-khao-man-gai",
        "imageAssetID": "khao-man-gai",
        "searchQuery": "Khao man kai",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าวมัน", "glossZhHans": "油饭；鸡油饭"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "มัน", "glossZhHans": "油；油润"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ]
        }
    },
    # 9. Pad See Ew
    {
        "id": "pad-see-ew",
        "category": "米饭与面食",
        "thai": "ผัดซีอิ๊ว",
        "meaningZhHans": "泰式炒酱油粉",
        "audioID": "thai-menu-pad-see-ew",
        "imageAssetID": "pad-see-ew",
        "searchQuery": "Pad see ew",
        "breakdown": {
            "combinations": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ซีอิ๊ว", "glossZhHans": "酱油"}
            ],
            "minimal": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ซีอิ๊ว", "glossZhHans": "酱油"}
            ]
        }
    },
    # 10. Pad Kra Pao
    {
        "id": "pad-kra-pao",
        "category": "米饭与面食",
        "thai": "ผัดกะเพรา",
        "meaningZhHans": "打抛饭／九层塔炒肉",
        "audioID": "audio-food_dining-word-052",
        "imageAssetID": "pad-kra-pao",
        "searchQuery": "Phat kaphrao",
        "breakdown": {
            "combinations": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "กะเพรา", "glossZhHans": "圣罗勒；打抛叶"}
            ],
            "minimal": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "กะเพรา", "glossZhHans": "圣罗勒"}
            ]
        }
    },
    # 11. Massaman Curry
    {
        "id": "massaman-curry",
        "category": "汤与咖喱",
        "thai": "แกงมัสมั่น",
        "meaningZhHans": "玛莎曼咖喱",
        "audioID": "thai-menu-massaman",
        "imageAssetID": "massaman",
        "searchQuery": "Massaman curry",
        "breakdown": {
            "combinations": [
                {"thai": "แกง", "glossZhHans": "咖喱；汤菜"},
                {"thai": "มัสมั่น", "glossZhHans": "玛莎曼"}
            ],
            "minimal": [
                {"thai": "แกง", "glossZhHans": "咖喱菜"},
                {"thai": "มัสมั่น", "glossZhHans": "玛莎曼"}
            ]
        }
    },
    # 12. Tom Kha Gai
    {
        "id": "tom-kha-gai",
        "category": "汤与咖喱",
        "thai": "ต้มข่าไก่",
        "meaningZhHans": "椰奶鸡汤",
        "audioID": "audio-food_dining-word-077",
        "imageAssetID": "tom-kha",
        "searchQuery": "Tom kha gai",
        "breakdown": {
            "combinations": [
                {"thai": "ต้มข่า", "glossZhHans": "椰奶汤底"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ],
            "minimal": [
                {"thai": "ต้ม", "glossZhHans": "煮；汤"},
                {"thai": "ข่า", "glossZhHans": "南姜"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ]
        }
    },
    # 13. Gai Yang
    {
        "id": "gai-yang",
        "category": "烧烤与小吃",
        "thai": "ไก่ย่าง",
        "meaningZhHans": "烤鸡",
        "audioID": "thai-menu-gai-yang",
        "imageAssetID": "gai-yang",
        "searchQuery": "Gai yang",
        "breakdown": {
            "combinations": [
                {"thai": "ไก่", "glossZhHans": "鸡肉"},
                {"thai": "ย่าง", "glossZhHans": "烤"}
            ],
            "minimal": [
                {"thai": "ไก่", "glossZhHans": "鸡肉"},
                {"thai": "ย่าง", "glossZhHans": "烤"}
            ]
        }
    },
    # 14. Boat Noodles
    {
        "id": "boat-noodles",
        "category": "米饭与面食",
        "thai": "ก๋วยเตี๋ยวเรือ",
        "meaningZhHans": "船面／船粉",
        "audioID": "thai-menu-boat-noodles",
        "imageAssetID": "boat-noodles",
        "searchQuery": "Boat noodles",
        "breakdown": {
            "combinations": [
                {"thai": "ก๋วยเตี๋ยว", "glossZhHans": "米粉；面条"},
                {"thai": "เรือ", "glossZhHans": "船"}
            ],
            "minimal": [
                {"thai": "ก๋วยเตี๋ยว", "glossZhHans": "面条"},
                {"thai": "เรือ", "glossZhHans": "船"}
            ]
        }
    },
    # 15. Spring Roll
    {
        "id": "spring-roll",
        "category": "烧烤与小吃",
        "thai": "ปอเปี๊ยะทอด",
        "meaningZhHans": "炸春卷",
        "audioID": "thai-menu-spring-roll",
        "imageAssetID": "spring-roll",
        "searchQuery": "Thai spring rolls",
        "breakdown": {
            "combinations": [
                {"thai": "ปอเปี๊ยะ", "glossZhHans": "春卷"},
                {"thai": "ทอด", "glossZhHans": "炸"}
            ],
            "minimal": [
                {"thai": "ปอเปี๊ยะ", "glossZhHans": "春卷"},
                {"thai": "ทอด", "glossZhHans": "炸"}
            ]
        }
    },
    # 16. Bangkok Pizza
    {
        "id": "bangkok-pizza",
        "category": "曼谷常见其他餐食",
        "thai": "พิซซ่า",
        "meaningZhHans": "披萨",
        "audioID": "thai-menu-pizza",
        "imageAssetID": "bangkok-pizza",
        "searchQuery": "Pizza Bangkok",
        "breakdown": {
            "combinations": [
                {"thai": "พิซซ่า", "glossZhHans": "披萨"}
            ],
            "minimal": [
                {"thai": "พิซซ่า", "glossZhHans": "披萨"}
            ]
        }
    },
    # --- NEW DISHES (17-56) ---
    # 17. Khao Pad Gai
    {
        "id": "khao-pad-gai",
        "category": "米饭与面食",
        "thai": "ข้าวผัดไก่",
        "meaningZhHans": "鸡肉炒饭",
        "audioID": "thai-menu-khao-pad-gai",
        "imageAssetID": "khao-pad-gai",
        "searchQuery": "Khao phat kai fried rice",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าวผัด", "glossZhHans": "炒饭"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ]
        }
    },
    # 18. Khao Pad Poo
    {
        "id": "khao-pad-poo",
        "category": "米饭与面食",
        "thai": "ข้าวผัดปู",
        "meaningZhHans": "蟹肉炒饭",
        "audioID": "thai-menu-khao-pad-poo",
        "imageAssetID": "khao-pad-poo",
        "searchQuery": "Khao phat pu crab fried rice",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าวผัด", "glossZhHans": "炒饭"},
                {"thai": "ปู", "glossZhHans": "螃蟹；蟹肉"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ปู", "glossZhHans": "螃蟹"}
            ]
        }
    },
    # 19. Khao Kha Moo
    {
        "id": "khao-kha-moo",
        "category": "米饭与面食",
        "thai": "ข้าวขาหมู",
        "meaningZhHans": "卤猪脚饭",
        "audioID": "thai-menu-khao-kha-moo",
        "imageAssetID": "khao-kha-moo",
        "searchQuery": "Khao kha mu pork leg",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "ขาหมู", "glossZhHans": "猪脚；卤猪蹄"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "ขา", "glossZhHans": "腿；脚"},
                {"thai": "หมู", "glossZhHans": "猪肉"}
            ]
        }
    },
    # 20. Khao Moo Daeng
    {
        "id": "khao-moo-daeng",
        "category": "米饭与面食",
        "thai": "ข้าวหมูแดง",
        "meaningZhHans": "泰式叉烧饭",
        "audioID": "thai-menu-khao-moo-daeng",
        "imageAssetID": "khao-moo-daeng",
        "searchQuery": "Khao mu daeng red pork",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "หมูแดง", "glossZhHans": "叉烧肉；红猪肉"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "หมู", "glossZhHans": "猪肉"},
                {"thai": "แดง", "glossZhHans": "红色"}
            ]
        }
    },
    # 21. Khao Moo Krop
    {
        "id": "khao-moo-krop",
        "category": "米饭与面食",
        "thai": "ข้าวหมูกรอบ",
        "meaningZhHans": "脆皮烧肉饭",
        "audioID": "thai-menu-khao-moo-krop",
        "imageAssetID": "khao-moo-krop",
        "searchQuery": "Khao mu krop crispy pork",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "หมูกรอบ", "glossZhHans": "脆皮烧肉"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "หมู", "glossZhHans": "猪肉"},
                {"thai": "กรอบ", "glossZhHans": "香脆"}
            ]
        }
    },
    # 22. Khao Soi
    {
        "id": "khao-soi",
        "category": "米饭与面食",
        "thai": "ข้าวซอย",
        "meaningZhHans": "清迈泰北咖喱面",
        "audioID": "thai-menu-khao-soi",
        "imageAssetID": "khao-soi",
        "searchQuery": "Khao soi Chiang Mai curry noodles",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าว", "glossZhHans": "米/面主食"},
                {"thai": "ซอย", "glossZhHans": "切细条；面条"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米/面"},
                {"thai": "ซอย", "glossZhHans": "细切"}
            ]
        }
    },
    # 23. Pad Kee Mao
    {
        "id": "pad-kee-mao",
        "category": "米饭与面食",
        "thai": "ผัดขี้เมา",
        "meaningZhHans": "醉鬼炒河粉",
        "audioID": "thai-menu-pad-kee-mao",
        "imageAssetID": "pad-kee-mao",
        "searchQuery": "Phat khi mao drunken noodles",
        "breakdown": {
            "combinations": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ขี้เมา", "glossZhHans": "醉汉；极辣风味"}
            ],
            "minimal": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ขี้", "glossZhHans": "癖性/者"},
                {"thai": "เมา", "glossZhHans": "醉酒"}
            ]
        }
    },
    # 24. Rad Na
    {
        "id": "rad-na",
        "category": "米饭与面食",
        "thai": "ราดหน้า",
        "meaningZhHans": "泰式滑蛋芡汁炒粉",
        "audioID": "thai-menu-rad-na",
        "imageAssetID": "rad-na",
        "searchQuery": "Rat na Thai noodles",
        "breakdown": {
            "combinations": [
                {"thai": "ราด", "glossZhHans": "浇淋；倒在上面"},
                {"thai": "หน้า", "glossZhHans": "表面；浇头"}
            ],
            "minimal": [
                {"thai": "ราด", "glossZhHans": "浇淋"},
                {"thai": "หน้า", "glossZhHans": "面/表面"}
            ]
        }
    },
    # 25. Kuay Teow Tom Yum
    {
        "id": "kuay-teow-tom-yum",
        "category": "米饭与面食",
        "thai": "ก๋วยเตี๋ยวต้มยำ",
        "meaningZhHans": "冬阴酸辣汤粉",
        "audioID": "thai-menu-kuay-teow-tom-yum",
        "imageAssetID": "kuay-teow-tom-yum",
        "searchQuery": "Kuaitiao tom yam noodles",
        "breakdown": {
            "combinations": [
                {"thai": "ก๋วยเตี๋ยว", "glossZhHans": "面条；米粉"},
                {"thai": "ต้มยำ", "glossZhHans": "冬阴酸辣汤"}
            ],
            "minimal": [
                {"thai": "ก๋วยเตี๋ยว", "glossZhHans": "面条"},
                {"thai": "ต้ม", "glossZhHans": "煮"},
                {"thai": "ยำ", "glossZhHans": "酸辣拌"}
            ]
        }
    },
    # 26. Bami Moo Daeng
    {
        "id": "bami-moo-daeng",
        "category": "米饭与面食",
        "thai": "บะหมี่หมูแดง",
        "meaningZhHans": "叉烧鸡蛋面",
        "audioID": "thai-menu-bami-moo-daeng",
        "imageAssetID": "bami-moo-daeng",
        "searchQuery": "Bami mu daeng egg noodles red pork",
        "breakdown": {
            "combinations": [
                {"thai": "บะหมี่", "glossZhHans": "鸡蛋面"},
                {"thai": "หมูแดง", "glossZhHans": "叉烧肉"}
            ],
            "minimal": [
                {"thai": "บะหมี่", "glossZhHans": "鸡蛋面"},
                {"thai": "หมู", "glossZhHans": "猪肉"},
                {"thai": "แดง", "glossZhHans": "红色"}
            ]
        }
    },
    # 27. Khao Tom Gai
    {
        "id": "khao-tom-gai",
        "category": "米饭与面食",
        "thai": "ข้าวต้มไก่",
        "meaningZhHans": "鸡肉泡饭／鸡肉粥",
        "audioID": "thai-menu-khao-tom-gai",
        "imageAssetID": "khao-tom-gai",
        "searchQuery": "Khao tom kai rice soup chicken",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าวต้ม", "glossZhHans": "泡饭；稀饭"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "ต้ม", "glossZhHans": "煮"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ]
        }
    },
    # 28. Pad Woon Sen
    {
        "id": "pad-woon-sen",
        "category": "米饭与面食",
        "thai": "ผัดวุ้นเส้น",
        "meaningZhHans": "泰式炒粉丝",
        "audioID": "thai-menu-pad-woon-sen",
        "imageAssetID": "pad-woon-sen",
        "searchQuery": "Phat wun sen stir fried glass noodles",
        "breakdown": {
            "combinations": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "วุ้นเส้น", "glossZhHans": "粉丝；冬粉"}
            ],
            "minimal": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "วุ้น", "glossZhHans": "透明胶冻"},
                {"thai": "เส้น", "glossZhHans": "细条"}
            ]
        }
    },
    # 29. Khao Khluk Kapi
    {
        "id": "khao-khluk-kapi",
        "category": "米饭与面食",
        "thai": "ข้าวคลุกกะปิ",
        "meaningZhHans": "泰式传统虾酱拌饭",
        "audioID": "thai-menu-khao-khluk-kapi",
        "imageAssetID": "khao-khluk-kapi",
        "searchQuery": "Khao khluk kapi shrimp paste rice",
        "breakdown": {
            "combinations": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "คลุก", "glossZhHans": "拌匀；揉合"},
                {"thai": "กะปิ", "glossZhHans": "传统虾酱"}
            ],
            "minimal": [
                {"thai": "ข้าว", "glossZhHans": "米饭"},
                {"thai": "คลุก", "glossZhHans": "拌"},
                {"thai": "กะปิ", "glossZhHans": "虾酱"}
            ]
        }
    },
    # 30. Panang Curry
    {
        "id": "panang-curry",
        "category": "汤与咖喱",
        "thai": "แกงพะแนง",
        "meaningZhHans": "帕能咖喱",
        "audioID": "thai-menu-panang-curry",
        "imageAssetID": "panang-curry",
        "searchQuery": "Phanaeng curry Panang",
        "breakdown": {
            "combinations": [
                {"thai": "แกง", "glossZhHans": "咖喱菜"},
                {"thai": "พะแนง", "glossZhHans": "帕能浓香咖喱"}
            ],
            "minimal": [
                {"thai": "แกง", "glossZhHans": "咖喱"},
                {"thai": "พะแนง", "glossZhHans": "帕能"}
            ]
        }
    },
    # 31. Red Curry
    {
        "id": "red-curry",
        "category": "汤与咖喱",
        "thai": "แกงเผ็ด",
        "meaningZhHans": "泰式红咖喱",
        "audioID": "thai-menu-red-curry",
        "imageAssetID": "red-curry",
        "searchQuery": "Kaeng phet Thai red curry",
        "breakdown": {
            "combinations": [
                {"thai": "แกง", "glossZhHans": "咖喱菜"},
                {"thai": "เผ็ด", "glossZhHans": "辛辣的"}
            ],
            "minimal": [
                {"thai": "แกง", "glossZhHans": "咖喱"},
                {"thai": "เผ็ด", "glossZhHans": "辣"}
            ]
        }
    },
    # 32. Yellow Curry
    {
        "id": "yellow-curry",
        "category": "汤与咖喱",
        "thai": "แกงกะหรี่",
        "meaningZhHans": "泰式黄咖喱",
        "audioID": "thai-menu-yellow-curry",
        "imageAssetID": "yellow-curry",
        "searchQuery": "Kaeng kari Thai yellow curry",
        "breakdown": {
            "combinations": [
                {"thai": "แกง", "glossZhHans": "咖喱菜"},
                {"thai": "กะหรี่", "glossZhHans": "黄咖喱"}
            ],
            "minimal": [
                {"thai": "แกง", "glossZhHans": "咖喱"},
                {"thai": "กะหรี่", "glossZhHans": "黄咖喱"}
            ]
        }
    },
    # 33. Gaeng Som
    {
        "id": "gaeng-som",
        "category": "汤与咖喱",
        "thai": "แกงส้ม",
        "meaningZhHans": "泰南酸汤咖喱",
        "audioID": "thai-menu-gaeng-som",
        "imageAssetID": "gaeng-som",
        "searchQuery": "Kaeng som Thai sour curry",
        "breakdown": {
            "combinations": [
                {"thai": "แกง", "glossZhHans": "咖喱；汤菜"},
                {"thai": "ส้ม", "glossZhHans": "酸味的"}
            ],
            "minimal": [
                {"thai": "แกง", "glossZhHans": "汤菜"},
                {"thai": "ส้ม", "glossZhHans": "酸味"}
            ]
        }
    },
    # 34. Tom Saep
    {
        "id": "tom-saep",
        "category": "汤与咖喱",
        "thai": "ต้มแซ่บ",
        "meaningZhHans": "东北酸辣排骨汤",
        "audioID": "thai-menu-tom-saep",
        "imageAssetID": "tom-saep",
        "searchQuery": "Tom saep pork soup Isan",
        "breakdown": {
            "combinations": [
                {"thai": "ต้ม", "glossZhHans": "煮汤"},
                {"thai": "แซ่บ", "glossZhHans": "酸辣浓郁；美味"}
            ],
            "minimal": [
                {"thai": "ต้ม", "glossZhHans": "煮"},
                {"thai": "แซ่บ", "glossZhHans": "美味爽辣"}
            ]
        }
    },
    # 35. Tom Jued Taohu
    {
        "id": "tom-jued-taohu",
        "category": "汤与咖喱",
        "thai": "ต้มจืดเต้าหู้",
        "meaningZhHans": "豆腐清汤",
        "audioID": "thai-menu-tom-jued-taohu",
        "imageAssetID": "tom-jued-taohu",
        "searchQuery": "Tom chuet taohu clear soup tofu",
        "breakdown": {
            "combinations": [
                {"thai": "ต้มจืด", "glossZhHans": "清淡煮汤"},
                {"thai": "เต้าหู้", "glossZhHans": "豆腐"}
            ],
            "minimal": [
                {"thai": "ต้ม", "glossZhHans": "煮"},
                {"thai": "จืด", "glossZhHans": "清淡"},
                {"thai": "เต้าหู้", "glossZhHans": "豆腐"}
            ]
        }
    },
    # 36. Gaeng Liang
    {
        "id": "gaeng-liang",
        "category": "汤与咖喱",
        "thai": "แกงเลียง",
        "meaningZhHans": "泰式香草胡椒杂菜汤",
        "audioID": "thai-menu-gaeng-liang",
        "imageAssetID": "gaeng-liang",
        "searchQuery": "Kaeng liang spicy vegetable soup Thai",
        "breakdown": {
            "combinations": [
                {"thai": "แกง", "glossZhHans": "汤菜"},
                {"thai": "เลียง", "glossZhHans": "传统香草蔬菜煮法"}
            ],
            "minimal": [
                {"thai": "แกง", "glossZhHans": "汤菜"},
                {"thai": "เลียง", "glossZhHans": "香草蔬菜煮法"}
            ]
        }
    },
    # 37. Poo Pad Pong Karee
    {
        "id": "poo-pad-pong-karee",
        "category": "海鲜与炒菜",
        "thai": "ปูผัดผงกะหรี่",
        "meaningZhHans": "黄咖喱炒蟹",
        "audioID": "thai-menu-poo-pad-pong-karee",
        "imageAssetID": "poo-pad-pong-karee",
        "searchQuery": "Pu phat phong kari fried crab curry",
        "breakdown": {
            "combinations": [
                {"thai": "ปู", "glossZhHans": "螃蟹"},
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ผงกะหรี่", "glossZhHans": "咖喱粉"}
            ],
            "minimal": [
                {"thai": "ปู", "glossZhHans": "螃蟹"},
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ผง", "glossZhHans": "粉末"},
                {"thai": "กะหรี่", "glossZhHans": "咖喱"}
            ]
        }
    },
    # 38. Kung Ob Woon Sen
    {
        "id": "kung-ob-woon-sen",
        "category": "海鲜与炒菜",
        "thai": "กุ้งอบวุ้นเส้น",
        "meaningZhHans": "鲜虾粉丝煲",
        "audioID": "thai-menu-kung-ob-woon-sen",
        "imageAssetID": "kung-ob-woon-sen",
        "searchQuery": "Kung op wun sen prawn glass noodles",
        "breakdown": {
            "combinations": [
                {"thai": "กุ้ง", "glossZhHans": "鲜虾"},
                {"thai": "อบ", "glossZhHans": "焖焗；烤烘"},
                {"thai": "วุ้นเส้น", "glossZhHans": "粉丝；冬粉"}
            ],
            "minimal": [
                {"thai": "กุ้ง", "glossZhHans": "虾"},
                {"thai": "อบ", "glossZhHans": "焖焗"},
                {"thai": "วุ้น", "glossZhHans": "透明胶冻"},
                {"thai": "เส้น", "glossZhHans": "细条"}
            ]
        }
    },
    # 39. Pla Neung Manao
    {
        "id": "pla-neung-manao",
        "category": "海鲜与炒菜",
        "thai": "ปลานึ่งมะนาว",
        "meaningZhHans": "青柠酸辣蒸鱼",
        "audioID": "thai-menu-pla-neung-manao",
        "imageAssetID": "pla-neung-manao",
        "searchQuery": "Pla nueng manao steamed fish lime",
        "breakdown": {
            "combinations": [
                {"thai": "ปลา", "glossZhHans": "鱼"},
                {"thai": "นึ่ง", "glossZhHans": "清蒸"},
                {"thai": "มะนาว", "glossZhHans": "青柠；柠檬"}
            ],
            "minimal": [
                {"thai": "ปลา", "glossZhHans": "鱼"},
                {"thai": "นึ่ง", "glossZhHans": "蒸"},
                {"thai": "มะนาว", "glossZhHans": "青柠"}
            ]
        }
    },
    # 40. Pla Tod Nam Pla
    {
        "id": "pla-tod-nam-pla",
        "category": "海鲜与炒菜",
        "thai": "ปลาทอดน้ำปลา",
        "meaningZhHans": "香脆炸鱼佐鱼露汁",
        "audioID": "thai-menu-pla-tod-nam-pla",
        "imageAssetID": "pla-tod-nam-pla",
        "searchQuery": "Pla thot nam pla fried fish fish sauce",
        "breakdown": {
            "combinations": [
                {"thai": "ปลา", "glossZhHans": "鱼"},
                {"thai": "ทอด", "glossZhHans": "油炸"},
                {"thai": "น้ำปลา", "glossZhHans": "鱼露"}
            ],
            "minimal": [
                {"thai": "ปลา", "glossZhHans": "鱼"},
                {"thai": "ทอด", "glossZhHans": "炸"},
                {"thai": "น้ำ", "glossZhHans": "水/汁"},
                {"thai": "ปลา", "glossZhHans": "鱼"}
            ]
        }
    },
    # 41. Pad Pak Boong
    {
        "id": "pad-pak-boong",
        "category": "海鲜与炒菜",
        "thai": "ผัดผักบุ้ง",
        "meaningZhHans": "炒空心菜／飞天通菜",
        "audioID": "thai-menu-pad-pak-boong",
        "imageAssetID": "pad-pak-boong",
        "searchQuery": "Phat phak bung morning glory stir fry",
        "breakdown": {
            "combinations": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ผักบุ้ง", "glossZhHans": "空心菜；通菜"}
            ],
            "minimal": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ผัก", "glossZhHans": "蔬菜"},
                {"thai": "บุ้ง", "glossZhHans": "蕹菜"}
            ]
        }
    },
    # 42. Pad Pak Ruam
    {
        "id": "pad-pak-ruam",
        "category": "海鲜与炒菜",
        "thai": "ผัดผักรวม",
        "meaningZhHans": "清炒什锦蔬菜",
        "audioID": "thai-menu-pad-pak-ruam",
        "imageAssetID": "pad-pak-ruam",
        "searchQuery": "Phat phak ruam mixed vegetables stir fry",
        "breakdown": {
            "combinations": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ผักรวม", "glossZhHans": "混合杂菜"}
            ],
            "minimal": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "ผัก", "glossZhHans": "蔬菜"},
                {"thai": "รวม", "glossZhHans": "综合"}
            ]
        }
    },
    # 43. Kai Jeow Moo Saap
    {
        "id": "kai-jeow-moo-saap",
        "category": "海鲜与炒菜",
        "thai": "ไข่เจียวหมูสับ",
        "meaningZhHans": "肉末泰式脆边煎蛋",
        "audioID": "thai-menu-kai-jeow-moo-saap",
        "imageAssetID": "kai-jeow-moo-saap",
        "searchQuery": "Khai chiao mu sap Thai omelette minced pork",
        "breakdown": {
            "combinations": [
                {"thai": "ไข่เจียว", "glossZhHans": "泰式煎蛋；炸蛋"},
                {"thai": "หมูสับ", "glossZhHans": "猪肉末"}
            ],
            "minimal": [
                {"thai": "ไข่", "glossZhHans": "鸡蛋"},
                {"thai": "เจียว", "glossZhHans": "油煎炸"},
                {"thai": "หมู", "glossZhHans": "猪肉"},
                {"thai": "สับ", "glossZhHans": "剁碎"}
            ]
        }
    },
    # 44. Pad Hoi Lai
    {
        "id": "pad-hoi-lai",
        "category": "海鲜与炒菜",
        "thai": "ผัดหอยลาย",
        "meaningZhHans": "辣椒膏炒花蛤",
        "audioID": "thai-menu-pad-hoi-lai",
        "imageAssetID": "pad-hoi-lai",
        "searchQuery": "Phat hoi lai stir fried clams chili paste",
        "breakdown": {
            "combinations": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "หอยลาย", "glossZhHans": "花蛤；文蛤"}
            ],
            "minimal": [
                {"thai": "ผัด", "glossZhHans": "炒"},
                {"thai": "หอย", "glossZhHans": "贝类"},
                {"thai": "ลาย", "glossZhHans": "花纹"}
            ]
        }
    },
    # 45. Tod Man Kung
    {
        "id": "tod-man-kung",
        "category": "海鲜与炒菜",
        "thai": "ทอดมันกุ้ง",
        "meaningZhHans": "泰式金钱炸虾饼",
        "audioID": "thai-menu-tod-man-kung",
        "imageAssetID": "tod-man-kung",
        "searchQuery": "Thot man kung prawn cakes",
        "breakdown": {
            "combinations": [
                {"thai": "ทอดมัน", "glossZhHans": "炸肉饼"},
                {"thai": "กุ้ง", "glossZhHans": "鲜虾"}
            ],
            "minimal": [
                {"thai": "ทอด", "glossZhHans": "炸"},
                {"thai": "มัน", "glossZhHans": "油润/虾浆"},
                {"thai": "กุ้ง", "glossZhHans": "虾"}
            ]
        }
    },
    # 46. Kai Dao
    {
        "id": "kai-dao",
        "category": "海鲜与炒菜",
        "thai": "ไข่ดาว",
        "meaningZhHans": "泰式炸荷包蛋",
        "audioID": "thai-menu-kai-dao",
        "imageAssetID": "kai-dao",
        "searchQuery": "Khai dao Thai fried egg",
        "breakdown": {
            "combinations": [
                {"thai": "ไข่", "glossZhHans": "鸡蛋"},
                {"thai": "ดาว", "glossZhHans": "星星；荷包蛋"}
            ],
            "minimal": [
                {"thai": "ไข่", "glossZhHans": "蛋"},
                {"thai": "ดาว", "glossZhHans": "星形"}
            ]
        }
    },
    # 47. Moo Ping
    {
        "id": "moo-ping",
        "category": "烧烤与小吃",
        "thai": "หมูปิ้ง",
        "meaningZhHans": "街头炭烤猪肉串",
        "audioID": "thai-menu-moo-ping",
        "imageAssetID": "moo-ping",
        "searchQuery": "Mu ping pork skewers",
        "breakdown": {
            "combinations": [
                {"thai": "หมู", "glossZhHans": "猪肉"},
                {"thai": "ปิ้ง", "glossZhHans": "炭烤；烤串"}
            ],
            "minimal": [
                {"thai": "หมู", "glossZhHans": "猪肉"},
                {"thai": "ปิ้ง", "glossZhHans": "烤"}
            ]
        }
    },
    # 48. Kor Moo Yang
    {
        "id": "kor-moo-yang",
        "category": "烧烤与小吃",
        "thai": "คอหมูย่าง",
        "meaningZhHans": "泰式炭烤猪颈肉",
        "audioID": "thai-menu-kor-moo-yang",
        "imageAssetID": "kor-moo-yang",
        "searchQuery": "Kho mu yang grilled pork neck",
        "breakdown": {
            "combinations": [
                {"thai": "คอหมู", "glossZhHans": "猪颈肉"},
                {"thai": "ย่าง", "glossZhHans": "烧烤"}
            ],
            "minimal": [
                {"thai": "คอ", "glossZhHans": "脖子/颈部"},
                {"thai": "หมู", "glossZhHans": "猪肉"},
                {"thai": "ย่าง", "glossZhHans": "烤"}
            ]
        }
    },
    # 49. Satay Gai
    {
        "id": "satay-gai",
        "category": "烧烤与小吃",
        "thai": "สะเต๊ะไก่",
        "meaningZhHans": "沙爹烤鸡肉串",
        "audioID": "thai-menu-satay-gai",
        "imageAssetID": "satay-gai",
        "searchQuery": "Satay kai chicken satay Thai",
        "breakdown": {
            "combinations": [
                {"thai": "สะเต๊ะ", "glossZhHans": "沙爹串"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ],
            "minimal": [
                {"thai": "สะเต๊ะ", "glossZhHans": "沙爹"},
                {"thai": "ไก่", "glossZhHans": "鸡肉"}
            ]
        }
    },
    # 50. Sai Krok Isan
    {
        "id": "sai-krok-isan",
        "category": "烧烤与小吃",
        "thai": "ไส้กรอกอีสาน",
        "meaningZhHans": "东北发酵酸香肠",
        "audioID": "thai-menu-sai-krok-isan",
        "imageAssetID": "sai-krok-isan",
        "searchQuery": "Sai krok Isan sausage",
        "breakdown": {
            "combinations": [
                {"thai": "ไส้กรอก", "glossZhHans": "香肠"},
                {"thai": "อีสาน", "glossZhHans": "泰国东北部"}
            ],
            "minimal": [
                {"thai": "ไส้", "glossZhHans": "肠衣/内馅"},
                {"thai": "กรอก", "glossZhHans": "灌注"},
                {"thai": "อีสาน", "glossZhHans": "东北部"}
            ]
        }
    },
    # 51. Larb Moo
    {
        "id": "larb-moo",
        "category": "烧烤与小吃",
        "thai": "ลาบหมู",
        "meaningZhHans": "伊森香草肉碎温沙拉",
        "audioID": "thai-menu-larb-moo",
        "imageAssetID": "larb-moo",
        "searchQuery": "Lap mu larb pork Isan salad",
        "breakdown": {
            "combinations": [
                {"thai": "ลาบ", "glossZhHans": "凉拌肉末沙拉"},
                {"thai": "หมู", "glossZhHans": "猪肉"}
            ],
            "minimal": [
                {"thai": "ลาบ", "glossZhHans": "拌肉碎"},
                {"thai": "หมู", "glossZhHans": "猪肉"}
            ]
        }
    },
    # 52. Yum Woon Sen
    {
        "id": "yum-woon-sen",
        "category": "烧烤与小吃",
        "thai": "ยำวุ้นเส้น",
        "meaningZhHans": "酸辣海鲜肉末粉丝沙拉",
        "audioID": "thai-menu-yum-woon-sen",
        "imageAssetID": "yum-woon-sen",
        "searchQuery": "Yam wun sen glass noodle salad",
        "breakdown": {
            "combinations": [
                {"thai": "ยำ", "glossZhHans": "酸辣凉拌"},
                {"thai": "วุ้นเส้น", "glossZhHans": "粉丝；冬粉"}
            ],
            "minimal": [
                {"thai": "ยำ", "glossZhHans": "凉拌"},
                {"thai": "วุ้น", "glossZhHans": "透明胶冻"},
                {"thai": "เส้น", "glossZhHans": "细条"}
            ]
        }
    },
    # 53. Nam Tok Moo
    {
        "id": "nam-tok-moo",
        "category": "烧烤与小吃",
        "thai": "น้ำตกหมู",
        "meaningZhHans": "瀑布烤猪肉沙拉",
        "audioID": "thai-menu-nam-tok-moo",
        "imageAssetID": "nam-tok-moo",
        "searchQuery": "Nam tok mu grilled pork waterfall salad",
        "breakdown": {
            "combinations": [
                {"thai": "น้ำตก", "glossZhHans": "瀑布风味拌烤肉"},
                {"thai": "หมู", "glossZhHans": "猪肉"}
            ],
            "minimal": [
                {"thai": "น้ำ", "glossZhHans": "水"},
                {"thai": "ตก", "glossZhHans": "降落/瀑布"},
                {"thai": "หมู", "glossZhHans": "猪肉"}
            ]
        }
    },
    # 54. Cha Manao
    {
        "id": "cha-manao",
        "category": "饮料与甜品",
        "thai": "ชามะนาว",
        "meaningZhHans": "泰式青柠冰红茶",
        "audioID": "thai-menu-cha-manao",
        "imageAssetID": "cha-manao",
        "searchQuery": "Cha manao Thai lemon iced tea",
        "breakdown": {
            "combinations": [
                {"thai": "ชา", "glossZhHans": "茶"},
                {"thai": "มะนาว", "glossZhHans": "青柠；柠檬"}
            ],
            "minimal": [
                {"thai": "ชา", "glossZhHans": "茶"},
                {"thai": "มะนาว", "glossZhHans": "青柠"}
            ]
        }
    },
    # 55. Nom Yen
    {
        "id": "nom-yen",
        "category": "饮料与甜品",
        "thai": "นมเย็น",
        "meaningZhHans": "泰式粉红冰奶",
        "audioID": "audio-food_dining-word-073",
        "imageAssetID": "nom-yen",
        "searchQuery": "Nom yen pink milk Thai",
        "breakdown": {
            "combinations": [
                {"thai": "นม", "glossZhHans": "牛奶"},
                {"thai": "เย็น", "glossZhHans": "冰凉；冷饮"}
            ],
            "minimal": [
                {"thai": "นม", "glossZhHans": "牛奶"},
                {"thai": "เย็น", "glossZhHans": "冷/凉"}
            ]
        }
    },
    # 56. Tub Tim Krop
    {
        "id": "tub-tim-krop",
        "category": "饮料与甜品",
        "thai": "ทับทิมกรอบ",
        "meaningZhHans": "椰奶红宝石马蹄爽",
        "audioID": "thai-menu-tub-tim-krop",
        "imageAssetID": "tub-tim-krop",
        "searchQuery": "Thapthim krop red rubies dessert Thai",
        "breakdown": {
            "combinations": [
                {"thai": "ทับทิม", "glossZhHans": "红宝石；石榴"},
                {"thai": "กรอบ", "glossZhHans": "清脆；爽脆"}
            ],
            "minimal": [
                {"thai": "ทับทิม", "glossZhHans": "红宝石"},
                {"thai": "กรอบ", "glossZhHans": "酥脆"}
            ]
        }
    }
]

def generate_audios():
    os.makedirs(AUDIO_DIR, exist_ok=True)
    generated = 0
    for card in CARDS:
        audio_id = card["audioID"]
        output_path = os.path.join(AUDIO_DIR, f"{audio_id}.mp3")
        if os.path.exists(output_path):
            continue
        thai_text = card["thai"]
        print(f"Generating audio for {card['id']}: {thai_text} -> {audio_id}.mp3")
        aiff_path = f"/tmp/{audio_id}.aiff"
        subprocess.run(["say", "-v", "Kanya", thai_text, "-o", aiff_path], check=True)
        subprocess.run([
            "ffmpeg", "-i", aiff_path,
            "-codec:a", "libmp3lame", "-b:a", "128k",
            output_path, "-y"
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        if os.path.exists(aiff_path):
            os.remove(aiff_path)
        generated += 1
    print(f"Generated {generated} new audio files.")

def fetch_wikimedia_image(query):
    url = (
        f"https://commons.wikimedia.org/w/api.php?action=query&format=json"
        f"&generator=search&gsrnamespace=6&gsrsearch={urllib.parse.quote(query)}"
        f"&gsrlimit=5&prop=imageinfo&iiprop=url|extmetadata"
    )
    req = urllib.request.Request(url, headers={"User-Agent": "ThaiLifeApp/1.0 (yaohuix@example.com)"})
    with urllib.request.urlopen(req, timeout=15) as resp:
        data = json.loads(resp.read().decode())
        pages = data.get("query", {}).get("pages", {})
        for pid, page in pages.items():
            title = page.get("title", "")
            if not title.lower().endswith((".jpg", ".jpeg", ".png")):
                continue
            imageinfos = page.get("imageinfo", [])
            if not imageinfos:
                continue
            info = imageinfos[0]
            img_url = info.get("url")
            meta = info.get("extmetadata", {})
            artist = meta.get("Artist", {}).get("value", "Wikimedia Contributor")
            # Strip HTML tags
            artist = re.sub(r"<[^>]+>", "", artist).strip() or "Wikimedia Contributor"
            license_short = meta.get("LicenseShortName", {}).get("value", "CC BY-SA")
            source_page = f"https://commons.wikimedia.org/wiki/{urllib.parse.quote(title)}"
            return {
                "title": title,
                "url": img_url,
                "artist": artist,
                "source": source_page,
                "license": license_short
            }
    return None

def process_images():
    os.makedirs(IMAGE_DIR, exist_ok=True)
    attributions = {}
    
    # Read existing attributions
    if os.path.exists(ATTRIBUTIONS_PATH):
        with open(ATTRIBUTIONS_PATH, "r", encoding="utf-8") as f:
            lines = f.readlines()
            current_file = None
            for line in lines:
                m = re.search(r"\|\s*`ThaiMenu/([^`]+)`\s*\|\s*([^|]+)\|\s*([^|]+)\|\s*([^|]+)\|", line)
                if m:
                    fname = m.group(1).replace(".jpg", "")
                    attributions[fname] = {
                        "artist": m.group(2).strip(),
                        "source": m.group(3).strip(),
                        "license": m.group(4).strip(),
                    }

    for card in CARDS:
        asset_id = card["imageAssetID"]
        target_path = os.path.join(IMAGE_DIR, f"{asset_id}.jpg")
        if os.path.exists(target_path) and asset_id in attributions:
            continue
        
        print(f"Fetching image for {card['id']} ({asset_id})...")
        queries = [
            card.get("searchQuery", ""),
            card["thai"],
            f"{card['id'].replace('-', ' ')} Thai food",
            card["meaningZhHans"]
        ]
        info = None
        for q in queries:
            if not q:
                continue
            try:
                info = fetch_wikimedia_image(q)
                if info:
                    break
            except Exception as e:
                print(f"  query '{q}' failed: {e}")
            time.sleep(0.5)

        if not info:
            print(f"  WARNING: Could not find image for {card['id']}")
            continue

        raw_tmp = f"/tmp/{asset_id}_raw"
        res = subprocess.run([
            "curl", "-A", "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)",
            "-s", "-L", info["url"], "-o", raw_tmp
        ])
        if res.returncode != 0 or not os.path.exists(raw_tmp) or os.path.getsize(raw_tmp) == 0:
            print(f"  FAILED to download image for {card['id']}")
            continue

        # Resize and save as JPEG using sips
        subprocess.run([
            "sips", "-s", "format", "jpeg",
            "--resampleWidth", "1000",
            raw_tmp, "--out", target_path
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=True)
        if os.path.exists(raw_tmp):
            os.remove(raw_tmp)

        attributions[asset_id] = {
            "artist": info["artist"],
            "source": info["source"],
            "license": info["license"]
        }
        print(f"  Saved {target_path} from {info['source']}")
        time.sleep(0.5)

    return attributions

def update_manifest_and_attributions(attributions):
    # 1. Update thai_menu_reference.json
    cleaned_cards = []
    for c in CARDS:
        card_copy = {k: v for k, v in c.items() if k != "searchQuery"}
        cleaned_cards.append(card_copy)
        
    reference = {
        "introductionZhHans": "一菜一张卡：先看图片和菜名，翻到背面再看词语拆解。",
        "cards": cleaned_cards
    }
    with open(MENU_JSON_PATH, "w", encoding="utf-8") as f:
        json.dump(reference, f, ensure_ascii=False, indent=2)
    print(f"Updated {MENU_JSON_PATH} with {len(cleaned_cards)} cards.")

    # 2. Update thai-menu-assets.md
    lines = [
        "# 泰国常见菜单图片归属记录\n",
        "\n",
        "此文件仅用于项目内部资源审计，不在 App 用户界面展示。图片来自 Wikimedia Commons，下载日期 2026-08-20/2026-08-21。\n",
        "\n",
        "| 文件 | 作者 | 来源 | 许可证 |\n",
        "|---|---|---|---|\n"
    ]
    for c in CARDS:
        asset_id = c["imageAssetID"]
        target_path = os.path.join(IMAGE_DIR, f"{asset_id}.jpg")
        attr = attributions.get(asset_id, {
            "artist": "Wikimedia Contributor",
            "source": "https://commons.wikimedia.org",
            "license": "CC BY-SA 4.0"
        })
        sha = ""
        if os.path.exists(target_path):
            with open(target_path, "rb") as f:
                sha = hashlib.sha256(f.read()).hexdigest()
        lines.append(f"| `ThaiMenu/{asset_id}.jpg` | {attr['artist']} | {attr['source']} | {attr['license']} |\n")
        if sha:
            lines.append(f"<!-- sha256: {sha} -->\n")

    with open(ATTRIBUTIONS_PATH, "w", encoding="utf-8") as f:
        f.writelines(lines)
    print(f"Updated {ATTRIBUTIONS_PATH} with all attributions.")

if __name__ == "__main__":
    generate_audios()
    attrs = process_images()
    update_manifest_and_attributions(attrs)
    print("Done expanding Thai menu reference!")
