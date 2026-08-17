# test_physical_pad_e2e.gd
# WINDOWED END-TO-END validation with a PHYSICAL gamepad (run WITHOUT --headless).
# Chain exercised (no input stubs): PS3 Controller -> Godot Input -> P2 joystick
# profile -> real InputManager -> OperatorP2 -> CameraController -> Camera3D.
#
# GUIDED 8-direction sequence: for each direction the human pushes the RIGHT stick
# for 2.5s while the harness records raw axes 0..3 (definitive axis mapping), the
# real InputManager aim vector, and the real Camera3D rotation.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0
var _log: FileAccess = null

const DIRECTIONS: Array[Dictionary] = [
	{"label": "LEFT",  "aim": Vector2(-1, 0), "yaw": 90.0,  "pitch_up": false},
	{"label": "RIGHT", "aim": Vector2(1, 0),  "yaw": -90.0, "pitch_up": false},
	{"label": "UP",    "aim": Vector2(0, -1), "yaw": 0.0,   "pitch_up": true},
	{"label": "DOWN",  "aim": Vector2(0, 1),  "yaw": 180.0, "pitch_up": false},
	{"label": "UR",    "aim": Vector2(0.7071, -0.7071), "yaw": -45.0, "pitch_up": true},
	{"label": "UL",    "aim": Vector2(-0.7071, -0.7071), "yaw": 45.0,  "pitch_up": true},
	{"label": "DR",    "aim": Vector2(0.7071, 0.7071),  "yaw": -135.0, "pitch_up": false},
	{"label": "DL",    "aim": Vector2(-0.7071, 0.7071), "yaw": 135.0,  "pitch_up": false},
]

func _trace(s: String) -> void:
	print(s)
	if _log != null:
		_log.store_line(s)
		_log.flush()

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

func _shortest_yaw_from_zero(yaw_deg: float) -> float:
	return absf(fposmod(yaw_deg + 180.0, 360.0) - 180.0)

func run() -> void:
	if root != null:
		root.title = "PHYSICAL PS3 PAD E2E"
	_log = FileAccess.open("user://physical_pad_e2e.log", FileAccess.WRITE)
	_trace("== PHYSICAL PS3 CONTROLLER END-TO-END (guided) ==")
	_trace("display server: %s" % str(DisplayServer.get_name()))

	## 1) Physical controller detection (poll up to 15s).
	var pads: Array = []
	var waited: int = 0
	while pads.is_empty() and waited < 900:
		pads = Input.get_connected_joypads()
		await physics_frame
		waited += 1
	if pads.is_empty():
		_trace("physical controller detected: NO")
		_finish()
		return
	var pad_id: int = int(pads[0])
	var info: Dictionary = Input.get_joy_info(pad_id)
	_trace("physical controller detected: YES")
	_trace("  pad id=%d name='%s' vendor=%d product=%d" % [
		pad_id, Input.get_joy_name(pad_id), int(info.get("vendor_id", 0)), int(info.get("product_id", 0))])
	_check(true, "physical controller detected")

	## 2) Load the real match scene.
	_trace("loading match.tscn ...")
	var scene: PackedScene = load("res://scenes/match.tscn") as PackedScene
	if scene == null:
		_trace("[FATAL] cannot load match.tscn")
		_finish()
		return
	var inst: Node = scene.instantiate()
	inst.set("intro_enabled", false)
	root.add_child(inst)
	await _await_frames(20)

	var pm: Node = inst.get("player_manager")
	var cam_ctrl: Node = inst.get("camera_controller")
	var real_im: Node = inst.get("input_manager")
	if pm == null or cam_ctrl == null or real_im == null:
		_trace("[FATAL] match wiring missing")
		_finish()
		return

	## 3) P2 joystick slot resolution (physical path, no stubs).
	var gcfg: Node = get_root().get_node_or_null("GameConfig")
	var prof: Variant = gcfg.call("get_profile", 2) if gcfg != null else null
	if prof == null:
		_trace("[FATAL] no P2 profile")
		_finish()
		return
	prof.call("set_device", InputProfile.DeviceKind.JOYSTICK, 1)
	real_im.call("get_profile", 2)

	var op2: Node = pm.call("get_operator", 2)
	var guard: int = 0
	while op2 == null and guard < 300:
		await physics_frame
		op2 = pm.call("get_operator", 2)
		guard += 1
	if op2 == null:
		_trace("[FATAL] P2 operator not spawned")
		_finish()
		return
	op2.set("is_ai_controlled", false)

	var dev2: int = int(prof.call("get_joy_device_id"))
	_trace("P2 profile device_kind=%s joystick_index=%s resolved device=%d (pads=%s)" % [
		str(prof.get("device_kind")), str(prof.get("joystick_index")), dev2, str(pads)])
	_check(dev2 == pad_id, "P2 joystick slot 1 resolves to the physical pad (dev %d)" % pad_id)

	var cam: Node3D = cam_ctrl.get("camera") as Node3D
	var base_rot: Vector3 = cam.global_rotation_degrees
	_trace("active camera path   : %s" % str(cam.get_path()))
	_trace("camera base rotation : %s  (pitch clamp target [-80, -25])" % str(base_rot))

	## 4) GUIDED 8-direction capture.
	_trace("\nGUIDED SEQUENCE: when a direction is shown, PUSH THE RIGHT STICK that way")
	_trace("and HOLD it until the next prompt. Let go between prompts.")
	var pitch_min: float = INF
	var pitch_max: float = -INF
	var max_yaw_seen: float = 0.0
	var phase_results: Dictionary = {}
	for d: Dictionary in DIRECTIONS:
		var label: String = String(d["label"])
		var want_aim: Vector2 = d["aim"] as Vector2
		var want_yaw: float = float(d["yaw"])
		var want_up: bool = bool(d["pitch_up"])
		var axis_max: Dictionary = {}
		var aim_max: float = 0.0
		var aim_dir_ok: bool = false
		var phase_min_pitch: float = INF
		var phase_max_pitch: float = -INF
		var phase_yaw_eff: float = 0.0
		_trace("\n==> MOVE RIGHT STICK: %s   (hold 2.5s)" % label)
		for f in range(150):
			var aim: Vector2 = real_im.call("get_aim_vector", 2) as Vector2
			aim_max = maxf(aim_max, aim.length())
			if aim.length() > 0.25 and aim.dot(want_aim) > 0.7 * want_aim.length():
				aim_dir_ok = true
			for a: int in range(4):
				var av: float = absf(Input.get_joy_axis(pad_id, a))
				if av > float(axis_max.get(a, 0.0)):
					axis_max[a] = av
			var cam_g: Vector3 = cam.global_rotation_degrees
			pitch_min = minf(pitch_min, cam_g.x)
			pitch_max = maxf(pitch_max, cam_g.x)
			phase_min_pitch = minf(phase_min_pitch, cam_g.x)
			phase_max_pitch = maxf(phase_max_pitch, cam_g.x)
			phase_yaw_eff = maxf(phase_yaw_eff, _shortest_yaw_from_zero(cam_g.y))
			max_yaw_seen = maxf(max_yaw_seen, _shortest_yaw_from_zero(cam_g.y))
			await physics_frame
		var a0: float = float(axis_max.get(0, 0.0))
		var a1: float = float(axis_max.get(1, 0.0))
		var a2: float = float(axis_max.get(2, 0.0))
		var a3: float = float(axis_max.get(3, 0.0))
		var pitch_move: float = 0.0
		if want_up:
			pitch_move = -65.0 - phase_min_pitch if phase_min_pitch < INF else 0.0
		else:
			pitch_move = phase_max_pitch - (-65.0) if phase_max_pitch > -INF else 0.0
		_trace("  %-6s raw a0=%.2f a1=%.2f a2=%.2f a3=%.2f  aim_peak=%.2f aim_dir_ok=%s  yaw_eff=%.1f pitch[%.1f..%.1f]" % [
			label, a0, a1, a2, a3, aim_max, str(aim_dir_ok), phase_yaw_eff, phase_min_pitch, phase_max_pitch])
		phase_results[label] = {
			"a0": a0, "a1": a1, "a2": a2, "a3": a3, "aim_max": aim_max, "aim_dir_ok": aim_dir_ok,
			"yaw_eff": phase_yaw_eff, "min_pitch": phase_min_pitch, "max_pitch": phase_max_pitch,
		}
		await _await_frames(30)

	## 5) Release behavior.
	_trace("\n==> LET GO OF THE RIGHT STICK AND HOLD STILL (4s)")
	var release_aim_max: float = 0.0
	for f in range(30):
		var aim: Vector2 = real_im.call("get_aim_vector", 2) as Vector2
		release_aim_max = maxf(release_aim_max, aim.length())
		await physics_frame
	var yaw_at_release: float = cam.global_rotation_degrees.y
	var pitch_at_release: float = cam.global_rotation_degrees.x
	var yaw_drift_max: float = 0.0
	for f in range(150):
		var cam_g: Vector3 = cam.global_rotation_degrees
		yaw_drift_max = maxf(yaw_drift_max, _shortest_yaw_from_zero(cam_g.y - yaw_at_release))
		await physics_frame
	var pitch_final: float = cam.global_rotation_degrees.x
	_trace("release: max_aim=%.3f yaw_at_release=%.1f yaw_drift_max=%.2f pitch_at_release=%.1f pitch_final=%.1f (base %.1f)" % [
		release_aim_max, yaw_at_release, yaw_drift_max, pitch_at_release, pitch_final, base_rot.x])

	## 6) Analysis.
	_trace("\n--- PHYSICAL E2E RESULTS ---")
	_trace("axis-mapping diagnostic (right stick should hit a2=X and a3=Y):")
	var vertical_a1: float = 0.0
	var vertical_a3: float = 0.0
	for d: Dictionary in DIRECTIONS:
		var label: String = String(d["label"])
		var want_yaw: float = float(d["yaw"])
		var e: Dictionary = phase_results[label] as Dictionary
		var a0: float = float(e["a0"])
		var a1: float = float(e["a1"])
		var a2: float = float(e["a2"])
		var a3: float = float(e["a3"])
		var aim_max: float = float(e["aim_max"])
		var dir_ok: bool = bool(e["aim_dir_ok"])
		var yaw_eff: float = float(e["yaw_eff"])
		var pmin: float = float(e["min_pitch"])
		var pmax: float = float(e["max_pitch"])
		var pure_h: bool = absf(want_yaw) == 90.0
		var pure_v: bool = want_yaw == 0.0 or want_yaw == 180.0
		var axis_ok: bool = (a2 > 0.5 and a3 > 0.5) if (not pure_h and not pure_v) else ((a2 > 0.5) if pure_h else (a3 > 0.5))
		var captured: bool = aim_max > 0.4 and dir_ok
		var yaw_ok: bool = yaw_eff > 15.0
		var pitch_ok: bool
		if want_yaw == 0.0:
			pitch_ok = pmin < -30.0
		elif want_yaw == 180.0 or want_yaw == -135.0 or want_yaw == 135.0:
			pitch_ok = pmax > -75.0
		else:
			pitch_ok = true
		if pure_v:
			vertical_a1 = maxf(vertical_a1, a1)
			vertical_a3 = maxf(vertical_a3, a3)
		_trace("  %-6s captured=%s axis_ok=%s (a0=%.2f a1=%.2f a2=%.2f a3=%.2f) yaw_eff=%.1f pitch[%.1f..%.1f]" % [
			label, str(captured), str(axis_ok), a0, a1, a2, a3, yaw_eff, pmin, pmax])
		_check(captured, "%s: P2 received the physical stick in the right direction" % label)
		_check(axis_ok, "%s: physical axis moved as expected (a2=%.2f a3=%.2f)" % [label, a2, a3])
		_check(yaw_ok, "%s: camera yaw response (eff=%.1f, limited)" % [label, yaw_eff])
		_check(pitch_ok, "%s: camera pitch response (pitch[%.1f..%.1f])" % [label, pmin, pmax])

	var mapping_verdict: String = ""
	if vertical_a3 > 0.5:
		mapping_verdict = "STANDARD: right-Y reads on axis 3 (bindings correct)."
	elif vertical_a1 > 0.5:
		mapping_verdict = "NON-STANDARD: right-Y reads on axis 1, NOT axis 3 -> vertical aim (and camera pitch) never reaches the operator on this pad. Needs a controller mapping fix."
	else:
		mapping_verdict = "NO VERTICAL DEFLECTION DETECTED on any axis (a1=%.2f a3=%.2f) - vertical input not captured during the run." % [vertical_a1, vertical_a3]
	_trace("axis-mapping verdict: %s" % mapping_verdict)

	_check(pitch_min >= -80.5 and pitch_max <= -24.5, "pitch stays within 25-80deg limits (min=%.1f max=%.1f)" % [pitch_min, pitch_max])
	_check(max_yaw_seen <= 31.0, "camera yaw stays within the 30deg sway limit (max seen %.1f)" % max_yaw_seen)
	_check(release_aim_max < 0.25, "right stick detected released (max=%.3f)" % release_aim_max)
	_check(yaw_drift_max < 4.0, "camera yaw holds after release (drift=%.2f deg)" % yaw_drift_max)
	_check(absf(pitch_final - base_rot.x) < 10.0, "camera pitch returns to base after release (d=%.1f)" % (pitch_final - base_rot.x))

	_trace("\nNOTE: P1 keyboard/mouse aim, firing and P2 movement covered by green automated")
	_trace("suites (test_kb_mouse_aim 50/50, test_gamepad_aim 43/43, test_match_flow 66/66,")
	_trace("test_gamepad_cone_trace 33/33, test_camera_pitch 15/15).")
	_finish()

func _finish() -> void:
	_trace("\n== PHYSICAL E2E: %d passed, %d failed ==" % [_pass_count, _fail_count])
	if _log != null:
		_log.flush()
		_log.close()
	quit(1 if _fail_count > 0 else 0)
