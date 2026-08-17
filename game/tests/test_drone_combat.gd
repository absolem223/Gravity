# test_drone_combat.gd
# Technical Rationale: Regression test for the drone PILOT fire feature. The
# drone reuses the existing WeaponBase / FireMode / LineOfSightQuery / GameRules
# pipeline (no parallel weapon system), with a strictly weaker GRAVITY-D profile
# than the operator's GRAVITY-1. Verifies:
#   1. The drone weapon is built on _ready and configured from exported tuning.
#   2. The drone profile is weaker and shorter-ranged than the operator's.
#   3. A hitscan round from an aiming drone damages an enemy operator.
#   4. Friendly fire is still gated by GameRules (teammates take no damage).
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
	print("== DRONE COMBAT TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	var op1: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op1.player_id = 1
	op1.team_id = OperatorBase.TEAM_ATTACKERS
	op1.position = Vector3(-4.0, 0.0, 0.0)
	root.add_child(op1)

	var op2: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op2.player_id = 2
	op2.team_id = OperatorBase.TEAM_DEFENDERS
	op2.position = Vector3(2.0, 0.0, 0.0)
	root.add_child(op2)

	var op3: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op3.player_id = 3
	op3.team_id = OperatorBase.TEAM_ATTACKERS
	op3.position = Vector3(2.0, 0.0, 2.0)
	root.add_child(op3)

	var drone: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	drone.operator = op1
	drone.position = Vector3(-2.0, 0.6, 0.0)
	root.add_child(drone)

	# Register physics bodies so the hitscan and LoS resolve against real bodies.
	for i: int in range(8):
		await get_root().get_tree().physics_frame

	# Freeze the drone so ESCORT autocontrol doesn't drag it toward the operator
	# while the test aims and fires.
	drone.set_mode(DroneBase.DroneMode.STATIONARY)
	drone.global_position = Vector3(-2.0, 0.6, 0.0)
	await get_root().get_tree().physics_frame
	print("    [probe] drone pos ", drone.global_position, " | P2 pos ", op2.global_position)

	_check(drone.weapon != null, "drone weapon is built on _ready")
	_check(drone.weapon != null and drone.weapon.weapon_name == "GRAVITY-D", "drone weapon is the GRAVITY-D profile")

	print("--- [1] Drone profile is strictly weaker than the operator's GRAVITY-1 ---")
	_check(op1.weapon != null, "operator weapon built")
	if drone.weapon != null and op1.weapon != null:
		_check(drone.weapon.base_damage < op1.weapon.base_damage,
			"drone damage (%.1f) < operator damage (%.1f)" % [drone.weapon.base_damage, op1.weapon.base_damage])
		_check(drone.weapon.range < op1.weapon.range,
			"drone range (%.1f) < operator range (%.1f)" % [drone.weapon.range, op1.weapon.range])
		print("    [probe] drone base_damage = %.1f, range = %.1f, fire_rate = %.2f" % [
			drone.weapon.base_damage, drone.weapon.range, drone.weapon.fire_mode.fire_rate])

	print("--- [2] Autoaim: drone acquires the nearest enemy in range with LoS ---")
	if drone.weapon != null:
		drone._acquire_combat_target()
		_check(drone._autoaim_target == op2, "drone locked the enemy operator P2 (nearest, clear LoS)")
		_check(drone._autoaim_target != op3, "drone did not lock teammate P3")

	print("--- [3] Hitscan round damages the enemy operator ---")
	if drone.weapon != null:
		# Face P2 (+X): forward_dir formula Vector3(-sin(y),0,-cos(y)) => +X needs y = -PI/2.
		drone.rotation.y = -PI / 2.0
		var ammo_before: int = drone.weapon.magazine.current_rounds
		var enemy_hp_before: float = op2.health_current
		# Mirrors the production PILOT loop: consume a round, then resolve the shot.
		if drone.weapon.try_consume_round():
			drone._execute_drone_shot()
		await get_root().get_tree().physics_frame
		var expected_damage: float = drone.weapon.base_damage * (1.0 - op2.damage_mitigation)
		print("    [probe] P2 HP %.1f -> %.1f | expected dmg ~%.1f | ammo %d -> %d" % [
			enemy_hp_before, op2.health_current, expected_damage, ammo_before, drone.weapon.magazine.current_rounds])
		_check(op2.health_current < op2.health_max, "enemy operator took damage from the drone")
		_check(absf((enemy_hp_before - op2.health_current) - expected_damage) < 0.6,
			"damage amount matches the drone's weaker profile (~%.1f)" % expected_damage)
		_check(drone.weapon.magazine.current_rounds == ammo_before - 1, "drone consumed exactly one round")

	print("--- [4] Friendly fire stays gated by GameRules (default off) ---")
	if drone.weapon != null:
		# Re-aim toward teammate P3 (same team as P1 -> blocked by GameRules default).
		var to_teammate: Vector3 = op3.global_position - drone.global_position
		to_teammate.y = 0.0
		drone.rotation.y = atan2(-to_teammate.x, -to_teammate.z)
		var teammate_hp_before: float = op3.health_current
		drone._execute_drone_shot()
		await get_root().get_tree().physics_frame
		print("    [probe] P3 HP %.1f -> %.1f" % [teammate_hp_before, op3.health_current])
		_check(absf(op3.health_current - teammate_hp_before) < 0.01, "teammate took no damage (friendly fire off)")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)