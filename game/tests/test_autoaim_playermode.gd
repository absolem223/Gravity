# test_autoaim_playermode.gd
# Technical Rationale: Regression test for the gamepad fire / auto-aim split:
#   - R2 (the fire action) on a gamepad profile is PURE FIRE: it fires along the
#     current right-stick aim direction and NEVER auto-acquires by itself.
#   - AUTO_AIM is an OPTIONAL capability gated by the "autoaim" action (STATE B):
#     while it is held, R2 acquires a valid enemy INSIDE the aim cone (range +
#     LoS + cover respected), steers onto it and the shot hits that target.
#   - Canonical default scheme isolation: LEFT stick moves / RIGHT stick aims and
#     neither leaks into the other.
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

## Stubbed InputManager: reports a GAMEPAD device (so the canonical gamepad
## wiring engages), plus configurable right-stick aim, left-stick movement, R2
## fire and the auto-aim action.
class StubInput:
	extends InputManager
	var fire_held: bool = false
	var autoaim_held: bool = false
	var aim_vec: Vector2 = Vector2.ZERO
	var move_vec: Vector2 = Vector2.ZERO

	func _init() -> void:
		var mirror: PlayerInputProfile = PlayerInputProfile.new()
		mirror.device_type = PlayerInputProfile.DeviceType.GAMEPAD
		_profiles[1] = mirror

	# Keep the GAMEPAD mirror set in _init (base _ready would resync it from the
	# authoritative GameConfig profile, which is keyboard+mouse after the P1
	# keyboard default pass). The gamepad path must be tested deterministically.
	func _initialize_profiles() -> void:
		pass

	func _sync_device_mirrors() -> void:
		pass

	func is_action_pressed(_player_id: int, action: String) -> bool:
		if action == "fire":
			return fire_held
		if action == "autoaim":
			return autoaim_held
		return false

	func get_aim_vector(_player_id: int) -> Vector2:
		return aim_vec

	func get_movement_vector(_player_id: int) -> Vector2:
		return move_vec

func _await_frames(n: int) -> void:
	for i in range(n):
		await get_root().get_tree().physics_frame

func run_test() -> void:
	print("== PLAYER R2+AUTO_AIM TEST (v0.96) ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	var stub: StubInput = StubInput.new()
	root.add_child(stub)

	var player: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	player.player_id = 1
	player.team_id = OperatorBase.TEAM_ATTACKERS
	player.position = Vector3(0.0, 0.0, 0.0)
	player._input_manager = stub
	root.add_child(player)
	# Deterministic test: no automatic physics stepping on the operators.
	player.set_physics_process(false)

	var enemy: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	enemy.player_id = 2
	enemy.team_id = OperatorBase.TEAM_DEFENDERS
	enemy.position = Vector3(6.0, 0.0, 0.0)
	enemy._input_manager = stub
	root.add_child(enemy)
	enemy.set_physics_process(false)

	var decoy: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	decoy.player_id = 3
	decoy.team_id = OperatorBase.TEAM_DEFENDERS
	decoy.position = Vector3(6.0, 0.0, 6.0)
	decoy._input_manager = stub
	root.add_child(decoy)
	decoy.set_physics_process(false)

	await _await_frames(8)
	_check(player.weapon != null, "player weapon is the GRAVITY-1 profile")

	print("--- [1] Canonical defaults: LEFT=move, RIGHT=aim (isolation) ---")
	# Right stick to the east (+X): aim_yaw must track it; position must not move.
	var yaw_before: float = player.aim_yaw
	stub.aim_vec = Vector2(1.0, 0.0)
	for i in range(6):
		player._update_autoaim()
		player._update_aim(0.03)
		await _await_frames(1)
	_check(absf(player.aim_yaw - yaw_before) > 0.1, "right stick changes the operator's aim_yaw")
	_check(absf(player.global_position.x) < 0.01 and absf(player.global_position.z) < 0.01,
		"right stick does NOT move the operator")
	_check(player._gamepad_aim_active, "right stick engages the active gamepad aim channel")

	# Left stick to the east (+X): position must move; aim_yaw must not change.
	var pos_before: Vector3 = player.global_position
	yaw_before = player.aim_yaw
	stub.aim_vec = Vector2.ZERO
	stub.move_vec = Vector2(1.0, 0.0)
	for i in range(12):
		player._update_autoaim()
		player._update_aim(0.03)
		player._process_locomotion(Vector2(1.0, 0.0), 0.03)
		# Physics stepping is disabled on this operator, so the body only moves
		# when move_and_slide() is driven explicitly (like the real _physics_process).
		player.move_and_slide()
		await _await_frames(1)
	_check(player.global_position.x > pos_before.x + 0.1, "left stick moves the operator along its movement vector")
	_check(absf(player.aim_yaw - yaw_before) < 0.05, "left stick does NOT change the operator's aim_yaw")

	print("--- [2] R2 WITHOUT auto-aim: pure directional fire along the right stick ---")
	# Strip every drone: an escort drone lingering near a teleported operator must
	# never masquerade as an "in-range enemy" for the no-acquisition checks.
	for n: Node in get_nodes_in_group("drones"):
		n.queue_free()
	await _await_frames(4)
	stub.move_vec = Vector2.ZERO
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._autoaim_target = null
	enemy.position = Vector3(40.0, 0.0, 0.0)   # out of range (20m combat range)
	enemy.health_current = enemy.health_max
	decoy.position = Vector3(40.0, 0.0, 40.0)
	decoy.health_current = decoy.health_max
	var expected_yaw: float = atan2(-0.7071, -0.7071)
	stub.aim_vec = Vector2(0.7071, 0.7071)
	stub.fire_held = true
	stub.autoaim_held = false
	for i in range(15):
		player._update_autoaim()
		player._update_aim(0.03)
		await _await_frames(1)
	_check(player._aim_source != OperatorBase.AimSource.AUTO_AIM,
		"R2 without the auto-aim action does NOT enter the AUTO_AIM channel")
	_check(player._autoaim_target == null, "no in-range enemy -> no autoaim lock acquired")
	_check(absf(wrapf(player.aim_yaw - expected_yaw, -PI, PI)) < 0.15,
		"R2 without a target: aim follows the right-stick direction")
	# Fire a single round: ammo consumed, shot resolved along aim, enemy NOT hit.
	if player.weapon != null:
		var ammo_before: int = player.weapon.magazine.current_rounds
		if player.weapon.try_consume_round():
			player._execute_tactical_shot()
		await _await_frames(1)
		_check(player.weapon.magazine.current_rounds == ammo_before - 1, "R2 consumed exactly one round")
		_check(absf(enemy.health_current - enemy.health_max) < 0.01,
			"out-of-range enemy not damaged by R2 free-aim fire")

	print("--- [3] AUTO-AIM ON (STATE B): R2 acquires the in-cone enemy and fires ---")
	enemy.position = Vector3(6.0, 0.0, 0.0)
	enemy.health_current = enemy.health_max
	decoy.position = Vector3(9.0, 0.0, 12.0)  # outside the east-facing 90° cone
	decoy.health_current = decoy.health_max
	stub.fire_held = true
	stub.autoaim_held = true
	stub.aim_vec = Vector2(1.0, 0.0)
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._autoaim_target = null
	for i in range(15):
		player._update_autoaim()
		player._update_aim(0.03)
		await _await_frames(1)
	_check(player._aim_source == OperatorBase.AimSource.AUTO_AIM,
		"auto-aim action held enters the AUTO_AIM channel (STATE B)")
	_check(player._autoaim_target == enemy, "R2 with auto-aim ON acquired the nearest in-cone enemy")
	var to_enemy: Vector3 = (enemy.global_position - player.global_position)
	to_enemy.y = 0.0
	var enemy_yaw: float = atan2(-to_enemy.x, -to_enemy.z)
	_check(absf(wrapf(player.aim_yaw - enemy_yaw, -PI, PI)) < 0.2, "R2-steered aim points at the acquired enemy")
	if player.weapon != null:
		var ammo_before: int = player.weapon.magazine.current_rounds
		if player.weapon.try_consume_round():
			player._execute_tactical_shot()
		await _await_frames(1)
		_check(player.weapon.magazine.current_rounds == ammo_before - 1, "R2 consumed exactly one round toward the lock")
		_check(enemy.health_current < enemy.health_max, "acquired enemy took damage")
		_check(absf(decoy.health_current - decoy.health_max) < 0.01,
			"the DECOY (outside the cone) took NO damage: correct target hit")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
