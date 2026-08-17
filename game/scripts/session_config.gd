# session_config.gd
# Autoload: match lobby settings passed from main menu into SANDBOX-01.
# Persists basic display/audio options to user://settings.cfg.

extends Node

enum ControlMode {
	HUMAN,
	AI
}

class SlotConfig:
	var enabled: bool = true
	var team_id: int = OperatorBase.TEAM_ATTACKERS
	var control_mode: ControlMode = ControlMode.HUMAN

const MATCH_SCENE_PATH: String = "res://scenes/match.tscn"
const SANDBOX_SCENE_PATH: String = "res://scenes/sandbox_test_scene.tscn"
const SETTINGS_PATH: String = "user://settings.cfg"

var slots: Array[SlotConfig] = []

@export var friendly_fire_enabled: bool = false
var master_volume_linear: float = 1.0
var fullscreen_enabled: bool = false

func _ready() -> void:
	reset_slots_to_defaults()
	load_settings()

func reset_slots_to_defaults() -> void:
	slots.clear()
	for i: int in range(InputManager.MAX_PLAYERS):
		var slot: SlotConfig = SlotConfig.new()
		slot.enabled = true
		slot.team_id = OperatorBase.TEAM_ATTACKERS if i < 2 else OperatorBase.TEAM_DEFENDERS
		slot.control_mode = ControlMode.HUMAN
		slots.append(slot)

func get_slot(player_id: int) -> SlotConfig:
	var idx: int = player_id - 1
	if idx < 0 or idx >= slots.size():
		return null
	return slots[idx]

func get_enabled_player_ids() -> Array[int]:
	var ids: Array[int] = []
	for p_id: int in range(1, InputManager.MAX_PLAYERS + 1):
		var slot: SlotConfig = get_slot(p_id)
		if slot != null and slot.enabled:
			ids.append(p_id)
	return ids

func count_enabled_slots() -> int:
	return get_enabled_player_ids().size()

func count_human_slots() -> int:
	var n: int = 0
	for p_id: int in get_enabled_player_ids():
		var slot: SlotConfig = get_slot(p_id)
		if slot != null and slot.control_mode == ControlMode.HUMAN:
			n += 1
	return n

func validate_lobby() -> String:
	if count_enabled_slots() < 2:
		return "Activá al menos 2 jugadores."
	if count_human_slots() < 1:
		return "Al menos 1 jugador debe ser humano."
	return ""

func apply_runtime_settings() -> void:
	var bus_idx: int = AudioServer.get_bus_index("Master")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, linear_to_db(clampf(master_volume_linear, 0.0, 1.0)))
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_FULLSCREEN and fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN and not fullscreen_enabled:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("audio", "master_volume_linear", master_volume_linear)
	cfg.set_value("display", "fullscreen", fullscreen_enabled)
	cfg.set_value("gameplay", "friendly_fire", friendly_fire_enabled)
	for i: int in range(slots.size()):
		var prefix: String = "slot_%d" % (i + 1)
		cfg.set_value("lobby", prefix + "_enabled", slots[i].enabled)
		cfg.set_value("lobby", prefix + "_team", slots[i].team_id)
		cfg.set_value("lobby", prefix + "_control", slots[i].control_mode)
	cfg.save(SETTINGS_PATH)

func load_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	master_volume_linear = cfg.get_value("audio", "master_volume_linear", 1.0) as float
	fullscreen_enabled = cfg.get_value("display", "fullscreen", false) as bool
	friendly_fire_enabled = cfg.get_value("gameplay", "friendly_fire", false) as bool
	for i: int in range(slots.size()):
		var prefix: String = "slot_%d" % (i + 1)
		if cfg.has_section_key("lobby", prefix + "_enabled"):
			slots[i].enabled = cfg.get_value("lobby", prefix + "_enabled") as bool
		if cfg.has_section_key("lobby", prefix + "_team"):
			slots[i].team_id = cfg.get_value("lobby", prefix + "_team") as int
		if cfg.has_section_key("lobby", prefix + "_control"):
			slots[i].control_mode = cfg.get_value("lobby", prefix + "_control") as int
