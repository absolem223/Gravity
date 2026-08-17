# input_manager.gd
# Technical Rationale: Per-scene query gateway between gameplay and the definitive
# InputProfile system. All gameplay input reads (movement vector, pressed, just
# pressed) are delegated to the per-player InputProfile owned by the GameConfig
# autoload. Gameplay NEVER queries keys, InputMap actions, or devices directly.
# The PlayerInputProfile inner class and get_profile() are retained purely for the
# SquadHUD device label; the authoritative input data lives in GameConfig profiles.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name InputManager
extends Node

## Signals
signal device_connection_changed(player_id: int, connected: bool)

## Number of supported local players.
const MAX_PLAYERS: int = 4

## Lightweight device info copy fed to the SquadHUD (read-only label).
class PlayerInputProfile:
	enum DeviceType { KEYBOARD_MOUSE, GAMEPAD, UNASSIGNED }

	var player_id: int = 1
	var device_id: int = -1
	var device_type: DeviceType = DeviceType.KEYBOARD_MOUSE
	var is_connected: bool = true

	func get_device_name() -> String:
		match device_type:
			DeviceType.KEYBOARD_MOUSE:
				return "Keyboard & Mouse"
			DeviceType.GAMEPAD:
				return "Gamepad #%d" % device_id
			_:
				return "Disconnected"

## Mirror profiles indexed by Player ID (1..4) — UI/HUD display only.
var _profiles: Dictionary = {}

func _ready() -> void:
	_initialize_profiles()
	_detect_joypads()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	# Debug-only probe binding for the sandbox Action System probe (non-gameplay). The
	# actual gameplay actions are resolved through profiles, never through the InputMap.
	_bind_key("debug_action_system", KEY_F12)

func _process(_delta: float) -> void:
	var cfg: Node = _config()
	if cfg == null:
		return
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var prof: InputProfile = cfg.call("get_profile", p_id) as InputProfile
		if prof != null:
			prof.poll_frame()

## ── Resolution ─────────────────────────────────────────────────────────────
## Locates the authoritative GameConfig autoload (profiles + slots).
func _config() -> Node:
	if get_tree() == null:
		return null
	return get_tree().root.get_node_or_null("GameConfig")

## ── Player device mirror (HUD-facing) ─────────────────────────────────────
func _initialize_profiles() -> void:
	_profiles.clear()
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var profile: PlayerInputProfile = PlayerInputProfile.new()
		profile.player_id = p_id
		_profiles[p_id] = profile

## Refreshes the HUD-facing device mirror from the authoritative profiles.
func _sync_device_mirrors() -> void:
	var cfg: Node = _config()
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var mirror: PlayerInputProfile = _profiles.get(p_id) as PlayerInputProfile
		if mirror == null:
			continue
		var prof: InputProfile = cfg.call("get_profile", p_id) as InputProfile if cfg != null else null
		if prof == null:
			mirror.device_type = PlayerInputProfile.DeviceType.KEYBOARD_MOUSE
			continue
		if prof.is_keyboard():
			mirror.device_type = PlayerInputProfile.DeviceType.KEYBOARD_MOUSE
			mirror.device_id = -1
		else:
			var dev: int = prof.get_joy_device_id()
			mirror.device_type = PlayerInputProfile.DeviceType.GAMEPAD
			mirror.device_id = dev
			mirror.is_connected = dev >= 0
		mirror.is_connected = true

func _detect_joypads() -> void:
	_sync_device_mirrors()

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	_sync_device_mirrors()
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var mirror: PlayerInputProfile = _profiles.get(p_id) as PlayerInputProfile
		if mirror != null:
			device_connection_changed.emit(p_id, mirror.is_connected)

## ── Gameplay query facade (delegates to authoritative profiles) ──────────
func get_profile(player_id: int) -> PlayerInputProfile:
	_sync_device_mirrors()
	return _profiles.get(player_id, null) as PlayerInputProfile

## Returns the 2D normalized movement vector for a player (keyboard/D-pad/stick).
func get_movement_vector(player_id: int) -> Vector2:
	var cfg: Node = _config()
	var prof: InputProfile = cfg.call("get_profile", player_id) as InputProfile if cfg != null else null
	if prof != null:
		return prof.get_movement_vector()
	return Vector2.ZERO

## Returns the 2D aim vector for a player from the joystick right-stick actions.
## The aim vector is isolated from movement: deflecting the right stick never
## affects get_movement_vector() and vice versa.
func get_aim_vector(player_id: int) -> Vector2:
	var cfg: Node = _config()
	var prof: InputProfile = cfg.call("get_profile", player_id) as InputProfile if cfg != null else null
	if prof != null:
		return prof.get_aim_vector()
	return Vector2.ZERO

## True while the given action is held for the player.
func is_action_pressed(player_id: int, action_suffix: String) -> bool:
	var cfg: Node = _config()
	var prof: InputProfile = cfg.call("get_profile", player_id) as InputProfile if cfg != null else null
	if prof != null:
		return prof.is_action_pressed(action_suffix)
	return false

## True on the exact frame the action was pressed (edge detected via polling).
func is_action_just_pressed(player_id: int, action_suffix: String) -> bool:
	var cfg: Node = _config()
	var prof: InputProfile = cfg.call("get_profile", player_id) as InputProfile if cfg != null else null
	if prof != null:
		return prof.is_action_just_pressed(action_suffix)
	return false

## ── Debug InputMap helper (sandbox Action System probe only) ──────────────
func _bind_key(action_name: String, keycode: Key) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	var existing: Array[InputEvent] = InputMap.action_get_events(action_name)
	for ev: InputEvent in existing:
		if ev is InputEventKey:
			InputMap.action_erase_event(action_name, ev)
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	InputMap.action_add_event(action_name, ev)