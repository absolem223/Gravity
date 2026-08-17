# test_drone_pilot_fire.gd
# Technical Rationale: Reproduction/regression test for the reported "drone does
# not fire while piloted" issue. Drives the REAL production call chain through a
# live Match: the operator's _process_drone_mode_inputs() enters PILOT when the
# drone_mode action is held > 0.35 s, and the drone's _physics_process() runs
# _process_drone_combat() in PILOT, reading the fire action off the operator's
# InputManager. A stubbed InputManager holds both actions.
#
# ROOT CAUSE LOCKED: the PILOT fire gate used the OPERATOR's spawn-room
# occupancy (operator.is_in_spawn_zone()). Operators cannot move while piloting,
# so a player who spawned in the room and flew the drone out could never fire —
# the operator was still "in spawn". The fix gates fire on the DRONE's OWN
# spawn-room occupancy: a drone parked inside its team's room is locked out, but
# a drone that has flown out fires even if the operator stays in the room.
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

## Stub InputManager reporting every action (drone_mode + fire) as held.
class HeldAllInput:
	extends InputManager
	func is_action_pressed(_player_id: int, _suffix: String) -> bool:
		return true

func run_test() -> void:
	print("== DRONE PILOT FIRE (REAL MATCH FLOW) ==")
	var cfg: Node = get_root().get_node_or_null("GameConfig")
	if cfg != null:
		cfg.call("reset_slots_to_defaults")

	var m: Match = (load("res://scenes/match.tscn") as PackedScene).instantiate() as Match
	m.intro_enabled = false
	get_root().add_child(m)
	current_scene = m
	for i in 12:
		await physics_frame

	var pm: PlayerManager = m.get_player_manager()
	var p1: OperatorBase = pm.get_operator(1)
	_check(p1 != null, "P1 operator spawned")
	if p1 == null:
		m.queue_free()
		print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
		quit(1)
		return

	p1.is_ai_controlled = false
	var held: HeldAllInput = HeldAllInput.new()
	m.add_child(held)
	p1.set_input_manager(held)
	for i in 8:
		await physics_frame

	var d1: DroneBase = p1.drone
	_check(d1 != null, "P1 owns a drone")
	_check(p1._input_manager != null, "P1 has an InputManager wired")
	if d1 == null:
		m.queue_free()
		print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
		quit(1)
		return

	# Pin the OPERATOR inside the attacker spawn room (room center (0,0,23),
	# radius 5). The operator is NOT moved for the rest of the test.
	p1.global_position = Vector3(0.0, 0.0, 23.0)
	d1.global_position = Vector3(0.0, 2.0, 22.0)  # drone still INSIDE the room
	await physics_frame
	_check(p1.is_in_spawn_zone(), "P1 operator is INSIDE its spawn room (stays home)")

	# ── Phase 1: drone still inside the spawn room -> fire locked out ──
	var rounds_start: int = d1.weapon.magazine.current_rounds
	for i in 50:
		await physics_frame   # PILOT enters after ~0.35 s of held drone_mode
	var rounds_mid: int = d1.weapon.magazine.current_rounds
	print("    [probe] phase1 drone in-spawn | mag %d -> %d | mode %d" % [
		rounds_start, rounds_mid, d1.current_mode])
	_check(d1.current_mode == DroneBase.DroneMode.PILOT, "drone is in PILOT mode (held drone_mode)")
	_check(rounds_mid == rounds_start, "spawn protection holds: drone parked in its room does NOT fire")

	# ── Phase 2: drone flies OUT of the room while the operator STAYS home ──
	d1.global_position = Vector3(0.0, 2.0, 14.0)  # 9 m from room center, 9 m from operator (< 28 range)
	for i in 60:
		await physics_frame
	var rounds_end: int = d1.weapon.magazine.current_rounds
	print("    [probe] phase2 drone out-of-spawn | mag %d -> %d | op in-spawn=%s" % [
		rounds_mid, rounds_end, p1.is_in_spawn_zone()])
	_check(p1.is_in_spawn_zone(), "operator still inside its spawn room during phase 2")
	_check(rounds_end < rounds_mid, "drone FIRES once IT has left the spawn room (drone-origin rule)")

	m.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)