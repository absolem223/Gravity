# test_gamepad_cone_trace.gd
# DIAGNOSTIC TRACE (no gameplay changes): traces the FULL chain from the
# physical right stick down to the ACTUAL rendered TacticalVisionCone node of
# the real match scene, and reports exactly which stage stops carrying the aim.
#
#   Physical pad -> InputManager.get_aim_vector() -> OperatorBase._update_aim
#   -> aim_yaw/aim_direction -> _update_precision_aim -> update_cone() ->
#   procedural TacticalVisionCone mesh -> what the player sees.
#
# Section A: real input plumbing snapshot (P2 profile, resolved device, raw
# axis report). This is a LIVE check when a gamepad is physically connected:
# it exposes a wrong/absent right-stick axis mapping (Case B) or a pad Godot
# never detected (Case A).
# Section B: deterministic full-loop trace with an injected right-stick vector
# at the InputManager boundary (no pad needed). It drives the real operator
# _physics_process and reads the REAL cone node's procedural mesh to verify the
# visible cone actually points where the aim says (Cases C/D).
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

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

var _log: FileAccess = null

func _init() -> void:
	call_deferred("run")

func _trace(s: String) -> void:
	print(s)
	if _log != null:
		_log.store_line(s)
		_log.flush()

func _game_config() -> Node:
	return get_root().get_node_or_null("GameConfig")

## Computes the direction the procedural cone mesh actually points at, in world
## space. The fan's arc vertices lie EXACTLY on their ray directions from the
## apex (wall hits shorten distances, never change angles), and the center ray
## (i=0) is aimed at exactly `expected` by construction. So the vertex whose
## signed angle from `expected` is smallest IS the drawn center ray — this is
## exact regardless of arena walls/covers. Returns Vector3.INF when no mesh.
func _mesh_drawn_dir(op: Node, cone: Node, expected: Vector3) -> Vector3:
	if cone == null or not is_instance_valid(cone):
		return Vector3.INF
	var mesh: Mesh = cone.get("mesh")
	if mesh == null or mesh.get_surface_count() < 1:
		return Vector3.INF
	var arrays: Array = mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
	if verts.is_empty():
		return Vector3.INF
	var op_pos: Vector3 = (op as Node3D).global_position
	var xf: Transform3D = (cone as Node3D).global_transform
	var best_err: float = 1.0
	var best_dir: Vector3 = Vector3.INF
	for i: int in range(verts.size()):
		var rel: Vector3 = xf * verts[i] - op_pos
		rel.y = 0.0
		if rel.length() < 0.3:
			continue
		var dir: Vector3 = rel.normalized()
		var err: float = absf(atan2(expected.cross(dir).y, expected.dot(dir)))
		if err < best_err:
			best_err = err
			best_dir = dir
	return best_dir

func _await_frames(n: int) -> void:
	for i in range(n):
		await physics_frame

func run() -> void:
	_log = FileAccess.open("user://cone_trace_progress.log", FileAccess.WRITE)
	_trace("== P2 GAMEPAD VISION-CONE FULL-CHAIN TRACE ==")
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
	var real_im: Node = inst.get("input_manager")
	if pm == null or cam_ctrl == null or real_im == null:
		_trace("[FAIL] match wiring missing: pm=%s cam=%s im=%s" % [str(pm), str(cam_ctrl), str(real_im)])
		quit(1)
		return

	var op2: Node = pm.call("get_operator", 2)
	if op2 == null:
		_trace("[FAIL] P2 operator not spawned")
		quit(1)
		return
	_trace("P2 operator: %s  is_ai_controlled=%s" % [str(op2.get_path()), str(op2.get("is_ai_controlled"))])

	var gcfg: Node = _game_config()
	_trace("game_config found: %s" % str(gcfg))
	_trace("calling get_profile(2)...")
	var prof: Variant = gcfg.call("get_profile", 2) if gcfg != null else null
	_trace("get_profile(2) returned: %s" % str(prof))
	_trace("calling Input.get_connected_joypads()...")
	var pads: Array = Input.get_connected_joypads()
	_trace("joypads enumerated")
	_trace("--- SECTION A: REAL INPUT PLUMBING SNAPSHOT ---")
	_trace("connected joypads (OS): %s" % str(pads))
	if prof != null:
		_trace("P2 profile device_kind: %s  joystick_index: %s" % [str(prof.get("device_kind")), str(prof.get("joystick_index"))])
		_trace("P2 resolved device id: %s" % str(prof.call("get_joy_device_id")))
		_trace("P2 device label: %s" % str(prof.call("get_device_label")))
		var ev_r: Array = prof.call("get_events", "aim_right")
		var ev_d: Array = prof.call("get_events", "aim_down")
		var rx_axis: int = 2
		var ry_axis: int = 3
		if not ev_r.is_empty() and (ev_r[0] as InputEvent).is_class("InputEventJoypadMotion"):
			rx_axis = int((ev_r[0] as InputEventJoypadMotion).axis)
		if not ev_d.is_empty() and (ev_d[0] as InputEvent).is_class("InputEventJoypadMotion"):
			ry_axis = int((ev_d[0] as InputEventJoypadMotion).axis)
		_trace("resolved right-stick axes (from bindings): rx_axis=%d ry_axis=%d" % [rx_axis, ry_axis])
		var dev: int = int(prof.call("get_joy_device_id"))
		if dev >= 0:
			_trace("RAW JOYSTICK AXIS REPORT for device %d ('%s'):" % [dev, Input.get_joy_name(dev)])
			for a: int in range(7):
				_trace("  axis %d = %.3f" % [a, Input.get_joy_axis(dev, a)])
			_trace("  -> right stick X (axis %d) = %.3f" % [rx_axis, Input.get_joy_axis(dev, rx_axis)])
			_trace("  -> right stick Y (axis %d) = %.3f" % [ry_axis, Input.get_joy_axis(dev, ry_axis)])
		else:
			_trace("NO PAD RESOLVED (dev=-1) -> get_aim_vector() takes the keyboard fallback and returns ZERO.")
			_trace("  CASE A CANDIDATE: input never reaches the operator because no pad is detected for slot 1.")
	_trace("real InputManager.get_aim_vector(2): %s" % str(real_im.call("get_aim_vector", 2)))
	_trace("op2.is_gamepad_input() (real): %s" % str(op2.call("is_gamepad_input")))

	# Force a deterministic human-gamepad setup for Section B (does not depend
	# on persisted config / pad presence). Documented: P2 = JOYSTICK slot 1.
	if prof != null:
		prof.call("set_device", InputProfile.DeviceKind.JOYSTICK, 1)
	op2.set("is_ai_controlled", false)

	var stub: StubInput = StubInput.new()
	inst.add_child(stub)
	op2.call("set_input_manager", stub)
	_trace("stub installed, awaiting 5 frames")
	await _await_frames(5)

	_trace("--- SECTION B: OPERATOR -> RENDERED CONE LOOP (injected right stick) ---")
	var cam_base: Vector3 = (cam_ctrl as Node).get("rotation_degrees") as Vector3
	_trace("camera rotation_degrees at start: %s" % str(cam_base))

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
		stub.aim_vec = stick
		await _await_frames(60)

		var aim_dir: Vector3 = (op2.get("aim_direction") as Vector3).normalized()
		var target_yaw: float = atan2(-stick.x, -stick.y)
		var want: Vector3 = Vector3(-sin(target_yaw), 0.0, -cos(target_yaw))

		var cone: Node = op2.get_node_or_null("TacticalVisionCone")
		var cone_path: String = str(cone.get_path()) if cone != null else "<none>"
		var cone_visible: bool = bool(cone.get("visible")) if cone != null else false
		var cone_rot: Vector3 = (cone as Node3D).get("rotation_degrees") as Vector3 if cone != null else Vector3.INF
		var drawn_dir: Vector3 = _mesh_drawn_dir(op2, cone, want)
		var drawn_yaw: float = atan2(-drawn_dir.x, -drawn_dir.z) if drawn_dir.is_finite() else NAN

		_trace("  %-11s stick=%s  aim_yaw=%.1f deg" % [label, str(stick), rad_to_deg(op2.get("aim_yaw"))])
		_trace("    op.aim_direction       : %s" % str(aim_dir))
		_trace("    expected direction     : %s" % str(want))
		_trace("    cone path              : %s" % cone_path)
		_trace("    cone visible           : %s  cone.rotation_degrees: %s" % [str(cone_visible), str(cone_rot)])
		_trace("    drawn mesh direction   : %s" % (str(drawn_dir) if drawn_dir.is_finite() else "<no mesh>"))
		_trace("    drawn mesh center (yaw): %s" % (("%.1f deg" % rad_to_deg(drawn_yaw)) if not is_nan(drawn_yaw) else "<no mesh>"))

		_check(aim_dir.dot(want) > 0.995, "P2 aim_direction == expected for %s" % label)
		if cone != null and cone_visible:
			if drawn_dir.is_finite():
				_check(drawn_dir.dot(want) > 0.999, "RENDERED cone mesh points at expected for %s" % label)
				_check(drawn_dir.dot(aim_dir) > 0.999, "RENDERED cone mesh == operator aim_direction for %s" % label)
			else:
				_check(false, "RENDERED cone mesh readable for %s (mesh missing/empty)" % label)
		else:
			_check(false, "cone visible for %s (cone=%s visible=%s)" % [label, str(cone), cone_visible])
		var cam_rot: Vector3 = (cam_ctrl as Node).get("rotation_degrees") as Vector3
		var cam_dy: float = fposmod(cam_rot.y - cam_base.y + 180.0, 360.0) - 180.0
		var cam_moved: bool = absf(cam_rot.x - cam_base.x) > 0.5 or absf(cam_dy) > 0.5
		_check(cam_moved, "camera rotation driven by %s (dPitch=%.2f dYaw=%.2f)" % [label, cam_rot.x - cam_base.x, cam_dy])

	# Release stick: aim direction must hold the last deflection.
	_trace("--- STICK RELEASE ---")
	stub.aim_vec = Vector2.ZERO
	await _await_frames(20)
	var held: Vector3 = (op2.get("aim_direction") as Vector3).normalized()
	var last_stick: Vector2 = stick_dirs["UP_LEFT"] as Vector2
	var last_want: Vector3 = Vector3(-sin(atan2(-last_stick.x, -last_stick.y)), 0.0, -cos(atan2(-last_stick.x, -last_stick.y)))
	_trace("held aim_direction after release: %s" % str(held))
	_check(held.dot(last_want) > 0.995, "right-stick release holds last P2 aim direction")

	# Scan for every cone node in the match to prove there is only ONE writer
	# surface: each operator's own TacticalVisionCone (no competing overlay).
	_trace("--- TREE SCAN: all TacticalVisionCone nodes ---")
	var cones: Array = inst.find_children("TacticalVisionCone", "MeshInstance3D", true, false)
	for c: Node in cones:
		_trace("  %s  parent=%s  visible=%s" % [str(c.get_path()), str(c.get_parent().name), str(c.get("visible"))])

	var total: int = _pass_count + _fail_count
	_trace("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	if _log != null:
		_log.flush()
		_log.close()
	quit(1 if _fail_count > 0 else 0)
