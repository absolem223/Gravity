# input_profile.gd
# Technical Rationale: Reusable per-player input profile. Encapsulates the full
# set of gameplay actions bound to either keyboard+mouse or a joystick slot,
# stored INDEPENDENTLY of Godot's InputMap. Gameplay consults the profile, never
# raw keys. Fully serializable so controls can be configured from a menu and
# persist between sessions. Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name InputProfile
extends RefCounted

## Canonical gameplay actions. The source of truth for "what actions exist".
## Menu-driven rebinding edits exactly these actions; gameplay queries them.
const ACTION_NAMES: Array[String] = [
	"move_up", "move_down", "move_left", "move_right",
	"aim_up", "aim_down", "aim_left", "aim_right", "aim_cone",
	"fire", "dash", "ability", "interact",
	"drone_mode", "back_operator", "drone_action", "menu",
	"crouch", "autoaim",
]

## Human-readable labels (indexed by ACTION_NAMES).
const ACTION_LABELS: Dictionary = {
	"move_up": "Mover arriba",
	"move_down": "Mover abajo",
	"move_left": "Mover izquierda",
	"move_right": "Mover derecha",
	"aim_up": "Apuntar arriba",
	"aim_down": "Apuntar abajo",
	"aim_left": "Apuntar izquierda",
	"aim_right": "Apuntar derecha",
	"aim_cone": "Cono de visión (autoapuntar)",
	"fire": "Disparar",
	"dash": "Dash",
	"ability": "Habilidad principal",
	"interact": "Interactuar",
	"drone_mode": "Cambiar al Drone",
	"back_operator": "Volver al Operador",
	"drone_action": "Acción del Drone",
	"menu": "Menú",
	"crouch": "Agacharse",
	"autoaim": "Autoapuntar",
}

enum DeviceKind { KEYBOARD, JOYSTICK }

## Analog joystick deadzone for digital actions (fire, dash, ...).
const JOY_DEADZONE: float = 0.25

## Which player slot owns this profile (1..4).
var player_id: int = 1

## Active device kind for this player.
var device_kind: DeviceKind = DeviceKind.KEYBOARD

## Menu joystick slot (1..N, N = number of connected pads). -1 when keyboard.
## Resolved to an OS device id at query time so hotplugging keeps working.
var joystick_index: int = -1

## action -> Array[InputEvent] (the bound events for this action).
var _bindings: Dictionary = {}

func is_keyboard() -> bool:
	return device_kind == DeviceKind.KEYBOARD

func get_device_label() -> String:
	if device_kind == DeviceKind.KEYBOARD:
		return "Teclado"
	var count: int = Input.get_connected_joypads().size()
	if joystick_index >= 1 and joystick_index <= count:
		return "Joystick %d" % joystick_index
	return "Joystick %d (no detectado)" % joystick_index

## Resolves this profile's joystick slot to an OS device id (-1 when invalid).
func get_joy_device_id() -> int:
	if device_kind != DeviceKind.JOYSTICK or joystick_index < 1:
		return -1
	return InputProfiles.resolve_joy_device(joystick_index)

## Sets the device for this player. Keyboard erases nothing; switching to a
## joystick slot keeps all bindings (they are interpreted per device).
func set_device(kind: DeviceKind, joy_slot: int) -> void:
	device_kind = kind
	joystick_index = -1 if kind == DeviceKind.KEYBOARD else joy_slot

## Binds a single event to an action (replaces any previous binding).
func bind_action(action: String, event: InputEvent) -> void:
	if event == null or not ACTION_NAMES.has(action):
		return
	_bindings[action] = [event]

## Returns the events bound to an action (empty when unbound).
func get_events(action: String) -> Array[InputEvent]:
	var raw: Array = _bindings.get(action, []) as Array
	var out: Array[InputEvent] = []
	for ev: Variant in raw:
		if ev is InputEvent:
			out.append(ev as InputEvent)
	return out

## True when the action currently has at least one bound event.
func has_binding(action: String) -> bool:
	var events: Array[InputEvent] = get_events(action)
	return not events.is_empty()

## ──────────────────────────────────────────────
## DEVICE QUERIES (independent of InputMap)
## ──────────────────────────────────────────────

## Analog strength [0..1] of an action from its bound events (device-scoped).
func get_action_strength(action: String) -> float:
	var events: Array[InputEvent] = get_events(action)
	if events.is_empty():
		return 0.0
	var strength: float = 0.0
	for ev: InputEvent in events:
		strength = maxf(strength, _event_strength(ev))
	return strength

## Pressed/held state of an action (buttons/keys = 1.0, analog > deadzone).
func is_action_pressed(action: String) -> bool:
	return get_action_strength(action) > JOY_DEADZONE

## ──────────────────────────────────────────────
## EDGE TRACKING (just_pressed) — independent of InputMap
## ──────────────────────────────────────────────
## poll_frame() must be called once per process frame (by the InputManager) to
## advance the prev/current snapshots. Queries read the sampled state so that
## "just pressed" never depends on Godot's InputMap.

var _prev_pressed: Dictionary = {}
var _cur_pressed: Dictionary = {}

## Advances the input snapshots. Call this before gameplay queries each frame.
func poll_frame() -> void:
	_prev_pressed = _cur_pressed
	_cur_pressed = {}
	for action: String in ACTION_NAMES:
		if is_action_pressed(action):
			_cur_pressed[action] = true

## True only on the frame the action transitions from released to pressed.
func is_action_just_pressed(action: String) -> bool:
	return _cur_pressed.get(action, false) and not _prev_pressed.get(action, false)

## Human-readable device label for this profile (used by the SquadHUD).
func get_device_name() -> String:
	if device_kind == DeviceKind.KEYBOARD:
		return "Teclado"
	return InputProfiles.joypad_slot_label(joystick_index)

## Movement vector from the four directional actions.
## Works for keyboard (WASD/arrows), D-pad and analog sticks.
## A radial analog deadzone is applied so a drifting/uncalibrated stick (small
## offset under JOY_DEADZONE) never yields a non-zero movement vector without
## the player actively moving the stick.
func get_movement_vector() -> Vector2:
	var v: Vector2 = Vector2(
		get_action_strength("move_right") - get_action_strength("move_left"),
		get_action_strength("move_down") - get_action_strength("move_up")
	)
	return deadzone_vector(v)

## Aim vector from the four directional aim actions (right stick on gamepads).
## Mirrors the movement vector pipeline with its own deadzone so a drifting
## right stick never produces an aim offset without the player deflecting it,
## and the right stick NEVER feeds the movement vector (full stick isolation).
func get_aim_vector() -> Vector2:
	if device_kind == DeviceKind.JOYSTICK:
		var dev: int = get_joy_device_id()
		if dev >= 0:
			var rx_axis: int = JOY_AXIS_RIGHT_X
			var ry_axis: int = JOY_AXIS_RIGHT_Y
			
			var ev_r: Array[InputEvent] = get_events("aim_right")
			if ev_r.is_empty() or not ev_r[0] is InputEventJoypadMotion:
				ev_r = get_events("aim_left")
			if not ev_r.is_empty() and ev_r[0] is InputEventJoypadMotion:
				rx_axis = (ev_r[0] as InputEventJoypadMotion).axis
				
			var ev_d: Array[InputEvent] = get_events("aim_down")
			if ev_d.is_empty() or not ev_d[0] is InputEventJoypadMotion:
				ev_d = get_events("aim_up")
			if not ev_d.is_empty() and ev_d[0] is InputEventJoypadMotion:
				ry_axis = (ev_d[0] as InputEventJoypadMotion).axis
				
			var rx: float = Input.get_joy_axis(dev, rx_axis)
			var ry: float = Input.get_joy_axis(dev, ry_axis)
			return deadzone_vector(Vector2(rx, ry))
	var v: Vector2 = Vector2(
		get_action_strength("aim_right") - get_action_strength("aim_left"),
		get_action_strength("aim_down") - get_action_strength("aim_up")
	)
	return deadzone_vector(v)



## Deadzones a 2D movement vector radially. Sub-JOY_DEADZONE magnitudes are
## cancelled (fixes drift-induced "stuck movement"); magnitudes > 1.0 are re-
## normalized; analog magnitudes inside [deadzone, 1] are rescaled to preserve
## the analog feel. Keyboard vectors (pure 0/1) are left intact.
static func deadzone_vector(v: Vector2) -> Vector2:
	var len: float = v.length()
	if len <= JOY_DEADZONE:
		return Vector2.ZERO
	if len > 1.0:
		return v.normalized()
	var rescaled: float = (len - JOY_DEADZONE) / (1.0 - JOY_DEADZONE)
	return v * (rescaled / len)

## ──────────────────────────────────────────────
## DEFAULT BINDINGS
## ──────────────────────────────────────────────

## Loads the default binding scheme for the player slot + current device.
func reset_defaults() -> void:
	_bindings.clear()
	if device_kind == DeviceKind.KEYBOARD:
		_reset_keyboard_defaults()
	else:
		_reset_joystick_defaults()

func _bind_key(action: String, keycode: Key) -> void:
	var ev: InputEventKey = InputEventKey.new()
	ev.keycode = keycode
	bind_action(action, ev)

func _bind_mouse(action: String, button: MouseButton) -> void:
	var ev: InputEventMouseButton = InputEventMouseButton.new()
	ev.button_index = button
	bind_action(action, ev)

func _bind_joy_button(action: String, button: JoyButton) -> void:
	var ev: InputEventJoypadButton = InputEventJoypadButton.new()
	ev.button_index = button
	bind_action(action, ev)

func _bind_joy_axis(action: String, axis: JoyAxis, value: float) -> void:
	var ev: InputEventJoypadMotion = InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	bind_action(action, ev)

## Keyboard defaults are per-slot so 4 keyboard players work simultaneously.
func _reset_keyboard_defaults() -> void:
	match player_id:
		1:
			_bind_key("move_up", KEY_W); _bind_key("move_down", KEY_S)
			_bind_key("move_left", KEY_A); _bind_key("move_right", KEY_D)
			_bind_mouse("fire", MOUSE_BUTTON_LEFT)
			_bind_key("ability", KEY_E); _bind_key("dash", KEY_SHIFT)
			_bind_key("interact", KEY_Q); _bind_key("drone_mode", KEY_SPACE)
			_bind_key("back_operator", KEY_T); _bind_key("drone_action", KEY_F)
			_bind_key("menu", KEY_ESCAPE); _bind_key("crouch", KEY_C)
			_bind_mouse("aim_cone", MOUSE_BUTTON_RIGHT)
		2:
			_bind_key("move_up", KEY_I); _bind_key("move_down", KEY_K)
			_bind_key("move_left", KEY_J); _bind_key("move_right", KEY_L)
			_bind_key("fire", KEY_U); _bind_key("ability", KEY_H)
			_bind_key("dash", KEY_G); _bind_key("interact", KEY_O)
			_bind_key("drone_mode", KEY_Y); _bind_key("back_operator", KEY_T)
			_bind_key("drone_action", KEY_F); _bind_key("menu", KEY_ESCAPE)
			_bind_key("crouch", KEY_N); _bind_key("autoaim", KEY_M)
		3:
			_bind_key("move_up", KEY_UP); _bind_key("move_down", KEY_DOWN)
			_bind_key("move_left", KEY_LEFT); _bind_key("move_right", KEY_RIGHT)
			_bind_key("fire", KEY_SLASH); _bind_key("ability", KEY_COMMA)
			_bind_key("dash", KEY_BRACKETRIGHT); _bind_key("interact", KEY_SEMICOLON)
			_bind_key("drone_mode", KEY_SHIFT); _bind_key("back_operator", KEY_APOSTROPHE)
			_bind_key("drone_action", KEY_F); _bind_key("menu", KEY_ESCAPE)
			_bind_key("crouch", KEY_PERIOD); _bind_key("autoaim", KEY_Z)
		4:
			_bind_key("move_up", KEY_KP_8); _bind_key("move_down", KEY_KP_5)
			_bind_key("move_left", KEY_KP_4); _bind_key("move_right", KEY_KP_6)
			_bind_key("fire", KEY_KP_0); _bind_key("ability", KEY_KP_7)
			_bind_key("dash", KEY_KP_DIVIDE); _bind_key("interact", KEY_KP_ENTER)
			_bind_key("drone_mode", KEY_KP_SUBTRACT); _bind_key("back_operator", KEY_KP_9)
			_bind_key("drone_action", KEY_KP_3); _bind_key("menu", KEY_ESCAPE)
			_bind_key("crouch", KEY_KP_PERIOD); _bind_key("autoaim", KEY_KP_1)
		_:
			_bind_key("move_up", KEY_W); _bind_key("move_down", KEY_S)
			_bind_key("move_left", KEY_A); _bind_key("move_right", KEY_D)
			_bind_key("fire", KEY_SPACE); _bind_key("ability", KEY_E)
			_bind_key("dash", KEY_B); _bind_key("interact", KEY_F)
			_bind_key("drone_mode", KEY_Q); _bind_key("back_operator", KEY_T)
			_bind_key("drone_action", KEY_G); _bind_key("menu", KEY_ESCAPE)
			_bind_key("crouch", KEY_C); _bind_key("autoaim", KEY_V)

func _reset_joystick_defaults() -> void:
	_bind_joy_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_bind_joy_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_bind_joy_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_bind_joy_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	_bind_joy_axis("aim_left", JOY_AXIS_RIGHT_X, -1.0)
	_bind_joy_axis("aim_right", JOY_AXIS_RIGHT_X, 1.0)
	_bind_joy_axis("aim_up", JOY_AXIS_RIGHT_Y, -1.0)
	_bind_joy_axis("aim_down", JOY_AXIS_RIGHT_Y, 1.0)
	_bind_joy_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_bind_joy_button("ability", JOY_BUTTON_LEFT_SHOULDER)
	_bind_joy_button("dash", JOY_BUTTON_A)          # South
	_bind_joy_button("interact", JOY_BUTTON_X)      # West
	_bind_joy_button("drone_mode", JOY_BUTTON_B)    # East
	_bind_joy_button("back_operator", JOY_BUTTON_BACK)
	_bind_joy_button("drone_action", JOY_BUTTON_Y)  # North
	_bind_joy_button("menu", JOY_BUTTON_START)
	_bind_joy_button("crouch", JOY_BUTTON_LEFT_STICK)
	_bind_joy_button("autoaim", JOY_BUTTON_RIGHT_STICK)

## ──────────────────────────────────────────────
## SERIALIZATION
## ──────────────────────────────────────────────

## Converts the profile to a plain Dictionary (JSON-safe).
func serialize() -> Dictionary:
	var actions: Dictionary = {}
	for action: String in ACTION_NAMES:
		var events: Array[InputEvent] = get_events(action)
		if events.is_empty():
			continue
		var ev: InputEvent = events[0]
		actions[action] = _event_to_dict(ev)
	return {
		"device_kind": int(device_kind),
		"joystick_index": joystick_index,
		"actions": actions,
	}

## Restores the profile from a serialized Dictionary. Unknown actions/events are
## ignored and the profile is padded back to a full default binding set.
func deserialize(data: Dictionary) -> void:
	var actions: Dictionary = {}
	if not data.is_empty() and data.has("actions") and data["actions"] is Dictionary:
		device_kind = int(data.get("device_kind", DeviceKind.KEYBOARD)) as DeviceKind
		joystick_index = int(data.get("joystick_index", -1))
		_bindings.clear()
		actions = data["actions"] as Dictionary
		for action: String in actions.keys():
			var ev: InputEvent = _dict_to_event(actions[action])
			if ev != null:
				bind_action(action, ev)
	## Fill any action that ended up unbound with a default binding.
	for action: String in ACTION_NAMES:
		if not has_binding(action):
			reset_defaults()  # rebuild full defaults then re-apply overrides below
			for a2: String in actions.keys():
				var ev2: InputEvent = _dict_to_event(actions[a2])
				if ev2 != null:
					bind_action(a2, ev2)
			return

func _event_to_dict(ev: InputEvent) -> Dictionary:
	if ev is InputEventKey:
		return {"type": "key", "code": (ev as InputEventKey).keycode}
	if ev is InputEventMouseButton:
		return {"type": "mouse", "button": int((ev as InputEventMouseButton).button_index)}
	if ev is InputEventJoypadButton:
		return {"type": "jbutton", "button": int((ev as InputEventJoypadButton).button_index)}
	if ev is InputEventJoypadMotion:
		return {"type": "jaxis", "axis": int((ev as InputEventJoypadMotion).axis), "value": (ev as InputEventJoypadMotion).axis_value}
	return {}

func _dict_to_event(data: Variant) -> InputEvent:
	if not data is Dictionary:
		return null
	var d: Dictionary = data as Dictionary
	match String(d.get("type", "")):
		"key":
			var kev: InputEventKey = InputEventKey.new()
			kev.keycode = int(d.get("code", 0)) as Key
			return kev
		"mouse":
			var mev: InputEventMouseButton = InputEventMouseButton.new()
			mev.button_index = int(d.get("button", 1)) as MouseButton
			return mev
		"jbutton":
			var jbev: InputEventJoypadButton = InputEventJoypadButton.new()
			jbev.button_index = int(d.get("button", 0)) as JoyButton
			return jbev
		"jaxis":
			var jmev: InputEventJoypadMotion = InputEventJoypadMotion.new()
			jmev.axis = int(d.get("axis", 0)) as JoyAxis
			jmev.axis_value = float(d.get("value", 1.0))
			return jmev
	return null

## ──────────────────────────────────────────────
## INTERNAL — raw device reads
## ──────────────────────────────────────────────

func _event_strength(ev: InputEvent) -> float:
	if ev is InputEventKey:
		var kev: InputEventKey = ev as InputEventKey
		if kev.keycode != KEY_NONE and Input.is_key_pressed(kev.keycode):
			return 1.0
		if kev.physical_keycode != KEY_NONE and Input.is_physical_key_pressed(kev.physical_keycode):
			return 1.0
	elif ev is InputEventMouseButton:
		if Input.is_mouse_button_pressed((ev as InputEventMouseButton).button_index):
			return 1.0
	elif ev is InputEventJoypadButton:
		var dev: int = get_joy_device_id()
		if dev >= 0 and Input.is_joy_button_pressed(dev, (ev as InputEventJoypadButton).button_index):
			return 1.0
	elif ev is InputEventJoypadMotion:
		var dev: int = get_joy_device_id()
		if dev >= 0:
			var jmev: InputEventJoypadMotion = ev as InputEventJoypadMotion
			var val: float = Input.get_joy_axis(dev, jmev.axis)
			if jmev.axis_value < 0.0:
				val = -val
			return maxf(0.0, val)
	return 0.0
