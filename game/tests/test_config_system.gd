# test_config_system.gd
# Technical Rationale: Headless validation of the definitive configuration system:
# GameConfig autoload, per-player InputProfiles, serialization round-trip, profile
# edge-tracking, InputManager delegation and InputProfiles device resolution.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func run_test() -> void:
	print("== CONFIG SYSTEM TEST ==")
	var cfg: Node = get_root().get_node_or_null("GameConfig")
	_check(cfg != null, "GameConfig autoload present in tree")

	# Hermetic start: force every profile back to keyboard defaults so the result
	# does not depend on any previously persisted user:// config.
	for p_id: int in range(1, 5):
		var prof: InputProfile = cfg.call("get_profile", p_id) as InputProfile
		if prof != null:
			prof.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
			prof.reset_defaults()

	# Two keyboard profiles may coexist with overlapping key bindings (shared input).
	var prof_a: InputProfile = cfg.call("get_profile", 1) as InputProfile
	var prof_b: InputProfile = cfg.call("get_profile", 2) as InputProfile
	_check(prof_a != null and prof_b != null, "P1 and P2 profiles exist for keyboard-sharing check")
	_check(prof_a.is_keyboard() and prof_b.is_keyboard(), "both P1 and P2 are keyboard devices")
	prof_a.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
	prof_b.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
	prof_a.reset_defaults()
	prof_b.reset_defaults()
	_check(prof_a != prof_b, "keyboard profiles are distinct instances (shared input, not shared object)")
	_check(prof_a.has_binding("move_up") and prof_b.has_binding("move_up"), "both keyboard profiles retain their own bindings")

	var prof_count: int = 0
	var all_defaults: bool = true
	for p_id: int in range(1, 5):
		var prof: InputProfile = cfg.call("get_profile", p_id) as InputProfile
		if prof != null:
			prof_count += 1
			if not prof.has_binding("move_up") or not prof.has_binding("fire"):
				all_defaults = false
	_check(prof_count == 4, "GameConfig owns 4 input profiles (got %d)" % prof_count)
	_check(all_defaults, "every profile has default move_up + fire bindings")

	# Serialization round-trip preserves the binding set.
	var prof1: InputProfile = cfg.call("get_profile", 1) as InputProfile
	_check(prof1 != null and prof1.is_keyboard(), "P1 default device is keyboard")
	if prof1 != null:
		var data: Dictionary = prof1.serialize()
		var restored: InputProfile = InputProfile.new()
		restored.player_id = 1
		restored.deserialize(data)
		_check(restored.has_binding("move_up") and restored.is_keyboard(), "serialize/deserialize round-trip keeps device + bindings")

	# Empty data falls back to full defaults for that slot.
	var empty_prof: InputProfile = InputProfile.new()
	empty_prof.player_id = 3
	empty_prof.deserialize({})
	_check(empty_prof.has_binding("move_up"), "deserialize({}) pads profile back to defaults")

	# bind_action replaces the previous binding (single source of truth).
	if prof1 != null:
		var kev: InputEventKey = InputEventKey.new()
		kev.keycode = KEY_R
		prof1.bind_action("dash", kev)
		var events: Array[InputEvent] = prof1.get_events("dash")
		_check(events.size() == 1 and events[0] is InputEventKey, "bind_action replaces binding (1 event)")
		prof1.reset_defaults()

	# InputManager delegates gameplay reads to GameConfig (no InputMap/hardcoded keys).
	var im: InputManager = InputManager.new()
	get_root().add_child(im)
	await physics_frame
	_check(im.get_movement_vector(1) == Vector2.ZERO, "InputManager movement is neutral without physical input (profile-driven)")
	_check(im.is_action_pressed(1, "fire") == false, "InputManager fire is false in headless (profile-driven)")
	_check(im.is_action_just_pressed(1, "ability") == false, "InputManager just_pressed is false in headless (edge-tracked)")
	im.queue_free()

	# Analog deadzone: a drifting stick (small offset) must NOT produce movement,
	# while a real deflection must pass through. Total cancels sub-deadzone drift.
	_check(InputProfile.deadzone_vector(Vector2(0.0, 0.0)) == Vector2.ZERO, "deadzone kills neutral vector")
	_check(InputProfile.deadzone_vector(Vector2(0.1, 0.0)) == Vector2.ZERO, "deadzone kills sub-deadzone drift (X)")
	_check(InputProfile.deadzone_vector(Vector2(0.0, -0.05)) == Vector2.ZERO, "deadzone kills sub-deadzone drift (Y)")
	_check(InputProfile.deadzone_vector(Vector2(0.25, 0.0)) == Vector2.ZERO, "deadzone kills exactly-at-deadzone drift")
	_check(InputProfile.deadzone_vector(Vector2(1.0, 0.0)) == Vector2(1.0, 0.0), "full push passes through at full magnitude")
	_check(InputProfile.deadzone_vector(Vector2(1.5, 0.0)) == Vector2(1.0, 0.0), "overshoot is normalized to unit length")
	_check(InputProfile.deadzone_vector(Vector2(1.0, 1.0)).length() > 0.99, "diagonal push keeps full magnitude")
	_check(InputProfile.deadzone_vector(Vector2(0.0, 1.0)) == Vector2(0.0, 1.0), "down input preserved")

	# InputProfiles device resolution.
	_check(InputProfiles.resolve_joy_device(-1) == -1, "resolve_joy_device(-1) is invalid")
	_check(InputProfiles.resolve_joy_device(1) >= -1, "resolve_joy_device(1) does not crash without pads")

	# Party validation against the slot store.
	cfg.call("reset_slots_to_defaults")
	_check(int(cfg.call("count_enabled_slots")) == 4, "4 slots enabled by default")
	_check(int(cfg.call("count_human_slots")) == 4, "4 human slots by default")
	_check(String(cfg.call("validate_party")).is_empty(), "party of 4 humans validates")

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)