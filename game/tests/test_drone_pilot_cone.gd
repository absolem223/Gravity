# test_drone_pilot_cone.gd
# Technical Rationale: Regression test for the drone PILOT vision cone. The
# visible cone reuses the drone's existing VisionCone3D range/field-of-view as a
# procedural fan child of the drone, so it rotates with the drone's OWN aim
# direction (right stick / autoaim) — never the camera. It is hidden outside
# PILOT mode.
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

## Stub InputManager holding ONLY the pilot aim-cone action. Repair: since
## commit daa42ff the visible cone is aim-gated (_pilot_cone.visible =
## is_aiming), so PILOT-mode visibility requires an active aim input.
class HeldAimInput:
	extends InputManager
	func is_action_pressed(_player_id: int, suffix: String) -> bool:
		return suffix == "aim_cone"

func run_test() -> void:
	print("== DRONE PILOT VISION CONE TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = 1
	op.team_id = OperatorBase.TEAM_ATTACKERS
	op.position = Vector3(-4.0, 0.0, 0.0)
	root.add_child(op)
	op.set_input_manager(HeldAimInput.new())

	var drone: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	drone.operator = op
	drone.position = Vector3(-2.0, 0.6, 0.0)
	root.add_child(drone)
	for i in range(6):
		await get_root().get_tree().physics_frame

	var cone: MeshInstance3D = drone._pilot_cone
	_check(cone != null, "drone has a PilotVisionCone node")
	_check(cone != null and cone.get_parent() == drone,
		"PilotVisionCone is a child of the drone (rotates with the drone's aim, not the camera)")
	_check(cone != null and cone.visible == false,
		"PilotVisionCone is hidden while the drone is in ESCORT")

	# The visible cone's REACH is the drone's WEAPON range (the combat envelope),
	# decoupled from the VisionCone3D detection range: the farthest fan vertex
	# from the cone center equals the weapon range.
	if drone.weapon != null and cone != null:
		var arrays: Array = cone.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var max_reach: float = 0.0
		for v: Vector3 in verts:
			max_reach = maxf(max_reach, Vector3(v.x, 0.0, v.z).length())
		_check(absf(max_reach - drone.weapon.range) < 0.5,
			"visible cone reaches the drone weapon range (%.1f m)" % max_reach)

	drone.set_mode(DroneBase.DroneMode.PILOT)
	await get_root().get_tree().physics_frame
	_check(cone != null and cone.visible,
		"PilotVisionCone is visible while the drone is in PILOT")

	drone.set_mode(DroneBase.DroneMode.ESCORT)
	await get_root().get_tree().physics_frame
	_check(cone != null and not cone.visible,
		"PilotVisionCone hides again when leaving PILOT")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)