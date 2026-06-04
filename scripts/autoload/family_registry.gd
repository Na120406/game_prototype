extends Node

enum FamilyStatus { INTACT, REDUCED, SCATTERED, EXTINCT }

var families: Dictionary = {}

func _ready() -> void:
	_build_initial_families()
	print("[FamilyRegistry] Ready — %d families registered." % families.size())

func _build_initial_families() -> void:
	families = {
		"shopkeeper_family": {
			"id": "shopkeeper_family",
			"name": "The Shopkeeper's Family",
			"surname": "Voss",
			"status": FamilyStatus.INTACT,
			"members": [
				{
					"id": "shopkeeper_father",
					"name": "Old Voss",
					"role": "father",
					"alive": true,
					"at_home": true,
					"personality": "cautious",
					"dialogue_id": "shopkeeper_father_normal",
					"successor": "shopkeeper_son",
					"scene_path": "res://scenes/npc/shopkeeper_father.tscn",
				},
				{
					"id": "shopkeeper_son",
					"name": "Young Voss",
					"role": "son",
					"alive": true,
					"at_home": true,
					"personality": "reckless",
					"dialogue_id": "shopkeeper_son_normal",
					"successor": "",
					"scene_path": "res://scenes/npc/shopkeeper_son.tscn",
				},
			],
			"current_head": "shopkeeper_father",
			"home_location": Vector2(240, 320),
			"business_name": "Voss General Store",
		},
		"farmer_family": {
			"id": "farmer_family",
			"name": "The Miller Family",
			"surname": "Miller",
			"status": FamilyStatus.INTACT,
			"members": [
				{
					"id": "farmer_mother",
					"name": "Martha Miller",
					"role": "mother",
					"alive": true,
					"at_home": true,
					"personality": "cautious",
					"dialogue_id": "farmer_mother_normal",
					"successor": "",
					"scene_path": "res://scenes/npc/farmer_mother.tscn",
				},
				{
					"id": "farmer_daughter",
					"name": "Eliza Miller",
					"role": "daughter",
					"alive": true,
					"at_home": true,
					"personality": "normal",
					"dialogue_id": "farmer_daughter_normal",
					"successor": "",
					"scene_path": "res://scenes/npc/farmer_daughter.tscn",
				},
			],
			"current_head": "farmer_mother",
			"home_location": Vector2(480, 180),
			"business_name": "Miller Farm",
		},
		"hermit_family": {
			"id": "hermit_family",
			"name": "The Hermit",
			"surname": "",
			"status": FamilyStatus.INTACT,
			"members": [
				{
					"id": "hermit",
					"name": "Old Hanz",
					"role": "hermit",
					"alive": true,
					"at_home": true,
					"personality": "old",
					"dialogue_id": "hermit_normal",
					"successor": "",
					"scene_path": "res://scenes/npc/hermit.tscn",
				},
			],
			"current_head": "hermit",
			"home_location": Vector2(600, 400),
			"business_name": "",
		},
	}

func get_family(family_id: String) -> Dictionary:
	return families.get(family_id, {})

func get_current_family_head(family_id: String) -> String:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return ""
	return family.get("current_head", "")

func get_family_members(family_id: String) -> Array:
	var family: Dictionary = families.get(family_id, {})
	return family.get("members", [])

func get_alive_members(family_id: String) -> Array:
	var members: Array = get_family_members(family_id)
	return members.filter(func(m: Dictionary) -> bool: return m.get("alive", false))

func mark_family_member_dead(member_id: String, family_id: String) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return false

	var members: Array = family["members"]
	for i: int in range(members.size()):
		var m_id: String = members[i].get("id", "")
		if m_id == member_id:
			members[i]["alive"] = false
			var dead_member: Dictionary = members[i]
			_on_member_death(family_id, dead_member)
			return true
	return false

func _on_member_death(family_id: String, dead_member: Dictionary) -> void:
	var family: Dictionary = families[family_id]
	var member_id: String = dead_member.get("id", "")

	if family.get("current_head", "") == member_id:
		var successor_id: String = dead_member.get("successor", "")
		if successor_id != "":
			_promote_successor(family_id, member_id, successor_id)
		else:
			_promote_next_oldest(family_id, member_id)

	var alive: Array = get_alive_members(family_id)
	var alive_count: int = alive.size()
	if alive_count == 0:
		family["status"] = FamilyStatus.EXTINCT
	elif alive_count == 1:
		family["status"] = FamilyStatus.REDUCED
	else:
		family["status"] = FamilyStatus.SCATTERED

	var status_key: String = FamilyStatus.keys()[family["status"]]
	GameState.set_flag("family_%s_status" % family_id, status_key)
	var family_name: String = family.get("name", family_id)
	print("[FamilyRegistry] %s is now %s" % [family_name, family["status"]])

func _promote_successor(family_id: String, old_id: String, new_id: String) -> void:
	families[family_id]["current_head"] = new_id
	var members: Array = families[family_id]["members"]
	for member_raw: Variant in members:
		var member: Dictionary = member_raw
		if member.get("id", "") == new_id:
			member["at_home"] = true
			GameState.set_flag("npc_%s_new_head" % new_id, true)
			GameState.set_flag("npc_%s_succeeded_from" % new_id, old_id)
			break

func _promote_next_oldest(family_id: String, dead_id: String) -> void:
	var alive_members: Array = get_alive_members(family_id)
	if alive_members.is_empty():
		return
	var new_head_id: String = alive_members[0].get("id", "")
	families[family_id]["current_head"] = new_head_id

func replace_family_member(family_id: String, old_id: String, new_id: String) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return false

	var members: Array = family["members"]
	for i: int in range(members.size()):
		var m_id: String = members[i].get("id", "")
		if m_id == old_id:
			members[i]["alive"] = false
			members[i]["at_home"] = false

	family["current_head"] = new_id
	GameState.set_flag("npc_%s_new_head" % new_id, true)
	GameState.set_flag("npc_%s_succeeded_from" % new_id, old_id)

	print("[FamilyRegistry] Replaced %s with %s in family %s" % [old_id, new_id, family_id])
	return true

func add_family_member(family_id: String, member_data: Dictionary) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return false
	var members: Array = family["members"]
	members.append(member_data)
	return true

func remove_family_member(family_id: String, member_id: String) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return false
	var members: Array = family["members"]
	for i: int in range(members.size()):
		var m_id: String = members[i].get("id", "")
		if m_id == member_id:
			members.remove_at(i)
			return true
	return false

func is_family_extinct(family_id: String) -> bool:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return true
	return family.get("status", FamilyStatus.INTACT) == FamilyStatus.EXTINCT

func get_family_status(family_id: String) -> String:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return "unknown"
	var status_key: String = FamilyStatus.keys()[family.get("status", FamilyStatus.INTACT)]
	return status_key

func get_all_families() -> Array:
	return families.keys()

func get_family_business(family_id: String) -> Dictionary:
	var family: Dictionary = families.get(family_id, {})
	if family.is_empty():
		return {}
	return {
		"name": family.get("business_name", ""),
		"location": family.get("home_location", Vector2.ZERO),
		"current_head": family.get("current_head", ""),
		"status": family.get("status", FamilyStatus.INTACT),
	}

func is_business_operational(family_id: String) -> bool:
	var business: Dictionary = get_family_business(family_id)
	if business.is_empty():
		return false
	if business.get("status", FamilyStatus.INTACT) == FamilyStatus.EXTINCT:
		return false
	var head_id: String = business.get("current_head", "")
	var family: Dictionary = families.get(family_id, {})
	var members: Array = family.get("members", [])
	for member_raw: Variant in members:
		var member: Dictionary = member_raw
		var m_id: String = member.get("id", "")
		var alive: bool = member.get("alive", false)
		if m_id == head_id and alive:
			return true
	return false

func get_scene_for_current_head(family_id: String) -> String:
	var head_id: String = get_current_family_head(family_id)
	var family: Dictionary = families.get(family_id, {})
	var members: Array = family.get("members", [])
	for member_raw: Variant in members:
		var member: Dictionary = member_raw
		if member.get("id", "") == head_id:
			return member.get("scene_path", "")
	return ""

func get_dialogue_for_current_head(family_id: String) -> String:
	var head_id: String = get_current_family_head(family_id)
	var family: Dictionary = families.get(family_id, {})
	var members: Array = family.get("members", [])
	for member_raw: Variant in members:
		var member: Dictionary = member_raw
		if member.get("id", "") == head_id:
			var dialogue_id: String = member.get("dialogue_id", "generic_greeting")
			var status: String = GameState.get_flag("family_%s_status" % family_id, "")
			if status == "REDUCED":
				return dialogue_id + "_grief"
			return dialogue_id
	return "generic_greeting"

func serialize_families() -> Dictionary:
	var serialized: Dictionary = {}
	for family_id: String in families:
		serialized[family_id] = families[family_id].duplicate(true)
	return serialized

func load_families(data: Dictionary) -> void:
	families = data.duplicate(true)
