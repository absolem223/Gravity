# test_menu_navigation.gd
# Technical Rationale: Regression tests for gamepad/keyboard menu navigation via
# the explicit ui_* InputMap actions in project.godot (ui_up/down/left/right +
# accept/cancel with joypad D-pad + A/B). Verifies the ui_* actions are defined,
# map to the expected devices, and that Control focus navigation moves between
# buttons (so pause + menus remain pad-navigable without a second input system).
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

func _has_joy(events: Array[InputEvent], button: JoyButton) -> bool:
	for ev: InputEvent in events:
		if ev is InputEventJoypadButton and (ev as InputEventJoypadButton).button_index == button:
			return true
	return false

func _has_key(events: Array[InputEvent], code: Key) -> bool:
	for ev: InputEvent in events:
		if ev is InputEventKey and (ev as InputEventKey).physical_keycode == code:
			return true
	return false

func run_test() -> void:
	print("== MENU NAVIGATION TEST ==")
	var cfg: Node = get_root().get_node_or_null("GameConfig")
	_check(cfg != null, "GameConfig autoload present in tree")
	await physics_frame

	# ── 11: ui_* actions are explicitly defined ──
	var required: Array[String] = ["ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right"]
	for a: String in required:
		_check(InputMap.has_action(a), "InputMap has explicit '%s'" % a)

	# ── 12..15: accept/cancel bound to joypad A/B ──
	var accept_evs: Array[InputEvent] = InputMap.action_get_events("ui_accept")
	var cancel_evs: Array[InputEvent] = InputMap.action_get_events("ui_cancel")
	_check(_has_joy(accept_evs, JOY_BUTTON_A), "ui_accept is bound to joypad A")
	_check(_has_joy(cancel_evs, JOY_BUTTON_B), "ui_cancel is bound to joypad B")
	_check(_has_key(accept_evs, KEY_ENTER) or _has_key(accept_evs, KEY_SPACE), "ui_accept also bound to Enter/Space")

	# ── 16..18: D-pad drives focus navigation ──
	var up_evs: Array[InputEvent] = InputMap.action_get_events("ui_up")
	var down_evs: Array[InputEvent] = InputMap.action_get_events("ui_down")
	var left_evs: Array[InputEvent] = InputMap.action_get_events("ui_left")
	var right_evs: Array[InputEvent] = InputMap.action_get_events("ui_right")
	_check(_has_joy(up_evs, JOY_BUTTON_DPAD_UP), "ui_up bound to joypad D-pad up")
	_check(_has_joy(down_evs, JOY_BUTTON_DPAD_DOWN), "ui_down bound to joypad D-pad down")
	_check(_has_joy(left_evs, JOY_BUTTON_DPAD_LEFT), "ui_left bound to joypad D-pad left")
	_check(_has_joy(right_evs, JOY_BUTTON_DPAD_RIGHT), "ui_right bound to joypad D-pad right")

	# ── 19: Control focus navigation actually moves between buttons (no parallel
	# menu input system: Godot built-in focus handles D-pad via ui_* actions). ──
	var stack: UIScreenStack = UIScreenStack.new()
	get_root().add_child(stack)
	var main: UIScreen = load("res://ui/screens/main_screen.gd").new()
	stack.push(main)
	await physics_frame
	await physics_frame
	# BindingsScreen is the richest focus graph; drive navigation on it.
	var bindings: UIScreen = load("res://ui/screens/bindings_screen.gd").new(1)
	stack.push(bindings)
	await physics_frame
	await physics_frame
	var vp: Viewport = get_root()
	var focus_a: Control = vp.gui_get_focus_owner()
	_check(focus_a != null, "BindingsScreen gains focus after push")
	# Simulate ui_down: follow the Control focus chain.
	var nav: Control = focus_a
	for i in 3:
		nav = nav.find_next_valid_focus()
		if nav == null:
			break
	_check((focus_a != null) and nav != null and nav != focus_a, "focus navigation finds a different control after ui_down chain")

	while stack.back_enabled() or stack.top() != null:
		stack.pop()
		await physics_frame
		if stack.top() == null:
			break

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)