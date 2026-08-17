# test_combat.gd
# Technical Rationale: Hitscan combat baseline test. The operator fires along
# the CANONICAL aim direction (aim_yaw / aim_direction), which is decoupled from
# body rotation — rotation.y is only a visual consequence that converges to
# aim_yaw. Firing therefore requires an explicitly established aim direction;
# rotating the body alone does NOT re-aim the shot. This test sets the aim
# deterministically before firing and documents the resulting damage pipeline.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("--- COMBAT TEST RUN ---")
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func run_test() -> void:
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	
	var op1: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op1.player_id = 1
	op1.position = Vector3(-2.0, 0.0, 0.0)
	root.add_child(op1)
	
	var op2: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op2.player_id = 2
	op2.team_id = OperatorBase.TEAM_DEFENDERS
	op2.position = Vector3(2.0, 0.0, 0.0)
	root.add_child(op2)
	
	# Wait several physics frames for rigid bodies to register in PhysicsServer
	for i: int in range(8):
		await get_root().get_tree().physics_frame

	print("P1 global_pos: ", op1.global_position, " | rot_y: ", op1.rotation.y)
	print("P1 collision_layer: ", op1.collision_layer, " | combat_mask: ", op1.combat_collision_mask)
	print("P2 collision_layer: ", op2.collision_layer)

	# ── Establish the canonical aim direction EXPLICITLY ─────────────────────
	# The shot travels along aim_direction (derived from aim_yaw), NOT body
	# rotation. To aim at P2 (+X) we set aim_yaw and sync the cached direction.
	# Forward formula: Vector3(-sin(yaw), 0, -cos(yaw)) => +X needs yaw = -PI/2.
	op1.aim_yaw = -PI / 2.0
	op1._sync_aim_direction()

	var forward_dir: Vector3 = op1.aim_direction.normalized()
	_check(forward_dir.distance_to(Vector3(1.0, 0.0, 0.0)) < 0.01,
		"explicit aim direction is +X (%.2f, %.2f, %.2f)" % [forward_dir.x, forward_dir.y, forward_dir.z])

	var eye_pos: Vector3 = op1.global_position + Vector3(0.0, 1.2, 0.0)
	var target_end_pos: Vector3 = eye_pos + (forward_dir * op1.weapon_range)
	print("Raycast: ", eye_pos, " -> ", target_end_pos)

	var exclude_list: Array[RID] = [op1.get_rid()]
	var los_res: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		op1, eye_pos, target_end_pos, exclude_list, op1.combat_collision_mask
	)
	
	print("LoS hit_collider: ", los_res.hit_collider)
	print("LoS is_visible: ", los_res.is_visible)
	_check(los_res.hit_collider == op2, "LoS raycast hits the enemy operator P2")

	# Connect damage signal (array holder so the lambda can write back).
	var signal_flags: Array = [false]
	op1.damage_dealt.connect(func(target: OperatorBase, dmg: float, mit: bool) -> void:
		signal_flags[0] = true
		print("  [probe] damage_dealt: target P", target.player_id, " | dmg ", dmg, " | mitigated ", mit)
	)

	# Fire!
	op1._execute_tactical_shot()
	
	await get_root().get_tree().physics_frame

	var expected_hp: float = op2.health_max - (op1.base_damage * (1.0 - op2.damage_mitigation))
	print("P2 HP after shot: ", op2.health_current, " / ", op2.health_max, " (expected ~", expected_hp, ")")
	
	_check(op2.health_current < op2.health_max, "damage was applied to the target")
	_check(absf(op2.health_current - expected_hp) < 0.5,
		"P2 HP matches base_damage * (1 - mitigation) (%.1f)" % expected_hp)
	_check(signal_flags[0], "damage_dealt signal fired on hit")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)