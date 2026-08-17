# key_capture_overlay.gd
# Technical Rationale: Reusable "press a key/button" modal. Listens for the next
# physical event matching the requested device kind and emits `captured` with the
# resulting InputEvent (the game then writes it into the player's InputProfile).
# Uses `_input()` (which runs BEFORE the GUI/focus system consumes events) so a
# focused action button cannot eat the key/button we want to capture. Grabs focus
# itself while listening to keep the focus outline honest and prevent Tab/arrows
# from drifting away. Escape cancels; all other input is swallowed so the menu
# underneath cannot react mid-capture.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name KeyCaptureOverlay
extends Control

signal captured(event: InputEvent)
signal cancelled

var _device_kind: int = InputProfile.DeviceKind.KEYBOARD
var _listening: bool = false

var _hint: Label = null
var _prompt: Label = null
var _sub: Label = null

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false

	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0.0, 0.0, 0.0, 0.6)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel: VBoxContainer = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 14)
	panel.custom_minimum_size = Vector2(560, 0)
	center.add_child(panel)

	_hint = MenuFactory.make_label("", 22, MenuFactory.COLOR_WARN)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_hint)
	_prompt = MenuFactory.make_label("Presioná una tecla / botón…", 34, MenuFactory.COLOR_TEXT)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_prompt)
	_sub = MenuFactory.make_label("Escape para cancelar", 16, MenuFactory.COLOR_MUTED)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(_sub)

## Begins listening for the next event of the given device kind, showing the
## action currently being assigned as visual feedback.
func start(device_kind: int, action_label: String = "") -> void:
	_device_kind = device_kind
	_listening = true
	_prompt.text = "Presioná una tecla…" if _device_kind == InputProfile.DeviceKind.KEYBOARD \
		else "Presioná un botón del control…"
	_hint.text = ("Asignando: %s" % action_label) if not action_label.is_empty() else ""
	visible = true
	# Take focus so the underlying action buttons cannot consume the next input.
	set_process_input(true)
	grab_focus()

func stop() -> void:
	_listening = false
	visible = false

func is_listening() -> bool:
	return _listening

func _matches(ev: InputEvent) -> bool:
	if _device_kind == InputProfile.DeviceKind.KEYBOARD:
		return ev is InputEventKey or ev is InputEventMouseButton
	return ev is InputEventJoypadButton or ev is InputEventJoypadMotion

## Captures input BEFORE the UI/GUI system so a focused button can't eat it.
func _input(event: InputEvent) -> void:
	if not _listening:
		return
	# Escape always cancels (keyboard escape for keyboard capture too).
	if event is InputEventKey and (event as InputEventKey).pressed \
			and (event as InputEventKey).keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_listening = false
		visible = false
		cancelled.emit()
		return
	if not _matches(event):
		# Swallow only events that belong to our dialog (ignore raw JIC).
		return
	if _device_kind == InputProfile.DeviceKind.KEYBOARD:
		if event is InputEventKey and (event as InputEventKey).pressed:
			get_viewport().set_input_as_handled()
			_listening = false
			visible = false
			captured.emit(event as InputEvent)
			return
		if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
			get_viewport().set_input_as_handled()
			_listening = false
			visible = false
			captured.emit(event as InputEvent)
			return
	elif event is InputEventJoypadButton and (event as InputEventJoypadButton).pressed:
		get_viewport().set_input_as_handled()
		_listening = false
		visible = false
		captured.emit(event as InputEvent)
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.9:
		get_viewport().set_input_as_handled()
		_listening = false
		visible = false
		captured.emit(event as InputEvent)