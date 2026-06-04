extends Node

signal event_chain_started(chain_id: String, root_event: String)
signal event_chain_step(chain_id: String, step_index: int, step_data: Dictionary)
signal event_chain_completed(chain_id: String)
signal event_chain_aborted(chain_id: String, reason: String)
signal branch_triggered(chain_id: String, branch_id: String, branch_data: Dictionary)
signal player_intervention_detected(chain_id: String, intervention_type: String)

enum ChainState { DORMANT, ACTIVE, PAUSED, COMPLETED, ABORTED }
enum Outcome { NONE, SAFE, INJURED, DEAD, MISSED, DELAYED }

const MAX_CHAIN_LENGTH: int = 20

var active_chains: Dictionary = {}
var completed_chains: Array[String] = []
var chain_definitions: Dictionary = {}
var scheduled_events: Array[Dictionary] = []

func _ready() -> void:
	_build_chain_library()
	print("[EventChainEngine] Ready — %d chain definitions loaded." % chain_definitions.size())

func _process(_delta: float) -> void:
	_process_scheduled_events()

func _process_scheduled_events() -> void:
	var to_remove: Array[int] = []
	for i: int in range(scheduled_events.size()):
		var ev: Dictionary = scheduled_events[i]
		ev["delay"] -= 1
		if ev["delay"] <= 0:
			_execute_scheduled_event(ev)
			to_remove.append(i)
	for i: int in range(to_remove.size() - 1, -1, -1):
		scheduled_events.remove_at(to_remove[i])

func _build_chain_library() -> void:
	chain_definitions = {
		"shopkeeper_mountain": {
			"id": "shopkeeper_mountain",
			"name": "Shopkeeper's Mountain Trip",
			"trigger_condition": "npc_schedule_mountain_day",
			"weather_sensitive": true,
			"base_risk": 0.0,
			"root_event": "shopkeeper_ascending",
			"outcomes": {
				"safe": {
					"weight": 0.70,
					"roll_threshold": 0.70,
					"consequences": [],
					"message": "Shopkeeper returned safely.",
				},
				"delayed": {
					"weight": 0.10,
					"roll_threshold": 0.80,
					"consequences": ["shop_late_open"],
					"message": "Shopkeeper returned late.",
				},
				"injured": {
					"weight": 0.15,
					"roll_threshold": 0.95,
					"consequences": ["shopkeeper_injured", "shop_closed_days"],
					"message": "Shopkeeper was injured on the mountain.",
				},
				"dead": {
					"weight": 0.05,
					"roll_threshold": 1.0,
					"consequences": ["shopkeeper_dead", "shop_closes", "funeral_scheduled", "son_takes_over"],
					"message": "Shopkeeper did not return.",
				},
			},
			"branches": {
				"injured_player_escorted": {
					"condition": "player_escorted",
					"modifiers": {
						"injured_weight": -0.08,
						"dead_weight": -0.03,
						"safe_weight": 0.11,
					},
				},
				"injured_bad_weather": {
					"condition": "weather_storm",
					"modifiers": {
						"injured_weight": 0.15,
						"dead_weight": 0.1,
					},
				},
				"dead_bad_weather": {
					"condition": "weather_heavy_rain",
					"modifiers": {
						"injured_weight": 0.2,
						"dead_weight": 0.2,
					},
				},
			},
			"chain_steps": [
				{"delay": 0, "step": "npc_departed", "action": "npc_leaves_home"},
				{"delay": 2, "step": "npc_ascending", "action": "npc_on_mountain"},
				{"delay": 5, "step": "outcome_resolved", "action": "resolve_outcome"},
				{"delay": 10, "step": "return_process", "action": "npc_returns_or_not"},
			],
		},
		"festival_day": {
			"id": "festival_day",
			"name": "Village Festival",
			"trigger_condition": "calendar_festival_day",
			"weather_sensitive": true,
			"base_risk": 0.0,
			"root_event": "festival_begins",
			"outcomes": {
				"proceeds": {
					"weight": 0.65,
					"roll_threshold": 0.65,
					"consequences": [],
					"message": "Festival proceeded normally.",
				},
				"rain_cancel": {
					"weight": 0.20,
					"roll_threshold": 0.85,
					"consequences": ["festival_cancelled", "villagers_disappointed"],
					"message": "Heavy rain cancelled the festival.",
				},
				"cancelled_mysterious": {
					"weight": 0.15,
					"roll_threshold": 1.0,
					"consequences": ["festival_cancelled_mystery", "strange_events"],
					"message": "The festival was cancelled for unknown reasons.",
				},
			},
			"branches": {},
			"chain_steps": [
				{"delay": 0, "step": "festival_setup", "action": "villagers_prepare"},
				{"delay": 3, "step": "festival_start", "action": "festival_begins"},
				{"delay": 8, "step": "outcome_resolved", "action": "resolve_outcome"},
			],
		},
		"harvest_blight": {
			"id": "harvest_blight",
			"name": "Crop Blight",
			"trigger_condition": "season_autumn_approaching",
			"weather_sensitive": false,
			"base_risk": 0.0,
			"root_event": "blight_signs_appear",
			"outcomes": {
				"healthy": {
					"weight": 0.50,
					"roll_threshold": 0.50,
					"consequences": [],
					"message": "Harvest was good.",
				},
				"partial_blight": {
					"weight": 0.35,
					"roll_threshold": 0.85,
					"consequences": ["crops_reduced", "food_shortage_warning"],
					"message": "Some crops were lost to blight.",
				},
				"total_blight": {
					"weight": 0.15,
					"roll_threshold": 1.0,
					"consequences": ["crops_destroyed", "food_shortage", "villagers_leaving"],
					"message": "All crops were destroyed by blight.",
				},
			},
			"branches": {},
			"chain_steps": [
				{"delay": 0, "step": "blight_signs", "action": "signs_noticed"},
				{"delay": 5, "step": "blight_spread", "action": "spreads_or_not"},
				{"delay": 10, "step": "harvest_time", "action": "harvest_assessed"},
			],
		},
	}

func trigger_chain(chain_id: String, context: Dictionary = {}) -> bool:
	if not chain_definitions.has(chain_id):
		push_error("[EventChainEngine] Unknown chain: %s" % chain_id)
		return false

	if active_chains.has(chain_id):
		return false

	var def: Dictionary = chain_definitions[chain_id]
	var chain: Dictionary = {
		"id": chain_id,
		"state": ChainState.ACTIVE,
		"context": context,
		"current_step": 0,
		"rolls_made": {},
		"active_branch": "",
		"consequences_applied": [],
		"intervention_active": false,
	}

	active_chains[chain_id] = chain
	_schedule_chain_steps(chain_id, def)
	var root_event: String = def.get("root_event", "")
	event_chain_started.emit(chain_id, root_event)
	print("[EventChainEngine] Chain started: %s" % chain_id)
	return true

func _schedule_chain_steps(chain_id: String, def: Dictionary) -> void:
	var steps: Array = def.get("chain_steps", [])
	for step_data: Dictionary in steps:
		scheduled_events.append({
			"chain_id": chain_id,
			"step": step_data.get("step", ""),
			"action": step_data.get("action", ""),
			"delay": step_data.get("delay", 0),
			"executed": false,
		})

func _execute_scheduled_event(ev: Dictionary) -> void:
	var chain_id: String = ev.get("chain_id", "")
	if not active_chains.has(chain_id):
		return

	var step: String = ev.get("step", "")
	var action: String = ev.get("action", "")
	var def: Dictionary = chain_definitions[chain_id]
	var chain: Dictionary = active_chains[chain_id]

	match action:
		"resolve_outcome":
			_resolve_outcome(chain_id)
		"npc_returns_or_not":
			_finalize_npc_return(chain_id)
		"npc_leaves_home":
			_apply_step_effect(chain_id, step, "npc_left_home")
		"npc_on_mountain":
			_apply_step_effect(chain_id, step, "npc_mountain_ascent")
		"harvest_assessed":
			_resolve_outcome(chain_id)

	event_chain_step.emit(chain_id, chain["current_step"], {"step": step, "action": action})
	chain["current_step"] += 1

	var chain_steps: Array = def.get("chain_steps", [])
	if chain["current_step"] >= chain_steps.size():
		_complete_chain(chain_id)

func _resolve_outcome(chain_id: String) -> void:
	var def: Dictionary = chain_definitions[chain_id]
	var chain: Dictionary = active_chains[chain_id]
	var context: Dictionary = chain.get("context", {})

	var outcome_weights: Dictionary = {}
	var outcomes: Dictionary = def.get("outcomes", {})
	for key: String in outcomes:
		var weight: float = outcomes[key].get("weight", 0.0)
		outcome_weights[key] = weight

	outcome_weights = _apply_branch_modifiers(chain_id, outcome_weights)
	var total: float = 0.0
	for w: float in outcome_weights.values():
		total += w
	for key: String in outcome_weights:
		outcome_weights[key] = outcome_weights[key] / total

	var roll: float = randf()
	var cumulative: float = 0.0
	var chosen_outcome: String = "safe"

	for outcome_key: String in outcome_weights:
		cumulative += outcome_weights[outcome_key]
		if roll <= cumulative:
			chosen_outcome = outcome_key
			break

	chain["rolls_made"]["outcome"] = chosen_outcome
	chain["rolls_made"]["roll_value"] = roll

	var outcome_data: Dictionary = def["outcomes"][chosen_outcome]
	print("[EventChainEngine] Chain '%s' outcome: %s (roll=%.2f)" % [chain_id, chosen_outcome, roll])

	var consequences: Array = outcome_data.get("consequences", [])
	for consequence_id: String in consequences:
		_apply_consequence(consequence_id, chain_id, context)
		chain["consequences_applied"].append(consequence_id)

	var event_id: String = chain_id + "_" + chosen_outcome
	EventManager.trigger_event(event_id)

func _apply_branch_modifiers(chain_id: String, weights: Dictionary) -> Dictionary:
	var def: Dictionary = chain_definitions[chain_id]
	var branches: Dictionary = def.get("branches", {})
	var chain: Dictionary = active_chains[chain_id]
	var context: Dictionary = chain.get("context", {})

	var modified: Dictionary = weights.duplicate(true)

	for branch_id: String in branches:
		var branch: Dictionary = branches[branch_id]
		var condition: String = branch.get("condition", "")
		var condition_met: bool = _check_branch_condition(condition, context)

		if condition_met:
			chain["active_branch"] = branch_id
			var modifiers: Dictionary = branch.get("modifiers", {})
			for outcome_key: String in modifiers:
				if modified.has(outcome_key):
					modified[outcome_key] = modified[outcome_key] + modifiers[outcome_key]
					modified[outcome_key] = maxf(0.0, modified[outcome_key])
			branch_triggered.emit(chain_id, branch_id, branch)

	return modified

func _check_branch_condition(condition: String, context: Dictionary) -> bool:
	match condition:
		"player_escorted":
			return context.get("player_escorted", false)
		"weather_storm":
			return WeatherSystem.get_today_weather() == "storm"
		"weather_heavy_rain":
			return WeatherSystem.get_today_weather() == "heavy_rain"
		"weather_rain":
			var weather: String = WeatherSystem.get_today_weather()
			return weather == "rain" or weather == "drizzle"
		"npc_has_escort":
			return context.get("has_escort", false)
	return false

func _apply_step_effect(chain_id: String, step: String, description: String) -> void:
	print("[EventChainEngine] Chain '%s' step '%s': %s" % [chain_id, step, description])

func _finalize_npc_return(chain_id: String) -> void:
	var chain: Dictionary = active_chains[chain_id]
	var rolls_made: Dictionary = chain.get("rolls_made", {})
	var outcome: String = rolls_made.get("outcome", "safe")
	match outcome:
		"safe", "delayed":
			pass
		"injured":
			GameState.set_flag("%s_npc_injured" % chain_id)
		"dead":
			GameState.set_flag("%s_npc_dead" % chain_id)
			var context: Dictionary = chain.get("context", {})
			var npc_id: String = context.get("npc_id", "")
			var family_id: String = context.get("family_id", "")
			FamilyRegistry.mark_family_member_dead(npc_id, family_id)

func _apply_consequence(consequence_id: String, chain_id: String, context: Dictionary) -> void:
	match consequence_id:
		"shop_closes":
			GameState.set_flag("shop_open", false)
			GameState.set_flag("shop_closes_day", GameState.current_day)
			ConsequenceResolver.apply_scene_change("res://scenes/world/shop.tscn", "set_shop_state", "closed")
		"shop_closed_days":
			var days: int = randi() % 3 + 2
			GameState.set_flag("shop_open", false)
			GameState.set_flag("shop_reopens_day", GameState.current_day + days)
			ConsequenceResolver.schedule_flag_change("shop_open", true, days)
		"shop_late_open":
			GameState.set_flag("shop_late", true)
		"funeral_scheduled":
			var funeral_day: int = GameState.current_day + 3
			GameState.set_flag("funeral_scheduled_day", funeral_day)
			ConsequenceResolver.schedule_event("funeral", funeral_day - GameState.current_day)
		"son_takes_over":
			var family_id: String = context.get("family_id", "")
			var son_npc_id: String = context.get("son_npc_id", "shopkeeper_son")
			ConsequenceResolver.schedule_family_succession(family_id, son_npc_id, GameState.current_day + 3)
			GameState.set_flag("new_shopkeeper", true)
		"food_shortage":
			GameState.set_flag("food_shortage", true)
			GameState.set_flag("food_shortage_day", GameState.current_day)
		"villagers_leaving":
			GameState.set_flag("villagers_leaving", true)
		"strange_events":
			GameState.set_flag("strange_events_active", true)
			WeatherSystem.trigger_anomaly_weather()

func register_player_intervention(chain_id: String, intervention_type: String) -> void:
	if not active_chains.has(chain_id):
		return
	active_chains[chain_id]["intervention_active"] = true
	active_chains[chain_id]["intervention_type"] = intervention_type
	player_intervention_detected.emit(chain_id, intervention_type)
	print("[EventChainEngine] Player intervention in chain '%s': %s" % [chain_id, intervention_type])

func pause_chain(chain_id: String) -> void:
	if active_chains.has(chain_id):
		active_chains[chain_id]["state"] = ChainState.PAUSED

func resume_chain(chain_id: String) -> void:
	if active_chains.has(chain_id):
		active_chains[chain_id]["state"] = ChainState.ACTIVE

func abort_chain(chain_id: String, reason: String) -> void:
	if active_chains.has(chain_id):
		active_chains[chain_id]["state"] = ChainState.ABORTED
		event_chain_aborted.emit(chain_id, reason)
		active_chains.erase(chain_id)
		print("[EventChainEngine] Chain aborted: %s (%s)" % [chain_id, reason])

func _complete_chain(chain_id: String) -> void:
	if active_chains.has(chain_id):
		active_chains[chain_id]["state"] = ChainState.COMPLETED
		completed_chains.append(chain_id)
		active_chains.erase(chain_id)
		event_chain_completed.emit(chain_id)
		print("[EventChainEngine] Chain completed: %s" % chain_id)

func get_chain_state(chain_id: String) -> int:
	if not active_chains.has(chain_id):
		if chain_id in completed_chains:
			return ChainState.COMPLETED
		return ChainState.DORMANT
	return active_chains[chain_id]["state"]

func is_chain_active(chain_id: String) -> bool:
	return active_chains.has(chain_id)

func get_chain_info(chain_id: String) -> Dictionary:
	if active_chains.has(chain_id):
		return active_chains[chain_id]
	return {}

func is_outcome_triggered(chain_id: String, outcome: String) -> bool:
	return GameState.get_flag("%s_%s" % [chain_id, outcome])

func simulate_chain(chain_id: String, context: Dictionary, days_to_simulate: int) -> Dictionary:
	if not chain_definitions.has(chain_id):
		return {}

	var def: Dictionary = chain_definitions[chain_id]
	var outcome_weights: Dictionary = {}
	var outcomes: Dictionary = def.get("outcomes", {})
	for key: String in outcomes:
		var weight: float = outcomes[key].get("weight", 0.0)
		outcome_weights[key] = weight

	var roll: float = randf()
	var cumulative: float = 0.0
	var chosen: String = "safe"
	for key: String in outcome_weights:
		cumulative += outcome_weights[key]
		if roll <= cumulative:
			chosen = key
			break

	var outcome_data: Dictionary = def["outcomes"][chosen]
	return {
		"chain_id": chain_id,
		"simulated_outcome": chosen,
		"roll": roll,
		"consequences": outcome_data.get("consequences", []),
		"message": outcome_data.get("message", ""),
	}

func get_all_active_chains() -> Array:
	return active_chains.keys()

func get_completed_chains() -> Array:
	return completed_chains.duplicate()

func get_chain_definition(chain_id: String) -> Dictionary:
	return chain_definitions.get(chain_id, {})
