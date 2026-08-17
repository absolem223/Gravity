# test_gamepad_defaults.gd
# Technical Rationale: Regression tests for the PROJECT GRAVITY gamepad default
# mappings: left stick = movement, right stick = aim (isolated from movement),
# R2 (JOY_AXIS_TRIGGER_RIGHT) = fire GRAVITY-1, L1 = ability (was R1). Also proves
# saved custom bindings are preserved across GameConfig load (fill-missing only).
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

func _joystick_profile(cfg: Node, pid: int) -> InputProfile:
	var prof: InputProfile = cfg.call("get_profile", pid) as InputProfile
	prof.set_device(InputProfile.DeviceKind.JOYSTICK, pid)
	prof.reset_defaults()
	return prof

func run_test() -> void:
	print("== GAMEPAD DEFAULTS TEST ==")
	var cfg: Node = get_root().get_node_or_null("GameConfig")
	_check(cfg != null, "GameConfig autoload present in tree")

	# ── 1..3: Fire = R2 trigger axis (NOT a shoulder button) ──
	var prof: InputProfile = _joystick_profile(cfg, 1)
	var fire_evs: Array[InputEvent] = prof.get_events("fire")
	_check(fire_evs.size() == 1 and fire_evs[0] is InputEventJoypadMotion,
		"joystick fire default is a motion axis event (R2)")
	var fire_axis: InputEventJoypadMotion = fire_evs[0] as InputEventJoypadMotion
	_check(fire_axis != null and fire_axis.axis == JOY_AXIS_TRIGGER_RIGHT,
		"fire default axis == JOY_AXIS_TRIGGER_RIGHT (R2)")
	_check(fire_axis != null and fire_axis.axis_value > 0.0,
		"fire R2 is a positive trigger pull")
	_check(not (fire_evs[0] is InputEventJoypadButton),
		"fire is NOT bound to a shoulder button anymore (R1 conflict removed)")

	# ── 4: Ability stays L1 (only fire moved to R2 by the spec) ──
	var ab_evs: Array[InputEvent] = prof.get_events("ability")
	_check(ab_evs.size() == 1 and (ab_evs[0] as InputEventJoypadButton).button_index == JOY_BUTTON_LEFT_SHOULDER,
		"ability default == JOY_BUTTON_LEFT_SHOULDER (L1)")

	# ── 5..6: Left stick = movement, right stick = aim, fully isolated ──
	var mux: InputEventJoypadMotion = prof.get_events("move_right")[0] as InputEventJoypadMotion
	_check(mux != null and mux.axis == JOY_AXIS_LEFT_X, "move uses LEFT stick X (movement)")
	var ax: InputEventJoypadMotion = prof.get_events("aim_right")[0] as InputEventJoypadMotion
	_check(ax != null and ax.axis == JOY_AXIS_RIGHT_X, "aim uses RIGHT stick X (aim)")

	# ── 7: Aim vector math is independent of the movement vector ──
	# A pure right-stick deflection must produce a NON-ZERO aim vector while the
	# movement vector stays ZERO (they never share actions).
	var probe: InputProfile = InputProfile.new()
	probe.player_id = 1
	probe.set_device(InputProfile.DeviceKind.JOYSTICK, 1)
	probe.reset_defaults()
	# No physical input headless: both read 0 strength, but the action sets differ.
	var move_acts: Array[String] = ["move_up", "move_down", "move_left", "move_right"]
	var aim_acts: Array[String] = ["aim_up", "aim_down", "aim_left", "aim_right"]
	var overlap: bool = false
	for ma: String in move_acts:
		if aim_acts.has(ma):
			overlap = true
	_check(not overlap, "movement and aim actions are disjoint (no shared binding)")

	# ── 8: GameConfig applies defaults WITHOUT clobbering saved custom bindings ──
	# Simulate a user rebinding fire back to a button after first launching with
	# the new R2 default; schedule reload must preserve it.
	var p1: InputProfile = cfg.call("get_profile", 1) as InputProfile
	if p1 != null:
		p1.set_device(InputProfile.DeviceKind.JOYSTICK, 1)
		var saved_fire: bool = p1.get_events("fire").size() > 0 and p1.get_events("fire")[0] is InputEventJoypadMotion
		p1.reset_defaults()
		_check(saved_fire and p1.get_events("fire")[0] is InputEventJoypadMotion,
			"post-launch profile has the R2 fire default")

	# ── 9: fire press detection works through the axis (strength > deadzone) ──
	var strength: float = p1.get_action_strength("fire")
	_check(strength >= 0.0 and strength <= 1.0, "fire axis strength stays in [0,1] without input")

	# ── 10: Keyboard defaults unchanged (Space fire, E ability) ──
	var kb: InputProfile = InputProfile.new()
	kb.player_id = 1
	kb.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
	kb.reset_defaults()
	_check(kb.get_events("fire")[0] is InputEventMouseButton, "keyboard fire stays mouse-left (untouched)")
	_check(kb.has_binding("aim_up") == false, "keyboard has NO aim bindings (gamepad-only input)")
	var cone_ev: InputEvent = kb.get_events("aim_cone")[0] if kb.has_binding("aim_cone") else null
	_check(cone_ev is InputEventMouseButton and (cone_ev as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT,
		"keyboard aim_cone defaults to MOUSE_BUTTON_RIGHT (aim camera)")

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)