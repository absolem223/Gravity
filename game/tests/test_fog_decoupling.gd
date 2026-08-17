# test_fog_decoupling.gd
# Technical Rationale: Headless validation of the Fog of War decoupling contract:
# (1) map exploration radius (operator.reveal_radius = 16m) is a SEPARATE source
# of truth from enemy detection (vision_cone.view_range = 32m), and (2) the
# operator's tactical vision cone reach equals the WEAPON range (the combat
# envelope), not the detection range. Detection ranges themselves are left
# untouched. Adheres to ADR-0001 (GDScript 2.x Strict Typing).

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
	print("== FOG OF WAR DECOUPLING TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = 1
	op.team_id = OperatorBase.TEAM_ATTACKERS
	op.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(op)
	for i in range(4):
		await get_root().get_tree().physics_frame

	# 1. Sources of truth are separated: reveal_radius (map exploration) vs
	# vision_cone.view_range (enemy detection). player_id 1 defaults to the Recon
	# role, which still enhances DETECTION to 40m while reveal_radius stays 16m —
	# proving the two are independent.
	_check(op.reveal_radius == 16.0, "operator reveal_radius is 16.0m (map exploration)")
	_check(op.vision_cone != null and op.vision_cone.view_range == 40.0,
		"operator vision_cone.view_range is 40.0m (Recon detection, unchanged)")
	_check(op.weapon != null and op.weapon.range == 20.0,
		"operator weapon.range is 20.0m (combat envelope)")
	_check(op.reveal_radius != op.vision_cone.view_range,
		"reveal_radius is a separate source of truth from vision_cone.view_range")

	# 2. Tactical cone reach = weapon range in open space (no walls truncate the
	# fan), and it is NOT the detection view_range.
	op._enter_precision_aim()
	var cone: OperatorBase.TacticalVisionCone = op._tactical_cone
	_check(cone != null, "tactical cone created")
	if cone != null:
		cone.update_cone(op, 1.0)
		var arrays: Array = cone.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var max_reach: float = 0.0
		for v: Vector3 in verts:
			max_reach = maxf(max_reach, Vector3(v.x, 0.0, v.z).length())
		_check(absf(max_reach - op.weapon.range) < 0.5,
			"tactical cone reaches the weapon range (%.1f m)" % max_reach)
		_check(absf(max_reach - op.vision_cone.view_range) > 5.0,
			"tactical cone reach is decoupled from view_range (%.1f vs 32.0m)" % max_reach)

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
