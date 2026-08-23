# test_crouch_damage_cover.gd
# Technical Rationale: Validates that a crouched Operator behind 1.2m medium cover
# is physically protected from enemy fire because the crouched collision shape
# sits below cover height (Y <= 1.0m) and angled shots are blocked by cover.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("--- CROUCH DAMAGE COVER TEST RUN ---")
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

	# Build floor
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var floor_shape: CollisionShape3D = CollisionShape3D.new()
	var floor_box: BoxShape3D = BoxShape3D.new()
	floor_box.size = Vector3(100.0, 1.0, 100.0)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)

	# Shooter (Enemy) at X=-3.0
	var enemy_shooter: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	enemy_shooter.player_id = 1
	enemy_shooter.team_id = OperatorBase.TEAM_ATTACKERS
	enemy_shooter.is_ai_controlled = true
	enemy_shooter.position = Vector3(-3.0, 0.0, 0.0)
	root.add_child(enemy_shooter)

	# Target (Player) at X=3.0
	var player_target: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	player_target.player_id = 2
	player_target.team_id = OperatorBase.TEAM_DEFENDERS
	player_target.position = Vector3(3.0, 0.0, 0.0)
	root.add_child(player_target)

	# Medium Cover at X=0 (height 1.2m, spans Y=0.0..1.2m)
	var med_cover: StaticBody3D = StaticBody3D.new()
	med_cover.name = "MediumCover"
	med_cover.position = Vector3(0.0, 0.6, 0.0)
	var med_shape: CollisionShape3D = CollisionShape3D.new()
	var med_box: BoxShape3D = BoxShape3D.new()
	med_box.size = Vector3(1.0, 1.2, 4.0)
	med_shape.shape = med_box
	med_cover.add_child(med_shape)
	root.add_child(med_cover)

	for i in range(15):
		await get_root().get_tree().physics_frame

	enemy_shooter.aim_yaw = -PI / 2.0 # aim at +X
	enemy_shooter._sync_aim_direction()
	enemy_shooter._autoaim_target = player_target
	enemy_shooter._aim_source = OperatorBase.AimSource.AUTO_AIM

	# --- TEST 1: STANDING TARGET BEHIND 1.2M COVER ---
	player_target.is_crouching = false
	player_target._update_crouch_visual()
	player_target.health_current = player_target.health_max
	var prev_hp: float = player_target.health_current

	enemy_shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame

	var dmg_t1: float = prev_hp - player_target.health_current
	print("Damage to standing target behind 1.2m cover: ", dmg_t1)
	_check(dmg_t1 > 0.0, "Standing target behind 1.2m cover is hit (shot clears cover and hits standing capsule)")

	# --- TEST 2: CROUCHING TARGET BEHIND 1.2M COVER ---
	player_target.is_crouching = true
	player_target._update_crouch_visual()
	for i in range(5):
		await get_root().get_tree().physics_frame

	player_target.health_current = player_target.health_max
	prev_hp = player_target.health_current

	# Enemy fires
	enemy_shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame

	var dmg_t2: float = prev_hp - player_target.health_current
	print("Damage to crouching target behind 1.2m cover: ", dmg_t2)
	_check(dmg_t2 == 0.0, "Crouching target behind 1.2m cover receives 0 damage (physically protected)")

	# --- TEST 3: CROUCHING TARGET IN THE OPEN (NO COVER) ---
	med_cover.position = Vector3(0.0, -10.0, 0.0) # remove cover
	for i in range(5):
		await get_root().get_tree().physics_frame

	player_target.is_crouching = true
	player_target._update_crouch_visual()
	player_target.health_current = player_target.health_max
	prev_hp = player_target.health_current

	enemy_shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame

	var dmg_t3: float = prev_hp - player_target.health_current
	print("Damage to crouching target in the open: ", dmg_t3)
	_check(dmg_t3 > 0.0, "Crouching target in the open takes normal damage")

	# --- TEST 4: TALL COVER (2.0M) PROTECTS BOTH ---
	var tall_cover: StaticBody3D = StaticBody3D.new()
	tall_cover.position = Vector3(0.0, 1.0, 0.0)
	var tall_shape: CollisionShape3D = CollisionShape3D.new()
	var tall_box: BoxShape3D = BoxShape3D.new()
	tall_box.size = Vector3(1.0, 2.0, 4.0)
	tall_shape.shape = tall_box
	tall_cover.add_child(tall_shape)
	root.add_child(tall_cover)

	for i in range(5):
		await get_root().get_tree().physics_frame

	# Standing behind tall cover
	player_target.is_crouching = false
	player_target._update_crouch_visual()
	player_target.health_current = player_target.health_max
	prev_hp = player_target.health_current
	enemy_shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame
	_check(player_target.health_current == prev_hp, "Standing target behind 2.0m tall cover is protected (0 damage)")

	# Crouching behind tall cover
	player_target.is_crouching = true
	player_target._update_crouch_visual()
	player_target.health_current = player_target.health_max
	prev_hp = player_target.health_current
	enemy_shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame
	_check(player_target.health_current == prev_hp, "Crouching target behind 2.0m tall cover is protected (0 damage)")

	# --- TEST 5: CROUCHED TARGET ANGLED / EXPOSED AROUND COVER ---
	# Move player to Z=5.0 so line-of-sight from shooter (-3, 1.35, 0) to target (3, 0.65, 5) clears tall cover (Z in [-2, 2])
	player_target.position = Vector3(3.0, 0.0, 5.0)
	enemy_shooter.aim_yaw = atan2(-6.0, -5.0)
	enemy_shooter._sync_aim_direction()

	for i in range(5):
		await get_root().get_tree().physics_frame

	player_target.is_crouching = true
	player_target._update_crouch_visual()
	player_target.health_current = player_target.health_max
	prev_hp = player_target.health_current

	enemy_shooter._execute_tactical_shot()
	await get_root().get_tree().physics_frame

	var dmg_t5: float = prev_hp - player_target.health_current
	print("Damage to crouching target angled around cover: ", dmg_t5)
	_check(dmg_t5 > 0.0, "Crouching target angled around cover takes damage when line of sight is clear")

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
