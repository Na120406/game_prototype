extends Control

signal sleep_chosen()

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
	visible = true
	var panel := _find_panel()
	if panel != null:
		panel.visible = true
	var vbox := _find_vbox()
	if vbox != null:
		var yes_btn: Button = vbox.find_child("YesBtn", true, false)
		if yes_btn != null:
			yes_btn.grab_focus()

func hide_prompt() -> void:
	visible = false
	var panel := _find_panel()
	if panel != null:
		panel.visible = false

func _input(event: InputEvent) -> void:
	var panel := _find_panel()
	if panel == null or not panel.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		hide_prompt()
		get_viewport().set_input_as_handled()

func _on_yes() -> void:
	hide_prompt()
	sleep_chosen.emit()

func _on_no() -> void:
	hide_prompt()
