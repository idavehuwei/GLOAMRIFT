extends RefCounted

const CHAPTERS = [
	{"name":"灰烬来信", "region":"鸦栖边境", "maps":["余烬村外", "遗忘墓园", "钟楼地窖"], "outside":[true,true,false], "color":"73816d", "boss":"欠薪的守墓人", "goal":"找回被偷走的晨钟", "story":"村里的晨钟失踪了，死人却准时上班。\n邮差递来一封烧焦的信：钟声被埋在地下。\n先去村外收集三枚余烬印记，再追踪墓园的脚印。", "joke":"守墓人：我只是想让大家睡个好觉，顺便拖欠三百年工资。"},
	{"name":"沼泽的税单", "region":"荧腐湿地", "maps":["蘑菇渡口", "沉没水道", "蛙王金库"], "outside":[true,false,false], "color":"528b7f", "boss":"收税蛙王", "goal":"夺回村民被征收的影子", "story":"晨钟响了，村民的影子却消失了。\n湿地蛙王宣称：有影子就要缴纳遮阳税。\n穿过荧光蘑菇林，潜入水道，撕毁那张荒唐的税单。", "joke":"蛙王：呱！打我可以，记得开发票。"},
	{"name":"雪线上的热汤", "region":"白骨雪岭", "maps":["风雪驿站", "冰封矿道", "霜心熔炉"], "outside":[true,false,false], "color":"829dad", "boss":"冰箱骑士", "goal":"点燃熔炉，救回冻住的商队", "story":"影子带回了北方的求救信。永冬封住山路，\n商队和最后一锅热汤一起被冻在雪里。\n寻找火种，重启霜心熔炉。别让骑士把世界调到冷藏档。", "joke":"冰箱骑士：关门！冷气都跑了！"},
	{"name":"不准下班", "region":"赤炉工业城", "maps":["焦土工坊", "废弃流水线", "契约焚化室"], "outside":[true,false,false], "color":"ad7356", "boss":"恶魔总监", "goal":"烧掉束缚亡灵的劳动契约", "story":"熔炉重新点燃，也照亮了地底工厂。\n失踪者正在替恶魔制造末日零件，工期写着：永远。\n从地面的工坊潜入流水线，把契约送进焚化室。", "joke":"恶魔总监：这是弹性工作制——弹到下辈子。"},
	{"name":"黎明退货处", "region":"无昼王庭", "maps":["破晓庭园", "倒悬书库", "永夜王座"], "outside":[true,false,false], "color":"9480ae", "boss":"永夜售后之王", "goal":"归还被封存的黎明", "story":"契约化成灰烬，幕后买家终于现身。\n永夜之王把黎明锁进王庭，只接受七天无理由退货。\n穿过庭园和倒悬书库，拿着晨钟，给这场黑夜画上句号。", "joke":"永夜之王：没有小票，世界末日也不能退！"}
]
const RARITY_NAMES = ["普通", "精良", "稀有", "史诗", "传说"]
const RARITY_COLORS = ["a3aaa7", "7aac91", "70aede", "b895df", "edba69"]
const SLOTS = ["武器", "护甲", "护符"]
const PREFIX = ["摸鱼的", "暴怒的", "吸血的", "加班的", "倒霉但强的", "会讲冷笑话的", "不讲武德的", "社恐的", "余烬之", "虚空之", "凌晨三点的", "拒绝内耗的"]
const BASES = [["断剑", "平底锅", "斩骨斧", "法棍", "幽火刃", "晾衣叉"], ["锁甲", "围裙", "夜行衣", "纸箱战甲", "龙鳞袍"], ["旧怀表", "打工魂", "猫爪符", "退货凭证", "咸鱼吊坠"]]
const SUFFIX = ["·回声", "·清醒", "·周五", "·破晓", "·不加糖", "·最后一击", "·带薪休假", "·虚无"]

static func loot(rng: RandomNumberGenerator, depth: int, guaranteed: bool = false, job: int = -1) -> Dictionary:
	var roll = rng.randf()
	var rarity = 4 if roll > 0.97 else (3 if roll > 0.84 else (2 if roll > 0.58 else (1 if roll > 0.25 else 0)))
	if guaranteed: rarity = maxi(2, rarity)
	var slot = rng.randi_range(0, 2)
	var power = 3 + depth * 2 + rarity * 4 + rng.randi_range(0, depth + 3)
	var choices = BASES[slot]
	if slot==0 and job>=0: choices = [["长剑","斩骨斧","平底锅","焰纹重刃"],["星火法杖","寒霜权杖","不加糖魔杖","虚空枝"],["猎影长弓","穿林短弓","机关弩","弹弓之王"]][job]
	return {"name":PREFIX[rng.randi_range(0,PREFIX.size()-1)] + choices[rng.randi_range(0,choices.size()-1)] + SUFFIX[rng.randi_range(0,SUFFIX.size()-1)], "slot":slot, "rarity":rarity, "power":power, "crit":rng.randi_range(1,5+rarity*3), "level":depth, "id":rng.randi()}

const TOWNS = ["余烬镇", "青灯港", "雪松堡", "炉火城", "晨星圣所"]
const CLASSES = [
	{"name":"战士", "title":"铁与血的守望者", "hp":140, "speed":135, "color":"d69a67", "weapon":"守望者长剑", "skills":["顺劈斩","旋风斩","裂地重击","冲锋"], "description":"重甲与剑盾，擅长贴身压制。\n旋风斩持续打击周围敌人；重击震晕敌群。"},
	{"name":"法师", "title":"驾驭余烬的织法者", "hp":90, "speed":140, "color":"85b4df", "weapon":"星火法杖", "skills":["火焰弹","寒冰新星","陨星坠落","闪烁"], "description":"以法杖发射爆炸火弹。\n寒冰新星冻结敌人；陨星轰击目标区域。"},
	{"name":"弓箭手", "title":"隐于林间的猎影者", "hp":110, "speed":165, "color":"91bd82", "weapon":"猎影长弓", "skills":["穿林箭","散射箭","箭雨","疾退"], "description":"敏捷的远程猎手，箭矢可穿透敌人。\n五重散射覆盖前方，箭雨持续压制目标区域。"}
]
const NPC_ROLES = ["委托人", "药剂师", "铁匠", "职业导师", "旅店老板", "伙伴契约"]
const NPC_NAMES = ["鸦邮差 · 科尔", "药剂师 · 米拉", "铁匠 · 布隆", "导师 · 伊莲", "旅店老板 · 奥多", "宠物商 · 绒绒"]

# 小宠物物种表。rarity 决定抽卡池层级；form 决定 world_3d.companion 的造型。
const PETS = [
	{"name":"余烬鼠","form":0,"rarity":0,"ranged":false,"bolt":"","power":6,"hp":54,"rate":0.95,"color":"a98a63","desc":"偷药水的灰毛小鼠，咬合力惊人，忠诚度为负。"},
	{"name":"骨犬幼崽","form":1,"rarity":0,"ranged":false,"bolt":"","power":8,"hp":74,"rate":1.10,"color":"9a9484","desc":"骨头还没长齐，已经学会替主人挡刀。"},
	{"name":"荧光蛾","form":2,"rarity":1,"ranged":true,"bolt":"venom","power":9,"hp":56,"rate":1.15,"color":"8fc49b","desc":"翅膀抖落的磷粉，会让敌人持续难受。"},
	{"name":"苔壳龟","form":3,"rarity":1,"ranged":false,"bolt":"","power":7,"hp":135,"rate":1.35,"color":"6f8a63","desc":"走得慢，但它是唯一敢跟首领对视的伙伴。"},
	{"name":"霜羽鸦","form":4,"rarity":2,"ranged":true,"bolt":"icebolt","power":13,"hp":68,"rate":1.05,"color":"7d9fc4","desc":"雪线带来的鸟。啄击带寒气，命中即减速。"},
	{"name":"熔岩史莱姆","form":5,"rarity":2,"ranged":false,"bolt":"","power":16,"hp":115,"rate":1.25,"color":"d08a52","desc":"黏在敌人身上不肯下来。据说尝起来像烤焦的糖。"},
	{"name":"符文石灵","form":6,"rarity":3,"ranged":false,"bolt":"","power":21,"hp":185,"rate":1.30,"color":"8b8f96","desc":"古代守卫的残片。沉默、可靠，从不请假。"},
	{"name":"幽焰狐","form":7,"rarity":3,"ranged":true,"bolt":"fireball","power":24,"hp":98,"rate":0.95,"color":"d98a5c","desc":"尾巴扫过的地方留下蓝色余烬，并且假装听不懂指令。"},
	{"name":"虚空之眼","form":8,"rarity":4,"ranged":true,"bolt":"icebolt","power":30,"hp":125,"rate":0.85,"color":"a98fd0","desc":"它看着你的时候，你也在被别的东西看着。"},
	{"name":"黎明幼龙","form":9,"rarity":4,"ranged":true,"bolt":"fireball","power":34,"hp":170,"rate":0.90,"color":"e0b169","desc":"被封存的黎明孵出来的幼龙，喷出的火是朝霞的颜色。"}
]

const ELITE_AFFIXES = ["烈焰", "冰霜", "雷鸣", "吸血", "迅捷"]
const MONSTER_NAMES = [
	["失魂守卫","墓园骷髅","丧钟祭司","","腐骨猎犬","掘墓蛛","亡骨射手"],
	["沼泽溺尸","苔骨仆从","蛙王巫医","","毒沼猎犬","荧腐毒蛛","苇林射手"],
	["霜铠亡卒","冰骨骷髅","暴雪术士","","雪岭霜狼","冰穴蛛","寒霜弩手"],
	["熔炉监工","焦骨工奴","契约术士","","煤渣魔犬","机械穴蛛","铆钉弩手"],
	["永夜禁卫","王庭遗骨","虚空织法者","","无昼影兽","裂隙织蛛","月蚀猎手"]
]
const BOSS_SKILLS = [
	["丧钟震荡", "亡骨复工", "狂暴：双重钟鸣"],
	["腐税毒潭", "五重毒息", "狂暴：泛滥征收"],
	["冰封牢笼", "极寒齐射", "狂暴：绝对零度"],
	["焚化流水线", "熔炉追责", "狂暴：全厂加班"],
	["虚空换位", "八方蚀光", "狂暴：黎明封印"]
]

# ---------- 成就与收藏 ----------
const ACH_KINDS = ["战斗", "探索", "财富", "伙伴", "旅程"]
const ACH_KIND_COLORS = ["c2705f", "7fa86a", "d0b06a", "8fa8d8", "a98fd0"]
# stat 为统计键，goal 为达成阈值，reward 为解锁时自动发放的奖励（金币 / 药水 / 锻造碎片）。
const ACHIEVEMENTS = [
	{"id":"first_blood","name":"第一滴血","desc":"击败第一名敌人","kind":0,"stat":"kills","goal":1,"reward":{"gold":30}},
	{"id":"slayer_50","name":"清道夫","desc":"累计击败 50 名敌人","kind":0,"stat":"kills","goal":50,"reward":{"gold":120}},
	{"id":"slayer_200","name":"不死屠夫","desc":"累计击败 200 名敌人","kind":0,"stat":"kills","goal":200,"reward":{"gold":400,"potions":2}},
	{"id":"elite_10","name":"精英猎手","desc":"击败 10 名精英敌人","kind":0,"stat":"elites","goal":10,"reward":{"shards":5}},
	{"id":"elite_40","name":"精英克星","desc":"击败 40 名精英敌人","kind":0,"stat":"elites","goal":40,"reward":{"shards":15}},
	{"id":"boss_1","name":"弑王者","desc":"击败一名章节首领","kind":0,"stat":"bosses","goal":1,"reward":{"gold":200}},
	{"id":"boss_5","name":"五王终结","desc":"击败五名章节首领","kind":0,"stat":"bosses","goal":5,"reward":{"potions":3}},
	{"id":"heavy_hit","name":"一击必杀","desc":"单次伤害达到 400","kind":0,"stat":"max_hit","goal":400,"reward":{"gold":150}},
	{"id":"crit_800","name":"会心一击","desc":"单次伤害达到 800","kind":0,"stat":"max_hit","goal":800,"reward":{"gold":500,"shards":5}},
	{"id":"flawless","name":"毫发无伤","desc":"不受伤清空一张地图","kind":0,"stat":"clean_maps","goal":1,"reward":{"potions":2}},
	{"id":"flawless_5","name":"幽灵行者","desc":"五次不受伤清空地图","kind":0,"stat":"clean_maps","goal":5,"reward":{"shards":10}},
	{"id":"chest_10","name":"开箱者","desc":"打开 10 个宝箱","kind":1,"stat":"chests","goal":10,"reward":{"gold":80}},
	{"id":"chest_40","name":"撬锁行家","desc":"打开 40 个宝箱","kind":1,"stat":"chests","goal":40,"reward":{"gold":300}},
	{"id":"marks_15","name":"印记收集者","desc":"收集 15 枚余烬印记","kind":1,"stat":"marks","goal":15,"reward":{"gold":100}},
	{"id":"deep_20","name":"深渊行者","desc":"抵达深度 20","kind":1,"stat":"max_depth","goal":20,"reward":{"gold":200}},
	{"id":"deep_50","name":"深潜者","desc":"抵达深度 50","kind":1,"stat":"max_depth","goal":50,"reward":{"gold":800,"shards":10}},
	{"id":"chapter_3","name":"远行者","desc":"推进到第三章","kind":1,"stat":"max_chapter","goal":3,"reward":{"gold":150}},
	{"id":"chapter_5","name":"无昼之路","desc":"推进到第五章","kind":1,"stat":"max_chapter","goal":5,"reward":{"gold":400,"potions":2}},
	{"id":"rich_1000","name":"小有积蓄","desc":"累计获得 1000 金币","kind":2,"stat":"gold_total","goal":1000,"reward":{"potions":1}},
	{"id":"rich_8000","name":"富甲一方","desc":"累计获得 8000 金币","kind":2,"stat":"gold_total","goal":8000,"reward":{"potions":3,"shards":10}},
	{"id":"legend_1","name":"传说初现","desc":"获得第一件传说装备","kind":2,"stat":"legendaries","goal":1,"reward":{"gold":200}},
	{"id":"legend_8","name":"传说收藏家","desc":"获得 8 件传说装备","kind":2,"stat":"legendaries","goal":8,"reward":{"shards":20}},
	{"id":"upgrade_5","name":"铸魂学徒","desc":"强化装备 5 次","kind":2,"stat":"upgrades","goal":5,"reward":{"shards":5}},
	{"id":"contract_6","name":"可靠打工人","desc":"完成 6 份城镇委托","kind":2,"stat":"contracts","goal":6,"reward":{"gold":300}},
	{"id":"pet_first","name":"第一个伙伴","desc":"获得第一只伙伴","kind":3,"stat":"pets","goal":1,"reward":{"gold":50}},
	{"id":"pet_5","name":"小小动物园","desc":"收集 5 种伙伴","kind":3,"stat":"pet_species","goal":5,"reward":{"gold":300}},
	{"id":"pet_all","name":"万物之友","desc":"集齐全部 10 种伙伴","kind":3,"stat":"pet_species","goal":10,"reward":{"potions":5,"shards":20}},
	{"id":"pet_lv10","name":"老练伙伴","desc":"伙伴达到 10 级","kind":3,"stat":"pet_level","goal":10,"reward":{"shards":10}},
	{"id":"veteran_1h","name":"老练旅人","desc":"游戏时长满 1 小时","kind":4,"stat":"playtime","goal":3600,"reward":{"gold":500}},
	{"id":"level_15","name":"渐入佳境","desc":"角色达到 15 级","kind":4,"stat":"max_level","goal":15,"reward":{"gold":300}},
	{"id":"death_1","name":"第一次也是最后一次","desc":"倒下过一次。账单仍然没有。","kind":4,"stat":"deaths","goal":1,"reward":{"potions":1}},
	{"id":"cycle_1","name":"深渊再来","desc":"进入第二轮深渊","kind":4,"stat":"cycle","goal":1,"reward":{"potions":2}},
	{"id":"hidden_return","name":"退货成功","desc":"把黎明退回了人间。","kind":4,"stat":"victories","goal":1,"hidden":true,"reward":{"gold":1000,"shards":20}},
	{"id":"hidden_classes","name":"三面手","desc":"三种职业都用过一遍。","kind":4,"stat":"classes","goal":3,"hidden":true,"reward":{"gold":200}}
]
const ARMORY_CAP = 30

static func bestiary_entries() -> Array:
	var out = []
	for c in CHAPTERS.size():
		for kind in MONSTER_NAMES[c].size():
			var name = str(MONSTER_NAMES[c][kind])
			if name == "": name = str(CHAPTERS[c].boss)
			out.append({"key":"%d:%d" % [c, kind], "name":name, "chapter":c, "boss":kind==3})
	return out
