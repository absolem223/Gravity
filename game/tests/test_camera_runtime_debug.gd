# test_camera_runtime_debug.gd
extends SceneTree

class StubInput extends InputManager:
	var aim_vec: Vector2 = Vector2.ZERO
	func _init() -> void:
		# Setup profiles so _is_using_gamepad works
		var mirror: PlayerInputProfile = PlayerInputProfile.new()
		mirror.player_id = 1
		mirror.device_type = PlayerInputProfile.DeviceType.GAMEPAD
		mirror.is_connected = true
		_profiles[1] = mirror
	func get_aim_vector(_pid: int) -> Vector2:
		return aim_vec
	func _initialize_profiles() -> void: pass
	func _sync_device_mirrors() -> void: pass

func _init() -> void:
	call_deferred("run")

func run() -> void:
	print("== START RUNTIME CAMERA DEBUG ==")
	var scene: PackedScene = load("res://scenes/sandbox_test_scene.tscn") as PackedScene
	if not scene:
		print("Failed to load sandbox scene")
		quit(1)
		return
		
	var inst: Node3D = scene.instantiate() as Node3D
	get_root().add_child(inst)
	
	# Wait a few frames for initialization
	for i in range(5):
		await physics_frame
		
	var player_mgr: PlayerManager = inst.get_node_or_null("PlayerManager") as PlayerManager
	var cam_ctrl: CameraController = inst.get_node_or_null("CameraController") as CameraController
	
	if not player_mgr or not cam_ctrl:
		print("Failed to find PlayerManager or CameraController. mgr=%s, ctrl=%s" % [str(player_mgr), str(cam_ctrl)])
		quit(1)
		return
		
	var ops: Array[OperatorBase] = player_mgr.get_all_operators()
	if ops.is_empty():
		print("No operators spawned!")
		quit(1)
		return
		
	var op: OperatorBase = ops[0]
	
	# Force-set the device kind to JOYSTICK in GameConfig for player 1
	var game_config: Node = get_root().get_node_or_null("GameConfig")
	if game_config:
		var profile: InputProfile = game_config.call("get_profile", op.player_id) as InputProfile
		if profile:
			profile.set_device(InputProfile.DeviceKind.JOYSTICK, 1) # JOYSTICK, slot 1
			
	var stub: StubInput = StubInput.new()
	inst.add_child(stub)
	op._input_manager = stub
	
	print("\n--- TEST AIM UP (0.0, -1.0) ---")
	stub.aim_vec = Vector2(0.0, -1.0) # STICK UP
	for i in range(30):
		await physics_frame
	print("After stick UP:")
	print("  op.aim_yaw: %.4f (deg: %.1f)" % [op.aim_yaw, rad_to_deg(op.aim_yaw)])
	print("  op.aim_direction: %s" % str(op.aim_direction))
	print("  cam_ctrl.rotation_degrees: %s" % str(cam_ctrl.rotation_degrees))
	print("  camera.global_transform.basis.get_euler(): %s" % str(cam_ctrl.camera.global_transform.basis.get_euler()))
	
	print("\n--- TEST AIM DOWN (0.0, 1.0) ---")
	stub.aim_vec = Vector2(0.0, 1.0) # STICK DOWN
	for i in range(30):
		await physics_frame
	print("After stick DOWN:")
	print("  op.aim_yaw: %.4f (deg: %.1f)" % [op.aim_yaw, rad_to_deg(op.aim_yaw)])
	print("  op.aim_direction: %s" % str(op.aim_direction))
	print("  cam_ctrl.rotation_degrees: %s" % str(cam_ctrl.rotation_degrees))
	print("  camera.global_transform.basis.get_euler(): %s" % str(cam_ctrl.camera.global_transform.basis.get_euler()))
	
	print("\n--- TEST AIM LEFT (-1.0, 0.0) ---")
	stub.aim_vec = Vector2(-1.0, 0.0) # STICK LEFT
	for i in range(30):
		await physics_frame
	print("After stick LEFT:")
	print("  op.aim_yaw: %.4f (deg: %.1f)" % [op.aim_yaw, rad_to_deg(op.aim_yaw)])
	print("  op.aim_direction: %s" % str(op.aim_direction))
	print("  cam_ctrl.rotation_degrees: %s" % str(cam_ctrl.rotation_degrees))
	print("  camera.global_transform.basis.get_euler(): %s" % str(cam_ctrl.camera.global_transform.basis.get_euler()))
	
	print("\n--- TEST AIM RIGHT (1.0, 0.0) ---")
	stub.aim_vec = Vector2(1.0, 0.0) # STICK RIGHT
	for i in range(30):
		await physics_frame
	print("After stick RIGHT:")
	print("  op.aim_yaw: %.4f (deg: %.1f)" % [op.aim_yaw, rad_to_deg(op.aim_yaw)])
	print("  op.aim_direction: %s" % str(op.aim_direction))
	print("  cam_ctrl.rotation_degrees: %s" % str(cam_ctrl.rotation_degrees))
	print("  camera.global_transform.basis.get_euler(): %s" % str(cam_ctrl.camera.global_transform.basis.get_euler()))
	
	# Let's clean up
	inst.queue_free()
	quit(0)
