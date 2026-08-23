# test_drone_hp_respawn.gd
# Tests:
#   1. Drone max HP is 500 (10x the original 50)
#   2. Drone is still destroyable when HP reaches 0
#   3. Destroyed drone leaves a wreck
#   4. Operator respawn creates a new drone when previous was destroyed
#   5. Old wreck persists after new drone spawns
#   6. Living drone is NOT duplicated on operator respawn

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
	print("--- DRONE HP + RESPAWN ON OPERATOR DEATH TEST ---")

	var test_root: Node3D = Node3D.new()
	_get_root().add_child(test_root)

	# Create operator P1
	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = 1
	op.team_id = OperatorBase.TEAM_ATTACKERS
	op.position = Vector3(0.0, 0.0, 0.0)
	test_root.add_child(op)

	for i in range(10):
		await _get_root().get_tree().physics_frame

	# Spawn drone
	op.spawn_drone()
	for i in range(5):
		await _get_root().get_tree().physics_frame

	var drone: DroneBase = op.drone
	_check(drone != null, "Drone spawned successfully")
	_check(op.has_drone_active, "has_drone_active is true after spawn")

	# --- TEST 1: DRONE MAX HP IS 500 ---
	_check(drone.health_max == 500.0, "Drone max HP is 500.0 (10x balance)")
	_check(drone.health_current == 500.0, "Drone current HP starts at 500.0")

	# --- TEST 2: DRONE IS STILL DESTROYABLE ---
	# Deal enough damage to destroy it
	drone.take_damage(250.0)
	_check(drone.health_current == 250.0, "Drone takes damage correctly (250 HP remaining)")

	drone.take_damage(250.0)
	# After destruction, the drone calls queue_free and operator.notify_drone_destroyed()
	for i in range(5):
		await _get_root().get_tree().physics_frame

	_check(not op.has_drone_active, "has_drone_active is false after drone destroyed")
	_check(op.drone == null, "Operator drone reference is null after destruction")

	# --- TEST 3: WRECK EXISTS ---
	var wrecks_before: Array[Node] = []
	for node: Node in _get_root().get_tree().get_nodes_in_group("wreck_sites"):
		wrecks_before.append(node)
	# Wrecks may or may not be in a group; check by class in parent
	var wreck_count_before: int = 0
	for child: Node in test_root.get_children():
		if child is WreckSite:
			wreck_count_before += 1
	_check(wreck_count_before >= 1, "Wreck exists after drone destruction (count: %d)" % wreck_count_before)

	# --- TEST 4: OPERATOR DIES AND RESPAWNS → NEW DRONE CREATED ---
	# Kill the operator
	op.health_current = 0.0
	op.die()
	for i in range(5):
		await _get_root().get_tree().physics_frame

	_check(op.is_dead, "Operator is dead after die()")
	_check(not op.has_drone_active, "Drone is NOT respawned immediately on operator death")

	# Simulate respawn (as the physics_process respawn timer would do)
	op.respawn(Vector3(5.0, 0.0, 0.0))
	for i in range(10):
		await _get_root().get_tree().physics_frame

	_check(not op.is_dead, "Operator is alive after respawn")
	_check(op.has_drone_active, "New drone is active after operator respawn")
	_check(op.drone != null, "Operator has a new drone reference after respawn")
	_check(op.drone != drone, "New drone is a different instance than the destroyed one")

	# --- TEST 5: OLD WRECK PERSISTS ---
	var wreck_count_after: int = 0
	for child: Node in test_root.get_children():
		if child is WreckSite:
			wreck_count_after += 1
	_check(wreck_count_after >= wreck_count_before, "Old wreck persists after new drone spawns (before: %d, after: %d)" % [wreck_count_before, wreck_count_after])

	# --- TEST 6: LIVING DRONE IS NOT DUPLICATED ON RESPAWN ---
	var current_drone: DroneBase = op.drone
	var drone_count_before: int = 0
	for node: Node in _get_root().get_tree().get_nodes_in_group("drones"):
		drone_count_before += 1

	# Kill and respawn operator again WITH a living drone
	op.health_current = 0.0
	op.die()
	for i in range(5):
		await _get_root().get_tree().physics_frame

	op.respawn(Vector3(10.0, 0.0, 0.0))
	for i in range(10):
		await _get_root().get_tree().physics_frame

	_check(op.drone == current_drone, "Living drone is NOT replaced on operator respawn")
	var drone_count_after: int = 0
	for node: Node in _get_root().get_tree().get_nodes_in_group("drones"):
		drone_count_after += 1
	_check(drone_count_after == drone_count_before, "No duplicate drones created when drone is alive (before: %d, after: %d)" % [drone_count_before, drone_count_after])

	test_root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
