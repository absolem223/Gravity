# test_combat.gd
# Tests hitscan combat: P1 shoots P2 with full LoS validation and damage calculation.
# P1 = ReconOperator (left), P2 = VanguardOperator (right, facing left)
# Expected: P1 hits P2, damage > 0, signal fires.
extends SceneTree

func _init() -> void:
	print("--- COMBAT TEST RUN ---")
	call_deferred("run_test")

func run_test() -> void:
	var root: Node3D = Node3D.new()
	get_root().add_child(root)
	
	var op1: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op1.player_id = 1
	op1.position = Vector3(-2.0, 0.0, 0.0)
	root.add_child(op1)
	
	var op2: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op2.player_id = 2
	op2.position = Vector3(2.0, 0.0, 0.0)
	root.add_child(op2)
	
	# Wait several physics frames for rigid bodies to register in PhysicsServer
	for i: int in range(8):
		await get_root().get_tree().physics_frame
	
	# P1 faces +X to aim at P2.
	# forward_dir formula: Vector3(-sin(y), 0, -cos(y))
	# To get +X direction: -sin(y) = 1 => y = -PI/2
	op1.rotation.y = -PI / 2.0
	
	print("P1 global_pos: ", op1.global_position, " | rot_y: ", op1.rotation.y)
	print("P2 global_pos: ", op2.global_position)
	print("P1 collision_layer: ", op1.collision_layer, " | combat_mask: ", op1.combat_collision_mask)
	print("P2 collision_layer: ", op2.collision_layer)
	
	# Verify forward direction before shot
	var forward_dir: Vector3 = Vector3(-sin(op1.rotation.y), 0.0, -cos(op1.rotation.y)).normalized()
	var eye_pos: Vector3 = op1.global_position + Vector3(0.0, 1.2, 0.0)
	var target_end_pos: Vector3 = eye_pos + (forward_dir * op1.weapon_range)
	
	print("Forward dir: ", forward_dir, " (should be roughly +X)")
	print("Raycast: ", eye_pos, " -> ", target_end_pos)
	
	var exclude_list: Array[RID] = [op1.get_rid()]
	var los_res: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		op1, eye_pos, target_end_pos, exclude_list, op1.combat_collision_mask
	)
	
	print("LoS hit_collider: ", los_res.hit_collider)
	print("LoS hit_position: ", los_res.hit_position)
	print("LoS is_visible: ", los_res.is_visible)
	
	# Connect damage signal
	op1.damage_dealt.connect(func(target: OperatorBase, dmg: float, mit: bool) -> void:
		print("✓ SUCCESS: P1 hit P", target.player_id, " for ", dmg, " dmg. Mitigated: ", mit)
	)
	
	# Fire!
	op1._execute_tactical_shot()
	
	await get_root().get_tree().physics_frame
	
	var expected_hp: float = op2.health_max - (op1.base_damage * (1.0 - op2.damage_mitigation))
	print("P2 HP after shot: ", op2.health_current, " / ", op2.health_max, " (expected ~", expected_hp, ")")
	
	if op2.health_current < op2.health_max:
		print("✓ PASS: Damage was applied correctly.")
	else:
		print("✗ FAIL: No damage was applied. Check collision layers and raycast direction.")
	
	root.queue_free()
	quit()
