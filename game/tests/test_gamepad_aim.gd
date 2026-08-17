# test_gamepad_aim.gd
# Technical Rationale: Regression test for the gamepad right-stick AIM + VISION
# CONE system:
#   - The FULL right-stick space (left/right/up/down/diagonals) maps to the
#     authoritative aim direction and the vision cone.
#   - Cone visibility is tied ONLY to right-stick deflection: deflection shows
#     the cone pointing at the stick, returning to deadzone hides it, and LEFT
#     stick movement / R2 / auto-aim never show it by themselves.
#   - R2 is PURE FIRE: with auto-aim OFF it fires along the stick aim and never
#     acquires; with auto-aim ON (STATE B, the "autoaim" action) it acquires only
#     a valid enemy inside the aim cone (respecting range, LoS and cover).
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

## Stubbed InputManager: reports a GAMEPAD device (so the canonical gamepad aim
## wiring engages), plus configurable right-stick aim, left-stick movement, R2
## fire and the auto-aim action.
class StubInput:
	extends InputManager
	var fire_held: bool = false
	var autoaim_held: bool = false
	var aim_vec: Vector2 = Vector2.ZERO
	var move_vec: Vector2 = Vector2.ZERO

	func _init() -> void:
		var mirror: PlayerInputProfile = PlayerInputProfile.new()
		mirror.device_type = PlayerInputProfile.DeviceType.GAMEPAD
		_profiles[1] = mirror

	func _initialize_profiles() -> void:
		pass

	func _sync_device_mirrors() -> void:
		pass

	func is_action_pressed(_player_id: int, action: String) -> bool:
		if action == "fire":
			return fire_held
		if action == "autoaim":
			return autoaim_held
		return false

	func get_aim_vector(_player_id: int) -> Vector2:
		return aim_vec

	func get_movement_vector(_player_id: int) -> Vector2:
		return move_vec

func _make_op(pid: int, team: int, pos: Vector3, root: Node3D, stub: StubInput) -> OperatorBase:
	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = pid
	op.team_id = team
	op.position = pos
	op._input_manager = stub
	root.add_child(op)
	# Deterministic test: no automatic physics stepping on the operators. Every
	# gameplay step below is driven manually, so frame counts are exact.
	op.set_physics_process(false)
	return op

func _await_frames(n: int) -> void:
	for i in range(n):
		await get_root().get_tree().physics_frame

func _strip_drones() -> void:
	for n: Node in get_nodes_in_group("drones"):
		n.queue_free()
	await _await_frames(4)

func _make_cover_wall(center: Vector3, root: Node3D) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 3
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.4, 2.0, 4.0)
	shape.shape = box
	body.add_child(shape)
	body.position = center
	root.add_child(body)
	return body

func run_test() -> void:
	print("== GAMEPAD AIM / VISION CONE TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	var stub: StubInput = StubInput.new()
	root.add_child(stub)

	var player: OperatorBase = _make_op(1, OperatorBase.TEAM_ATTACKERS, Vector3(0.0, 0.0, 0.0), root, stub)
	await _await_frames(8)
	_check(player.weapon != null, "player weapon is the GRAVITY-1 profile")

	# ── [1] Full right-stick aiming space: left / right / up / down / diagonals ──
	print("--- [1] Right-stick full aiming space ---")
	var stick_dirs: Dictionary = {
		"N":  Vector2(0.0, -1.0),
		"NE": Vector2(0.7071, -0.7071),
		"E":  Vector2(1.0, 0.0),
		"SE": Vector2(0.7071, 0.7071),
		"S":  Vector2(0.0, 1.0),
		"SW": Vector2(-0.7071, 0.7071),
		"W":  Vector2(-1.0, 0.0),
		"NW": Vector2(-0.7071, -0.7071),
	}
	var expected_dirs: Dictionary = {
		"N":  Vector3(0.0, 0.0, -1.0),
		"NE": Vector3(0.7071, 0.0, -0.7071),
		"E":  Vector3(1.0, 0.0, 0.0),
		"SE": Vector3(0.7071, 0.0, 0.7071),
		"S":  Vector3(0.0, 0.0, 1.0),
		"SW": Vector3(-0.7071, 0.0, 0.7071),
		"W":  Vector3(-1.0, 0.0, 0.0),
		"NW": Vector3(-0.7071, 0.0, -0.7071),
	}
	for d: String in stick_dirs.keys():
		var s: Vector2 = stick_dirs[d] as Vector2
		var t: float = atan2(-s.x, -s.y)
		# Start from the OPPOSITE facing so every direction produces a visible
		# turn (proves up/down are not accidental no-ops).
		player.aim_yaw = wrapf(t + PI, -PI, PI)
		player._sync_aim_direction()
		stub.aim_vec = s
		for i in range(20):
			player._update_aim(0.03)
		var got: Vector3 = player.aim_direction.normalized()
		var want: Vector3 = (expected_dirs[d] as Vector3).normalized()
		_check(got.dot(want) > 0.995, "stick %-2s -> aim direction %-22s (dot %.3f)" % [d, str(want), got.dot(want)])
	stub.aim_vec = Vector2.ZERO

	# ── [2] Cone visibility is tied to RIGHT-STICK deflection only ──
	print("--- [2] Cone visibility: right-stick deflection only ---")
	# 2a: neutral stick -> cone hidden
	stub.move_vec = Vector2.ZERO
	stub.fire_held = false
	stub.autoaim_held = false
	for i in range(6):
		player._update_precision_aim()
	_check(player._gamepad_cone_blend < 0.01, "neutral right stick -> cone blend is zero (cone hidden)")
	_check(player._tactical_cone == null or not player._tactical_cone.visible,
		"neutral right stick -> tactical cone NOT visible")

	# 2b/2c: deflection shows the cone pointing at the stick; deadzone hides it
	for i in range(12):
		player._update_precision_aim()
	stub.aim_vec = Vector2(1.0, 0.0)
	for i in range(10):
		player._update_precision_aim()
	_check(player._gamepad_cone_blend > 0.5, "right-stick deflection drives the cone blend up")
	_check(player._tactical_cone != null and player._tactical_cone.visible,
		"right-stick deflection -> cone visible")
	stub.aim_vec = Vector2.ZERO
	for i in range(15):
		player._update_precision_aim()
	_check(player._gamepad_cone_blend < 0.01, "right stick back in deadzone -> cone blend returns to zero")
	_check(player._tactical_cone != null and not player._tactical_cone.visible,
		"right stick back in deadzone -> cone NOT left frozen on screen")

	# 2d: every cardinal direction shows the cone pointing exactly that way
	var cardinal: Array = [
		[Vector2(-1.0, 0.0), Vector3(-1.0, 0.0, 0.0), "left"],
		[Vector2(1.0, 0.0), Vector3(1.0, 0.0, 0.0), "right"],
		[Vector2(0.0, -1.0), Vector3(0.0, 0.0, -1.0), "up"],
		[Vector2(0.0, 1.0), Vector3(0.0, 0.0, 1.0), "down"],
	]
	for c: Array in cardinal:
		stub.aim_vec = c[0] as Vector2
		player.aim_yaw = 0.0
		player._sync_aim_direction()
		for i in range(25):
			player._update_aim(0.03)
			player._update_precision_aim()
		var cd: Vector3 = player.aim_direction.normalized()
		_check(cd.dot(c[1] as Vector3) > 0.995,
			"right stick %s -> cone points %-5s (dot %.3f)" % [c[2], c[2], cd.dot(c[1] as Vector3)])
		_check(player._gamepad_cone_blend > 0.01 and player._tactical_cone != null and player._tactical_cone.visible,
			"right stick %s -> cone visible" % c[2])
	stub.aim_vec = Vector2.ZERO
	for i in range(15):
		player._update_precision_aim()

	# 2e: LEFT-stick movement alone never shows the cone
	stub.move_vec = Vector2(1.0, 0.0)
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	for i in range(8):
		player._update_precision_aim()
		player._process_locomotion(stub.move_vec, 0.03)
	_check(player._gamepad_cone_blend < 0.01, "left-stick movement alone does NOT show the cone")
	_check(player._tactical_cone == null or not player._tactical_cone.visible,
		"left-stick movement with neutral right stick keeps the cone hidden")
	stub.move_vec = Vector2.ZERO

	# ── [3] R2 with auto-aim OFF: pure directional fire ──
	print("--- [3] R2 with auto-aim OFF: fires along the right-stick aim ---")
	await _strip_drones()
	var east: OperatorBase = _make_op(2, OperatorBase.TEAM_DEFENDERS, Vector3(6.0, 0.0, 0.0), root, stub)
	var south: OperatorBase = _make_op(3, OperatorBase.TEAM_DEFENDERS, Vector3(0.0, 0.0, 6.0), root, stub)
	await _await_frames(4)
	# The freshly-spawned ESCORT drones would block the hitscan ray (they hover
	# in front of their operator) and would be auto-acquired as the nearest
	# enemy. This test targets OPERATOR auto-aim, so every escort drone is
	# stripped before the fire/acquisition sections (operators never respawn a
	# drone while their flag stays set, so the rest of the test is drone-free).
	await _strip_drones()
	var east_max: float = east.health_max
	var south_max: float = south.health_max

	player.aim_yaw = 0.0
	player._sync_aim_direction()
	stub.aim_vec = Vector2(1.0, 0.0)   # point EAST with the right stick
	stub.fire_held = true
	stub.autoaim_held = false
	# The gamepad branch lerps with the REAL physics delta (1/60 in headless),
	# so the aim needs enough frames to fully converge onto the target bearing
	# before the shot — a partially-converged aim would miss the capsule at 6m.
	for i in range(40):
		player._update_autoaim()
		player._update_aim(0.03)
	_check(player._aim_source != OperatorBase.AimSource.AUTO_AIM,
		"R2 alone does NOT enter the AUTO_AIM channel (normal directional fire)")
	_check(player._autoaim_target == null, "R2 alone does NOT auto-acquire an enemy")
	_check(absf(wrapf(player.aim_yaw - (-PI * 0.5), -PI, PI)) < 0.2,
		"R2 directional fire: aim follows the right-stick direction")
	if player.weapon != null:
		var ammo_before: int = player.weapon.magazine.current_rounds
		if player.weapon.try_consume_round():
			player._execute_tactical_shot()
		_check(player.weapon.magazine.current_rounds == ammo_before - 1, "R2 fired exactly one round")
		_check(east.health_current < east_max, "R2 directional fire hit the enemy the stick was pointing at (east)")
		_check(absf(south.health_current - south_max) < 0.01,
			"R2 directional fire did NOT hit the enemy NOT in the aim line (south)")



	# ── [4] Auto-aim ON (STATE B): cone-constrained acquisition ──
	print("--- [4] Auto-aim ON: cone-constrained target acquisition ---")
	# 4a: valid enemy INSIDE the cone -> acquired, steered at and fired on
	player.aim_yaw = 0.0
	player._sync_aim_direction()
	stub.aim_vec = Vector2(1.0, 0.0)   # cone faces EAST
	stub.autoaim_held = true
	stub.fire_held = true
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._autoaim_target = null
	east.health_current = east_max
	south.health_current = south_max
	for i in range(20):
		player._update_autoaim()
		player._update_aim(0.03)
	_check(player._aim_source == OperatorBase.AimSource.AUTO_AIM,
		"auto-aim action held enters the AUTO_AIM channel (STATE B)")
	_check(player._autoaim_target == east, "auto-aim ON: in-cone enemy is acquired")
	var to_east: Vector3 = (east.global_position - player.global_position)
	to_east.y = 0.0
	var east_yaw: float = atan2(-to_east.x, -to_east.z)
	_check(absf(wrapf(player.aim_yaw - east_yaw, -PI, PI)) < 0.15, "aim steers onto the acquired enemy")
	if player.weapon != null:
		var ab: int = player.weapon.magazine.current_rounds
		if player.weapon.try_consume_round():
			player._execute_tactical_shot()
		_check(player.weapon.magazine.current_rounds == ab - 1, "R2 fired one round at the lock")
		_check(east.health_current < east_max, "R2 with auto-aim damaged the acquired enemy")
		_check(absf(south.health_current - south_max) < 0.01,
			"R2 with auto-aim did NOT hit the enemy outside the cone")

	# 4b: enemy OUTSIDE the cone (but in range) -> NOT acquired
	east.position = Vector3(40.0, 0.0, 0.0)   # out of range
	player.aim_yaw = 0.0
	player._sync_aim_direction()
	stub.aim_vec = Vector2(1.0, 0.0)   # cone faces EAST; the only in-range enemy is SOUTH
	stub.autoaim_held = true
	stub.fire_held = false
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._autoaim_target = null
	for i in range(20):
		player._update_autoaim()
		player._update_aim(0.03)
	_check(player._autoaim_target == null, "auto-aim ON: enemy OUTSIDE the cone is NOT acquired")

	# 4c: enemy INSIDE the cone but behind cover -> NOT acquired
	var wall: StaticBody3D = _make_cover_wall(Vector3(3.0, 1.0, 0.0), root)
	await _await_frames(2)
	east.position = Vector3(6.0, 0.0, 0.0)   # in range + in cone, but walled off
	east.health_current = east_max
	player.aim_yaw = 0.0
	player._sync_aim_direction()
	stub.aim_vec = Vector2(1.0, 0.0)
	stub.autoaim_held = true
	stub.fire_held = false
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._autoaim_target = null
	for i in range(20):
		player._update_autoaim()
		player._update_aim(0.03)
	_check(player._autoaim_target == null, "auto-aim ON: enemy BEHIND COVER is NOT acquired")
	root.remove_child(wall)
	wall.queue_free()

	# 4d: no valid target -> normal directional firing is preserved
	player.aim_yaw = 0.0
	player._sync_aim_direction()
	stub.aim_vec = Vector2(1.0, 0.0)   # aim EAST
	stub.autoaim_held = true
	stub.fire_held = true
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._autoaim_target = null
	east.position = Vector3(40.0, 0.0, 0.0)   # nothing valid along the aim
	east.health_current = east_max
	south.health_current = south_max
	for i in range(20):
		player._update_autoaim()
		player._update_aim(0.03)
	_check(player._autoaim_target == null, "auto-aim ON with NO valid target -> no lock")
	_check(absf(wrapf(player.aim_yaw - (-PI * 0.5), -PI, PI)) < 0.2,
		"auto-aim ON with no target: aim keeps following the right stick")
	if player.weapon != null:
		var ab2: int = player.weapon.magazine.current_rounds
		if player.weapon.try_consume_round():
			player._execute_tactical_shot()
		_check(player.weapon.magazine.current_rounds == ab2 - 1, "auto-aim ON with no target: R2 still fired")
		_check(absf(south.health_current - south_max) < 0.01,
			"auto-aim ON with no target: shot went along the stick (south enemy NOT hit)")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
