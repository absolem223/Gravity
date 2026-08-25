# players_config_screen.gd
# Technical Rationale: Per-player setup (MC_PLAYERS). Renders 4 player slots with
# type (Humano/IA), device (Teclado / Joystick 1..N, N = connected pads), a rebind
# entry and live occupancy protection against duplicate device assignment. Writes
# exclusively to GameConfig (slots + profiles) and persists automatically.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name PlayersConfigScreen
extends UIScreen

const MAX_PLAYERS: int = InputManager.MAX_PLAYERS

var _enabled: Array[CheckBox] = []
var _type: Array[OptionButton] = []
var _device: Array[OptionButton] = []
var _reassign: Array[Button] = []
var _status: Label = null
var _dialog: ConfirmDialog = null
var _pending_pid: int = -1       # player awaiting a joystick reassignment
var _pending_joy_slot: int = -1  # joystick slot being claimed
var _pending_owner: int = -1     # current holder of that joystick

func _ready() -> void:
	super._ready()
	screen_title = "Configuración de Jugadores"
	_build()
	_refresh_device_options()
	focus_first()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_dialog.confirmed.connect(_on_device_confirm)

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	_refresh_device_options()

func _build() -> void:
	add_child(MenuFactory.make_background())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_right", 96)
	add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)

	box.add_child(MenuFactory.make_title("Configuración de Jugadores"))
	box.add_child(MenuFactory.make_hint(
		"Por jugador: Activo, tipo (Humano / IA) y dispositivo. " +
		"Ingresá a “Reasignar…” para cambiar cada acción. Los joysticks se detectan automáticamente."))

	var header: GridContainer = GridContainer.new()
	header.columns = 5
	header.add_theme_constant_override("h_separation", 16)
	box.add_child(header)
	header.add_child(MenuFactory.make_label("Jugador", 16))
	header.add_child(MenuFactory.make_label("Activo", 16))
	header.add_child(MenuFactory.make_label("Tipo", 16))
	header.add_child(MenuFactory.make_label("Dispositivo", 16))
	header.add_child(MenuFactory.make_label("Acciones", 16))

	for p_id: int in range(1, MAX_PLAYERS + 1):
		var grid: GridContainer = GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 16)
		box.add_child(grid)

		grid.add_child(MenuFactory.make_label("P%d" % p_id, 18, MenuFactory.COLOR_TEXT))

		var en: CheckBox = CheckBox.new()
		grid.add_child(en)
		_enabled.append(en)

		var t: OptionButton = OptionButton.new()
		t.add_item("Humano", GameConfig.ControlMode.HUMAN)
		t.add_item("IA", GameConfig.ControlMode.AI)
		grid.add_child(t)
		_type.append(t)

		var d: OptionButton = OptionButton.new()
		d.custom_minimum_size = Vector2(220, 0)
		grid.add_child(d)
		_device.append(d)

		var rb: Button = MenuFactory.make_button("Reasignar…", Callable(), 0, 40)
		grid.add_child(rb)
		_reassign.append(rb)

		_apply_row(p_id, en, t, d, rb)

	_status = MenuFactory.make_label("", 16, MenuFactory.COLOR_WARN)
	box.add_child(_status)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 30)
	box.add_child(spacer)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(MenuFactory.make_button("Volver", pop))
	row.add_child(MenuFactory.make_button("Iniciar Partida", _on_start))
	box.add_child(row)

	_dialog = ConfirmDialog.new()
	add_child(_dialog)

## Populates a single slot row from the current GameConfig data and hooks its signals.
func _apply_row(p_id: int, en: CheckBox, t: OptionButton, d: OptionButton, rb: Button) -> void:
	var pid: int = p_id
	var slot: Variant = GameConfig.get_slot(p_id)
	en.button_pressed = slot.enabled if slot != null else true
	t.select(0 if slot != null and slot.control_mode == GameConfig.ControlMode.HUMAN else 1)

	en.toggled.connect(func(on: bool) -> void: _on_enabled_changed(pid, on))
	t.item_selected.connect(func(idx: int) -> void: _on_type_changed(pid, idx))
	d.item_selected.connect(func(idx: int) -> void: _on_device_changed(pid, idx))
	rb.pressed.connect(func() -> void: _on_reassign(pid))

## Rebuilds every device OptionButton from the currently connected controllers.
## Joystick slots are ALWAYS listed so options are never silently hidden: a slot
## with no device attached is shown as "(desconectado)" instead of disappearing.
## When zero controllers are connected a hint is shown, but the configuration
## system stays fully accessible (a slot can be pre-assigned for later).
func _refresh_device_options() -> void:
	var pads: Array[int] = InputProfiles.get_connected_joypads()
	var shown_slots: int = maxi(pads.size(), InputProfiles.MAX_PLAYERS)
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var prof: InputProfile = GameConfig.get_profile(p_id)
		var opt: OptionButton = _device[p_id - 1]
		opt.clear()
		opt.add_item("Teclado", 0)
		for i: int in range(1, shown_slots + 1):
			if i <= pads.size():
				var dev: int = pads[i - 1]
				var name: String = Input.get_joy_name(dev)
				var label: String = "Joystick %d — %s" % [i, name if not name.is_empty() else "Control"]
				opt.add_item(label, i)
			else:
				opt.add_item("Joystick %d (desconectado)" % i, i)
		if prof == null or prof.is_keyboard():
			opt.select(0)
		else:
			var stored_slot: int = prof.joystick_index
			var found: int = -1
			for i: int in range(0, opt.item_count):
				if opt.get_item_id(i) == stored_slot:
					found = i
					break
			if found >= 0:
				opt.select(found)
			else:
				opt.add_item("Joystick %d (desconectado)" % stored_slot, stored_slot)
				opt.select(opt.item_count - 1)
		_update_row_state(p_id)
	if pads.is_empty():
		_status.text = "No se detectó ningún control. Conectá un joystick y reaparecerá aquí; también podés asignar un slot y configurarlo de antemano."

## Enables/disables device & reassign widgets depending on slot type.
func _update_row_state(p_id: int) -> void:
	var slot: Variant = GameConfig.get_slot(p_id)
	var is_human: bool = slot != null and slot.control_mode == GameConfig.ControlMode.HUMAN
	_device[p_id - 1].disabled = not is_human
	_reassign[p_id - 1].disabled = not is_human
	_enabled[p_id - 1].disabled = false

func _on_enabled_changed(p_id: int, on: bool) -> void:
	var slot: Variant = GameConfig.get_slot(p_id)
	if slot != null:
		slot.enabled = on
	GameConfig.save_settings()

func _on_type_changed(p_id: int, idx: int) -> void:
	var slot: Variant = GameConfig.get_slot(p_id)
	if slot != null:
		slot.control_mode = idx
	_update_row_state(p_id)
	GameConfig.save_settings()

func _on_device_changed(p_id: int, idx: int) -> void:
	var opt: OptionButton = _device[p_id - 1]
	var dev_id: int = opt.get_item_id(idx)
	var kind: int = InputProfile.DeviceKind.KEYBOARD if dev_id == 0 else InputProfile.DeviceKind.JOYSTICK
	var joy_slot: int = dev_id if dev_id > 0 else -1
	var prof: InputProfile = GameConfig.get_profile(p_id)
	if prof == null:
		return

	# Keyboard is a shared device: it NEVER conflicts with other players.
	if kind == InputProfile.DeviceKind.KEYBOARD:
		_status.text = ""
		prof.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
		prof.reset_defaults()
		GameConfig.save_settings()
		return

	# Joystick: check whether another human player already holds this slot.
	var owner: int = _joystick_owner(joy_slot, p_id)
	if owner >= 0:
		_pending_pid = p_id
		_pending_joy_slot = joy_slot
		_pending_owner = owner
		_status.text = ""
		_dialog.open(
			"Este control está asignado actualmente al Jugador %d.\n\n¿Querés reasignarlo al Jugador %d?" % [owner, p_id])
		return

	_status.text = ""
	prof.set_device(InputProfile.DeviceKind.JOYSTICK, joy_slot)
	prof.reset_defaults()
	GameConfig.save_settings()

func _on_device_confirm(choice: bool) -> void:
	if _pending_pid < 1 or _pending_joy_slot < 1 or _pending_owner < 1:
		_pending_pid = -1
		_pending_joy_slot = -1
		_pending_owner = -1
		return
	if choice:
		_swap_devices(_pending_pid, _pending_joy_slot, _pending_owner)
		_status.text = "Controles intercambiados entre Jugador %d y Jugador %d." % [_pending_pid, _pending_owner]
	else:
		_revert_device_select(_pending_pid)
		_status.text = "Cambio cancelado."
	_pending_pid = -1
	_pending_joy_slot = -1
	_pending_owner = -1

## Swaps the target joystick to `pid`; the current holder takes `pid`'s old device.
func _swap_devices(p_id: int, joy_slot: int, owner: int) -> void:
	var prof_new: InputProfile = GameConfig.get_profile(p_id)
	var prof_old: InputProfile = GameConfig.get_profile(owner)
	if prof_new == null or prof_old == null:
		return
	var old_kind: int = prof_new.device_kind
	var old_slot: int = prof_new.joystick_index
	prof_old.set_device(old_kind, old_slot)
	prof_old.reset_defaults()
	prof_new.set_device(InputProfile.DeviceKind.JOYSTICK, joy_slot)
	prof_new.reset_defaults()
	GameConfig.save_settings()
	_refresh_device_options()

## Restores the device OptionButton to the player's stored selection.
func _revert_device_select(p_id: int) -> void:
	var opt: OptionButton = _device[p_id - 1]
	var prof: InputProfile = GameConfig.get_profile(p_id)
	if prof == null:
		return
	if prof.is_keyboard():
		opt.select(0)
	else:
		for i: int in range(0, opt.item_count):
			if opt.get_item_id(i) == prof.joystick_index:
				opt.select(i)
				return

## Returns the human player currently holding the joystick slot (or -1).
func _joystick_owner(joy_slot: int, except_p_id: int) -> int:
	for other: int in range(1, MAX_PLAYERS + 1):
		if other == except_p_id:
			continue
		var slot: Variant = GameConfig.get_slot(other)
		if slot == null or slot.control_mode != GameConfig.ControlMode.HUMAN:
			continue
		var prof: InputProfile = GameConfig.get_profile(other)
		if prof != null and not prof.is_keyboard() and prof.joystick_index == joy_slot:
			return other
	return -1

func _on_reassign(p_id: int) -> void:
	push(BindingsScreen.new(p_id))

## Test/validation helper: first player's device OptionButton.
func get_first_device_option() -> OptionButton:
	if _device.is_empty():
		return null
	return _device[0] as OptionButton

func _on_start() -> void:
	GameConfig.save_settings()
	var err: String = GameConfig.validate_party()
	if not err.is_empty():
		_status.text = err
		return
	GameConfig.apply_runtime_settings()
	var music := get_tree().root.get_node_or_null("MusicController")
	if music != null and music.get_current_state() != MusicController.State.COMBAT:
		music.set_state(MusicController.State.COMBAT, 1.5)
	get_tree().change_scene_to_file(GameConfig.MATCH_SCENE_PATH)