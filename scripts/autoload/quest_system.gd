extends Node

signal quest_accepted(quest_id: String, context: Dictionary)
signal quest_completed(quest_id: String)
signal quest_failed(quest_id: String)

var active_quests: Array[Dictionary] = []
var completed_quests: Array[String] = []
var failed_quests: Array[String] = []

var quest_definitions: Dictionary = {}

func _ready() -> void:
	_build_quest_library()
	print("[QuestSystem] Ready — %d quests available." % quest_definitions.size())

func _build_quest_library() -> void:
	quest_definitions = {
		"escort_voss_mountain": {
			"id": "escort_voss_mountain",
			"name": "Mountain Walk",
			"description": "Old Voss is heading up the mountain. He seems uneasy about going alone.",
			"giver": "shopkeeper_father",
			"type": "escort",
			"target_npc": "shopkeeper_father",
			"target_location": "mountain_path",
			"reward": {"item": "old_key", "amount": 1},
			"fail_conditions": ["npc_died_without_player"],
			"chain_interaction": "shopkeeper_mountain",
			"intervention_effect": "player_escorted",
		},
		"deliver_medicine": {
			"id": "deliver_medicine",
			"name": "Medicine Delivery",
			"description": "Martha Miller needs medicine delivered to Old Voss before his mountain trip.",
			"giver": "farmer_mother",
			"type": "delivery",
			"target_npc": "shopkeeper_father",
			"reward": {"item": "coin", "amount": 50},
			"chain_interaction": "shopkeeper_mountain",
		},
		"investigate_noise": {
			"id": "investigate_noise",
			"name": "Strange Sounds",
			"description": "Villagers have been hearing strange sounds at night near the forest edge.",
			"giver": "hermit",
			"type": "investigation",
			"target_location": "forest_edge",
			"reward": {"item": "lore_fragment", "amount": 1},
			"chain_interaction": "harvest_blight",
		},
		"attend_festival": {
			"id": "attend_festival",
			"name": "Village Festival",
			"description": "The annual village festival is tomorrow. Everyone is invited.",
			"giver": "shopkeeper_father",
			"type": "social",
			"target_location": "village_square",
			"chain_interaction": "festival_day",
			"fail_conditions": ["player_absent", "festival_cancelled"],
		},
	}

func accept_quest(quest_id: String) -> bool:
	if not quest_definitions.has(quest_id):
		push_error("[QuestSystem] Unknown quest: %s" % quest_id)
		return false

	for quest: Dictionary in active_quests:
		var existing_id: String = quest.get("id", "")
		if existing_id == quest_id:
			return false

	var quest_def: Dictionary = quest_definitions[quest_id]
	var quest: Dictionary = quest_def.duplicate()
	quest["accepted_day"] = GameState.current_day
	quest["status"] = "active"
	active_quests.append(quest)

	if quest_def.has("chain_interaction"):
		var chain_id: String = quest_def.get("chain_interaction", "")
		if quest_def.has("intervention_effect"):
			var effect: String = quest_def.get("intervention_effect", "")
			_register_intervention(quest_id, chain_id, effect)

	quest_accepted.emit(quest_id, quest)
	print("[QuestSystem] Quest accepted: %s" % quest_id)
	return true

func complete_quest(quest_id: String) -> bool:
	var quest_idx: int = _find_active_quest(quest_id)
	if quest_idx < 0:
		return false

	var quest: Dictionary = active_quests[quest_idx]
	active_quests.remove_at(quest_idx)
	completed_quests.append(quest_id)

	var reward: Dictionary = quest.get("reward", {})
	if reward.has("item"):
		var item: String = reward.get("item", "")
		var amount: int = reward.get("amount", 1)
		GameState.add_item(item, amount)

	quest_completed.emit(quest_id)
	print("[QuestSystem] Quest completed: %s" % quest_id)
	return true

func fail_quest(quest_id: String, reason: String) -> bool:
	var quest_idx: int = _find_active_quest(quest_id)
	if quest_idx < 0:
		return false

	var quest: Dictionary = active_quests[quest_idx]
	active_quests.remove_at(quest_idx)
	failed_quests.append(quest_id)

	GameState.set_flag("quest_%s_failed" % quest_id, true)
	GameState.set_flag("quest_%s_fail_reason" % quest_id, reason)

	quest_failed.emit(quest_id)
	print("[QuestSystem] Quest failed: %s (%s)" % [quest_id, reason])
	return true

func _register_intervention(quest_id: String, chain_id: String, effect: String) -> void:
	GameState.set_flag("quest_%s_intervention_%s" % [quest_id, chain_id], true)

func check_intervention(quest_id: String, chain_id: String) -> bool:
	return GameState.get_flag("quest_%s_intervention_%s" % [quest_id, chain_id], false)

func on_event_outcome(chain_id: String, outcome: String) -> void:
	for quest: Dictionary in active_quests:
		var interaction: String = quest.get("chain_interaction", "")
		if interaction != chain_id:
			continue

		var qtype: String = quest.get("type", "")
		var qid: String = quest.get("id", "")

		match outcome:
			"safe":
				if qtype == "escort":
					complete_quest(qid)
			"injured":
				if qtype == "escort":
					complete_quest(qid)
			"dead":
				if qtype == "escort":
					var fail_reason: String = "The person you were supposed to protect died."
					if check_intervention(qid, chain_id):
						fail_reason = "Despite your escort, something went terribly wrong."
					fail_quest(qid, fail_reason)

func is_quest_active(quest_id: String) -> bool:
	for quest: Dictionary in active_quests:
		var existing_id: String = quest.get("id", "")
		if existing_id == quest_id:
			return true
	return false

func is_quest_completed(quest_id: String) -> bool:
	return quest_id in completed_quests

func is_quest_failed(quest_id: String) -> bool:
	return quest_id in failed_quests

func _find_active_quest(quest_id: String) -> int:
	for i: int in range(active_quests.size()):
		var existing_id: String = active_quests[i].get("id", "")
		if existing_id == quest_id:
			return i
	return -1

func get_active_quests() -> Array:
	return active_quests.duplicate()

func get_quest_definition(quest_id: String) -> Dictionary:
	return quest_definitions.get(quest_id, {})

func get_available_quests() -> Array:
	var available: Array = []
	for quest_id: String in quest_definitions:
		if not is_quest_active(quest_id) and not is_quest_completed(quest_id) and not is_quest_failed(quest_id):
			available.append(quest_definitions[quest_id])
	return available

func has_active_escort_quest(target_npc: String) -> bool:
	for quest: Dictionary in active_quests:
		var targ: String = quest.get("target_npc", "")
		var qtype: String = quest.get("type", "")
		if targ == target_npc and qtype == "escort":
			return true
	return false
