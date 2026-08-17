# test_camera_pitch.gd
# INTEGRATION TEST for the REAL camera pipeline (Part B/C). Does NOT use the
# TacticalVisionCone as evidence. Exercises the actual Camera3D rotation when
# vertical + horizontal right-stick input is injected at the InputManager
# boundary, in all 8 directions.
#
# Before the fix this test FAILS (camera is frozen at a fixed top-down pitch),
# proving the camera does not respond to vertical aim input. After the fix the
# camera must yaw with the stick X and pitch with the stick Y.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0
var _log: FileAccess = null

func _trace(s: String) -> void:
	print(s)
	if _log != null:
		_log.store_line(s)
		_log.flush()

class StubInput extends InputManager:
	var aim_vec: Vector2 = Vector2.ZERO

	func get_aim_vector(_player_id: int) -> Vector2:
		return aim_vec

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func _init() -> void:
	call_deferred("run")

func _await_frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func _parent_chain(node: Node) -> String:
	var parts: Array[String] = []
	var cur: Node = node
	while cur != null:
		parts.append("%s<%s>" % [cur.name, cur.get_class()])
		cur = cur.get_parent()
	return " -> ".join(parts)

func run() -> void:
	_log = FileAccess.open("user://camera_pitch_progress.log", FileAccess.WRITE)
	_trace("== REAL CAMERA PITCH TEST ==")
	var scene: PackedScene = load("res://scenes/match.tscn") as PackedScene
	if scene == null:
		_trace("[FAIL] cannot load match.tscn")
		quit(1)
		return
	var inst: Node = scene.instantiate()
	inst.set("intro_enabled", false)
	get_root().add_child(inst)
	_trace("match added, awaiting 10 frames")
	await _await_frames(10)
	_trace("frames done, reading wiring")

	var pm: Node = inst.get("player_manager")
	var cam_ctrl: Node = inst.get("camera_controller")
	if pm == null or cam_ctrl == null:
		_trace("[FAIL] match wiring missing")
		quit(1)
		return
	var cam: Node3D = cam_ctrl.get("camera") as Node3D
	if cam == null:
		_trace("[FAIL] CameraController.camera is null")
		quit(1)
		return

	_trace("--- ACTIVE CAMERA (Part C) ---")
	_trace("camera path            : %s" % str(cam.get_path()))
	_trace("parent chain           : %s" % _parent_chain(cam))
	_trace("camera.current         : %s" % str(cam.get("current")))
	_trace("cam local rotation     : %s" % str(cam.get("rotation_degrees")))
	_trace("cam global rotation    : %s" % str(cam.get("global_rotation_degrees")))
	_trace("cam global_transform   : %s" % str(cam.get("global_transform")))
	_trace("controller rotation    : %s" % str(cam_ctrl.get("rotation_degrees")))
	_trace("controller pitch base  : %s" % str(cam_ctrl.get("pitch_angle_degrees")))

	var op2: Node = pm.call("get_operator", 2)
	if op2 == null:
		_trace("[FAIL] P2 not spawned")
		quit(1)
		return
	var gcfg: Node = get_root().get_node_or_null("GameConfig")
	_trace("forcing P2 JOYSTICK slot 1")
	if gcfg != null:
		var prof: Variant = gcfg.call("get_profile", 2)
		if prof != null:
			prof.call("set_device", InputProfile.DeviceKind.JOYSTICK, 1)
	op2.set("is_ai_controlled", false)
	var stub: StubInput = StubInput.new()
	inst.add_child(stub)
	op2.call("set_input_manager", stub)
	if op2.has_method("bind_camera_aim"):
		op2.call("bind_camera_aim", cam_ctrl)
		_trace("P2 bound to camera as aim driver (bind_camera_aim)")
	else:
		_trace("NOTE: OperatorBase has no bind_camera_aim yet (pre-fix state)")
	_trace("stub installed, awaiting 5 frames")
	await _await_frames(5)
	var gx0: float = (cam.get("global_rotation_degrees") as Vector3).x
	var gy0: float = (cam.get("global_rotation_degrees") as Vector3).y
	_trace("initial camera pitch (global x): %.2f deg   yaw (global y): %.2f deg" % [gx0, gy0])

	var stick_dirs: Dictionary = {
		"UP": Vector2(0.0, -1.0),
		"DOWN": Vector2(0.0, 1.0),
		"LEFT": Vector2(-1.0, 0.0),
		"RIGHT": Vector2(1.0, 0.0),
		"UP_RIGHT": Vector2(0.7071, -0.7071),
		"UP_LEFT": Vector2(-0.7071, -0.7071),
		"DOWN_RIGHT": Vector2(0.7071, 0.7071),
		"DOWN_LEFT": Vector2(-0.7071, 0.7071),
	}
	var results: Dictionary = {}

	for label: String in stick_dirs.keys():
		stub.aim_vec = stick_dirs[label] as Vector2
		await _await_frames(60)
		var g: Vector3 = cam.get("global_rotation_degrees") as Vector3
		var c: Vector3 = cam_ctrl.get("rotation_degrees") as Vector3
		results[label] = {"global": g, "ctrl": c, "cam_global_xform": cam.get("global_transform")}
		_trace("  %-11s cam.global_rotation=%s  ctrl.rotation_degrees=%s" % [label, str(g), str(c)])

	# Neutral stick: camera should return to base pitch (yaw holds last aim).
	stub.aim_vec = Vector2.ZERO
	await _await_frames(60)
	var gfinal: Vector3 = cam.get("global_rotation_degrees") as Vector3
	var gfinal_xform: Transform3D = cam.get("global_transform") as Transform3D
	_trace("final (neutral) camera: global_rotation=%s" % str(gfinal))
	_trace("final camera global_transform=%s" % str(gfinal_xform))

	var up: Vector3 = (results["UP"]["global"] as Vector3)
	var down: Vector3 = (results["DOWN"]["global"] as Vector3)
	var left: Vector3 = (results["LEFT"]["global"] as Vector3)
	var right: Vector3 = (results["RIGHT"]["global"] as Vector3)
	var du: float = up.x - gx0
	var dd: float = down.x - gx0

	print("\n--- CAMERA PITCH VERIFICATION (Part B) ---")
	_check(absf(du) > 1.0, "stick UP changes camera pitch (d=%.2f)" % du)
	_check(absf(dd) > 1.0, "stick DOWN changes camera pitch (d=%.2f)" % dd)
	_check(du * dd < 0.0, "UP and DOWN pitch move in opposite directions")
	_check(absf(left.y - gy0) > 1.0, "stick LEFT changes camera yaw (d=%.2f)" % (left.y - gy0))
	_check(absf(right.y - gy0) > 1.0, "stick RIGHT changes camera yaw (d=%.2f)" % (right.y - gy0))
	_check(absf(left.y - right.y) > 1.0, "LEFT and RIGHT yaw differ")

	for label: String in stick_dirs.keys():
		var g: Vector3 = results[label]["global"] as Vector3
		_check((absf(g.x - gx0) > 1.0 or absf(g.y - gy0) > 1.0), "camera responds to %s" % label)

	_check(absf(gfinal.x - gx0) < 1.0, "camera pitch returns to base on neutral stick (d=%.2f)" % (gfinal.x - gx0))

	if _log != null:
		_log.flush()
		_log.close()
	print("\n== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
