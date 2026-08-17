# test_gamepad_pitch.gd
# Regression test kept under the old filename because earlier camera-pitch work
# lived here. The intended design is now explicit: right-stick X/Y controls the
# operator's planar aim/vision cone only. It must not rotate, pitch, zoom or move
# the shared camera.
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

class StubInput:
	extends InputManager
	var aim_by_player: Dictionary = {}
	var move_by_player: Dictionary = {}

	func _init() -> void:
		for pid: int in [1, 2]:
			var mirror: PlayerInputProfile = PlayerInputProfile.new()
			mirror.player_id = pid
			mirror.device_type = PlayerInputProfile.DeviceType.GAMEPAD
			mirror.is_connected = true
			_profiles[pid] = mirror

	func _initialize_profiles() -> void:
		pass

	func _sync_device_mirrors() -> void:
		pass

	func get_aim_vector(player_id: int) -> Vector2:
		return aim_by_player.get(player_id, Vector2.ZERO) as Vector2

	func get_movement_vector(player_id: int) -> Vector2:
		return move_by_player.get(player_id, Vector2.ZERO) as Vector2

func _make_op(pid: int, stub: StubInput, root: Node3D) -> OperatorBase:
	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = pid
	op.team_id = OperatorBase.TEAM_ATTACKERS
	op.position = Vector3(float(pid) * 2.0, 0.0, 0.0)
	op._input_manager = stub
	root.add_child(op)
	op.set_physics_process(false)
	return op

func _await_frames(n: int) -> void:
	for i in range(n):
		await get_root().get_tree().physics_frame

func _drive_aim(op: OperatorBase, steps: int) -> void:
	for i in range(steps):
		op._update_aim(0.03)
		op._sync_aim_direction()

func run_test() -> void:
	print("== GAMEPAD CHARACTER AIM / CAMERA REGRESSION TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	var stub: StubInput = StubInput.new()
	root.add_child(stub)

	var p1: OperatorBase = _make_op(1, stub, root)
	var p2: OperatorBase = _make_op(2, stub, root)
	await _await_frames(6)

	var cam: CameraController = CameraController.new()
	var cam3d: Camera3D = Camera3D.new()
	cam3d.name = "Camera3D"
	cam.add_child(cam3d)
	root.add_child(cam)
	cam.targets = [p1 as Node3D, p2 as Node3D]
	cam.follow_speed = 0.0
	cam.zoom_speed = 0.0
	await _await_frames(2)

	var base_cam_rotation: Vector3 = cam.rotation_degrees
	var base_cam_position: Vector3 = cam.global_position
	var expected_dirs: Dictionary = {
		"UP": Vector3(0.0, 0.0, -1.0),
		"DOWN": Vector3(0.0, 0.0, 1.0),
		"LEFT": Vector3(-1.0, 0.0, 0.0),
		"RIGHT": Vector3(1.0, 0.0, 0.0),
		"UP_RIGHT": Vector3(0.7071, 0.0, -0.7071),
		"DOWN_RIGHT": Vector3(0.7071, 0.0, 0.7071),
		"DOWN_LEFT": Vector3(-0.7071, 0.0, 0.7071),
		"UP_LEFT": Vector3(-0.7071, 0.0, -0.7071),
	}
	var stick_dirs: Dictionary = {
		"UP": Vector2(0.0, -1.0),
		"DOWN": Vector2(0.0, 1.0),
		"LEFT": Vector2(-1.0, 0.0),
		"RIGHT": Vector2(1.0, 0.0),
		"UP_RIGHT": Vector2(0.7071, -0.7071),
		"DOWN_RIGHT": Vector2(0.7071, 0.7071),
		"DOWN_LEFT": Vector2(-0.7071, 0.7071),
		"UP_LEFT": Vector2(-0.7071, -0.7071),
	}

	for label: String in stick_dirs.keys():
		var stick: Vector2 = stick_dirs[label] as Vector2
		var target_yaw: float = atan2(-stick.x, -stick.y)
		p2.aim_yaw = wrapf(target_yaw + PI, -PI, PI)
		p2._sync_aim_direction()
		stub.aim_by_player[2] = stick
		stub.aim_by_player[1] = Vector2.ZERO
		_drive_aim(p2, 30)
		cam._physics_process(0.03)
		var got: Vector3 = p2.aim_direction.normalized()
		var want: Vector3 = (expected_dirs[label] as Vector3).normalized()
		_check(got.dot(want) > 0.995, "P2 right stick %s -> P2 aim/cone direction %s" % [label, str(want)])
		_check(p1.aim_direction.dot(Vector3(0.0, 0.0, -1.0)) > 0.995, "P1 aim unaffected by P2 right stick %s" % label)
		_check(cam.rotation_degrees.is_equal_approx(base_cam_rotation), "camera rotation unchanged by P2 right stick %s" % label)
		_check(cam.global_position.distance_to(base_cam_position) < 0.01, "camera position unchanged by P2 right stick %s" % label)

	var held_dir: Vector3 = p2.aim_direction
	stub.aim_by_player[2] = Vector2.ZERO
	_drive_aim(p2, 20)
	_check(p2.aim_direction.dot(held_dir.normalized()) > 0.995, "right-stick release holds last P2 aim direction")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
