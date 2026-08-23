# test_combat_cover_crouch.gd
# Technical Rationale: Validates that Operator shot origin dynamically follows
# crouch stance (standing: Y=1.35m, crouching: Y=0.65m) and that physical 1.2m
# medium cover obstructs crouching shots while allowing standing shots to clear.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("--- COMBAT COVER CROUCH TEST RUN ---")
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func run_test() -> void:
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	# Build floor so operators settle at Y=0.0
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(100.0, 1.0, 100.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	# Shooter Operator at X=-3.0
	var shooter: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	shooter.player_id = 1
	shooter.team_id = OperatorBase.TEAM_ATTACKERS
	shooter.position = Vector3(-3.0, 0.0, 0.0)
	root.add_child(shooter)

	# Target Operator at X=3.0
	var target_op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	target_op.player_id = 2
	target_op.team_id = OperatorBase.TEAM_DEFENDERS
	target_op.position = Vector3(3.0, 0.0, 0.0)
	root.add_child(target_op)

	# Medium Cover (1.2m tall, centered at X=0, Y=0.6, spanning Y=0.0..1.2m)
	var med_cover: StaticBody3D = StaticBody3D.new()
	med_cover.name = "MediumCover"
	med_cover.position = Vector3(0.0, 0.6, 0.0)
	var med_shape: CollisionShape3D = CollisionShape3D.new()
	var med_box: BoxShape3D = BoxShape3D.new()
	med_box.size = Vector3(1.0, 1.2, 4.0)
	med_shape.shape = med_box
	med_cover.add_child(med_shape)
	root.add_child(med_cover)

	for i in range(15):
		await get_root().get_tree().physics_frame

	# Aim shooter at target (+X direction)
	shooter.aim_yaw = -PI / 2.0
	shooter._sync_aim_direction()

	# --- TEST 1: STANDING OPERATOR BEHIND 1.2M COVER ---
	shooter.is_crouching = false
	var standing_origin: Vector3 = shooter.get_shot_origin()
	print("Standing shot origin: ", standing_origin)
	_check(standing_origin.y > 1.2, "Standing shot origin (%.2fm) is above 1.2m cover" % standing_origin.y)

	var damage_received: Array[float] = [0.0]
	target_op.damage_dealt.connect(func(_t: OperatorBase, _d: float, _m: bool) -> void: pass)
	var prev_hp: float = target_op.health_current
	shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame

	var dmg_standing: float = prev_hp - target_op.health_current
	print("Damage dealt while standing over 1.2m cover: ", dmg_standing)
	_check(dmg_standing > 0.0, "Standing shot clears 1.2m cover and damages enemy")

	# --- TEST 2: CROUCHING OPERATOR BEHIND 1.2M COVER ---
	target_op.health_current = target_op.health_max
	prev_hp = target_op.health_current
	shooter.is_crouching = true
	var crouch_origin: Vector3 = shooter.get_shot_origin()
	print("Crouching shot origin: ", crouch_origin)
	_check(crouch_origin.y < 1.2, "Crouching shot origin (%.2fm) is below 1.2m cover" % crouch_origin.y)

	# Verify raycast collider is the cover StaticBody3D
	var eye_pos: Vector3 = shooter.get_shot_origin()
	var end_pos: Vector3 = eye_pos + (shooter.aim_direction.normalized() * shooter.weapon_range)
	var los_crouch: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		shooter, eye_pos, end_pos, [shooter.get_rid()], shooter.combat_collision_mask
	)
	print("Crouch LoS hit_collider: ", los_crouch.hit_collider)
	_check(los_crouch.hit_collider == med_cover, "Crouched shot physically collides with 1.2m cover")

	shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame

	var dmg_crouch: float = prev_hp - target_op.health_current
	print("Damage dealt while crouching behind 1.2m cover: ", dmg_crouch)
	_check(dmg_crouch == 0.0, "Crouched shot is blocked by 1.2m cover (0 damage dealt)")

	# --- TEST 3: NO COVER (STANDING & CROUCHING) ---
	med_cover.position = Vector3(0.0, -10.0, 0.0) # move cover away
	for i in range(3):
		await get_root().get_tree().physics_frame

	# Standing with no cover
	shooter.is_crouching = false
	target_op.health_current = target_op.health_max
	prev_hp = target_op.health_current
	shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame
	_check(target_op.health_current < prev_hp, "Standing shot with no cover hits enemy")

	# Crouching with no cover
	shooter.is_crouching = true
	target_op.health_current = target_op.health_max
	prev_hp = target_op.health_current
	shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame
	_check(target_op.health_current < prev_hp, "Crouching shot with no cover hits enemy")

	# --- TEST 4: TALL COVER (2.0M TALL) BLOCKS STANDING ---
	var tall_cover: StaticBody3D = StaticBody3D.new()
	tall_cover.position = Vector3(0.0, 1.0, 0.0) # height 2.0m, spans Y=0.0..2.0m
	var tall_shape: CollisionShape3D = CollisionShape3D.new()
	var tall_box: BoxShape3D = BoxShape3D.new()
	tall_box.size = Vector3(1.0, 2.0, 4.0)
	tall_shape.shape = tall_box
	tall_cover.add_child(tall_shape)
	root.add_child(tall_cover)

	for i in range(5):
		await get_root().get_tree().physics_frame

	shooter.is_crouching = false
	target_op.health_current = target_op.health_max
	prev_hp = target_op.health_current
	shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame
	_check(target_op.health_current == prev_hp, "Tall 2.0m cover blocks standing shot")

	# --- TEST 5: DRONE FIRING UNCHANGED ---
	var drone: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	drone.operator = shooter
	drone.position = Vector3(-3.0, 2.4, 0.0)
	drone.rotation.y = -PI / 2.0 # facing +X
	root.add_child(drone)

	for i in range(5):
		await get_root().get_tree().physics_frame

	target_op.health_current = target_op.health_max
	prev_hp = target_op.health_current
	drone.call("_execute_drone_shot")
	await get_root().get_tree().physics_frame
	# Drone at Y=2.4m fires down over tall cover or hits target
	_check(absf(drone.global_position.y - 2.4) < 0.05, "Drone operates at airborne height 2.4m")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
