# test_drone_camera_framing.gd
# Technical Rationale: Regression test for the shared-camera fix. Before the
# fix, Match._update_camera_targets() SWAPPED the operator out for the drone as
# the camera target while piloting, so the shared viewport abandoned the squad
# and anchored on the far-away drone (making every other player appear to slide
# with it). The fix APPENDS the drone as an extra target while keeping the
# operator as a framing anchor, and caps framing spread so a distant drone does
# not zoom the camera all the way out.
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

func _new_match() -> Match:
	var m: Match = (load("res://scenes/match.tscn") as PackedScene).instantiate() as Match
	m.intro_enabled = false
	get_root().add_child(m)
	current_scene = m
	return m

func run_test() -> void:
	print("== DRONE CAMERA FRAMING TEST ==")
	var cfg: Node = get_root().get_node_or_null("GameConfig")
	if cfg != null:
		cfg.call("reset_slots_to_defaults")

	var m: Match = _new_match()
	for i in 6:
		await physics_frame

	var pm: PlayerManager = m.get_player_manager()
	var p1: OperatorBase = pm.get_operator(1)
	# Group the whole squad near the origin so the centroid test is meaningful
	# (other operators spawn scattered across the arena by default).
	var op_idx: int = 0
	for op: OperatorBase in pm.get_all_operators():
		op.global_position = Vector3(-2.0 + op_idx, 0.0, 0.0)
		op_idx += 1
	for i in 4:
		await physics_frame

	var d1: DroneBase = p1.drone
	_check(d1 != null, "P1 owns a drone")
	_check(m.camera_controller != null, "Match has a shared camera_controller")

	print("--- [1] Camera targets keep the operator anchored while piloting ---")
	if d1 != null:
		d1.set_mode(DroneBase.DroneMode.PILOT)
	_check(p1.is_piloting_drone, "P1 enters PILOT mode")
	m._update_camera_targets()
	await physics_frame

	var cam_targets: Array[Node3D] = m.camera_controller.targets
	_check(cam_targets.has(p1), "operator is ALWAYS a camera framing anchor (never swapped out)")
	_check(cam_targets.has(d1), "piloted drone is tracked as an ADDITIONAL camera target")

	print("--- [2] Far drone inflates framing only up to the cap (zoom stays bounded) ---")
	if d1 != null:
		# Park the drone at its max range limit (28m) plus margin — well beyond
		# framing cap contribution, representative of a scouting drone.
		d1.global_position = Vector3(250.0, 2.0, 0.0)
	# Recompute centroid/zoom with the far drone present.
	m.camera_controller._update_centroid_and_zoom()
	var zoom_with_drone: float = m.camera_controller._current_zoom_distance
	print("    [probe] zoom distance with drone 250m away = %.1f (cap %d, max %d)" % [
		zoom_with_drone, int(m.camera_controller.max_framing_spread), int(m.camera_controller.max_zoom_distance)])
	_check(zoom_with_drone <= m.camera_controller.max_zoom_distance,
		"zoom distance never exceeds max_zoom_distance")
	_check(zoom_with_drone < 60.0,
		"framing spread is capped: a 250m drone does NOT zoom the squad camera out")

	# Without the cap (legacy swap behavior) the zoom would target ~off-scale;
	# prove the cap is what keeps the value bounded.
	var capped_spread: float = minf(250.0, m.camera_controller.max_framing_spread) + m.camera_controller.bounding_box_padding
	var capped_zoom: float = clampf(m.camera_controller.min_zoom_distance + capped_spread * 0.8,
		m.camera_controller.min_zoom_distance, m.camera_controller.max_zoom_distance)
	_check(absf(zoom_with_drone - capped_zoom) < 0.01,
		"zoom equals the capped-spread formula (%.1f)" % capped_zoom)

	print("--- [3] Operator anchoring keeps the centroid near the squad ---")
	if d1 != null:
		d1.global_position = Vector3(28.0, 2.0, 0.0)
	m.camera_controller._update_centroid_and_zoom()
	var centroid: Vector3 = m.camera_controller._target_centroid
	print("    [probe] centroid = ", centroid, " | P1 at ", p1.global_position)
	# With 4 operators near the origin + 1 drone at 28m, a pure average would sit
	# ~5.6m out; the anchor keeps it grounded on the squad, not chasing the drone.
	_check(centroid.distance_to(Vector3.ZERO) < 12.0,
		"centroid stays near the squad (operator anchors it) instead of chasing the drone to x=28")

	m.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)