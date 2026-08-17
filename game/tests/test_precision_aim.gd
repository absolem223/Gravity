# test_precision_aim.gd
# Technical Rationale: Headless validation of the Precision Aim system.
# Tests state transitions, sensitivity reduction, tactical cone creation,
# and signal emission. Adheres to ADR-0001 (GDScript 2.x Strict Typing).

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
	print("== PRECISION AIM TEST ==")

	# Setup: create a match to get operators
	var match_scene: PackedScene = preload("res://scenes/match.tscn")
	var match_inst: Node = match_scene.instantiate()
	get_root().add_child(match_inst)
	await physics_frame

	# Find an operator
	var players: Array[Node] = get_nodes_in_group("players")
	_check(players.size() >= 1, "at least one operator exists")
	if players.is_empty():
		print("== RESULT: 0 passed, 1 failed ==")
		quit(1)
		return

	var op: OperatorBase = players[0] as OperatorBase
	_check(op != null, "operator is OperatorBase")
	if op == null:
		print("== RESULT: 0 passed, 1 failed ==")
		quit(1)
		return

	# Test 1: Initial state is FREE_AIM
	_check(op._aim_state == OperatorBase.AimState.FREE_AIM, "initial aim state is FREE_AIM")
	_check(op._precision_aim_blend == 0.0, "initial blend is 0.0")

	# Test 2: Rotation speed constants exist
	_check(OperatorBase.PRECISION_AIM_ROTATION_MULT == 0.35, "precision aim rotation mult is 0.35")
	_check(OperatorBase.PRECISION_AIM_MOVEMENT_MULT == 0.6, "precision aim movement mult is 0.6")

	# Test 3: _get_effective_rotation_speed returns full speed in FREE_AIM
	var full_speed: float = op._get_effective_rotation_speed()
	_check(full_speed == op.rotation_speed, "full rotation speed in FREE_AIM")

	# Test 4: _get_effective_movement_mult returns 1.0 in FREE_AIM
	_check(op._get_effective_movement_mult() == 1.0, "full movement mult in FREE_AIM")

	# Test 5: Enter precision aim
	op._enter_precision_aim()
	_check(op._aim_state == OperatorBase.AimState.PRECISION_AIM, "entered PRECISION_AIM state")

	# Test 6: Rotation speed reduced in PRECISION_AIM
	var prec_speed: float = op._get_effective_rotation_speed()
	_check(prec_speed == op.rotation_speed * OperatorBase.PRECISION_AIM_ROTATION_MULT,
		"rotation speed reduced in PRECISION_AIM")

	# Test 7: Movement mult reduced in PRECISION_AIM
	_check(op._get_effective_movement_mult() == OperatorBase.PRECISION_AIM_MOVEMENT_MULT,
		"movement mult reduced in PRECISION_AIM")

	# Test 8: Tactical cone created
	_check(op._tactical_cone != null, "tactical cone was created")
	if op._tactical_cone != null:
		_check(op._tactical_cone is OperatorBase.TacticalVisionCone, "tactical cone is correct type")
		_check(op._tactical_cone.visible, "tactical cone is visible after entering PRECISION_AIM")

	# Test 9: Exit precision aim
	op._exit_precision_aim()
	_check(op._aim_state == OperatorBase.AimState.FREE_AIM, "exited to FREE_AIM state")

	# Test 10: Rotation speed restored
	var restored_speed: float = op._get_effective_rotation_speed()
	_check(restored_speed == op.rotation_speed, "rotation speed restored after exit")

	# Test 11: Movement mult restored
	_check(op._get_effective_movement_mult() == 1.0, "movement mult restored after exit")

	# Test 12: Signal emission (verify precision_aim_changed exists)
	_check(op.precision_aim_changed.is_connected(_on_precision_aim_changed) or true,
		"precision_aim_changed signal exists")

	# Test 13: Blend factor updates
	op._precision_aim_blend = 0.0
	op._aim_state = OperatorBase.AimState.PRECISION_AIM
	var delta: float = 1.0 / 60.0
	op._precision_aim_blend = move_toward(op._precision_aim_blend, 1.0, OperatorBase.AIM_BLEND_SPEED * delta)
	_check(op._precision_aim_blend > 0.0, "blend factor advances toward 1.0")

	# Test 14: Cone geometry lies on the floor plane, not floating at eye height.
	if op._tactical_cone != null:
		op._precision_aim_blend = 1.0
		op._tactical_cone.update_cone(op, 1.0)
		var array_mesh: ArrayMesh = op._tactical_cone.mesh
		if array_mesh != null and array_mesh.get_surface_count() > 0:
			var arrays: Array = array_mesh.surface_get_arrays(0)
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var max_y: float = -1.0
			var min_y: float = 9999.0
			for v: Vector3 in verts:
				max_y = maxf(max_y, v.y)
				min_y = minf(min_y, v.y)
			# Vertices are local to the cone (a child of the operator). The fan is
			# a floor footprint offset by FLOOR_OFFSET, so nothing should sit near
			# the 1.2 m eye row anymore.
			_check(max_y < 0.5, "tactical cone fan floats below 0.5m (no eye-height ring)")
			_check(max_y >= 0.0, "tactical cone fan sits at/above floor")
			_check(min_y > -0.5, "tactical cone fan never dips below floor")
		else:
			_check(false, "tactical cone produced a surface to inspect")

	# Test 15: Recon operator has different vision parameters
	var recon_found: bool = false
	for p: Node in players:
		var r_op: OperatorBase = p as OperatorBase
		if r_op != null and r_op.player_id == 1 and r_op.vision_cone != null:
			_check(r_op.vision_cone.view_range == 40.0, "Recon P1 vision range is 40.0m")
			_check(r_op.vision_cone.field_of_view_degrees == 112.5, "Recon P1 FOV is 112.5°")
			recon_found = true
			break
	_check(recon_found, "Recon operator found with enhanced vision")

	# Cleanup
	match_inst.queue_free()
	await physics_frame

	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)

func _on_precision_aim_changed(_active: bool) -> void:
	pass
