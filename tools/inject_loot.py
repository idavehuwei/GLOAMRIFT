#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""向 loot.json 注入新增掉落内容（套装/传奇/传奇护符/护符词缀/护符底）。
仅追加，不改动既有条目；写回保持 JSON 合法、ensure_ascii=False。"""
import json, os

PATH = os.path.join(os.path.dirname(__file__), "..", "godot", "data", "loot.json")
PATH = os.path.abspath(PATH)

with open(PATH, "r", encoding="utf-8") as f:
    d = json.load(f)

# ---------- 新增套装（3 套）----------
NEW_SETS = [
    {
        "id": "frostfang", "n": "霜牙", "cls": "archer", "min": 28, "max": 50,
        "flavor": "雪原猎手靠这个活下来。牙是狼的，皮是狼的。",
        "bonuses": [
            {"need": 2, "t": "寒风里移动不被减速。"},
            {"need": 4, "t": "暴击对冻住的敌人额外 +25%。"},
            {"need": 6, "t": "击杀冻住的敌人，下一箭不耗蓝。"}
        ],
        "pieces": [
            {"id": "ff_w", "type": "weapon", "cls": "archer", "n": "霜牙长弓", "g": "🏹", "spd": 1.1, "d": [6, 12], "flavor": "弓弦冻过，射出去带霜。", "affixes": [{"n": "伤害", "k": "dmg", "min": 6, "max": 13}, {"n": "敏捷", "k": "dex", "min": 10, "max": 22}]},
            {"id": "ff_b", "type": "boots", "n": "霜牙软靴", "g": "👟", "armor": 14, "flavor": "踩雪没声。", "affixes": [{"n": "护甲", "k": "armor", "min": 12, "max": 26}, {"n": "移动速度%", "k": "ms", "min": 5, "max": 12}]},
            {"id": "ff_g", "type": "gloves", "n": "霜牙皮护腕", "g": "🦾", "armor": 12, "flavor": "手套上结着冰。", "affixes": [{"n": "护甲", "k": "armor", "min": 10, "max": 22}, {"n": "暴击几率%", "k": "crit", "min": 4, "max": 10}]},
            {"id": "ff_a", "type": "amulet", "n": "霜牙兽牙坠", "g": "🦷", "armor": 3, "flavor": "狼牙磨的坠子。", "affixes": [{"n": "敏捷", "k": "dex", "min": 12, "max": 26}, {"n": "暴击伤害%", "k": "critDmg", "min": 15, "max": 35}]}
        ]
    },
    {
        "id": "ash", "n": "灰烬", "cls": "mage", "min": 30, "max": 55,
        "flavor": "烧过的东西还在发热。",
        "bonuses": [
            {"need": 2, "t": "技能点燃地面，踩到的怪持续受伤。"},
            {"need": 4, "t": "法力低于 30% 时技能伤害 +20%。"},
            {"need": 6, "t": "击杀点燃的敌人回 8% 法力。"}
        ],
        "pieces": [
            {"id": "ash_o", "type": "offhand", "n": "灰烬魔典", "g": "📕", "armor": 5, "flavor": "书页焦黑但字还亮。", "affixes": [{"n": "法力回复", "k": "mpre", "min": 4, "max": 9}, {"n": "技能伤害%", "k": "skDmg", "min": 6, "max": 14}]},
            {"id": "ash_r", "type": "ring", "n": "灰烬戒", "g": "💎", "armor": 3, "flavor": "指环里封着一点火星。", "affixes": [{"n": "精神", "k": "ene", "min": 12, "max": 26}, {"n": "暴击几率%", "k": "crit", "min": 4, "max": 10}]},
            {"id": "ash_h", "type": "helm", "n": "灰烬兜帽", "g": "🧢", "armor": 16, "flavor": "兜帽挡烟。", "affixes": [{"n": "护甲", "k": "armor", "min": 14, "max": 30}, {"n": "最大法力%", "k": "mp", "min": 20, "max": 45}]},
            {"id": "ash_w", "type": "weapon", "cls": "mage", "n": "灰烬法杖", "g": "🪄", "spd": 1.0, "d": [6, 12], "flavor": "杖头是一团没灭的火。", "affixes": [{"n": "伤害", "k": "dmg", "min": 6, "max": 13}, {"n": "精神", "k": "ene", "min": 12, "max": 26}]}
        ]
    },
    {
        "id": "bedrock", "n": "磐石", "cls": "warrior", "min": 40, "max": 70,
        "flavor": "站住了，后面的人才能过。",
        "bonuses": [
            {"need": 2, "t": "受到伤害降低 8%。"},
            {"need": 4, "t": "格挡后 3 秒内下次攻击必爆。"},
            {"need": 6, "t": "生命低于 50% 时减伤再 +15%。"}
        ],
        "pieces": [
            {"id": "br_a", "type": "armor", "n": "磐石板甲", "g": "🦺", "armor": 40, "flavor": "重得像座山。", "affixes": [{"n": "护甲", "k": "armor", "min": 36, "max": 80}, {"n": "体魄", "k": "vit", "min": 18, "max": 42}, {"n": "受到伤害降低%", "k": "dr", "min": 6, "max": 16}]},
            {"id": "br_b", "type": "belt", "n": "磐石铁扣", "g": "🔗", "armor": 18, "flavor": "腰带扣死死锁着。", "affixes": [{"n": "护甲", "k": "armor", "min": 16, "max": 34}, {"n": "力量", "k": "str", "min": 12, "max": 26}]},
            {"id": "br_am", "type": "amulet", "n": "磐石符石", "g": "🔶", "armor": 4, "flavor": "石头刻的护符。", "affixes": [{"n": "全属性", "k": "all", "min": 8, "max": 18}, {"n": "最大生命%", "k": "hp", "min": 15, "max": 35}]},
            {"id": "br_w", "type": "weapon", "cls": "warrior", "n": "磐石巨锤", "g": "⚒", "spd": 0.8, "d": [12, 22], "flavor": "一锤下去地动。", "affixes": [{"n": "伤害", "k": "dmg", "min": 8, "max": 18}, {"n": "力量", "k": "str", "min": 16, "max": 36}, {"n": "攻击速度%", "k": "as", "min": 4, "max": 10}]}
        ]
    }
]

# ---------- 新增传奇（每 boss 各 2 件，共 10）----------
NEW_UNIQUES = [
    {"id": "u_valak_helm", "boss": "valak", "n": "不肯落下的盔", "g": "⛑", "type": "helm", "rarity": 3, "armor": 58, "title": "齐整", "flavor": "桥上的人都没下来，这盔替他看着。", "affixes": [{"n": "护甲", "k": "armor", "min": 28, "max": 66}, {"n": "体魄", "k": "vit", "min": 16, "max": 38}, {"n": "受到伤害降低%", "k": "dr", "min": 6, "max": 16}]},
    {"id": "u_valak_boots", "boss": "valak", "n": "十九步靴", "g": "👟", "type": "boots", "rarity": 3, "armor": 46, "title": "齐整", "flavor": "桥上十九步，每一步都数过。", "affixes": [{"n": "护甲", "k": "armor", "min": 22, "max": 52}, {"n": "移动速度%", "k": "ms", "min": 6, "max": 14}, {"n": "最大生命%", "k": "hp", "min": 12, "max": 28}]},
    {"id": "u_singer_gloves", "boss": "singer", "n": "余唱之握", "g": "🦾", "type": "gloves", "rarity": 3, "armor": 50, "title": "余唱", "flavor": "手套上还有钟声的余震。", "affixes": [{"n": "护甲", "k": "armor", "min": 24, "max": 56}, {"n": "精神", "k": "ene", "min": 16, "max": 36}, {"n": "技能伤害%", "k": "skDmg", "min": 8, "max": 18}]},
    {"id": "u_singer_helm", "boss": "singer", "n": "沉钟之冠", "g": "🎩", "type": "helm", "rarity": 3, "armor": 60, "title": "余唱", "flavor": "钟沉了，冠还在响。", "affixes": [{"n": "护甲", "k": "armor", "min": 30, "max": 68}, {"n": "最大法力%", "k": "mp", "min": 18, "max": 40}, {"n": "暴击伤害%", "k": "critDmg", "min": 15, "max": 38}]},
    {"id": "u_grey_ring", "boss": "grey", "n": "刮痕之戒", "g": "💎", "type": "ring", "rarity": 3, "title": "刮痕", "flavor": "凿船的刮痕，一圈一圈。", "affixes": [{"n": "力量", "k": "str", "min": 14, "max": 32}, {"n": "敏捷", "k": "dex", "min": 14, "max": 32}, {"n": "受到伤害降低%", "k": "dr", "min": 6, "max": 15}]},
    {"id": "u_grey_boots", "boss": "grey", "n": "湿甲长靴", "g": "🥾", "type": "boots", "rarity": 3, "armor": 48, "title": "刮痕", "flavor": "海水泡过的靴子，还在滴水。", "affixes": [{"n": "护甲", "k": "armor", "min": 22, "max": 54}, {"n": "体魄", "k": "vit", "min": 16, "max": 38}, {"n": "移动速度%", "k": "ms", "min": 6, "max": 14}]},
    {"id": "u_asm_helm", "boss": "assembly", "n": "众议之盔", "g": "⛑", "type": "helm", "rarity": 3, "armor": 58, "title": "众议", "flavor": "每道决议都刻在盔上。", "affixes": [{"n": "护甲", "k": "armor", "min": 28, "max": 66}, {"n": "全属性", "k": "all", "min": 10, "max": 22}, {"n": "受到伤害降低%", "k": "dr", "min": 6, "max": 15}]},
    {"id": "u_asm_boots", "boss": "assembly", "n": "议案之靴", "g": "👟", "type": "boots", "rarity": 3, "armor": 46, "title": "众议", "flavor": "一条条议案，踩在脚下。", "affixes": [{"n": "护甲", "k": "armor", "min": 22, "max": 52}, {"n": "最大生命%", "k": "hp", "min": 14, "max": 32}, {"n": "金币发现%", "k": "gf", "min": 12, "max": 30}]},
    {"id": "u_kor_amu", "boss": "kor", "n": "第一根坠", "g": "🔶", "type": "amulet", "rarity": 3, "armor": 4, "title": "第一根", "flavor": "第一根钉子，他带在身上。", "affixes": [{"n": "全属性", "k": "all", "min": 12, "max": 26}, {"n": "暴击伤害%", "k": "critDmg", "min": 18, "max": 42}, {"n": "最大生命%", "k": "hp", "min": 15, "max": 35}]},
    {"id": "u_kor_gloves", "boss": "kor", "n": "钉底之握", "g": "🦾", "type": "gloves", "rarity": 3, "armor": 52, "title": "第一根", "flavor": "手套满是钉痕。", "affixes": [{"n": "护甲", "k": "armor", "min": 24, "max": 58}, {"n": "力量", "k": "str", "min": 18, "max": 40}, {"n": "攻击速度%", "k": "as", "min": 6, "max": 14}]}
]

# ---------- 新增传奇护符（3 件）----------
NEW_CHARM_UNIQUES = [
    {"id": "c_fang", "n": "兽牙护符", "g": "🦷", "flavor": "狼王牙磨的护符，带着野性。", "affixes": [{"n": "体魄", "k": "vit", "min": 12, "max": 28}, {"n": "移动速度%", "k": "ms", "min": 5, "max": 12}]},
    {"id": "c_aegis", "n": "圣壁护符", "g": "🛡", "flavor": "封着一层薄薄的壁。", "affixes": [{"n": "全抗性%", "k": "resAll", "min": 6, "max": 14}, {"n": "受到伤害降低%", "k": "dr", "min": 5, "max": 12}]},
    {"id": "c_blood", "n": "血怒护符", "g": "🩸", "flavor": "沾血的护符，越打越红。", "affixes": [{"n": "击杀回血%", "k": "killhp", "min": 3, "max": 7}, {"n": "暴击几率%", "k": "crit", "min": 4, "max": 10}]}
]

# ---------- 新增护符词缀（8 条）----------
NEW_CHARM_AFFIX = [
    {"n": "全属性", "k": "all", "r": [3, 8]},
    {"n": "技能伤害%", "k": "skDmg", "r": [4, 10]},
    {"n": "穿透%", "k": "pierce", "r": [5, 12]},
    {"n": "全抗性%", "k": "resAll", "r": [3, 7]},
    {"n": "荆棘", "k": "thorns", "r": [6, 16]},
    {"n": "击杀回血%", "k": "killhp", "r": [2, 5]},
    {"n": "残血增伤%", "k": "lowhp", "r": [6, 16]},
    {"n": "精英伤害%", "k": "elitedmg", "r": [8, 18]}
]

# ---------- 新增护符底（各 size +2）----------
NEW_CHARM_BASE = {
    "1": [{"n": "齿坠", "g": "🦷"}, {"n": "石珠", "g": "🔶"}],
    "2": [{"n": "铜镜", "g": "🪞"}, {"n": "骨牌", "g": "🂠"}],
    "3": [{"n": "玉匣", "g": "🎁"}, {"n": "符匣", "g": "🗝"}]
}

# ---------- 校验 k 是否会被 apply_mod 消费（安全网）----------
SAFE_K = {
    "str", "dex", "vit", "ene", "armor", "hp", "mp", "dmg", "crit", "as", "leech",
    "ms", "critDmg", "dr", "cdr", "mpre", "hpre", "dodge", "all", "main",
    "skDmg", "pierce", "resPhys", "resFire", "resIce", "resShadow", "resAll",
    "gf", "mf", "killhp", "killmp", "thorns", "chillhit", "freezehit",
    "killburst", "lowhp", "elitedmg"
}

def check_affixes(label, arr):
    for a in arr:
        k = a.get("k")
        if k not in SAFE_K:
            raise SystemExit("UNSAFE affix k=%r in %s" % (k, label))

for s in NEW_SETS:
    for p in s["pieces"]:
        check_affixes("set %s/%s" % (s["id"], p["id"]), p.get("affixes", []))
for u in NEW_UNIQUES:
    check_affixes("unique %s" % u["id"], u.get("affixes", []))
for c in NEW_CHARM_UNIQUES:
    check_affixes("charm_unique %s" % c["id"], c.get("affixes", []))
for a in NEW_CHARM_AFFIX:
    check_affixes("charm_affix", [a])

# ---------- 追加 ----------
existing_ids = {u.get("id") for u in d["UNIQUES"]}
for u in NEW_UNIQUES:
    if u["id"] in existing_ids:
        raise SystemExit("duplicate unique id %s" % u["id"])
    d["UNIQUES"].append(u)

existing_set_ids = {s.get("id") for s in d["SETS"]}
for s in NEW_SETS:
    if s["id"] in existing_set_ids:
        raise SystemExit("duplicate set id %s" % s["id"])
    d["SETS"].append(s)

existing_cu = {c.get("id") for c in d["CHARM_UNIQUES"]}
for c in NEW_CHARM_UNIQUES:
    if c["id"] in existing_cu:
        raise SystemExit("duplicate charm_unique id %s" % c["id"])
    d["CHARM_UNIQUES"].append(c)

d["CHARM_AFFIX"].extend(NEW_CHARM_AFFIX)
for sz, arr in NEW_CHARM_BASE.items():
    d["CHARM_BASE"].setdefault(sz, [])
    d["CHARM_BASE"][sz].extend(arr)

with open(PATH, "w", encoding="utf-8") as f:
    json.dump(d, f, ensure_ascii=False, indent=2)

# ---------- 报告 ----------
print("UNIQUES:", len(d["UNIQUES"]), "(+%d)" % len(NEW_UNIQUES))
print("SETS:", len(d["SETS"]), "(+%d)" % len(NEW_SETS))
print("CHARM_UNIQUES:", len(d["CHARM_UNIQUES"]), "(+%d)" % len(NEW_CHARM_UNIQUES))
print("CHARM_AFFIX:", len(d["CHARM_AFFIX"]), "(+%d)" % len(NEW_CHARM_AFFIX))
print("CHARM_BASE sizes:", {k: len(v) for k, v in d["CHARM_BASE"].items()})
print("OK")
