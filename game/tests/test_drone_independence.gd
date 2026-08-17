# test_drone_independence.gd
# Technical Rationale: Regression test for the "drone takes control of Player"
# diagnosis. Mirrors the real-game flow: P1's drone (PILOT mode) approaches and
# stops directly on the enemy operator's body, then stays there for many physics
# frames. The test asserts the sampled operator's tree parent, transform, drift,
# velocity and pilot flag are untouched by the drone — proving the drone has no
# parenting/transform/AI/physics coupling that drags another operator around.
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

## Moves the drone a step toward `to` and waits one physics frame, so the
## physics engine and the drone's move_and_slide run for real between steps.
func _drone_step(drone: DroneBase, to: Vector3) -> void:
	drone.global_position = drone.global_position.lerp(to, 0.4)
	await physics_frame

func run_test() -> void:
	print("== DRONE INDEPENDENCE TEST ==")
	var cfg: Node = get_root().get_node_or_null("GameConfig")
	if cfg != null:
		cfg.call("reset_slots_to_defaults")

	var m: Match = _new_match()
	for i in 6:
		await physics_frame

	var pm: PlayerManager = m.get_player_manager()
	var p1: OperatorBase = pm.get_operator(1)
	var sampled: OperatorBase = pm.get_operator(4)  # independent player operator
	p1.global_position = Vector3(0.0, 0.0, 0.0)
	sampled.global_position = Vector3(3.0, 0.0, 0.0)
	# Let the deferred drone spawns land and independent operators rest.
	for i in 4:
		await physics_frame

	var d1: DroneBase = p1.drone
	_check(d1 != null, "P1 owns a drone")
	_check(d1 != null and d1.operator == p1, "drone.operator is strictly P1")
	_check(d1 != null and p1.drone_status_changed != null, "drone wiring is present")

	print("--- [1] Parenting stays under PlayerManager (no reparent, no attachment) ---")
	var pm_node: Node = pm
	_check(sampled.get_parent() == pm_node, "sampled operator parent is PlayerManager (not drone)")
	_check(d1 != null and d1.get_parent() == pm_node, "drone parent is PlayerManager (sibling, not owner)")
	_check(d1 != null and sampled.get_parent() != d1, "sampled is NOT a child of the drone")
	_check(d1 == null or not sampled.get_children().has(d1), "drone is NOT a child of the sampled operator")
	_check(sampled.is_piloting_drone == false, "sampled operator is NOT flagged as piloting")

	print("--- [2] PILOT the drone and drive it onto the sampling operator's body ---")
	if d1 != null:
		d1.set_mode(DroneBase.DroneMode.PILOT)
	_check(p1.is_piloting_drone == true and p1.drone != null, "P1 enters PILOT mode (drone owns the operator link)")
	_check(sampled.is_piloting_drone == false, "sampled operator pilot flag still untouched during P1 PILOT")

	# Let gravity/collision settle P1 onto its resting spot, then record a baseline.
	for i in range(6):
		await physics_frame
	var p1_baseline: Vector3 = p1.global_position

	var start_parent: Node = sampled.get_parent()
	var init_pos: Vector3 = sampled.global_position
	var approach_target: Vector3 = init_pos + Vector3(0.0, 0.6, 0.0)
	var max_drift: float = 0.0

	print("--- [3] Approach, overlap, hold — sampled transform must stay rigid ---")
	if d1 != null and p1.is_piloting_drone:
		# Fly through the operator's body slowly, then stop exactly on it.
		for i in range(6):
			await _drone_step(d1, init_pos + Vector3(0.0, 0.6, -2.0))
			await _drone_step(d1, approach_target)
		# Hold exactly on the operator's own cell for a sustained window.
		for i in range(120):
			await physics_frame
			max_drift = maxf(max_drift, sampled.global_position.distance_to(init_pos))

	_check(sampled.get_parent() == start_parent, "sampled operator parent did not change")
	_check(max_drift < 0.01, "sampled operator's max drift while overlapped is zero (no physical coupling)")
	_check(sampled.global_position.distance_to(init_pos) < 0.01, "sampled operator stayed at its world position (no attachment)")
	_check(sampled.velocity.length() < 0.01, "sampled operator has zero drift velocity (was never pushed)")
	print("    [probe] P1 delta from baseline = ", p1.global_position.distance_to(p1_baseline),
		" | P1 global_position = ", p1.global_position)
	_check(p1.global_position.distance_to(p1_baseline) < 0.01, "P1 operator freezes in place while piloting (input not leaked)")

	print("--- [4] Residual control flags ---")
	_check(sampled.is_ai_controlled == false, "sampled operator stayed human-controlled")
	_check(sampled.ai_move_input == Vector2.ZERO, "sampled operator movement input untouched")
	if d1 != null and d1.operator != null:
		_check(sampled != d1.operator, "sampled operator is NOT the drone's owner")

	m.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)