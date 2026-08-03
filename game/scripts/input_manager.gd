# input_manager.gd
# Technical Rationale: Refined input management system for 2-4 local players.
# Encapsulates player device profiles (PlayerInputProfile) and manages gamepad hotplugging dynamically.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name InputManager
extends Node

## Signals
signal device_connection_changed(player_id: int, connected: bool)

## Number of supported local players in Vertical Slice
const MAX_PLAYERS: int = 4

## Inner data class representing a player's input hardware profile
class PlayerInputProfile:
	enum DeviceType { KEYBOARD_MOUSE, GAMEPAD, UNASSIGNED }

	var player_id: int = 1
	var device_id: int = -1 # -1 = Keyboard/Mouse, 0+ = Gamepad Device ID
	var device_type: DeviceType = DeviceType.KEYBOARD_MOUSE
	var is_connected: bool = true
	var role_name_placeholder: String = "Operator"

	func get_device_name() -> String:
		match device_type:
			DeviceType.KEYBOARD_MOUSE:
				return "Keyboard & Mouse"
			DeviceType.GAMEPAD:
				return "Gamepad #%d" % device_id
			_:
				return "Disconnected"

## Registry of active player profiles indexed by Player ID (1..4)
var _profiles: Dictionary = {}

## Tracks connected Joypads detected by Godot OS layer
var _connected_joypads: Array[int] = []

func _ready() -> void:
	_initialize_profiles()
	_detect_joypads()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_setup_default_input_map()

## Creates initial default profiles for players 1 to 4
func _initialize_profiles() -> void:
	_profiles.clear()
	var role_names: Array[String] = ["Recon", "Vanguard", "Tech Disruptor", "Field Engineer"]
	
	for p_id: int in range(1, MAX_PLAYERS + 1):
		var profile: PlayerInputProfile = PlayerInputProfile.new()
		profile.player_id = p_id
		profile.role_name_placeholder = role_names[p_id - 1]
		_profiles[p_id] = profile

## Detects currently connected controllers at launch
func _detect_joypads() -> void:
	_connected_joypads.clear()
	var joypads: Array[int] = Input.get_connected_joypads()
	for joy_id: int in joypads:
		_connected_joypads.append(joy_id)
	_auto_assign_devices()

## Callback when a gamepad is plugged in or unplugged
func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		if not _connected_joypads.has(device_id):
			_connected_joypads.append(device_id)
	else:
		_connected_joypads.erase(device_id)
	
	_auto_assign_devices()

## Automatically assigns available controllers to players 1-4
func _auto_assign_devices() -> void:
	var p1_prof: PlayerInputProfile = _profiles.get(1)
	if p1_prof != null:
		p1_prof.device_id = -1
		p1_prof.device_type = PlayerInputProfile.DeviceType.KEYBOARD_MOUSE
		p1_prof.is_connected = true

	for i: int in range(0, 3):
		var p_id: int = i + 2
		var prof: PlayerInputProfile = _profiles.get(p_id)
		if prof != null:
			if i < _connected_joypads.size():
				prof.device_id = _connected_joypads[i]
				prof.device_type = PlayerInputProfile.DeviceType.GAMEPAD
				prof.is_connected = true
			else:
				prof.device_id = -1
				prof.device_type = PlayerInputProfile.DeviceType.KEYBOARD_MOUSE
				prof.is_connected = true
			device_connection_changed.emit(p_id, prof.is_connected)

## Configures InputMap programmatically for 4 players
func _setup_default_input_map() -> void:
	for player_id: int in range(1, MAX_PLAYERS + 1):
		_ensure_player_action(player_id, "move_left")
		_ensure_player_action(player_id, "move_right")
		_ensure_player_action(player_id, "move_up")
		_ensure_player_action(player_id, "move_down")
		_ensure_player_action(player_id, "fire")
		_ensure_player_action(player_id, "interact")
		_ensure_player_action(player_id, "drone_mode")

func _ensure_player_action(player_id: int, action_suffix: String) -> void:
	var action_name: String = "p%d_%s" % [player_id, action_suffix]
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)

## Retrieves profile for specified player ID
func get_profile(player_id: int) -> PlayerInputProfile:
	return _profiles.get(player_id, null)

## Returns 2D normalized movement vector for specified player ID
func get_movement_vector(player_id: int) -> Vector2:
	var left_action: String = "p%d_move_left" % player_id
	var right_action: String = "p%d_move_right" % player_id
	var up_action: String = "p%d_move_up" % player_id
	var down_action: String = "p%d_move_down" % player_id

	var input_vec: Vector2 = Input.get_vector(left_action, right_action, up_action, down_action)

	var profile: PlayerInputProfile = get_profile(player_id)
	if profile != null and profile.device_type == PlayerInputProfile.DeviceType.GAMEPAD and profile.device_id >= 0:
		var joy_x: float = Input.get_joy_axis(profile.device_id, JOY_AXIS_LEFT_X)
		var joy_y: float = Input.get_joy_axis(profile.device_id, JOY_AXIS_LEFT_Y)
		var joy_vec: Vector2 = Vector2(joy_x, joy_y)
		if joy_vec.length() > 0.2:
			input_vec = joy_vec

	if input_vec == Vector2.ZERO:
		input_vec = _read_fallback_keyboard_vector(player_id)

	return input_vec.normalized() if input_vec.length() > 1.0 else input_vec

## Fallback mapping for testing 4 players on a single keyboard
func _read_fallback_keyboard_vector(player_id: int) -> Vector2:
	var vec: Vector2 = Vector2.ZERO
	match player_id:
		1: # WASD
			if Input.is_key_pressed(KEY_A): vec.x -= 1.0
			if Input.is_key_pressed(KEY_D): vec.x += 1.0
			if Input.is_key_pressed(KEY_W): vec.y -= 1.0
			if Input.is_key_pressed(KEY_S): vec.y += 1.0
		2: # IJKL
			if Input.is_key_pressed(KEY_J): vec.x -= 1.0
			if Input.is_key_pressed(KEY_L): vec.x += 1.0
			if Input.is_key_pressed(KEY_I): vec.y -= 1.0
			if Input.is_key_pressed(KEY_K): vec.y += 1.0
		3: # Arrow Keys
			if Input.is_key_pressed(KEY_LEFT): vec.x -= 1.0
			if Input.is_key_pressed(KEY_RIGHT): vec.x += 1.0
			if Input.is_key_pressed(KEY_UP): vec.y -= 1.0
			if Input.is_key_pressed(KEY_DOWN): vec.y += 1.0
		4: # Numpad 4568
			if Input.is_key_pressed(KEY_KP_4): vec.x -= 1.0
			if Input.is_key_pressed(KEY_KP_6): vec.x += 1.0
			if Input.is_key_pressed(KEY_KP_8): vec.y -= 1.0
			if Input.is_key_pressed(KEY_KP_5): vec.y += 1.0
	return vec

## Checks if specified action is currently pressed (held down) for player ID
func is_action_pressed(player_id: int, action_suffix: String) -> bool:
	var action_name: String = "p%d_%s" % [player_id, action_suffix]
	if InputMap.has_action(action_name) and Input.is_action_pressed(action_name):
		return true

	# Check gamepad trigger or button if profile is Gamepad
	var profile: PlayerInputProfile = get_profile(player_id)
	if profile != null and profile.device_type == PlayerInputProfile.DeviceType.GAMEPAD and profile.device_id >= 0:
		if action_suffix == "fire":
			if Input.is_joy_button_pressed(profile.device_id, JOY_BUTTON_RIGHT_SHOULDER) or Input.get_joy_axis(profile.device_id, JOY_AXIS_TRIGGER_RIGHT) > 0.5:
				return true

	# Keyboard fallback shortcuts for testing fire action:
	if action_suffix == "fire":
		match player_id:
			1: return Input.is_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_E) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
			2: return Input.is_key_pressed(KEY_U) or Input.is_key_pressed(KEY_O)
			3: return Input.is_key_pressed(KEY_SLASH) or Input.is_key_pressed(KEY_SHIFT)
			4: return Input.is_key_pressed(KEY_KP_0) or Input.is_key_pressed(KEY_KP_ENTER)

	return false

## Checks if specified action was pressed this frame for player ID
func is_action_just_pressed(player_id: int, action_suffix: String) -> bool:
	var action_name: String = "p%d_%s" % [player_id, action_suffix]
	if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
		return true
	return false
