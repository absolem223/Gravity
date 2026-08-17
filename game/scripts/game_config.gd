# game_config.gd
# Technical Rationale: Definitve configuration system for Gravity. Single runtime
# authority for the whole pre-match setup (slots: enabled/team/control) plus the
# per-player InputProfile book. The UI writes this; gameplay reads it. Everything
# persists automatically to user://gravity_config.cfg (no user intervention).
# Replaces the former SessionConfig autoload while keeping its public surface so
# the match/player wiring keeps working unchanged.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

extends Node

## Slot: a single configurable player position in a party.
enum ControlMode {
	HUMAN,
	AI
}

class PlayerSlot:
	var enabled: bool = true
	var team_id: int = OperatorBase.TEAM_ATTACKERS
	var control_mode: ControlMode = ControlMode.HUMAN

const MATCH_SCENE_PATH: String = "res://scenes/match.tscn"
const SANDBOX_SCENE_PATH: String = "res://scenes/sandbox_test_scene.tscn"
const SETTINGS_PATH: String = "user://gravity_config.cfg"
const MAX_PLAYERS: int = InputManager.MAX_PLAYERS

## Lobby slot config, indexed by player_id-1.
var slots: Array[PlayerSlot] = []

## Gameplay / display preferences (persisted).
var friendly_fire_enabled: bool = false
var master_volume_linear: float = 1.0
var fullscreen_enabled: bool = false
var show_joystick_diagnostics: bool = false

## Per-player input profiles, indexed by player_id (1..MAX_PLAYERS).
var _input_profiles: Dictionary = {}

func _ready() -> void:
	reset_slots_to_defaults()
	_initialize_profiles()
	load_settings()
	_apply_device_defaults()

## Preset defaults for all slots (attackers x2, defenders x2, all HUMAN).
func reset_slots_to_defaults() -> void:
	slots.clear()
	for i: int in range(MAX_PLAYERS):
		var slot: PlayerSlot = PlayerSlot.new()
		slot.enabled = true
		slot.team_id = OperatorBase.TEAM_ATTACKERS if i < 2 else OperatorBase.TEAM_DEFENDERS
		slot.control_mode = ControlMode.HUMAN
		slots.append(slot)

## Creates the 4 InputProfile instances (bindings are populated by load/defaults).
func _initialize_profiles() -> void:
	_input_profiles.clear()
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var prof: InputProfile = InputProfile.new()
		prof.player_id = p_id
		_input_profiles[p_id] = prof

## Assigns a sensible default device per slot when nothing is persisted yet:
## P1 -> Teclado; P2..P4 -> Joystick slots 1..3 when pads are connected, else Keyboard.
func _apply_device_defaults() -> void:
	var pads: Array[int] = InputProfiles.get_connected_joypads()
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var prof: InputProfile = get_profile(p_id)
		if prof == null or prof.has_binding("move_up"):
			continue
		if p_id == 1:
			prof.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
		elif (p_id - 1) <= pads.size():
			prof.set_device(InputProfile.DeviceKind.JOYSTICK, p_id - 1)
		else:
			prof.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
		prof.reset_defaults()

## ── Slot accessors ──────────────────────────────────────────────────────────
func get_slot(player_id: int) -> PlayerSlot:
	var idx: int = player_id - 1
	if idx < 0 or idx >= slots.size():
		return null
	return slots[idx]

func get_enabled_player_ids() -> Array[int]:
	var ids: Array[int] = []
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var slot: PlayerSlot = get_slot(p_id)
		if slot != null and slot.enabled:
			ids.append(p_id)
	return ids

func count_enabled_slots() -> int:
	return get_enabled_player_ids().size()

func count_human_slots() -> int:
	var n: int = 0
	for p_id: int in get_enabled_player_ids():
		var slot: PlayerSlot = get_slot(p_id)
		if slot != null and slot.control_mode == ControlMode.HUMAN:
			n += 1
	return n

func validate_party() -> String:
	if count_enabled_slots() < 2:
		return "Activá al menos 2 jugadores."
	if count_human_slots() < 1:
		return "Al menos 1 jugador debe ser humano."
	# Reject two human players sharing the same joystick slot.
	var joy_owners: Dictionary = {}
	for p_id: int in get_enabled_player_ids():
		var slot: PlayerSlot = get_slot(p_id)
		if slot == null or slot.control_mode != ControlMode.HUMAN:
			continue
		var prof: InputProfile = get_profile(p_id)
		if prof == null or prof.is_keyboard() or prof.joystick_index < 1:
			continue
		var js: int = prof.joystick_index
		if joy_owners.has(js):
			var prev: int = joy_owners.get(js, -1) as int
			return "Jugadores %d y %d comparten el Joystick %d. Reasigná otro dispositivo." % [prev, p_id, js]
		joy_owners[js] = p_id
	return ""

## ── Input profile accessors ────────────────────────────────────────────────
func get_profile(player_id: int) -> InputProfile:
	return _input_profiles.get(player_id, null) as InputProfile

func get_input_profile(player_id: int) -> InputProfile:
	return get_profile(player_id)

func get_all_profiles() -> Array[InputProfile]:
	var list: Array[InputProfile] = []
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var prof: InputProfile = get_profile(p_id)
		if prof != null:
			list.append(prof)
	return list

## ── Runtime display settings ───────────────────────────────────────────────
func apply_runtime_settings() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clampf(master_volume_linear, 0.0, 1.0)))
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN and fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and not fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

## ── Persistence ────────────────────────────────────────────────────────────
## Saves slots, preferences AND every input profile. Called automatically on
## any change (input bindings, device, party, settings).
func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "master_volume_linear", master_volume_linear)
	cfg.set_value("display", "fullscreen", fullscreen_enabled)
	cfg.set_value("display", "show_joystick_diagnostics", show_joystick_diagnostics)
	cfg.set_value("gameplay", "friendly_fire", friendly_fire_enabled)
	for i: int in range(slots.size()):
		var prefix: String = "slot_%d" % (i + 1)
		cfg.set_value("lobby", prefix + "_enabled", slots[i].enabled)
		cfg.set_value("lobby", prefix + "_team", slots[i].team_id)
		cfg.set_value("lobby", prefix + "_control", slots[i].control_mode)
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var prof: InputProfile = get_profile(p_id)
		if prof != null:
			cfg.set_value("input", "player_%d" % p_id, JSON.stringify(prof.serialize()))
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume_linear = cfg.get_value("audio", "master_volume_linear", 1.0) as float
	fullscreen_enabled = cfg.get_value("display", "fullscreen", false) as bool
	show_joystick_diagnostics = cfg.get_value("display", "show_joystick_diagnostics", false) as bool
	friendly_fire_enabled = cfg.get_value("gameplay", "friendly_fire", false) as bool
	for i: int in range(slots.size()):
		var prefix: String = "slot_%d" % (i + 1)
		if cfg.has_section_key("lobby", prefix + "_enabled"):
			slots[i].enabled = cfg.get_value("lobby", prefix + "_enabled") as bool
		if cfg.has_section_key("lobby", prefix + "_team"):
			slots[i].team_id = cfg.get_value("lobby", prefix + "_team") as int
		if cfg.has_section_key("lobby", prefix + "_control"):
			slots[i].control_mode = cfg.get_value("lobby", prefix + "_control") as int
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var prof: InputProfile = get_profile(p_id)
		if prof == null or not cfg.has_section_key("input", "player_%d" % p_id):
			continue
		var data: Variant = JSON.parse_string(cfg.get_value("input", "player_%d" % p_id))
		if data is Dictionary:
			prof.deserialize(data)