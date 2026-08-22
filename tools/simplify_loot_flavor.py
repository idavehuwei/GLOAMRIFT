import json

PATH = "godot/data/loot.json"

new_flavor = {
    # ---- UNIQUES ----
    "u_hammer": "铁匠卡登的锤。一锤一个。",
    "u_nineteen": "桥上十九道栏，每根拦过一个人。",
    "u_ruler": "量尺只剩一格，够量一个人。",
    "u_thimble": "第七个封墙人带的顶针。",
    "u_second": "第二根钉的坑挖好了，还空着。",
    "u_voices": "合唱少一个人，就薄一分。",
    "u_breath": "他们从不同时换气。",
    "u_pitch": "八岁的皮尔，音总高半度。",
    "u_rule": "唱起来就不能停，这是规矩。",
    "u_unfinished": "他们唱到一半沉了，还差最后一段。",
    "u_third": "头两回我吐了，第三条才顺手。",
    "u_names": "他记得每一条船。",
    "u_tide": "水一格格涨，他在水里没事。",
    "u_son": "他这辈子就想证明爹没白死。",
    "u_shoe": "水面浮起一只小孩的鞋。",
    "u_aye": "一个人开口，其余就好办。",
    "u_custom": "照旧例，谁也不用想。",
    "u_abstain": "我不懂这些，弃权。",
    "u_erl": "第四十一张票，唯一开了口的。",
    "u_retally": "三百年后，有人把那天的票又数了一遍。",
    "u_acres": "湖北边二十亩，他记得每一垄。",
    "u_green": "她就想吃点新鲜的。",
    "u_law": "他给赖账写了后果，三百年后还在执行。",
    "u_down": "第四年，他站到裂口边说：我下去。",
    "u_enough": "三百年了，没人应他。",
    # ---- SET: 石桥守望 ----
    "watch": "他们守过这座桥。桥在，人没了。",
    "watch_w": "守桥的剑，刃口一直对着河。",
    "watch_a": "铁锈比漆厚，漆下压着名字。",
    "watch_h": "帽檐挡住北风，也挡住脸。",
    "watch_g": "掌心磨穿了三层铁。",
    "watch_b": "鞋底还沾着桥板的灰。",
    "watch_l": "扣环是用桥钉打的。",
    # ---- SET: 暮语猎手 ----
    "dusk": "林子里先出声的，不是人。",
    "dusk_w": "弦是蛛丝，她说这样听得见风。",
    "dusk_a": "叶子缝进去的，不是装饰。",
    "dusk_h": "帽沿压得很低，她不想被林子看见。",
    "dusk_g": "指节上有拉弦磨的茧。",
    "dusk_b": "踩落叶不响，林子喜欢。",
    "dusk_l": "扣子是一颗没孵的卵。",
    # ---- SET: 余烬课徒 ----
    "ember": "第一课：火记得谁点过它。",
    "ember_w": "杖头还烫，课没上完。",
    "ember_a": "下摆烧焦一圈。",
    "ember_h": "帽里有烟，戴上就咳。",
    "ember_g": "指尖黑了，洗不掉。",
    "ember_b": "走过的地方留一圈温的。",
    "ember_o": "只抄到第三页，后面是火。",
    # ---- SET: 裂隙行者 ----
    "rift": "下去的人会换一双脚，这双还没换完。",
    "rift_a": "领口朝下，它记得怎么下去。",
    "rift_h": "戴上会听见呼吸，不是你的。",
    "rift_g": "掌纹被抹平了。",
    "rift_b": "底上没有泥，泥不敢粘。",
    "rift_l": "扣一次，深一层。",
    # ---- SET: 灰舱旧例 ----
    "grey": "照旧例，谁也不用想。",
    "grey_w": "锤面刻着：附议。",
    "grey_a": "甲缝里夹着一张弃权票。",
    "grey_h": "面罩只留一条缝，开口的人走这条缝。",
    "grey_g": "握这锤的换过十一任。",
    "grey_b": "踏在舱板上，像在计票。",
    "grey_l": "扣环是一枚空选票。",
    # ---- SET: 织母丝线 ----
    "silk": "丝不是穿的，是用来记路的。",
    "silk_w": "杖身会自己往前伸。",
    "silk_a": "袍上的纹会动，眨眼换一条。",
    "silk_h": "冠是个茧，还没破。",
    "silk_g": "指间总粘着一根丝，拔不掉。",
    "silk_b": "墙也能走，你最好别试。",
    "silk_o": "页与页之间，是丝。",
    # ---- SET: 十一条船 ----
    "fleet": "他记得每一条船，第十一条没回来。",
    "fleet_w": "弦潮得发白，像泡了很久。",
    "fleet_a": "盐渍到领口，下面压着名字。",
    "fleet_h": "帽檐滴过十一年的水。",
    "fleet_g": "掌心一道沟，缆绳勒的。",
    "fleet_b": "走地上也像在船上。",
    "fleet_l": "扣在涨潮的那一格。",
    # ---- SET: 第一次下潜 ----
    "dive": "第四年，他站到裂口边说：我下去。",
    "dive_w": "刃尖朝下，只认这一条路。",
    "dive_a": "甲里写着日期，没有回来的。",
    "dive_h": "戴上就看不见天。",
    "dive_g": "抓过裂口的边，边上早没了。",
    "dive_b": "一步比一步深，靴底还在。",
    "dive_n": "坠子是一颗没点亮的灯。",
    # ---- CHARM UNIQUES ----
    "c_pin": "第七个封墙人带的顶针。",
    "c_whistle": "皮尔吹过，音总高半度。",
    "c_lace": "水面浮起一只小孩的鞋，带子还在。",
    "c_ticket": "我不懂这些，弃权。",
    "c_clod": "湖北边二十亩，他还记得土的味道。",
}

d = json.load(open(PATH, encoding="utf-8"))
changed = 0
missing = 0

def walk(o):
    global changed, missing
    if isinstance(o, dict):
        if "flavor" in o:
            i = o.get("id", "")
            if i in new_flavor:
                if o["flavor"] != new_flavor[i]:
                    o["flavor"] = new_flavor[i]
                    changed += 1
            else:
                missing += 1
                print("未匹配 id:", i, "->", o["flavor"])
        for v in o.values():
            walk(v)
    elif isinstance(o, list):
        for v in o:
            walk(v)

walk(d)
json.dump(d, open(PATH, "w", encoding="utf-8"), ensure_ascii=False, indent=2)
open(PATH, "a", encoding="utf-8").write("\n")
print("已改写 flavor 条数:", changed, "| 未匹配:", missing)
