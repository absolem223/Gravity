# confirm_dialog.gd
# Technical Rationale: Reusable YES/NO confirmation modal used for destructive or
# transferful operations (e.g. reassigning a joystick between players). Focusable and
# keyboard/gamepad navigable. Emits `confirmed(choice)`. Not redesigned gameplay.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name ConfirmDialog
extends Control

signal confirmed(choice: bool)

var _message: Label = null
var _yes: Button = null
var _no: Button = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	focus_mode = Control.FOCUS_NONE

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var panel: PanelContainer = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 0)
	add_child(panel)

	var mb: MarginContainer = MarginContainer.new()
	mb.add_theme_constant_override("margin_left", 28)
	mb.add_theme_constant_override("margin_right", 28)
	mb.add_theme_constant_override("margin_top", 24)
	mb.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(mb)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 20)
	mb.add_child(box)

	_message = MenuFactory.make_label("", 18)
	_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_message)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(row)

	_yes = MenuFactory.make_button("Sí", _on_yes, 140, 46)
	row.add_child(_yes)
	_no = MenuFactory.make_button("No", _on_no, 140, 46)
	row.add_child(_no)

## Shows the dialog with the given message. "Sí" receives initial focus.
func open(message: String) -> void:
	_message.text = message
	visible = true
	_yes.grab_focus()

func _close(choice: bool) -> void:
	visible = false
	confirmed.emit(choice)

func _on_yes() -> void:
	_close(true)

func _on_no() -> void:
	_close(false)

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		match (event as InputEventKey).keycode:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_on_no()
				return
			KEY_ENTER, KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				_on_yes()
				return