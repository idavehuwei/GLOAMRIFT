#!/usr/bin/env python3
"""Emit godot/autoload/Data.gd tables from the web game's constants."""
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "autoload" / "Data.gd"

# --- tables copied from shadow-depths.html ---

AREA = r'''
const AREA := {
	"town": {id="town", n="石桥镇", kind="town", ch=1, skin="stone", seed=99, lvl=1,
		pal={floor=Vector3(0.50,0.46,0.36), fog=0x2a2620, sky=0x2e2a24, amb=0.86, sun=0.75, sunc=0xffd9a8, dens=0.014},
		exits=[{to="waste", label="城门 · 落石荒原", x=34.0, z=6.0}, {kind="rift", label="裂隙入口", x=-8.0, z=22.0}]},
	"rime": {id="rime", n="白喉隘口", kind="town", ch=2, skin="ice", seed=201, lvl=24,
		pal={floor=Vector3(0.62,0.66,0.74), fog=0x6a8498, sky=0x7a96aa, amb=0.88, sun=0.78, sunc=0xdfeaff, dens=0.015},
		houses=[[-15,-10,6,5],[9,-11,7,5],[-6,-13,6,4],[-17,6,6,4],[13,7,6,4],[-12,11,5,4]],
		exits=[{to="frost", label="北门 · 冰湖", x=0.0, z=-22.0}, {to="ash", label="南路 · 灰烬峡谷", x=0.0, z=16.0}, {to="harbor", label="东路 · 潮灯港", x=34.0, z=6.0}]},
	"harbor": {id="harbor", n="潮灯港", kind="town", ch=3, skin="dock", seed=301, lvl=35,
		pal={floor=Vector3(0.42,0.38,0.32), fog=0x243440, sky=0x2a3c48, amb=0.78, sun=0.7, sunc=0xc8d8e8, dens=0.017},
		houses=[[-14,-9,7,5],[10,-10,6,5],[-5,-13,6,4],[-16,5,5,4],[12,6,7,5],[-11,10,6,4]],
		exits=[{to="shore", label="码头 · 沉船海岸", x=12.0, z=22.0}, {to="rime", label="北路 · 白喉隘口", x=0.0, z=-22.0}, {to="sink", label="西路 · 沉降残镇", x=-32.0, z=4.0}]},
	"sink": {id="sink", n="沉降残镇", kind="town", ch=4, skin="ruin", seed=401, lvl=50,
		pal={floor=Vector3(0.32,0.28,0.30), fog=0x1a141c, sky=0x161218, amb=0.58, sun=0.42, sunc=0x8a6ab0, dens=0.022},
		houses=[[-15,-10,6,4],[8,-11,6,5],[-4,-13,5,4],[-16,6,5,4],[11,7,6,4],[-12,10,5,4]],
		exits=[{to="sinkf", label="井口 · 沉降区", x=0.0, z=16.0}, {to="harbor", label="海岸回头", x=34.0, z=6.0}, {to="well", label="更深 · 桥墩井口", x=-32.0, z=4.0}]},
	"well": {id="well", n="桥墩井口", kind="town", ch=5, skin="nail", seed=501, lvl=65,
		pal={floor=Vector3(0.36,0.30,0.26), fog=0x1c1210, sky=0x18100e, amb=0.55, sun=0.4, sunc=0xc08050, dens=0.024},
		houses=[[-12,-9,6,4],[8,-10,6,4],[-5,-12,5,4],[-14,5,5,4],[10,6,5,4]],
		exits=[{to="shaft", label="下行 · 桥墩井道", x=0.0, z=16.0}, {to="sink", label="回沉降残镇", x=34.0, z=6.0}]},
	"waste": {id="waste", n="落石荒原", kind="field", ch=1, lvl=3, seed=11, mobs=["wolf","boar","bandit","snake"], block="rock", shape="waste",
		pal={floor=Vector3(0.44,0.40,0.28), fog=0x39382e, sky=0x3d3c31, amb=0.72, sun=0.8, sunc=0xffe0b0, dens=0.017},
		marks=[{kind="travel", to="town", label="石桥镇", x=-24.0, z=14.0},
			{kind="travel", to="wood", label="暮语林地", x=24.0, z=-16.0},
			{kind="dungeon", to="crypt", label="哭嚎墓窖", x=2.0, z=-20.0}]},
	"wood": {id="wood", n="暮语林地", kind="field", ch=1, lvl=9, seed=22, mobs=["spider","treant","banditbow","wasp","frog"], block="tree", shape="wood",
		pal={floor=Vector3(0.24,0.34,0.22), fog=0x1e2a20, sky=0x22301f, amb=0.62, sun=0.62, sunc=0xbfe0a0, dens=0.024},
		marks=[{kind="travel", to="waste", label="落石荒原", x=-24.0, z=16.0},
			{kind="travel", to="ash", label="灰烬峡谷", x=24.0, z=-14.0},
			{kind="dungeon", to="nest", label="腐丝蛛巢", x=-4.0, z=-21.0}]},
	"ash": {id="ash", n="灰烬峡谷", kind="field", ch=1, lvl=17, seed=33, mobs=["lavabeast","ashmage","golem"], block="spire", shape="ash",
		pal={floor=Vector3(0.36,0.24,0.20), fog=0x30181a, sky=0x2c1618, amb=0.58, sun=0.6, sunc=0xff9a6a, dens=0.026},
		marks=[{kind="travel", to="wood", label="暮语林地", x=-24.0, z=16.0},
			{kind="travel", to="rime", label="白喉隘口", x=-28.0, z=-24.0},
			{kind="dungeon", to="fort", label="熔火要塞", x=12.0, z=-19.0}]},
	"frost": {id="frost", n="北境冰湖", kind="field", ch=2, lvl=24, seed=44, mobs=["frostwolf","icespider","rimeknight"], block="pillar", shape="frost", hz="ice",
		pal={floor=Vector3(0.62,0.68,0.76), fog=0x8aa8bc, sky=0x9eb6c8, amb=0.9, sun=0.85, sunc=0xdfeaff, dens=0.016},
		marks=[{kind="travel", to="rime", label="白喉隘口", x=-24.0, z=16.0},
			{kind="dungeon", to="abbey", label="断桥修道院", x=6.0, z=-21.0},
			{kind="dungeon", to="belfry", label="湖底钟窖", x=18.0, z=8.0}]},
	"shore": {id="shore", n="沉船海岸", kind="field", ch=3, lvl=35, seed=55, mobs=["drowned","wrecker","brinewolf"], block="wreck", shape="shore",
		pal={floor=Vector3(0.48,0.42,0.32), fog=0x2a3844, sky=0x2e4250, amb=0.7, sun=0.68, sunc=0xc8d8e8, dens=0.02},
		marks=[{kind="travel", to="harbor", label="潮灯港", x=-24.0, z=16.0},
			{kind="dungeon", to="tide", label="潮下墓场", x=4.0, z=-18.0},
			{kind="dungeon", to="hull", label="朽舟腹", x=20.0, z=6.0}]},
	"sinkf": {id="sinkf", n="沉降区", kind="field", ch=4, lvl=52, seed=66, mobs=["wraith","ghoul","brute"], block="rock", shape="sink",
		pal={floor=Vector3(0.26,0.22,0.26), fog=0x120e16, sky=0x100c14, amb=0.5, sun=0.32, sunc=0x7a5aa0, dens=0.03},
		marks=[{kind="travel", to="sink", label="沉降残镇", x=-24.0, z=16.0},
			{kind="dungeon", to="ledger", label="账房", x=2.0, z=-20.0},
			{kind="dungeon", to="chorus", label="众议厅", x=18.0, z=4.0}]},
	"shaft": {id="shaft", n="桥墩井道", kind="field", ch=5, lvl=66, seed=77, mobs=["brute","wraith","golem"], block="rock", shape="shaft",
		pal={floor=Vector3(0.30,0.24,0.20), fog=0x140c0c, sky=0x100808, amb=0.48, sun=0.3, sunc=0xc07040, dens=0.032},
		marks=[{kind="travel", to="well", label="桥墩井口", x=-24.0, z=16.0},
			{kind="dungeon", to="nail", label="钉底", x=4.0, z=-22.0}]},
}
'''

HEAD = '''extends Node
## 网页版数据表一比一迁入。技能描述用公式字段，运行时拼字。

const TOWN_HOUSES := [[-16,-11,7,5],[8,-12,8,5],[-4,-14,7,4],[-18,5,6,5],[12,6,6,5],[-14,10,6,4]]
'''

TAIL = r'''
const DUNGEONS := [
	{id="crypt", n="哭嚎墓窖", lvl=6, floors=2, boss="boneking", mobs=["skeleton","ghoul","rat"], from="waste",
		desc="石桥镇的旧墓地。棺材是空的，声音却没停过。"},
	{id="nest", n="腐丝蛛巢", lvl=12, floors=2, boss="broodmother", mobs=["spider","ghoul","wraith"], from="wood",
		desc="林子最深处的一张网，大到能兜住一整支商队。"},
	{id="fort", n="熔火要塞", lvl=20, floors=3, boss="lord", mobs=["imp","brute","wraith"], from="ash",
		desc="裂隙的第一批仆从在这里筑巢，也把门锁在了里面。"},
	{id="abbey", n="断桥修道院", lvl=27, floors=3, boss="osser", mobs=["rimeknight","icespider","wraith"], from="frost",
		desc="唱起来就不能停。主祭还在唱。", pal="ice"},
	{id="belfry", n="湖底钟窖", lvl=32, floors=2, boss="singer", mobs=["icespider","wraith","rimeknight"], from="frost",
		desc="钟在湖底。声音从冰里往上爬。", pal="ice"},
	{id="tide", n="潮下墓场", lvl=38, floors=2, boss="tideguide", mobs=["drowned","wrecker","ghoul"], from="shore",
		desc="退潮才看得见的沟。旗在前面晃，别跟着。", pal="sea"},
	{id="hull", n="朽舟腹", lvl=45, floors=2, boss="gray", mobs=["drowned","wrecker","brinewolf"], from="shore",
		desc="最大那条船的肚子。有人还在凿。", pal="sea"},
	{id="ledger", n="账房", lvl=55, floors=2, boss="seven", mobs=["wraith","imp","brute"], from="sinkf",
		desc="七本账同时翻开。影子不会排队。", pal="deep"},
	{id="chorus", n="众议厅", lvl=62, floors=2, boss="voice", mobs=["wraith","imp","ghoul"], from="sinkf",
		desc="没有身体，只有一声声赞成。把会开停。", pal="deep"},
	{id="nail", n="钉底", lvl=70, floors=1, boss="kor", mobs=["brute","wraith","golem"], from="shaft",
		desc="最早被钉住的那个要挣出来。按回去。", pal="nail"}
]

const RIFT_PAL := {floor=Vector3(0.32,0.30,0.26), fog=0x06050a, sky=0x06050a, amb=0.55, sun=0.3, sunc=0x6a7ab0, dens=0.026}
const DUN_PAL := {
	"ice": {floor=Vector3(0.46,0.52,0.60), fog=0x152028, sky=0x121c24, amb=0.5, sun=0.26, sunc=0xa8c8e0, dens=0.03},
	"sea": {floor=Vector3(0.26,0.24,0.22), fog=0x0c161c, sky=0x0a1418, amb=0.48, sun=0.24, sunc=0x6a8aaa, dens=0.032},
	"deep": {floor=Vector3(0.20,0.18,0.22), fog=0x08060c, sky=0x06050a, amb=0.42, sun=0.18, sunc=0x6a4a80, dens=0.036},
	"nail": {floor=Vector3(0.26,0.20,0.16), fog=0x10080a, sky=0x0a0606, amb=0.4, sun=0.2, sunc=0xc07040, dens=0.034}
}

const DIFF := {
	"normal": {id="normal", n="普通", hp=1.0, dmg=1.0, xp=1.0, elite=0.0, res=0, ilvl=0, floor=-40},
	"hell": {id="hell", n="地狱", hp=4.5, dmg=3.0, xp=3.5, elite=0.09, res=-40, ilvl=3, floor=-40},
	"nightmare": {id="nightmare", n="噩梦", hp=14.0, dmg=7.5, xp=9.0, elite=0.21, res=-90, ilvl=6, floor=-90}
}
const DIFF_ORDER := ["normal", "hell", "nightmare"]
const CH_KEYS := [
	{ch=1, dun="fort", n="瓦拉克", k="第一章", title="门从里面开了", d="恐惧领主倒下。北面开始冻。白喉隘口的风先到。"},
	{ch=2, dun="belfry", n="无名唱者", k="第二章", title="钟停了", d="唱到一半沉了下去。东边十一条船。别跟着数。"},
	{ch=3, dun="hull", n="格雷", k="第三章", title="凿子停了", d="一条一条凿完的。裂口更深的门开了。从沉降残镇下去。"},
	{ch=4, dun="chorus", n="众议之声", k="第四章", title="会开停了", d="赞成停了。伤口还在。最底下那个要挣出来。去桥墩井口。"},
	{ch=5, dun="nail", n="柯尔", k="第五章", title="按回去了", d="钉子还在。裂口没合上。"}
]
const DOOR_LINE := {
	"crypt": "棺材是空的。声音没停。", "nest": "网是给孩子留的。", "fort": "门从里面锁着。",
	"abbey": "唱起来就不能停。", "belfry": "钟在湖底。",
	"tide": "旗在前面晃。别跟着。", "hull": "有人还在凿。",
	"ledger": "七本账同时翻开。", "chorus": "伤口自己会说话。", "nail": "最早被钉住的那个要挣出来。"
}
const END_CINE := {
	"normal": {k="五章", n="按回去了", d="钉子还在。裂口没合上。你回来的时候，镇子还在，灯少了几盏。同一条裂口，再走一遍。", unlock="hell"},
	"hell": {k="地狱", n="你回来了", d="这一遍，是你留下的。名字开始往下掉。最底下还有一层。", unlock="nightmare"},
	"nightmare": {k="够了吗", n="三百年了", d="没人回答他。你站在最底下。钉子还在。你可以上去。", final=1}
}

const CLASSES := {
	"warrior": {n="战士", g="⚔", atk="melee", range=2.4,
		desc="近身缠斗，靠护甲和生命硬吃伤害。武器伤害最高，怕被风筝。",
		info="高 力量 / 体魄 · 近战 · 坚韧",
		base={str=22, dex=12, vit=22, ene=8}, grow={str=3, dex=1, vit=3, ene=1},
		look={body=0x6b3230, leg=0x35302c, arm=0xc39a72, helm=0x8f7a44, weapon=0xb9c2cc, wkind="sword", shield=0x6a5a44, cape=0x4a1616}},
	"mage": {n="法师", g="🔮", atk="ranged", range=10.0,
		proj={color=0x8fb0ff, speed=22.0, r=0.24},
		desc="远程法术输出，范围伤害与控制最强。血少，站位一错就没。",
		info="高 精神 · 远程法术 · 范围控场",
		base={str=9, dex=12, vit=12, ene=24}, grow={str=1, dex=1, vit=2, ene=4},
		look={body=0x3a3a7a, leg=0x2a2a4a, arm=0xc39a72, hood=0x2f2f66, weapon=0x8fb0ff, wkind="staff", wlen=1.5, cape=0x27275c}},
	"archer": {n="弓箭手", g="🏹", atk="ranged", range=12.0,
		proj={color=0xffe6a0, speed=32.0, r=0.13, arrow=true},
		desc="射程最远、攻速最快，靠位移和陷阱拉开距离。单体爆发依赖暴击。",
		info="高 敏捷 · 远程物理 · 高攻速",
		base={str=12, dex=24, vit=14, ene=12}, grow={str=1, dex=4, vit=2, ene=1},
		look={body=0x3f5a34, leg=0x33402a, arm=0xc39a72, weapon=0x8a6a3a, wkind="bow", quiver=true, boots=0x4a3a2a, cape=0x2f4a2a}}
}

const ELEM := {
	"phys": {n="物理", imm="忘了疼", c="#c8c0ad"},
	"fire": {n="火", imm="烧过一次了", c="#ff7a2a"},
	"ice": {n="冰", imm="本来就是冷的", c="#8fd3ff"},
	"shadow": {n="暗影", imm="已经没什么可怕的", c="#9a7aff"}
}
const TYPE_ELEM := {
	"lavabeast": "fire", "ashmage": "fire", "imp": "fire",
	"frostwolf": "ice", "icespider": "ice", "rimeknight": "ice", "singer": "ice", "osser": "ice",
	"wraith": "shadow", "ghoul": "shadow", "spider": "shadow", "broodmother": "shadow"
}

const SKILLS := [
	{id="cleave", cls="warrior", n="裂地斩", g="💥", req=1, mp=6, cd=2.2, elem="phys", kind="aoe", rad=4.2, pct=150, grow=40, knock=true, syn=[{id="whirl", per=6}]},
	{id="charge", cls="warrior", n="猛冲", g="⚡", req=3, mp=12, cd=6.0, elem="phys", kind="dash", pct=130, grow=40, syn=[{id="quake", per=8}]},
	{id="whirl", cls="warrior", n="旋风斩", g="🌀", req=6, mp=18, cd=9.0, elem="phys", kind="channel", rad=3.6, dur=2.0, tick=0.35, pct=55, grow=16},
	{id="shout", cls="warrior", n="战吼", g="📣", req=9, mp=16, cd=18.0, elem="phys", kind="buff", dur=12.0, pct=20, grow=8},
	{id="fortify", cls="warrior", n="坚壁", g="🛡", req=12, mp=18, cd=20.0, elem="phys", kind="shield", dur=14.0, amt=90, grow=55},
	{id="quake", cls="warrior", n="震地", g="🌋", req=15, mp=28, cd=13.0, elem="phys", kind="aoe", rad=7.0, pct=190, grow=70, stun=2.0},
	{id="fire", cls="mage", n="火球术", g="🔥", req=1, mp=8, cd=0.55, elem="fire", kind="bolt", pct=120, grow=34, splash=true, syn=[{id="meteor", per=8}]},
	{id="nova", cls="mage", n="寒冰新星", g="❄", req=4, mp=20, cd=7.0, elem="ice", kind="aoe", rad=5.2, pct=100, grow=30, slow=4.0, syn=[{id="blink", per=10}]},
	{id="blink", cls="mage", n="闪现", g="✨", req=6, mp=14, cd=7.0, elem="shadow", kind="blink", pct=60, grow=20},
	{id="arcane", cls="mage", n="奥术飞弹", g="🌟", req=9, mp=22, cd=4.0, elem="shadow", kind="missiles", pct=90, grow=26, nbase=2, syn=[{id="drain", per=6}]},
	{id="drain", cls="mage", n="生命汲取", g="🩸", req=12, mp=16, cd=5.0, elem="shadow", kind="drain", pct=120, grow=35, heal=0.6},
	{id="meteor", cls="mage", n="陨石", g="☄", req=15, mp=32, cd=12.0, elem="fire", kind="cursor_aoe", rad=5.0, pct=240, grow=80},
	{id="multishot", cls="archer", n="多重射击", g="🎯", req=1, mp=8, cd=1.6, elem="phys", kind="fan", pct=75, grow=18, nbase=4, syn=[{id="arrowrain", per=0, dur=0.2}]},
	{id="pierce", cls="archer", n="穿透射击", g="➶", req=4, mp=14, cd=4.0, elem="phys", kind="line", pct=150, grow=45, syn=[{id="poison", per=8}]},
	{id="roll", cls="archer", n="翻滚", g="🤸", req=6, mp=8, cd=5.0, elem="phys", kind="roll", dur=0.5, grow_dur=0.06},
	{id="poison", cls="archer", n="毒藤箭", g="🍃", req=9, mp=16, cd=6.0, elem="shadow", kind="poison", pct=90, grow=25, dot=40, dotg=14, dot_t=6.0},
	{id="hawkeye", cls="archer", n="鹰眼", g="👁", req=12, mp=18, cd=20.0, elem="phys", kind="hawk", dur=12.0, crit=10, critg=4, asv=15, asg=5},
	{id="arrowrain", cls="archer", n="箭雨", g="🌧", req=15, mp=30, cd=12.0, elem="phys", kind="rain", dur=2.0, pct=230, grow=75}
]

const SK_RUNES := {
	"cleave": [
		{id="shock", n="震荡", d="不再击退。每多命中一个，冷却 −0.4 秒。"},
		{id="sweep", n="横扫", d="打成面前扇形，更宽，不改伤害。"}
	],
	"charge": [
		{id="breach", n="破阵", d="命中敌人后 2 秒内可再冲一次。"},
		{id="slam", n="冲撞", d="一路不削。终点砸地，范围更大。"}
	],
	"whirl": [
		{id="anchor", n="钉地", d="不再跟着走。原地转，范围更宽。"},
		{id="blade", n="绞杀", d="每次命中把敌人往身边拉。"}
	],
	"shout": [
		{id="taunt", n="嘲弄", d="不再增伤。把周围敌人拉过来并减速。"},
		{id="echo", n="回声", d="持续期间每 4 秒再吼一声，小范围减速。"}
	],
	"fortify": [
		{id="thorns", n="反刺", d="护盾期间受击，周围挨一下。"},
		{id="wall", n="石垣", d="不给自己盾。在面前立一堵墙。"}
	],
	"quake": [
		{id="fissure", n="地裂", d="不再圆形。沿瞄准方向一条地裂。"},
		{id="aftershock", n="余震", d="1.5 秒后再震一次，伤害减半。"}
	],
	"fire": [
		{id="split", n="裂焰", d="命中后分裂为 3 枚小火球，总伤害不变。"},
		{id="linger", n="凝滞", d="飞行变慢。命中留下 3 秒火池。"}
	],
	"nova": [
		{id="winter", n="凛冬", d="范围 −30%。对减速中的目标伤害 +80%。"},
		{id="shard", n="冰刺", d="不再圆形。朝周围射出 8 道冰刺。"}
	],
	"blink": [
		{id="afterimage", n="残像", d="原地炸一下再闪。"},
		{id="chain", n="连环", d="落地后 2 秒内可再闪一次。"}
	],
	"arcane": [
		{id="burst", n="炸裂", d="飞弹减半。命中爆炸溅射。"},
		{id="seek", n="寻踪", d="飞弹更慢，跟踪更死，会穿透。"}
	],
	"drain": [
		{id="link", n="双汲", d="同时吸最近两只，治疗对半。"},
		{id="siphon", n="蚀潮", d="不回血。目标脚下留减速圈。"}
	],
	"meteor": [
		{id="shower", n="雨坠", d="裂成 3 颗小陨石散落，总伤害不变。"},
		{id="core", n="核芯", d="范围收窄。中心眩晕。"}
	],
	"multishot": [
		{id="focus", n="收束", d="箭数减半，扇形收窄，单箭伤害翻倍。"},
		{id="through", n="穿林", d="箭会穿透，扇形略宽。"}
	],
	"pierce": [
		{id="ricochet", n="弹射", d="不直线穿透。打中弹到下一个人。"},
		{id="wide", n="阔矢", d="箭更粗更短，一条宽带。"}
	],
	"roll": [
		{id="smoke", n="烟幕", d="起点留下减速烟。"},
		{id="stab", n="刺出", d="结束时对面前劈一下。"}
	],
	"poison": [
		{id="cloud", n="毒雾", d="命中炸毒云。"},
		{id="vine", n="藤钉", d="箭变慢。命中钉住一小会儿。"}
	],
	"hawkeye": [
		{id="mark", n="标记", d="不给自己暴击。点名当前目标，受伤增加。"},
		{id="keen", n="锐目", d="持续期间普攻穿透。"}
	],
	"arrowrain": [
		{id="hail", n="雹矢", d="范围变窄，持续时间更长。"},
		{id="volley", n="齐射", d="立刻落三波，不再铺地。"}
	]
}

const TALENTS := {
	"warrior": [
		{id="wf6", n="血怒", g="🩸", max=1, d="击杀回 5% 生命。血低于 40% 时伤害 +20%。战吼改为立刻回 25% 生命，不再增伤。"},
		{id="wb6", n="不屈", g="🛡", max=1, d="护甲 +12%，受伤 −8%。坚壁碎裂时，5 码内挨 150% 伤害并眩晕 1.5 秒。"}
	],
	"mage": [
		{id="mfl6", n="裂焰", g="🔥", max=1, d="火球与陨石伤害 +15%。火球改为穿透，伤害 −20%。"},
		{id="mfr6", n="永冻", g="❄", max=1, d="对减速或冻结的目标伤害 +20%。寒冰新星对已减速的目标冻结 2 秒，范围 −20%。"}
	],
	"archer": [
		{id="ap6", n="一箭", g="➶", max=1, d="暴击 +6%。穿透射击不再穿透，单目标伤害 +80%。"},
		{id="ag6", n="残影", g="💨", max=1, d="移动速度 +8%。翻滚不再无敌。1.5 秒内下次攻击伤害 +50%。"}
	]
}

const RARITY := [
	{n="普通", c="#c8c0ad", hex=0xc8c0ad, af=0},
	{n="魔法", c="#6f9ede", hex=0x6f9ede, af=1},
	{n="稀有", c="#d8c15c", hex=0xd8c15c, af=2},
	{n="传奇", c="#c8762c", hex=0xc8762c, af=3},
	{n="神器", c="#8e5ad8", hex=0x8e5ad8, af=4}
]
const SLOTDEF := [
	{k="helm", n="头盔", g="⛑"}, {k="amulet", n="护身符", g="📿"},
	{k="ring1", n="戒指", g="💍", t="ring"}, {k="ring2", n="戒指", g="💍", t="ring"},
	{k="belt", n="腰带", g="🎗"}, {k="weapon", n="武器", g="🗡"},
	{k="armor", n="胸甲", g="🦺"}, {k="offhand", n="副手", g="🛡"},
	{k="gloves", n="手套", g="🧤"}, {k="boots", n="靴子", g="🥾"}
]
const BASES := {
	"weapon": {
		"warrior": [{n="短剑", g="🗡", d=[3,6], sp=1.0}, {n="阔剑", g="⚔", d=[5,10], sp=1.0}, {n="战斧", g="🪓", d=[7,14], sp=0.88}, {n="钉头锤", g="🔨", d=[6,12], sp=0.94}],
		"mage": [{n="橡木杖", g="🪄", d=[3,7], sp=1.05}, {n="符文长杖", g="🔱", d=[5,11], sp=1.0}, {n="水晶权杖", g="💠", d=[7,13], sp=0.95}],
		"archer": [{n="猎弓", g="🏹", d=[3,7], sp=1.15}, {n="复合弓", g="🎯", d=[5,11], sp=1.08}, {n="重弩", g="⚙", d=[8,15], sp=0.85}]
	},
	"armor": [{n="皮甲", g="🥋", a=[6,12]}, {n="锁子甲", g="🛡", a=[12,22]}, {n="板甲", g="🦺", a=[20,34]}],
	"helm": [{n="头巾", g="🎩", a=[3,6]}, {n="铁盔", g="⛑", a=[6,13]}, {n="角盔", g="👑", a=[10,19]}],
	"offhand": [{n="木盾", g="🛡", a=[5,11]}, {n="塔盾", g="🔰", a=[12,24]}, {n="魔典", g="📖", a=[2,5]}, {n="箭袋", g="🎒", a=[2,5]}],
	"belt": [{n="布带", g="🎗", a=[2,5]}, {n="镶钉腰带", g="🧶", a=[5,10]}],
	"gloves": [{n="皮手套", g="🧤", a=[2,6]}, {n="钢手甲", g="✋", a=[6,12]}],
	"boots": [{n="软靴", g="🥾", a=[2,6]}, {n="战靴", g="👢", a=[6,12]}],
	"amulet": [{n="骨坠", g="📿", a=[0,2]}, {n="银徽", g="🔮", a=[1,4]}],
	"ring": [{n="铜戒", g="💍", a=[0,2]}, {n="血石戒", g="💎", a=[1,4]}]
}
const AFFIX := [
	{n="力量", k="str", r=[2,7]}, {n="敏捷", k="dex", r=[2,7]}, {n="体魄", k="vit", r=[2,8]}, {n="精神", k="ene", r=[2,6]},
	{n="护甲", k="armor", r=[4,16]}, {n="最大生命", k="hp", r=[8,28]}, {n="最大法力", k="mp", r=[5,18]},
	{n="伤害", k="dmg", r=[1,5]}, {n="暴击几率%", k="crit", r=[2,6]}, {n="攻击速度%", k="as", r=[3,9]},
	{n="生命偷取%", k="leech", r=[1,4]}, {n="移动速度%", k="ms", r=[3,8]},
	{n="暴击伤害%", k="critDmg", r=[6,16]}, {n="受到伤害降低%", k="dr", r=[2,6]}, {n="技能伤害%", k="skDmg", r=[4,12]},
	{n="冷却缩减%", k="cdr", r=[3,8]}, {n="闪避%", k="dodge", r=[2,6]}, {n="生命回复", k="hpre", r=[2,7]},
	{n="法力回复", k="mpre", r=[2,6]}, {n="金币发现%", k="gf", r=[8,28]}, {n="拾得%", k="mf", r=[6,22]},
	{n="物理抗性%", k="resPhys", r=[4,12]}, {n="火焰抗性%", k="resFire", r=[4,12]},
	{n="冰霜抗性%", k="resIce", r=[4,12]}, {n="暗影抗性%", k="resShadow", r=[4,12]},
	{n="全抗性%", k="resAll", r=[3,8]}, {n="穿透%", k="pierce", r=[6,16]}
]
const FEEL_AFFIX := [
	{n="击杀回血%", k="killhp", r=[2,5], feel=1}, {n="击杀回蓝%", k="killmp", r=[3,8], feel=1},
	{n="受击回击%", k="thorns", r=[10,26], feel=1}, {n="击中减速%", k="chillhit", r=[10,24], feel=1},
	{n="击中冻结%", k="freezehit", r=[4,11], feel=1}, {n="击杀爆裂%", k="killburst", r=[16,36], feel=1},
	{n="残血增伤%", k="lowhp", r=[10,22], feel=1}, {n="精英伤害%", k="elitedmg", r=[10,24], feel=1}
]
const RUNES := [
	{id="rune_ember", n="余烬", g="🔥", k="dmg", v=[4,9], tier=1},
	{id="rune_frost", n="霜结", g="❄", k="armor", v=[8,18], tier=1},
	{id="rune_vita", n="命泉", g="❤", k="hp", v=[12,24], tier=1},
	{id="rune_hawk", n="鹰羽", g="🪶", k="crit", v=[2,5], tier=2},
	{id="rune_gale", n="疾风", g="💨", k="as", v=[4,8], tier=2},
	{id="rune_leech", n="饥渴", g="🩸", k="leech", v=[1,3], tier=3}
]
const RUNE_GRADE := ["", "碎屑", "结晶", "完整"]
const PRE := ["幽影", "焦骨", "锈蚀", "狼首", "苍白", "烈焰", "远古", "无声", "裂隙", "血誓", "霜噬", "石桥"]
const SUF := ["之约", "的余烬", "的低语", "之刃", "的守望", "的墓志", "之怒", "的黄昏"]
const UNIQUE_NAMES := ["瓦拉克的枷锁", "塞克拉的指骨", "织母的丝腺", "执政官的遗诺", "第一次下潜", "桥下之物"]
const CRATE_TYPES := ["weapon", "armor", "helm", "offhand", "gloves", "boots", "belt", "amulet", "ring"]
const CRATE_MULT := {weapon=1.35, armor=1.2, helm=1.0, offhand=1.05, gloves=0.82, boots=0.82, belt=0.72, amulet=1.45, ring=1.4}
const ELITE_MODS := [
	{id="split", n="数不清的", d="倒下时裂成两只半血的。", mute=["child"]},
	{id="wake", n="喊名字的", d="周期性大喊，唤醒周围沉睡的死者。"},
	{id="rise", n="不肯散的", d="第一次倒下后原地再站起来，剩四成血。", mute=["grudge"]},
	{id="burn", n="烧着的", d="走过的地方留下火痕。"},
	{id="frost", n="冻住的", d="挨打时反弹寒气，打它的人会慢下来。"},
	{id="child", n="带着孩子的", d="身边跟着一只小的。孩子死了，它会暴怒。", mute=["split"]},
	{id="rush", n="还在赶路的", d="跑得极快，会主动拉开再折返。", mute=["guard", "choir"]},
	{id="guard", n="护着东西的", d="受伤时把伤害分给周围同伴。先清小的。", mute=["rush"]},
	{id="grudge", n="记仇的", d="同一技能打中三次后，对该技能免疫片刻。", mute=["rise"]},
	{id="count", n="数着数的", d="每隔一阵放一次冲击，头顶会读秒。"},
	{id="choir", n="还在带着的", d="周围同伴打得更狠、跑得更快。先砍这个，打断也行。", mute=["rush"]}
]
const ELITE_COMBOS := [
	{ids=["wake", "child"], n="把孩子喊回来"},
	{ids=["burn", "count"], n="数着火走"},
	{ids=["frost", "grudge"], n="记在冰里"},
	{ids=["guard", "wake"], n="护着还在喊"},
	{ids=["split", "burn"], n="火也裂开"},
	{ids=["rise", "count"], n="数完再站"},
	{ids=["child", "frost"], n="孩子冻着"},
	{ids=["frost", "count"], n="数到冰里"},
	{ids=["split", "wake"], n="越喊越多"},
	{ids=["guard", "frost"], n="护着一块冰"},
	{ids=["rise", "burn"], n="烧着不肯走"},
	{ids=["rush", "frost"], n="带冰赶路"},
	{ids=["choir", "wake"], n="带着他们喊"},
	{ids=["choir", "frost"], n="带着一块冰"},
	{ids=["choir", "burn"], n="火也跟着"},
	{ids=["choir", "child"], n="孩子也带着"}
]
const SUPER_UNIQUES := [
	{id="who", area="waste", n="厉啸 · 谁来着", type="bandit", mods=["wake"], callName="谁来着",
		pack=4, hp=1.45, x=8.0, z=6.0, hint="荒原上有人在喊名字",
		last="……我叫什么来着。", last2="你……你替我记着行吗。就一下。", relic="halfpaper"},
	{id="weaver", area="wood", n="还在织的", type="spider", mods=["child", "guard"],
		pack=3, hp=1.5, x=-12.0, z=2.0, hint="林子里有一张不肯收的网", last="丝还没断。",
		codex={n="还在织的", text="林子深处一张网。她说是留给孩子的。"}},
	{id="ember", area="ash", n="不肯灭的", type="lavabeast", mods=["burn", "rise"],
		pack=3, hp=1.55, x=8.0, z=8.0, hint="峡谷里有一团还在烧的东西", last="还亮着。",
		codex={n="不肯灭的", text="灰烬峡谷里，有一团火怎么踩都不灭。"}},
	{id="hum", area="frost", n="还在哼的", type="rimeknight", mods=["count", "frost"],
		pack=3, hp=1.5, x=-8.0, z=-8.0, hint="冰上有人在数拍子", last="……走调了。",
		codex={n="还在哼的", text="冰湖上有人在数拍子。拍子是从修道院漏出来的。"}},
	{id="tidewait", area="shore", n="还在等潮的", type="drowned", mods=["wake", "guard"],
		pack=4, hp=1.5, x=12.0, z=-4.0, hint="岸边有人在等潮", last="退了再走。",
		codex={n="还在等潮的", text="岸边站着一个溺尸。潮不来，他不走。"}},
	{id="clerk", area="sinkf", n="还在记账的", type="wraith", mods=["grudge", "frost"],
		pack=3, hp=1.5, x=-6.0, z=8.0, hint="沉降区里有人在记账", last="账没写完。",
		codex={n="还在记账的", text="沉降区里有人划名字。划到你为止。"}},
	{id="nailer", area="shaft", n="还在钉的", type="brute", mods=["rise", "count"],
		pack=3, hp=1.55, x=10.0, z=4.0, hint="井道里有人还在钉", last="钉还在。",
		codex={n="还在钉的", text="桥墩井道里，有人把自己钉在墙上。"}}
]

const QUESTS := [
	{id="q1", n="去荒原杀狼", d="东边荒原的狼在咬牲口。去砍 8 只。", type="killtype", t="wolf", need=8, xp=150, gold=180, req=""},
	{id="q2", n="去荒原砍强盗", d="墓窖的喊声把强盗叫醒了。清掉 6 个劫掠者。先砍那个会厉啸、把死人喊起来的头目。", type="killtype", t="bandit", need=6, xp=260, gold=260, req="q1"},
	{id="q3", n="去墓窖砍塞克拉", d="白骨女王塞克拉一喊，死人就站起来。进哭嚎墓窖，把她砍死。", type="dungeon", t="crypt", need=1, xp=700, gold=600, item=true, req="q2"},
	{id="q4", n="去林地烧蜘蛛", d="北面林地开了。烧掉 10 只腐丝蛛。", type="killtype", t="spider", need=10, xp=900, gold=700, req="q3"},
	{id="q5", n="去蛛巢杀织母", d="顺着丝找到蛛巢，杀掉织母阿拉卡。", type="dungeon", t="nest", need=1, xp=1600, gold=1200, item=true, req="q4"},
	{id="q6", n="下裂口三层", d="镇子下面就是裂口。先打到第 3 层。", type="rift", need=3, xp=1200, gold=900, req="q3"},
	{id="q7", n="去峡谷杀精英", d="峡谷里的东西从裂口爬出来。击杀 6 只精英。", type="elite", need=6, xp=2400, gold=1600, req="q5"},
	{id="q8", n="去要塞杀瓦拉克", d="熔火要塞的门从里面锁着。斩杀恐惧领主瓦拉克。", type="dungeon", t="fort", need=1, xp=5200, gold=3600, item=true, req="q7"},
	{id="q9", n="下到裂口第十层", d="没有人从第 10 层回来过。你可以是第一个。", type="rift", need=10, xp=8000, gold=6000, item=true, req="q6"},
	{id="q10", n="去冰湖杀霜狼", d="北面冻住了。去白喉隘口后面的冰湖，砍 8 只霜狼。", type="killtype", t="frostwolf", need=8, xp=2800, gold=1800, req="q8"},
	{id="q11", n="去修道院杀奥赛尔", d="断桥修道院里有人还在唱。等他吸气，砍死主祭奥赛尔。", type="dungeon", t="abbey", need=1, xp=4200, gold=2800, item=true, req="q10"},
	{id="q12", n="去钟窖砸无名唱者", d="钟在湖底。下去把无名唱者砸哑。", type="dungeon", t="belfry", need=1, xp=5600, gold=3600, item=true, req="q11"},
	{id="q13", n="去海岸杀溺尸", d="东边十一条船沉了。去潮灯港外的海岸，清 10 具溺尸。", type="killtype", t="drowned", need=10, xp=4800, gold=3000, req="q12"},
	{id="q14", n="去潮下墓场", d="退潮才看得见的沟。打断引水人的旗，再砍他。", type="dungeon", t="tide", need=1, xp=6200, gold=4000, item=true, req="q13"},
	{id="q15", n="去朽舟腹杀格雷", d="最大那条船肚子里，有人还在凿。宰了格雷。", type="dungeon", t="hull", need=1, xp=7800, gold=5200, item=true, req="q14"},
	{id="q16", n="去沉降区清怨魂", d="从裂口往下走。沉降区里的尸会挡路。砍 8 只哀嚎怨魂。", type="killtype", t="wraith", need=8, xp=6400, gold=4200, req="q15"},
	{id="q17", n="去账房砍七影", d="七个影子一起冲。点哪个打哪个。", type="dungeon", t="ledger", need=1, xp=8600, gold=5600, item=true, req="q16"},
	{id="q18", n="去众议厅打哑声音", d="伤口自己会说话。把众议之声打停。", type="dungeon", t="chorus", need=1, xp=9800, gold=6800, item=true, req="q17"},
	{id="q19", n="钉底", d="最底下那个要挣出来。下去，按回去。", type="dungeon", t="nail", need=1, xp=12000, gold=9000, item=true, req="q18"}
]

const NPCDEF := [
	{id="kaden", n="铁匠 卡登", t="制式 · 重铸 · 箱子", g="⚒", dx=-9, dz=-4, asset="npc_kaden"},
	{id="mara", n="药剂商 玛拉", t="药水与补给", g="⚗", dx=9, dz=-4, asset="npc_mara"},
	{id="vaun", n="赌徒 沃恩", t="猜大小 · 赌货", g="🎲", dx=4, dz=2, asset="npc_vaun"},
	{id="selin", n="执政官 塞琳", t="镇务委托", g="📜", dx=0, dz=-9, asset="npc_selin"},
	{id="bridge", n="桥头老人", t="念一遍名字 · 存档", g="🪧", dx=15, dz=3, verb="念名", only=["town"], asset="npc_bridge"},
	{id="stash", n="银行", t="跨角色金库 · 40 格", g="🏦", x=-20.0, z=14.0, kind="stash", verb="打开", labelY=1.5},
	{id="board", n="悬赏板", t="每日五条", g="📋", x=10.0, z=16.0, kind="board", verb="查看", labelY=2.2},
	{id="waystone", n="传送石碑", t="已探明之地", g="🗿", x=0.0, z=20.0, kind="waystone", verb="触摸", labelY=2.8},
	{id="spring", n="复活井", t="喝一口，补满 · 死了在这儿醒", g="井", x=-6.0, z=6.0, kind="spring", verb="喝水", labelY=1.8},
	{id="harun", n="守隘 哈伦", t="白喉的风", g="🧣", dx=-6, dz=6, only=["rime"], asset="npc_harun"},
	{id="wick", n="守灯 维克", t="十一条船", g="🏮", dx=-6, dz=6, only=["harbor"], asset="npc_wick"},
	{id="quill", n="学徒 奎尔", t="没写完的账", g="📓", dx=-6, dz=6, only=["sink"], asset="npc_quill"},
	{id="nock", n="守井 诺克", t="第七根还在", g="⛓", dx=-6, dz=6, only=["well"], asset="npc_nock"}
]

const ETYPES := {
	"wolf": {n="灰狼", form="beast", body=0x6a6258, skin=0x8a8278, leg=0x4a443c, tail=true, hp=38, dmg=[5,9], speed=4.6, range=2.0, xp=14, scale=1.0, atkCd=1.2},
	"boar": {n="野猪", form="beast", body=0x5a4030, skin=0x6a4c38, leg=0x3a2a1e, horn=true, hp=70, dmg=[8,14], speed=3.4, range=2.1, xp=22, scale=1.15, atkCd=1.8},
	"bandit": {n="劫掠者", body=0x6a4a3a, skin=0xc39a72, leg=0x3a2a20, helm=0x5a4a3a, weapon=0xa8b0b8, wkind="sword", hp=60, dmg=[7,13], speed=3.6, range=2.3, xp=24, scale=1.0, atkCd=1.6},
	"banditbow": {n="强盗弓手", body=0x4a5a3a, skin=0xc39a72, leg=0x2a3a20, weapon=0x8a6a3a, wkind="bow", quiver=true, hp=48, dmg=[9,15], speed=3.4, range=11.0, xp=30, scale=1.0, atkCd=2.0, ranged=true, pcolor=0xffe6a0},
	"spider": {n="腐丝蛛", form="beast", body=0x3a2a4a, skin=0x5a3a6a, leg=0x241a30, tail=true, hp=52, dmg=[8,15], speed=4.2, range=2.1, xp=32, scale=0.95, atkCd=1.4},
	"rat": {n="沟鼠", form="beast", body=0x5a4a3a, skin=0x6a5a48, leg=0x3a2e24, tail=true, hp=26, dmg=[4,7], speed=5.0, range=1.8, xp=12, scale=1.0, atkCd=1.0},
	"snake": {n="毒牙蛇", form="beast", body=0x3a5a3a, skin=0x5a7a4a, leg=0x2a3a2a, hp=44, dmg=[7,12], speed=3.9, range=2.0, xp=20, scale=1.0, atkCd=1.4},
	"frog": {n="吞舌蛙", form="beast", body=0x4a6a3a, skin=0x6a8a4a, leg=0x2a3a24, hp=58, dmg=[9,15], speed=3.0, range=2.2, xp=26, scale=1.0, atkCd=1.7},
	"wasp": {n="针尾蜂", form="beast", body=0x6a5a1a, skin=0xc8a83a, leg=0x3a2e10, tail=true, hp=32, dmg=[8,13], speed=5.2, range=2.0, xp=22, scale=1.0, atkCd=1.1},
	"treant": {n="暮语树妖", body=0x3f5a2a, skin=0x5a7a3a, leg=0x2a3a1a, hp=150, dmg=[14,24], speed=2.4, range=2.8, xp=60, scale=1.5, atkCd=2.2},
	"lavabeast": {n="熔岩兽", form="beast", body=0x7a2a10, skin=0xff6a2a, leg=0x4a1a08, aura=0xff5a1e, horn=true, hp=180, dmg=[18,30], speed=3.8, range=2.4, xp=95, scale=1.25, atkCd=1.6},
	"ashmage": {n="灰烬巫师", body=0x4a2a4a, skin=0x9a6aa0, leg=0x2a182a, hood=0x3a1a3a, aura=0xc86aff, hp=120, dmg=[20,32], speed=3.0, range=12.0, xp=110, scale=1.05, atkCd=2.2, ranged=true, pcolor=0xc86aff},
	"golem": {n="碎石魔像", body=0x5a5450, skin=0x6a635c, leg=0x3a3632, hp=320, dmg=[26,40], speed=2.6, range=3.0, xp=170, scale=1.7, atkCd=2.4},
	"frostwolf": {n="霜狼", form="beast", body=0xb8c8d4, skin=0xd0dce6, leg=0x8aa0b0, tail=true, hp=210, dmg=[22,34], speed=4.8, range=2.1, xp=120, scale=1.08, atkCd=1.15},
	"icespider": {n="冰结蛛", form="beast", body=0x8aa8c0, skin=0xc0d4e4, leg=0x5a7088, tail=true, hp=160, dmg=[20,32], speed=4.4, range=2.1, xp=110, scale=1.0, atkCd=1.3},
	"rimeknight": {n="霜铠骑士", body=0x6a7a8a, skin=0xc8d4de, leg=0x3a4a58, helm=0xa8c0d0, weapon=0xc8e4ff, wkind="sword", hp=280, dmg=[26,40], speed=3.2, range=2.5, xp=160, scale=1.15, atkCd=1.7},
	"drowned": {n="溺尸", body=0x3a5a52, skin=0x6a8a7a, leg=0x2a3a36, hp=240, dmg=[24,36], speed=2.6, range=2.2, xp=140, scale=1.12, atkCd=1.8},
	"wrecker": {n="沉船匪", body=0x4a3a32, skin=0xa89070, leg=0x2a221c, helm=0x5a4a3a, weapon=0xb0a090, wkind="sword", hp=220, dmg=[22,34], speed=3.5, range=2.3, xp=130, scale=1.05, atkCd=1.55},
	"brinewolf": {n="盐须狼", form="beast", body=0x6a7268, skin=0x8a9288, leg=0x4a5248, tail=true, hp=200, dmg=[20,32], speed=4.5, range=2.0, xp=125, scale=1.05, atkCd=1.2},
	"skeleton": {n="骷髅战士", body=0xd9d3c0, skin=0xe6e1d2, leg=0x8f8874, helm=0x776b52, weapon=0x9aa3ad, wkind="sword", hp=40, dmg=[6,11], speed=3.5, range=2.2, xp=18, scale=1.0, atkCd=1.5},
	"ghoul": {n="腐尸", body=0x54703f, skin=0x6d8452, leg=0x3d4c30, hp=72, dmg=[8,14], speed=2.8, range=2.2, xp=24, scale=1.12, atkCd=1.9},
	"imp": {n="暗影使徒", body=0x4b2f6d, skin=0x7a4fae, leg=0x2e1d45, aura=0x9a5cff, hp=44, dmg=[10,18], speed=3.2, range=11.0, xp=34, scale=0.95, atkCd=2.2, ranged=true, pcolor=0x9a5cff},
	"brute": {n="裂颅屠夫", body=0x7a3520, skin=0xa15a33, leg=0x412216, weapon=0xc0b8a6, wkind="sword", hp=150, dmg=[16,28], speed=3.2, range=2.7, xp=66, scale=1.4, atkCd=2.1},
	"wraith": {n="哀嚎怨魂", body=0x2a4a5a, skin=0x4a7a8a, leg=0x1a2a35, aura=0x5fd8ff, hp=64, dmg=[12,20], speed=4.3, range=2.3, xp=44, scale=1.05, atkCd=1.3},
	"boneking": {n="白骨女王 · 塞克拉", body=0xe8e2cf, skin=0xf0ead8, leg=0xa89f88, helm=0xc8b070, weapon=0xd8d0b0, wkind="sword", aura=0xfff0a0, hp=900, dmg=[24,38], speed=3.3, range=9.0, xp=700, scale=2.05, atkCd=1.7, boss=true, ranged=true, skill="nova", pcolor=0xf0e0a0},
	"broodmother": {n="织母 · 阿拉卡", form="beast", body=0x3a1a4a, skin=0x7a2a8a, leg=0x201030, aura=0xc86aff, tail=true, hp=1500, dmg=[30,46], speed=3.6, range=3.0, xp=1400, scale=2.4, atkCd=1.6, boss=true, skill="summon"},
	"lord": {n="恐惧领主 · 瓦拉克", body=0x3b1030, skin=0x8a2050, leg=0x210a1c, helm=0xb0303c, weapon=0xe0503c, wkind="sword", aura=0xff3a3a, hp=2600, dmg=[38,58], speed=3.6, range=8.5, xp=3000, scale=2.2, atkCd=1.5, boss=true, ranged=true, skill="slam", pcolor=0xff3a2a},
	"grom": {n="腐化巨兽 · 格罗姆", body=0x4a6a2a, skin=0x6a8a3a, leg=0x2a3a18, weapon=0x8a7a5a, wkind="sword", aura=0x9aff5a, hp=1800, dmg=[34,52], speed=3.9, range=3.4, xp=1800, scale=2.3, atkCd=1.9, boss=true, skill="slam"},
	"osser": {n="主祭 · 奥赛尔", body=0x4a5a6a, skin=0xd0dce6, leg=0x2a3848, hood=0x3a4a5a, weapon=0xa8d0ff, wkind="staff", wlen=1.6, aura=0x8fd3ff, hp=2800, dmg=[32,50], speed=3.1, range=9.0, xp=3200, scale=1.9, atkCd=1.6, boss=true, ranged=true, skill="nova", pcolor=0x8fd3ff},
	"singer": {n="无名唱者", body=0xc8d4de, skin=0xe8eef4, leg=0x8aa0b0, aura=0xdfeaff, hp=3600, dmg=[36,54], speed=3.4, range=8.0, xp=4500, scale=2.1, atkCd=1.5, boss=true, ranged=true, skill="nova", pcolor=0xdfeaff},
	"tideguide": {n="引水人", body=0x2a4a52, skin=0x6a8a82, leg=0x1a2a2e, hood=0x1a3038, weapon=0x4a7a6a, wkind="staff", aura=0x4ad0c0, hp=3000, dmg=[34,52], speed=3.2, range=10.0, xp=3800, scale=1.85, atkCd=1.7, boss=true, ranged=true, skill="summon", pcolor=0x4ad0c0},
	"gray": {n="凿船者 · 格雷", body=0x4a3a30, skin=0xa89070, leg=0x2a221c, helm=0x5a4a3a, weapon=0xc8b090, wkind="sword", aura=0xc8a060, hp=4200, dmg=[40,62], speed=3.3, range=3.2, xp=5200, scale=2.0, atkCd=1.55, boss=true, skill="slam"},
	"seven": {n="七影", body=0x2a1a30, skin=0x6a4a80, leg=0x1a1020, aura=0x9a5cff, hp=3800, dmg=[38,58], speed=3.6, range=3.4, xp=5600, scale=1.7, atkCd=1.4, boss=true, skill="summon"},
	"voice": {n="众议之声", body=0x3a3a4a, skin=0x8a8a9a, leg=0x222230, aura=0xc8c0ff, hp=4600, dmg=[42,64], speed=3.5, range=9.0, xp=6800, scale=2.0, atkCd=1.45, boss=true, ranged=true, skill="nova", pcolor=0xc8c0ff},
	"kor": {n="钉底 · 柯尔", body=0x6a4a3a, skin=0xc8a080, leg=0x3a2a22, helm=0x8a7a5a, weapon=0xc0b090, wkind="sword", aura=0xffa060, hp=5200, dmg=[48,72], speed=3.2, range=3.6, xp=8000, scale=1.6, atkCd=1.6, boss=true, skill="slam"}
}

const RIFT_MOBS := ["skeleton", "ghoul", "imp", "wraith", "brute", "spider"]
const RIFT_BOSSES := ["boneking", "grom", "lord", "broodmother"]
const RIFT_AFFIXES := [
	{id="rage", n="狂暴", g="⚡", d="怪物出手更快。", loot=15, asp=1.4},
	{id="hard", n="硬化", g="🛡", d="怪物更抗打。", loot=15, dr=0.375},
	{id="wane", n="虚弱", g="🥀", d="你的治疗减半。", loot=20, heal=0.5},
	{id="swarm", n="群集", g="👥", d="怪更多，但更脆。", loot=25, count=1.6, hp=0.75},
	{id="echo", n="回响", g="🔁", d="精英倒下裂成两只半血的。", loot=30},
	{id="hush", n="寂静", g="🤫", d="技能冷却更长。", loot=25, cd=1.35},
	{id="hoard", n="宝藏", g="📦", d="本层有一只揣着东西往外跑的。", loot=40}
]
const ROOM_KINDS := ["vault", "shrine", "cage", "trap"]
const SHRINE_PICKS := [
	{id="greed", n="贪婪", g="💰", d="本层金币掉落 +150%。你挨打 +25%。"},
	{id="swift", n="迅捷", g="🌪", d="移动与攻速 +20%。最大生命 −20%。"},
	{id="plenty", n="丰饶", g="🌾", d="再涌出一批怪。掉落品质抬一档。"}
]
const ENEMY_ASSET := {
	"skeleton": "mob_skeleton", "ghoul": "mob_zombie", "imp": "mob_goblin",
	"bandit": "mob_bandit", "banditbow": "npc_rogue", "brute": "mob_bandit",
	"ashmage": "mob_wizard", "rimeknight": "mob_knight", "drowned": "mob_drowned", "wrecker": "mob_bandit",
	"boneking": "boss_sekhra", "lord": "mob_lord", "seven": "mob_ninja", "gray": "mob_bandit", "kor": "mob_bandit",
	"osser": "mob_wizard", "singer": "mob_wizard", "tideguide": "mob_wizard", "voice": "mob_wizard",
	"wolf": "mob_wolf", "boar": "mob_boar", "frostwolf": "mob_husky", "brinewolf": "mob_fox", "lavabeast": "mob_boar", "grom": "mob_stag",
	"spider": "mob_spider", "icespider": "mob_spider", "broodmother": "mob_spider",
	"rat": "mob_rat", "snake": "mob_snake", "frog": "mob_frog", "wasp": "mob_wasp"
}
const CLASS_ASSET := {"warrior": "char_warrior", "mage": "char_mage", "archer": "char_archer"}

const PHRASES := [
	{id="enough", n="够了吗", flavor="三百年了，没人回答他。", types=["weapon"], need=3, runes=["rune_ember","rune_frost","rune_hawk"], pw="击杀后 2 秒内伤害 +40%，可叠三层。"},
	{id="godown", n="我下去", flavor="第四年，他站在裂口边上说：我下去。", types=["armor"], need=2, runes=["rune_leech","rune_leech"], pw="生命低于 35% 时，获得等同已损失生命 30% 的护盾（12 秒一次）。"},
	{id="notyou", n="不得替", flavor="开口的人用那条缝。别人不行。", types=["weapon","armor"], need=4, runes=["rune_frost","rune_hawk","rune_ember","rune_leech"], pw="技能无法被打断。治疗最多把你补到 80%。"},
	{id="unsung", n="还没唱完", flavor="他们唱到一半沉了下去。", types=["helm"], need=2, runes=["rune_hawk","rune_ember"], pw="每 4 秒的第 4 秒，下一次技能不耗蓝。"},
	{id="still", n="还亮着", flavor="灰里有一团不肯散的火。", types=["offhand"], need=2, runes=["rune_ember","rune_vita"], pw="抗性上限 75% → 85%。"},
	{id="offkey", n="走调了", flavor="音总是高半度，但他们从没让他停。", types=["boots"], need=2, runes=["rune_gale","rune_hawk"], pw="穿透 +15%，移动速度 +8%。"}
]

func dun_by_id(id: String) -> Dictionary:
	for d in DUNGEONS:
		if d.id == id:
			return d
	return {}


func sk_by_id(id: String) -> Dictionary:
	for s in SKILLS:
		if s.id == id:
			return s
	return {}


func area_of(id: String) -> Dictionary:
	return AREA.get(id, {})


func etype(id: String) -> Dictionary:
	return ETYPES.get(id, {})


func type_elem(t: String) -> String:
	return TYPE_ELEM.get(t, "phys")


func class_skills(cls: String) -> Array:
	var out := []
	for s in SKILLS:
		if s.cls == cls:
			out.append(s)
	return out


func class_talents(cls: String) -> Array:
	return TALENTS.get(cls, [])


func rift_affix_by_id(id: String) -> Dictionary:
	for a in RIFT_AFFIXES:
		if a.id == id:
			return a
	return {}


func shrine_pick_by_id(id: String) -> Dictionary:
	for s in SHRINE_PICKS:
		if s.id == id:
			return s
	return {}


func first_skill(cls: String) -> Dictionary:
	for s in SKILLS:
		if s.cls == cls and int(s.req) == 1:
			return s
	return {}


func rune_by_id(id: String) -> Dictionary:
	for r in RUNES:
		if r.id == id:
			return r
	return {}


func phrase_by_id(id: String) -> Dictionary:
	for p in PHRASES:
		if p.id == id:
			return p
	return {}


func elite_mod_by_id(id: String) -> Dictionary:
	for m in ELITE_MODS:
		if m.id == id:
			return m
	return {}


func su_by_id(id: String) -> Dictionary:
	for s in SUPER_UNIQUES:
		if s.id == id:
			return s
	return {}


func named_combo(mods: Array) -> Dictionary:
	for c in ELITE_COMBOS:
		var ok := true
		for id in c.ids:
			if not mods.has(id):
				ok = false
				break
		if ok:
			return c
	return {}


func slot_name_of(type: String) -> String:
	for s in SLOTDEF:
		if str(s.get("t", s.k)) == type:
			return str(s.n)
	return type


func affix_by_k(k: String) -> Dictionary:
	for a in AFFIX:
		if a.k == k:
			return a
	for a in FEEL_AFFIX:
		if a.k == k:
			return a
	return {}


func rune_name(def: Dictionary, g: int) -> String:
	g = clampi(g, 1, 3)
	if def.is_empty():
		def = RUNES[0]
	return ("完整" + str(def.n)) if g >= 3 else (str(def.n) + str(RUNE_GRADE[g]))


func rune_val(def: Dictionary, g: int) -> int:
	if def.is_empty():
		def = RUNES[0]
	g = clampi(g, 1, 3)
	var lo: int = int(def.v[0])
	var hi: int = int(def.v[1])
	if g <= 1:
		return lo
	if g == 2:
		return hi
	return int(round(hi * 1.55))
'''

def main():
    text = HEAD + AREA + TAIL
    OUT.write_text(text, encoding="utf-8")
    print("wrote", OUT, "bytes", OUT.stat().st_size)

if __name__ == "__main__":
    main()
