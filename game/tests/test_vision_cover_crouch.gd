# test_vision_cover_crouch.gd
# Technical Rationale: Validates that Operator vision origin dynamically follows
# crouch stance (standing: Y=1.35m, crouching: Y=0.65m) and that physical 1.2m
# medium cover obstructs crouching vision while allowing standing vision to clear.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("--- VISION COVER CROUCH TEST RUN ---")
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

	# Observer Operator at X=-3.0, facing +X (yaw = -PI/2)
	var observer: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	observer.player_id = 1
	observer.team_id = OperatorBase.TEAM_ATTACKERS
	observer.position = Vector3(-3.0, 0.0, 0.0)
	observer.rotation.y = -PI / 2.0
	root.add_child(observer)

	# Enemy Operator at X=3.0
	var enemy_op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	enemy_op.player_id = 2
	enemy_op.team_id = OperatorBase.TEAM_DEFENDERS
	enemy_op.is_ai_controlled = true
	enemy_op.position = Vector3(3.0, 0.0, 0.0)
	root.add_child(enemy_op)

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

	var vc: VisionCone3D = observer.vision_cone
	_check(vc != null, "Observer has VisionCone3D component")

	# --- TEST 1: STANDING OPERATOR BEHIND 1.2M COVER ---
	observer.is_crouching = false
	observer._update_crouch_visual()
	var standing_origin: Vector3 = observer.get_vision_origin()
	print("Standing vision origin: ", standing_origin)
	_check(standing_origin.y > 1.2, "Standing vision origin (%.2fm) is above 1.2m cover" % standing_origin.y)
	_check(absf(vc.global_position.y - 1.35) < 0.05, "VisionCone3D global_position.y is at 1.35m when standing")

	for i in range(3):
		await get_root().get_tree().physics_frame
	vc._perform_vision_scan()
	var standing_visible: bool = vc.is_target_visible(enemy_op)
	print("Enemy visible to standing operator over 1.2m cover: ", standing_visible)
	_check(standing_visible == true, "Standing operator sees enemy over 1.2m cover")

	# --- TEST 2: CROUCHING OPERATOR BEHIND 1.2M COVER ---
	observer.is_crouching = true
	observer._update_crouch_visual()
	var crouch_origin: Vector3 = observer.get_vision_origin()
	print("Crouching vision origin: ", crouch_origin)
	_check(crouch_origin.y < 1.2, "Crouching vision origin (%.2fm) is below 1.2m cover" % crouch_origin.y)
	_check(absf(vc.global_position.y - 0.65) < 0.05, "VisionCone3D global_position.y is at 0.65m when crouching")

	for i in range(3):
		await get_root().get_tree().physics_frame
	vc._perform_vision_scan()
	var crouch_visible: bool = vc.is_target_visible(enemy_op)
	print("Enemy visible to crouching operator behind 1.2m cover: ", crouch_visible)
	_check(crouch_visible == false, "Crouching operator vision is physically occluded by 1.2m cover")

	# --- TEST 3: CROUCHING OPERATOR WITH CLEAR LINE OF SIGHT (NO COVER) ---
	med_cover.position = Vector3(0.0, -10.0, 0.0) # move cover away
	for i in range(3):
		await get_root().get_tree().physics_frame

	observer.is_crouching = true
	observer._update_crouch_visual()
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc._perform_vision_scan()
	_check(vc.is_target_visible(enemy_op) == true, "Crouching operator sees enemy with clear line of sight (no cover)")

	# --- TEST 4: STANDING OPERATOR WITH NO COVER ---
	observer.is_crouching = false
	observer._update_crouch_visual()
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc._perform_vision_scan()
	_check(vc.is_target_visible(enemy_op) == true, "Standing operator sees enemy with clear line of sight (no cover)")

	# --- TEST 5: TALL COVER (2.0M TALL) BLOCKS BOTH STANDING AND CROUCHING ---
	var tall_cover: StaticBody3D = StaticBody3D.new()
	tall_cover.position = Vector3(0.0, 1.0, 0.0) # height 2.0m
	var tall_shape: CollisionShape3D = CollisionShape3D.new()
	var tall_box: BoxShape3D = BoxShape3D.new()
	tall_box.size = Vector3(1.0, 2.0, 4.0)
	tall_shape.shape = tall_box
	tall_cover.add_child(tall_shape)
	root.add_child(tall_cover)

	for i in range(5):
		await get_root().get_tree().physics_frame

	# Standing with tall cover
	observer.is_crouching = false
	observer._update_crouch_visual()
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc._perform_vision_scan()
	_check(vc.is_target_visible(enemy_op) == false, "Tall 2.0m cover blocks standing operator vision")

	# Crouching with tall cover
	observer.is_crouching = true
	observer._update_crouch_visual()
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc._perform_vision_scan()
	_check(vc.is_target_visible(enemy_op) == false, "Tall 2.0m cover blocks crouching operator vision")

	# --- TEST 6: ANGLED VISION AROUND COVER WHILE CROUCHED ---
	# Move enemy to Z=5.0 so line-of-sight from observer (-3, 0.65, 0) to enemy (3, 1.35, 5) crosses X=0 at Z=2.5, clearing tall cover (Z in [-2, 2])
	enemy_op.position = Vector3(3.0, 0.0, 5.0)
	for i in range(5):
		await get_root().get_tree().physics_frame
	vc._perform_vision_scan()
	_check(vc.is_target_visible(enemy_op) == true, "Crouching operator sees enemy angled around cover edge")

	# --- TEST 7: DRONE VISION UNCHANGED ---
	var drone: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	drone.operator = observer
	drone.position = Vector3(-3.0, 2.4, 0.0)
	drone.rotation.y = -PI / 2.0 # facing +X
	root.add_child(drone)

	for i in range(5):
		await get_root().get_tree().physics_frame

	var drone_vc: VisionCone3D = drone.vision_cone
	_check(drone_vc != null, "Drone has VisionCone3D")
	_check(drone_vc.view_range == 24.0, "Drone view_range is 24.0m")
	_check(absf(drone.global_position.y - 2.4) < 0.05, "Drone operates at airborne height 2.4m")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
