# test_ai_controller.gd
# Technical Rationale: Validates the minimal AI brain drives AI operators through
# the OperatorBase drive hooks: it leaves the spawn room, attacks a terminal
# (recapturing/capturing), and sets combat fire against an enemy in LoS range.
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

func _new_match() -> Match:
	var m: Match = (load("res://scenes/match.tscn") as PackedScene).instantiate() as Match
	m.intro_enabled = false
	get_root().add_child(m)
	current_scene = m
	return m

## Steps an operator incrementally toward a target so CoreCaptureZone's
## body_entered fires reliably (teleports can be missed by area overlap).
func _step_to(op: OperatorBase, target: Vector3) -> void:
	op.velocity = Vector3.ZERO
	for i in range(16):
		op.global_position = op.global_position.lerp(target, 0.5)
		for _f in range(2):
			await physics_frame

func run_test() -> void:
	print("== AI CONTROLLER TEST ==")
	# Hermetic: ensure all 4 slots are enabled regardless of persisted config.
	var cfg: Node = get_root().get_node_or_null("GameConfig")
	if cfg != null:
		cfg.call("reset_slots_to_defaults")

	var m: Match = _new_match()
	for i in 5:
		await physics_frame

	print("--- [1] AIController wired into the match ---")
	var ac: AIController = m.get_ai_controller()
	_check(ac != null, "match exposes an AIController")
	_check(ac != null and ac._player_manager != null and ac._terminal_manager != null,
		"AIController bound to player/terminal managers")

	# Force P3 (defender, team 1) to AI.
	var pm: PlayerManager = m.get_player_manager()
	var p3: OperatorBase = pm.get_operator(3)
	p3.is_ai_controlled = true

	print("--- [2] AI leaves the spawn room ---")
	p3.global_position = Vector3(0.0, 0.0, -23.0)
	for i in 3:
		await physics_frame
	var moved_out: bool = false
	for i in 240:
		await physics_frame
		if not p3.is_in_spawn_zone():
			moved_out = true
			break
	_check(moved_out, "AI P3 left the protected spawn room")

	print("--- [3] AI captures a terminal ---")
	var tm: TerminalManager = m.get_terminal_manager()
	var tb: AICore = tm.get_terminal("Terminal_B")
	tb.hack_controller.hack_speed_percent_per_second = 50.0
	tb.hack_controller.capture_threshold_percent = 40.0
	# Step P3 onto the terminal so the capture zone registers presence.
	await _step_to(p3, tb.global_position + Vector3(0.0, 1.0, 0.0))
	var captured: bool = false
	for i in 240:
		await physics_frame
		if tb.get_owning_team() == OperatorBase.TEAM_DEFENDERS:
			captured = true
			break
	_check(captured, "AI operator captured Terminal B")

	print("--- [4] Combat: AI fires at an enemy in LoS range ---")
	var m2: Match = _new_match()  # fresh match, clear state
	m2.queue_free()
	for i in 2:
		await physics_frame
	m = _new_match()
	for i in 5:
		await physics_frame
	pm = m.get_player_manager()
	p3 = pm.get_operator(3)
	p3.is_ai_controlled = true
	var p4: OperatorBase = pm.get_operator(4)
	p4.is_ai_controlled = true
	var p1: OperatorBase = pm.get_operator(1)
	# Park the two attack/human operators and one AI far so combat is isolated.
	p3.global_position = Vector3(-5.0, 0.0, 0.0)
	p4.global_position = Vector3(5.0, 0.0, 0.0)
	p1.global_position = Vector3(0.0, 0.0, 8.0)
	var fired: bool = false
	for i in 260:
		await physics_frame
		if p3.ai_fire_input:
			fired = true
			break
	_check(fired, "AI fires against an enemy in range with LoS")

	m.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)