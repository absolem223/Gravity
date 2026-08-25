# test_ai_drone_autonomy.gd
# Focused acceptance test for AI-owned DRONE autonomy (ESCORT->SEARCH->ENGAGE->RETURN).
# Verifies:
#   A. Human drones are NEVER steered (control gate).
#   B. AI drone leaves escort, physically separates, flies to a search probe.
#   C. On detecting an enemy operator it engages: closes to stand-off, acquires
#      the EXISTING autonomous combat lock and deals damage with stock stats.
#   D. Losing the target -> RETURN -> seamless stock ESCORT handover.
#   E. Operator downed -> steering dropped instantly.
#   F. Zero stat changes anywhere (drone + operators identical pre/post).
#   G. The drone stays in ESCORT DroneMode the whole time (control seam only).
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0
var ctrl: DroneAIController = null
var _p1: OperatorBase = null
var _p2: OperatorBase = null
var _p3: OperatorBase = null
var _d1: DroneBase = null
var _d3: DroneBase = null

func _init() -> void:
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func _steps(n: int) -> void:
	for i: int in n:
		await physics_frame

## Ticks up to max_frames while cond fails; returns true when cond became true.
## When drive_ctrl is true the controller is ticked manually each frame (its
## _physics_process is disabled for deterministic headless stepping).
func _wait_until(cond: Callable, max_frames: int, drive_ctrl: bool = false) -> bool:
	for i: int in max_frames:
		if drive_ctrl:
			ctrl.tick(1.0 / 60.0)
		if cond.call():
			return true
		await physics_frame
	if drive_ctrl:
		ctrl.tick(1.0 / 60.0)
	return cond.call()

func run_test() -> void:
	print("== AI DRONE AUTONOMY TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	# Lobby slots: P1,P2 human ATK; P3 AI DEF.
	var session: Node = get_root().get_node_or_null("GameConfig")
	var saved_modes: Array[int] = []
	var saved_teams: Array[int] = []
	if session != null:
		for p_id: int in [1, 2, 3]:
			var slot: Variant = session.call("get_slot", p_id)
			saved_modes.append(int(slot.control_mode))
			saved_teams.append(int(slot.team_id))
		session.get_slot(1).control_mode = 0
		session.get_slot(2).control_mode = 0
		session.get_slot(3).control_mode = 1
		session.get_slot(1).team_id = 0
		session.get_slot(2).team_id = 0
		session.get_slot(3).team_id = 1

	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var fshape: CollisionShape3D = CollisionShape3D.new()
	var fbox: BoxShape3D = BoxShape3D.new()
	fbox.size = Vector3(200.0, 1.0, 200.0)
	fshape.shape = fbox
	floor_body.add_child(fshape)
	root.add_child(floor_body)

	# Real PlayerManager so production enumeration paths are exercised.
	var pm: PlayerManager = PlayerManager.new()
	root.add_child(pm)
	pm.setup_squad(null, [1, 2, 3])
	# CRITICAL: separate squads SYNCHRONOUSLY before the first physics frame.
	# Headless fallback spawns put P1 and P3 on the SAME _spawn_offsets[0]
	# point; two deeply-interpenetrated capsules make the solver eject both
	# skyward with huge identical velocity, poisoning every later check.
	pm.get_operator(1).global_position = Vector3(-14.0, 0.0, -14.0)
	pm.get_operator(2).global_position = Vector3(-11.0, 0.0, -14.0)
	pm.get_operator(3).global_position = Vector3(14.0, 0.0, 14.0)
	await physics_frame
	await physics_frame
	await physics_frame # deferred spawn_drone()

	var p1: OperatorBase = pm.get_operator(1)
	var p2: OperatorBase = pm.get_operator(2)
	var p3: OperatorBase = pm.get_operator(3)
	var d1: DroneBase = p1.drone
	var d3: DroneBase = p3.drone
	_p1 = p1
	_p2 = p2
	_p3 = p3
	_d1 = d1
	_d3 = d3
	_check(p1 != null and p2 != null and p3 != null, "operators spawned")
	_check(d1 != null and d3 != null, "drones spawned for both sides")
	_check(p3.is_ai_controlled, "P3 is AI-controlled")

	ctrl = DroneAIController.new()
	root.add_child(ctrl)
	ctrl.set_physics_process(false) # manual deterministic ticking
	ctrl._player_manager = pm       # harness gate (_match stays null)
	ctrl.search_trigger_interval = 0.5
	ctrl.search_timeout = 30.0
	ctrl.target_lose_timeout = 1.0

	# ── Stat snapshot BEFORE ────────────────────────────────────────────────
	var snap_d3: Array = [d3.health_max, d3.weapon.base_damage, d3.speed, d3.acceleration, d3.deceleration, d3.vision_cone.view_range, d3.weapon.range]
	var snap_p3: Array = [p3.health_max, p3.base_damage, p3.move_speed]
	var snap_p1: Array = [p1.health_max, p1.base_damage]

	print("--- [A] Human drone untouched (gate) ---")
	for i: int in 20:
		ctrl.tick(1.0 / 60.0)
		await physics_frame
	_check(d1.ai_steering_target == null, "human drone never receives ai_steering_target")
	_check(d1.current_mode == DroneBase.DroneMode.ESCORT, "human drone mode stays ESCORT")

	print("--- [B] ESCORT -> SEARCH ---")
	var entered_search: bool = await _wait_until(func() -> bool:
		return ctrl._states.has(d3.get_instance_id()) and int(ctrl._states[d3.get_instance_id()]["state"]) == DroneAIController.State.SEARCH, 240, true)
	_check(entered_search, "AI drone enters SEARCH after trigger interval")
	var got_point: bool = await _wait_until(func() -> bool:
		return d3.ai_steering_target != null, 30, true)
	_check(got_point, "AI drone receives a steering point")
	var sep0: float = Vector2(d3.global_position.x - p3.global_position.x, d3.global_position.z - p3.global_position.z).length()
	var separated: bool = await _wait_until(func() -> bool:
		return Vector2(d3.global_position.x - p3.global_position.x, d3.global_position.z - p3.global_position.z).length() > sep0 + 6.0, 600, true)
	_check(separated, "AI drone physically separates from its operator (%.1fm -> +6m)" % sep0)
	_check(d3.current_mode == DroneBase.DroneMode.ESCORT, "mode STILL ESCORT during SEARCH (control seam only)")

	print("--- [C] SEARCH -> ENGAGE (stock combat) ---")
	var point_v: Variant = d3.ai_steering_target
	_check(point_v is Vector3, "steering point is a Vector3")
	if point_v is Vector3:
		var probe: Vector3 = point_v
		p1.global_position = Vector3(probe.x, 0.0, probe.z) # enemy waiting at the probe
	var engaged: bool = await _wait_until(func() -> bool:
		return ctrl._states.has(d3.get_instance_id()) and int(ctrl._states[d3.get_instance_id()]["state"]) == DroneAIController.State.ENGAGE, 360, true)
	_check(engaged, "enemy operator detected by drone cone -> ENGAGE")
	var locked_and_firing: bool = await _wait_until(func() -> bool:
		return d3._autoaim_target == p1 and p1.health_current < p1.health_max - 8.0, 900, true)
	_check(locked_and_firing, "stock autonomous combat locks and damages the enemy (>= 8 dmg)")
	_check(d3.current_mode == DroneBase.DroneMode.ESCORT, "mode STILL ESCORT during ENGAGE")

	print("--- [D] Target lost -> RETURN -> ESCORT ---")
	p1.die()
	p1.process_mode = Node.PROCESS_MODE_DISABLED # freeze corpse (no auto-respawn noise)
	var returning: bool = await _wait_until(func() -> bool:
		return ctrl._states.has(d3.get_instance_id()) and int(ctrl._states[d3.get_instance_id()]["state"]) == DroneAIController.State.RETURN, 300, true)
	_check(returning, "target lost -> RETURN state")
	var home: bool = await _wait_until(func() -> bool:
		var st: Variant = ctrl._states.get(d3.get_instance_id())
		if st == null:
			return false
		var st_d: Dictionary = st
		if int(st_d["state"]) != DroneAIController.State.ESCORT:
			return false
		var anchor: Vector3 = p3.global_position + (p3.global_transform.basis.z * d3.follow_distance) + Vector3(0.0, d3.follow_height_offset, 0.0)
		var off: Vector3 = anchor - d3.global_position
		off.y = 0.0
		return off.length() <= 4.0, 900, true)
	_check(home, "drone returned to escort anchorage and handed back to stock behaviour")
	_check(d3.ai_steering_target == null, "steering override cleared after return")

	print("--- [E] Operator downed -> instant release ---")
	ctrl.tick(1.0 / 60.0)
	await physics_frame
	# Force a fresh SEARCH cycle then take the operator down mid-search.
	ctrl.search_trigger_interval = 0.05
	var searching_again: bool = await _wait_until(func() -> bool:
		return ctrl._states.has(d3.get_instance_id()) and int(ctrl._states[d3.get_instance_id()]["state"]) == DroneAIController.State.SEARCH, 120, true)
	_check(searching_again, "drone probes again (cycle restarts)")
	p3.die()
	ctrl.tick(1.0 / 60.0)
	_check(d3.ai_steering_target == null, "operator downed -> steering dropped instantly")

	print("--- [F] Stats unchanged ---")
	var snap_d3_post: Array = [d3.health_max, d3.weapon.base_damage, d3.speed, d3.acceleration, d3.deceleration, d3.vision_cone.view_range, d3.weapon.range]
	var snap_p3_post: Array = [p3.health_max, p3.base_damage, p3.move_speed]
	var snap_p1_post: Array = [p1.health_max, p1.base_damage]
	_check(snap_d3_post == snap_d3, "drone stats identical (hp/dmg/speed/accel/decel/view_range/weapon_range)")
	_check(snap_p3_post == snap_p3, "AI operator stats identical")
	_check(snap_p1_post == snap_p1, "human operator stats identical")

	# ── Teardown ────────────────────────────────────────────────────────────
	if session != null:
		for idx: int in range(3):
			session.get_slot(idx + 1).control_mode = saved_modes[idx]
			session.get_slot(idx + 1).team_id = saved_teams[idx]

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
