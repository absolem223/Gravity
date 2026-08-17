# bindings_screen.gd
# Technical Rationale: Modern gamepad + keyboard binding editor. Left — a visible,
# focusable action list (name + current binding + [Reasignar] button per row);
# right — a live gamepad diagram that highlights the button bound to the selected
# action. Selecting an action enters capture mode immediately; the overlay captures
# the next InputEventJoypadButton / InputEventJoypadMotion / InputEventKey, the
# profile updates, saves, and the diagram refreshes in real time. Fully navigable
# with mouse, keyboard and gamepad. Adheres to ADR-0001.

class_name BindingsScreen
extends UIScreen

const GROUPS: Array[Dictionary] = [
	{"title": "Movimiento", "actions": ["move_up", "move_down", "move_left", "move_right"]},
	{"title": "Apuntado", "actions": ["aim_up", "aim_down", "aim_left", "aim_right", "aim_cone"]},
	{"title": "Combate", "actions": ["fire", "dash", "ability", "interact"]},
	{"title": "Drone", "actions": ["drone_mode", "back_operator", "drone_action"]},
	{"title": "Sistema", "actions": ["menu"]},
	{"title": "Avanzado", "actions": ["crouch", "autoaim"]},
]

const _ROW_W: int = 300
const _ACCEL: Color = Color(0.92, 0.58, 0.20)

var _player_id: int = 1
var _overlay: KeyCaptureOverlay = null
var _pending_action: String = ""
var _selected_action: String = ""
var _rows: Dictionary = {}          # action -> HBoxContainer
var _bind_buttons: Dictionary = {}  # action -> Button (current binding)
var _reassign_buttons: Dictionary = {} # action -> Button ([Reasignar])
var _diagram: PadDiagram = null
var _caption: Label = null
var _warn: Label = null

func _init(pid: int = 1) -> void:
	_player_id = pid

func _ready() -> void:
	super._ready()
	screen_title = "Controles — Jugador %d" % _player_id
	_build()
	_refresh()
	focus_first()
	_overlay.captured.connect(_on_overlay_captured)
	_overlay.cancelled.connect(_on_overlay_cancelled)

func _build() -> void:
	add_child(MenuFactory.make_background())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 80)
	margin.add_theme_constant_override("margin_top", 44)
	margin.add_theme_constant_override("margin_right", 80)
	margin.add_theme_constant_override("margin_bottom", 36)
	add_child(margin)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 18)
	margin.add_child(outer)

	# ── Header ──
	var header: HBoxContainer = HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	header.add_child(MenuFactory.make_button("Volver", pop, 140, 44))
	header.add_child(MenuFactory.make_button("Restablecer", _on_reset, 140, 44))
	var title: Label = MenuFactory.make_title("Jugador %d — Controles" % _player_id)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_child(title)
	outer.add_child(header)

	# ── Caption ──
	_caption = MenuFactory.make_label("Seleccioná una acción para reasignar.", 17, MenuFactory.COLOR_TEXT)
	_caption.custom_minimum_size = Vector2(0, 24)
	outer.add_child(_caption)

	# ── Main split ──
	var main: HBoxContainer = HBoxContainer.new()
	main.add_theme_constant_override("separation", 32)
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(main)

	# Left: action list (scrollable so every group + row stays reachable).
	var prof: InputProfile = GameConfig.get_profile(_player_id)
	var is_gamepad: bool = prof != null and not prof.is_keyboard()

	var list_scroll: ScrollContainer = ScrollContainer.new()
	list_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_child(list_scroll)

	var list: VBoxContainer = VBoxContainer.new()
	list.add_theme_constant_override("separation", 4)
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_scroll.add_child(list)

	for group: Dictionary in GROUPS:
		list.add_child(MenuFactory.make_section(String(group["title"])))
		for action: String in (group["actions"] as Array[String]):
			var row: HBoxContainer = _make_action_row(action)
			_rows[action] = row
			list.add_child(row)

	# Right: gamepad diagram
	var diag_wrap: CenterContainer = CenterContainer.new()
	diag_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	diag_wrap.custom_minimum_size = Vector2(0, 0)
	if is_gamepad:
		_diagram = PadDiagram.new()
		diag_wrap.add_child(_diagram)
	main.add_child(diag_wrap)

	# ── Warning ──
	_warn = MenuFactory.make_label("", 15, MenuFactory.COLOR_WARN)
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn.custom_minimum_size = Vector2(0, 24)
	outer.add_child(_warn)

	_overlay = KeyCaptureOverlay.new()
	add_child(_overlay)

## Builds a single action row: label + current binding button + reassign button.
func _make_action_row(action: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var accent: ColorRect = ColorRect.new()
	accent.custom_minimum_size = Vector2(4, 0)
	accent.color = Color(0.92, 0.58, 0.20, 0.0)
	row.add_child(accent)

	var lbl: Label = MenuFactory.make_label(
		String(InputProfile.ACTION_LABELS.get(action, action)), 16, MenuFactory.COLOR_TEXT)
	lbl.custom_minimum_size = Vector2(_ROW_W, 0)
	row.add_child(lbl)

	# Current binding (also clickable to reboot capture).
	var btn: Button = MenuFactory.make_button("", func() -> void: _on_action(action), 0, 44)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(btn)
	_bind_buttons[action] = btn

	# Explicit reassign affordance.
	var rb: Button = MenuFactory.make_button("Reasignar", func() -> void: _on_action(action), 150, 44)
	row.add_child(rb)
	_reassign_buttons[action] = rb

	# Hover feedback on the binding button.
	btn.mouse_entered.connect(func() -> void:
		if _selected_action != action:
			accent.color = Color(0.92, 0.58, 0.20, 0.30))
	btn.mouse_exited.connect(func() -> void:
		if _selected_action != action:
			accent.color = Color(0.92, 0.58, 0.20, 0.0))

	return row

func _action_list_buttons() -> Array[Button]:
	var out: Array[Button] = []
	for action: String in _rows.keys():
		var rb: Button = _reassign_buttons.get(action) as Button
		if rb != null:
			out.append(rb)
	return out

func _update_selection(action: String) -> void:
	for act: String in _rows.keys():
		var row: HBoxContainer = _rows[act] as HBoxContainer
		var accent: ColorRect = row.get_child(0) as ColorRect
		if act == action:
			accent.color = _ACCEL
		else:
			accent.color = Color(0.92, 0.58, 0.20, 0.0)

## ── Capture flow ─────────────────────────────────────────────────────────
func _on_action(action: String) -> void:
	_selected_action = action
	_update_selection(action)
	_pending_action = action
	var prof: InputProfile = GameConfig.get_profile(_player_id)
	var label: String = String(InputProfile.ACTION_LABELS.get(action, action))
	if prof != null and prof.is_keyboard():
		_caption.text = "Asignando: %s — Presioná una tecla…" % label
	else:
		_caption.text = "Asignando: %s — Presioná un botón del control…" % label
	_diagram_highlight(action)
	var dev_kind: int = prof.device_kind if prof != null else InputProfile.DeviceKind.KEYBOARD
	_overlay.start(dev_kind, label)

func _on_overlay_captured(event: InputEvent) -> void:
	if _pending_action.is_empty():
		return
	var prof: InputProfile = GameConfig.get_profile(_player_id)
	if prof != null:
		prof.bind_action(_pending_action, event)
		GameConfig.save_settings()
		_caption.text = "«%s» asignado a %s" % [
			String(InputProfile.ACTION_LABELS.get(_pending_action, _pending_action)),
			_binding_label(prof, event),
		]
	_pending_action = ""
	_refresh()

func _on_overlay_cancelled() -> void:
	_pending_action = ""
	_caption.text = "Captura cancelada."
	_refresh()

func _on_reset() -> void:
	var prof: InputProfile = GameConfig.get_profile(_player_id)
	if prof != null:
		prof.reset_defaults()
		GameConfig.save_settings()
	_caption.text = "Controles restablecidos."
	_refresh()

## ── Rendering ────────────────────────────────────────────────────────────
func _refresh() -> void:
	var prof: InputProfile = GameConfig.get_profile(_player_id)
	for action: String in _rows.keys():
		var btn: Button = _bind_buttons[action] as Button
		var text: String = "— sin asignar —"
		if prof != null and prof.has_binding(action):
			text = _binding_label(prof, prof.get_events(action)[0])
		btn.text = text
		if _selected_action == action:
			btn.modulate = Color(1.12, 1.05, 0.85)
		else:
			btn.modulate = Color.WHITE
	# Keep diagram in sync with the selected action.
	_refresh_diagram()
	_warn.text = _conflicts_message(prof)
	_restore_caption()

func _refresh_diagram() -> void:
	if _diagram == null:
		return
	var prof: InputProfile = GameConfig.get_profile(_player_id)
	if _selected_action.is_empty() or prof == null or not prof.has_binding(_selected_action):
		_diagram.clear_highlight()
	else:
		_diagram.set_highlight_event(prof.get_events(_selected_action)[0])

func _restore_caption() -> void:
	if _pending_action.is_empty() and not _caption.text.begins_with("Asignando"):
		_caption.text = "Seleccioná una acción para reasignar."

func _diagram_highlight(action: String) -> void:
	if _diagram == null:
		return
	var prof: InputProfile = GameConfig.get_profile(_player_id)
	if prof != null and prof.has_binding(action):
		_diagram.set_highlight_event(prof.get_events(action)[0])
	else:
		_diagram.clear_highlight()

## Human-readable label for a binding, respecting controller family.
func _binding_label(prof: InputProfile, ev: InputEvent) -> String:
	if prof == null or prof.is_keyboard():
		return MenuFactory.event_label(ev)
	var device: int = prof.get_joy_device_id()
	return InputProfiles.binding_label(ev, InputProfiles.joypad_layout_name(device))

## Detects duplicated keys/buttons WITHIN this profile (keyboard is shared, so
## only per-profile duplicates are reported). Returns a short warning or "".
func _conflicts_message(prof: InputProfile) -> String:
	if prof == null:
		return ""
	var sig_to_action: Dictionary = {}
	for action: String in InputProfile.ACTION_NAMES:
		if not prof.has_binding(action):
			continue
		var sig: String = _event_signature(prof.get_events(action)[0])
		if sig.is_empty():
			continue
		if sig_to_action.has(sig):
			return "«%s» y «%s» usan la misma entrada." % [
				String(InputProfile.ACTION_LABELS.get(String(sig_to_action[sig]), sig_to_action[sig])),
				String(InputProfile.ACTION_LABELS.get(action, action)),
			]
		sig_to_action[sig] = action
	return ""

func _event_signature(ev: InputEvent) -> String:
	if ev is InputEventKey:
		var k: InputEventKey = ev as InputEventKey
		return "key:%d" % (k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode)
	if ev is InputEventMouseButton:
		return "mouse:%d" % int((ev as InputEventMouseButton).button_index)
	if ev is InputEventJoypadButton:
		return "joy:%d" % int((ev as InputEventJoypadButton).button_index)
	if ev is InputEventJoypadMotion:
		var m: InputEventJoypadMotion = ev as InputEventJoypadMotion
		return "axis:%d:%s" % [int(m.axis), "+" if m.axis_value >= 0.0 else "-"]
	return ""

func _layout_family_key() -> String:
	var prof: InputProfile = GameConfig.get_profile(_player_id)
	if prof == null:
		return "generic"
	var dev: int = prof.get_joy_device_id()
	match InputProfiles.joypad_layout_name(dev):
		"xbox":       return "xbox"
		"playstation": return "playstation"
		"nintendo":   return "nintendo"
		_:            return "generic"

## Test/validation helper: number of rendered action rows.
func action_count() -> int:
	return _rows.size()

## Test/validation helper: the Button showing the current binding for `action`.
func get_binding_button(action: String) -> Button:
	return _bind_buttons.get(action, null) as Button

## Test/validation helper: the [Reasignar] Button for `action`.
func get_reassign_button(action: String) -> Button:
	return _reassign_buttons.get(action, null) as Button

## Test/validation helper: whether the assertion overlay is currently listening.
func is_capturing() -> bool:
	return _overlay != null and _overlay.is_listening()

## Test/validation helper: currently highlighted action (or "").
func get_selected_action() -> String:
	return _selected_action

## Test/validation helper: highlight event currently shown in the diagram.
func get_diagram_highlight() -> InputEvent:
	if _diagram == null:
		return null
	return _diagram.get_highlighted_event()