# test_fog_decoupling.gd
# Technical Rationale: Headless validation of the Fog of War coupling contract:
# (1) map exploration radius (operator.reveal_radius) NOW EQUALS enemy detection
# (vision_cone.view_range) so the visible ground fog circle matches the tactical
# vision cone reach. The orange inner ring (drawn separately) still marks the
# WEAPON combat range (20m) — a distinct system. Detection ranges untouched.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

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
	print("== FOG OF WAR COUPLING TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = 1
	op.team_id = OperatorBase.TEAM_ATTACKERS
	op.position = Vector3(0.0, 0.0, 0.0)
	root.add_child(op)
	for i in range(4):
		await get_root().get_tree().physics_frame

	# 1. Sources of truth are NOW UNIFIED: reveal_radius == vision_cone.view_range.
	# player_id 1 defaults to the Recon role, which enhances BOTH to 40m.
	_check(op.reveal_radius == 40.0, "operator reveal_radius is 40.0m (matches view_range)")
	_check(op.vision_cone != null and op.vision_cone.view_range == 40.0,
		"operator vision_cone.view_range is 40.0m (Recon detection)")
	_check(op.weapon != null and op.weapon.range == 20.0,
		"operator weapon.range is 20.0m (combat envelope)")
	_check(op.reveal_radius == op.vision_cone.view_range,
		"reveal_radius EQUALS vision_cone.view_range (unified source of truth)")

	# 2. Tactical cone OUTER REACH equals the detection view_range (so the visible
	# fan matches exactly what the squad can actually see/detect), and it is
	# decoupled from the weapon combat range (which the orange inner ring shows).
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
		_check(absf(max_reach - op.vision_cone.view_range) < 0.5,
			"tactical cone OUTER reach equals view_range (%.1f m)" % max_reach)
		_check(max_reach < op.vision_cone.view_range * 1.25,
			"tactical cone is NOT ~2x the detection range (%.1f vs 2x=%.1f)" % [max_reach, op.vision_cone.view_range * 2.0])
		_check(absf(max_reach - op.weapon.range) > 5.0,
			"tactical cone reach is decoupled from weapon range (%.1f vs 20.0m)" % max_reach)

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)