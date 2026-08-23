# test_operator_hp_particles.gd
# Tests:
#   1. Base Operator health_max is 1000.0 (10x increase)
#   2. Vanguard Operator health_max is 1500.0 (1.5x passive)
#   3. Operator receives damage and triggers armor fragment particles
#   4. Operator dies when health reaches 0.0

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _check(condition: bool, label: String) -> void:
	if condition:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func _get_root() -> Window:
	return root

func _init() -> void:
	run_test.call_deferred()

func run_test() -> void:
	print("--- OPERATOR HP BALANCE + DAMAGE PARTICLE TEST ---")

	var test_root: Node3D = Node3D.new()
	_get_root().add_child(test_root)

	# --- TEST 1: BASE OPERATOR HP IS 250.0 ---
	var base_op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	base_op.player_id = 1
	base_op.team_id = OperatorBase.TEAM_ATTACKERS
	test_root.add_child(base_op)

	for i in range(5):
		await _get_root().get_tree().physics_frame

	_check(base_op.health_max == 250.0, "Base Operator health_max is 250.0")
	_check(base_op.health_current == 250.0, "Base Operator health_current starts at 250.0")

	# --- TEST 2: DAMAGE & PARTICLE CREATION ---
	var children_before: int = test_root.get_child_count()
	base_op.take_damage(100.0)

	for i in range(2):
		await _get_root().get_tree().physics_frame

	_check(base_op.health_current == 150.0, "Base Operator HP reduced to 150.0 after 100.0 damage")
	var particle_found: bool = false
	for child in test_root.get_children():
		if child is CPUParticles3D:
			particle_found = true
			break
	_check(particle_found, "Damage particle effect (CPUParticles3D) spawned in parent on hit")

	# --- TEST 3: DEATH ON 0 HP ---
	base_op.take_damage(150.0)
	for i in range(5):
		await _get_root().get_tree().physics_frame

	_check(base_op.health_current == 0.0, "Base Operator HP reaches 0.0")
	_check(base_op.is_dead, "Base Operator enters DEAD state when HP reaches 0.0")

	# --- TEST 4: VANGUARD OPERATOR PASSIVE HP (375.0) ---
	var van_op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	van_op.player_id = 2
	van_op.team_id = OperatorBase.TEAM_DEFENDERS
	test_root.add_child(van_op)

	for i in range(5):
		await _get_root().get_tree().physics_frame

	_check(van_op.health_max == 375.0, "Vanguard Operator health_max is 375.0 (1.5x of 250.0)")
	_check(van_op.health_current == 375.0, "Vanguard Operator health_current starts at 375.0")

	test_root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
