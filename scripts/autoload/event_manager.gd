extends Node

signal event_triggered(event_id: String)
signal world_state_changed(area_id: String)
signal anomaly_occurred(anomaly_type: String, position: Vector2)

var active_events: Array[String] = []
var triggered_events: Array[String] = []
var missed_events: Array[String] = []

var event_cooldowns: Dictionary = {}
var anomaly_occurrences: int = 0

const MIN_ANOMALY_INTERVAL: float = 300.0

func _ready() -> void:
	print("[EventManager] Ready — world event system active.")

func trigger_event(event_id: String) -> bool:
	if event_id in triggered_events:
		return false
	if event_id in event_cooldowns:
		var cooldown_ms: int = event_cooldowns[event_id]
		if Time.get_ticks_msec() < cooldown_ms:
			return false

	triggered_events.append(event_id)
	active_events.append(event_id)
	event_triggered.emit(event_id)
	print("[EventManager] Event triggered: %s" % event_id)
	return true

func register_missed_event(event_id: String, description: String) -> void:
	if event_id in missed_events:
		return
	missed_events.append(event_id)
	print("[EventManager] Missed event: %s — %s" % [event_id, description])

func check_missed_events() -> Array:
	return missed_events.duplicate()

func is_event_triggered(event_id: String) -> bool:
	return event_id in triggered_events

func reset_area_events(area_id: String) -> void:
	var prefix: String = area_id + "_"
	for i: int in range(triggered_events.size() - 1, -1, -1):
		var event_id: String = triggered_events[i]
		if event_id.begins_with(prefix):
			triggered_events.remove_at(i)
			active_events.erase(event_id)

func spawn_anomaly(anomaly_type: String, position: Vector2) -> void:
	anomaly_occurrences += 1
	event_cooldowns["anomaly_last"] = Time.get_ticks_msec() + int(MIN_ANOMALY_INTERVAL * 1000.0)
	anomaly_occurred.emit(anomaly_type, position)
	print("[EventManager] Anomaly at %s: %s" % [str(position), anomaly_type])

func can_trigger_anomaly() -> bool:
	if not event_cooldowns.has("anomaly_last"):
		return true
	return Time.get_ticks_msec() >= event_cooldowns["anomaly_last"]
