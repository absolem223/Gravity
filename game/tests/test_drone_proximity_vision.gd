# test_drone_proximity_vision.gd
# Regression test: an airborne drone (Y=2.4m) must NOT lose vision of a
# ground-level enemy at close proximity. Tests the fix for the bug where
# steep-angle LoS rays hit the top of the operator capsule, causing
# the distance-based visibility heuristic to reject the target.
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
	print("== DRONE PROXIMITY VISION TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	# Build a floor so operators don't sink
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(100.0, 1.0, 100.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	# Enemy operator at the origin
	var enemy_op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	enemy_op.player_id = 2
	enemy_op.team_id = OperatorBase.TEAM_DEFENDERS
	enemy_op.is_ai_controlled = true
	enemy_op.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(enemy_op)

	# Drone facing -Z (toward enemy) at airborne height
	var drone: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	drone.position = Vector3(0.0, 2.4, 15.0)
	drone.rotation.y = 0.0
	root.add_child(drone)

	for i in range(20):
		await get_root().get_tree().physics_frame

	var vc: Node = drone.get_node_or_null("VisionCone3D")
	if vc == null:
		print("  [FAIL] drone has no VisionCone3D child")
		_fail_count += 1
		root.queue_free()
		print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
		quit(1)
		return

	print("--- [1] Medium range ---")
	drone.position = Vector3(0.0, 2.4, 15.0)
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc.call("_perform_vision_scan")
	_check(vc.call("is_target_visible", enemy_op) == true, "Drone detects enemy at 15m")

	print("--- [2] Near max range ---")
	drone.position = Vector3(0.0, 2.4, 23.0)
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc.call("_perform_vision_scan")
	_check(vc.call("is_target_visible", enemy_op) == true, "Drone detects enemy at 23m (within 24m)")

	print("--- [3] Beyond max range ---")
	drone.position = Vector3(0.0, 2.4, 26.0)
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc.call("_perform_vision_scan")
	_check(vc.call("is_target_visible", enemy_op) == false, "Drone does NOT detect enemy at 26m (beyond 24m)")

	print("--- [4] Close proximity (bug regression) ---")
	var close_dists: Array[float] = [5.0, 3.0, 2.0, 1.0, 0.5]
	for d: float in close_dists:
		drone.position = Vector3(0.0, 2.4, d)
		for j in range(3):
			await get_root().get_tree().physics_frame
		vc.call("_perform_vision_scan")
		var detected: bool = vc.call("is_target_visible", enemy_op) as bool
		_check(detected, "Drone sees enemy at close range %.1fm (Y=2.4m)" % d)

	print("--- [5] Directly above ---")
	drone.position = Vector3(0.0, 2.4, 0.0)
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc.call("_perform_vision_scan")
	_check(vc.call("is_target_visible", enemy_op) as bool, "Drone sees enemy directly below it")

	print("--- [6] Facing away (FOV rejection) ---")
	drone.position = Vector3(0.0, 2.4, 5.0)
	drone.rotation.y = PI
	for i in range(3):
		await get_root().get_tree().physics_frame
	vc.call("_perform_vision_scan")
	_check(vc.call("is_target_visible", enemy_op) == false, "Drone does NOT detect enemy behind it")

	print("--- [7] Cover blocks LoS ---")
	drone.rotation.y = 0.0
	drone.position = Vector3(0.0, 2.4, 8.0)
	var cover: StaticBody3D = StaticBody3D.new()
	cover.position = Vector3(0.0, 1.5, 4.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(10.0, 4.0, 1.0)
	shape.shape = box
	cover.add_child(shape)
	root.add_child(cover)
	for i in range(5):
		await get_root().get_tree().physics_frame
	vc.call("_perform_vision_scan")
	_check(vc.call("is_target_visible", enemy_op) == false, "Cover blocks drone line of sight")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
