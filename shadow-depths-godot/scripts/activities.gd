extends RefCounted
var g
var shards = 0
var buff_time = 0.0
var contracts: Array = []
var sites: Array = []
var challenge_ids: Array = []
var challenge_active = false
func _init(owner_game):
	g = owner_game
	contracts = [
		{"name":"清剿亡者","kind":"kill","goal":12,"count":0,"accepted":false,"claimed":false},
		{"name":"精英狩猎","kind":"elite","goal":3,"count":0,"accepted":false,"claimed":false},
		{"name":"遗迹寻宝","kind":"chest","goal":4,"count":0,"accepted":false,"claimed":false}]
func reset_map():
	buff_time = 0; sites.clear(); challenge_ids.clear(); challenge_active = false
	if not g.in_town:
		sites.append({"pos":Vector2(795,675),"kind":"blessing","name":"余烬祝福祭坛","used":false})
		sites.append({"pos":Vector2(1035,465),"kind":"challenge","name":"精英试炼祭坛","used":false})
func update(dt: float): buff_time = maxf(0,buff_time-dt)
func interact() -> bool:
	for site in sites:
		if site.pos.distance_to(g.player)>60: continue
		if site.used: g.note("这座祭坛的力量已经用尽。"); return true
		site.used = true
		if site.kind=="blessing":
			buff_time = 90; g.mana = 100; g.burst(site.pos,Color("bcd19a")); g.note("余烬祝福：本地图内 90 秒伤害提升 25%。")
		else:
			for i in 3:
				var p = site.pos+Vector2.from_angle(i*TAU/3)*54
				if not g.walkable(p): p = site.pos
				g.spawn_enemy(p,[0,4,6][i],true)
				challenge_ids.append(g.enemy_uid)
			challenge_active = not challenge_ids.is_empty()
			g.note("精英试炼开启：击败祭坛召出的精英，赢取史诗装备与材料！")
		return true
	return false
func progress(kind: String):
	for c in contracts:
		if c.kind==kind and c.accepted and not c.claimed: c.count = mini(c.goal,c.count+1)
func killed(e: Dictionary):
	progress("kill")
	if e.get("elite",false): progress("elite"); shards += 1
	if e.boss: shards += 5
	if challenge_ids.has(e.get("uid",-1)):
		challenge_ids.erase(e.uid)
		if challenge_ids.is_empty() and challenge_active:
			challenge_active = false; shards += 10
			var item = g.Data.loot(g.rng,g.depth(),true,g.hero_class); item.rarity = maxi(3,int(item.rarity)); item.power += 5
			g.drops.append({"pos":e.pos,"kind":"item","item":item})
			g.note("祭坛试炼完成！额外史诗装备 + 10 锻造碎片。")
func contract_action(index: int):
	if index<0 or index>=contracts.size(): return
	var c = contracts[index]
	if c.claimed: g.note("本轮委托已完成；通关本章会刷新。")
	elif not c.accepted:
		if not g.in_town: g.note("请回到城镇领取委托。"); return
		c.accepted = true; g.note("领取支线委托："+c.name); g.save_game()
	elif c.count>=c.goal:
		if not g.in_town: g.note("回城后可领取委托奖励。"); return
		if g.inventory.size()>=36: g.note("请先腾出一格背包再领奖。"); return
		c.claimed = true; g.gold += 100*g.depth(); shards += 5
		if g.achv != null: g.achv.contract_done()
		g.inventory.append(g.Data.loot(g.rng,g.depth(),true,g.hero_class)); g.note("委托奖励：金币、稀有装备与 5 碎片。"); g.save_game()
func salvage():
	if not g.in_town: g.note("分解装备需要回到城镇。"); return
	if g.inventory.is_empty(): return
	var index = clampi(g.selected,0,g.inventory.size()-1)
	var item = g.inventory[index]
	var amount = 2+int(item.rarity)*2
	shards += amount; g.inventory.remove_at(index); g.note("分解获得 %d 锻造碎片。" % amount); g.save_game()
func upgrade(slot: int):
	if not g.in_town: g.note("强化装备需要回到城镇。"); return
	var item = g.equipped[slot]
	if item.name=="空": g.note("请先装备物品。"); return
	var rank = int(item.get("upgrade",0))
	if rank>=5: g.note("此装备已经强化至 +5。"); return
	var cost = 3+rank*2
	var coins = 25*g.depth()*(rank+1)
	if shards<cost or g.gold<coins: g.note("材料或金币不足。"); return
	shards -= cost; g.gold -= coins; item.power += 2+g.depth(); item["upgrade"] = rank+1
	g.note("强化成功："+item.name+" +%d" % (rank+1)); g.save_game()
	if g.achv != null: g.achv.upgraded()
func next_chapter():
	for c in contracts: c.count = 0; c.accepted = false; c.claimed = false
func snapshot() -> Dictionary: return {"shards":shards,"contracts":contracts}
func restore(data: Dictionary):
	shards = maxi(0,int(data.get("shards",0)))
	if data.get("contracts",[]).size()==3: contracts = data.contracts
