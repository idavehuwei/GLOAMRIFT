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
const NPC_ROLES = ["委托人", "药剂师", "铁匠", "职业导师", "旅店老板"]
const NPC_NAMES = ["鸦邮差 · 科尔", "药剂师 · 米拉", "铁匠 · 布隆", "导师 · 伊莲", "旅店老板 · 奥多"]

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
