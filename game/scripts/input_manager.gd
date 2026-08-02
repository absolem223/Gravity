# input_manager.gd
# Technical Rationale: Centralized local multiplayer input dispatcher (2-4 players).
# Maps hardware devices (Keyboard/Mouse & Gamepads 0-3) to abstract Player IDs.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name InputManager
extends Node

## Number of supported local players in Vertical Slice
const MAX_PLAYERS: int = 4

## Mapping of player IDs (1-4) to assigned device IDs (-1 for Keyboard/Mouse, 0+ for Gamepads)
var _player_device_map: Dictionary = {
	1: -1, # Default: Player 1 on Keyboard/Mouse or Gamepad 0
	2: 0,  # Default: Player 2 on Gamepad 0 (or 1 if P1 uses Gamepad 0)
	3: 1,  # Default: Player 3 on Gamepad 1
	4: 2   # Default: Player 4 on Gamepad 2
}

## Tracks connected Joypads detected by Godot OS layer
var _connected_joypads: Array[int] = []

func _ready() -> void:
	_detect_joypads()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_setup_default_input_map()

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
	if _connected_joypads.size() == 0:
		# Keyboard for P1, default stubs for P2-P4
		_player_device_map[1] = -1
		_player_device_map[2] = 0
		_player_device_map[3] = 1
		_player_device_map[4] = 2
	else:
		# If controllers are present, assign Gamepad 0 to P1 (or keep Keyboard), Gamepad 1 to P2, etc.
		_player_device_map[1] = -1 # P1 gets Keyboard + Gamepad 0 if present
		for i: int in range(0, _connected_joypads.size()):
			var p_id: int = i + 2 # P2, P3, P4
			if p_id <= MAX_PLAYERS:
				_player_device_map[p_id] = _connected_joypads[i]

## Configures InputMap programmatically for 4 players to prevent project.godot bloat
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

## Returns 2D normalized movement vector for specified player ID
func get_movement_vector(player_id: int) -> Vector2:
	var left_action: String = "p%d_move_left" % player_id
	var right_action: String = "p%d_move_right" % player_id
	var up_action: String = "p%d_move_up" % player_id
	var down_action: String = "p%d_move_down" % player_id

	# Primary input reading using standard InputMap
	var input_vec: Vector2 = Input.get_vector(left_action, right_action, up_action, down_action)

	# Fallback for Direct Keyboard inputs per player slot (P1: WASD, P2: IJKL, P3: Arrow Keys, P4: Numpad)
	if input_vec == Vector2.ZERO:
		input_vec = _read_fallback_keyboard_vector(player_id)
	
	# Fallback for Gamepad devices according to device map
	if input_vec == Vector2.ZERO:
		var device_id: int = _player_device_map.get(player_id, -2)
		if device_id >= 0:
			var joy_x: float = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X)
			var joy_y: float = Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
			var joy_vec: Vector2 = Vector2(joy_x, joy_y)
			if joy_vec.length() > 0.2: # Deadzone filter
				input_vec = joy_vec

	return input_vec.normalized() if input_vec.length() > 1.0 else input_vec

## Fallback mapping for testing 4 players on a single keyboard when gamepads are absent
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

## Checks if specified action was pressed this frame for player ID
func is_action_just_pressed(player_id: int, action_suffix: String) -> bool:
	var action_name: String = "p%d_%s" % [player_id, action_suffix]
	if InputMap.has_action(action_name) and Input.is_action_just_pressed(action_name):
		return true
	return false
