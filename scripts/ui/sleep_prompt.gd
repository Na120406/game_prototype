extends Control

signal sleep_chosen()
signal sleep_started()
signal sleep_cancelled()

var _is_open: bool = false

func _ready() -> void:
	visible = false

	var panel := find_child("Panel", true, false)
	if panel != null:
		panel.visible = false
		var vbox := panel.find_child("VBox", true, false)
		if vbox != null:
			var yes_btn: Button = vbox.find_child("YesBtn", true, false)
			var no_btn: Button = vbox.find_child("NoBtn", true, false)
			if yes_btn != null:
				yes_btn.pressed.connect(_on_yes)
			if no_btn != null:
				no_btn.pressed.connect(_on_no)

func _find_panel() -> Control:
	return find_child("Panel", true, false)

func _find_vbox() -> Control:
	var panel := _find_panel()
	if panel == null:
		return null
	return panel.find_child("VBox", true, false)

func show_prompt() -> void:
	_is_open = true
	visible = true
	GameState.game_interacting = true
	var uif: Node = get_node_or_null("/root/UIFocusManager")
	if uif != null:
		uif.call("dim_background", true)
	var panel := _find_panel()
	if panel != null:
		panel.visible = true
	var backdrop: Control = null
	if get_parent() != null:
		backdrop = get_parent().get_node_or_null("SleepBackdrop")
	if backdrop != null:
		backdrop.visible = true
	accept_event()

func hide_prompt() -> void:
	_is_open = false
	visible = false
	GameState.game_interacting = false
	var uif: Node = get_node_or_null("/root/UIFocusManager")
	if uif != null:
		uif.call("dim_background", false)
	var panel := _find_panel()
	var vbox := _find_vbox()
	var cm: Node = get_node_or_null("/root/ConfigManager")
	if vbox != null:
		var title: Label = vbox.find_child("Title", true, false)
		var yes_btn: Button = vbox.find_child("YesBtn", true, false)
		var no_btn: Button = vbox.find_child("NoBtn", true, false)
		if cm != null and cm.has_method("translate_text"):
			if title != null: title.text = cm.translate_text("ui.sleep.confirm", "Ngủ đến ngày mai?")
			if yes_btn != null: yes_btn.text = cm.translate_text("ui.sleep.yes", "Có [E]")
			if no_btn != null: no_btn.text = cm.translate_text("ui.sleep.no", "Không [ESC]")
	if panel != null:
		panel.visible = false
	var backdrop: Control = null
	if get_parent() != null:
		backdrop = get_parent().get_node_or_null("SleepBackdrop")
	if backdrop != null:
		backdrop.visible = false

func _input(event: InputEvent) -> void:
	if not _is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_prompt()
		sleep_cancelled.emit()
		accept_event()
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"):
		accept_event()
		_on_yes()

func _on_yes() -> void:
	# Notify the player state before the prompt disappears and the day advances.
	sleep_started.emit()
	hide_prompt()
	sleep_chosen.emit()

func _on_no() -> void:
	hide_prompt()
	sleep_cancelled.emit()
