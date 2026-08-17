# test_kb_mouse_aim.gd
# Technical Rationale: Regression test for the keyboard+mouse "aim camera" pass.
# P1 (keyboard+mouse) aims with the cursor: the cursor projects onto the
# operator's floor plane and the canonical aim turns toward that world point
# (full 360°). RMB (aim_cone) shows the SAME tactical cone as the gamepad
# right-stick mode WITHOUT entering PRECISION_AIM (rotation/movement stay
# normal). LMB (fire) drives the existing AUTO_AIM channel but is cone-
# constrained: only enemies inside the shown cone can be locked, and autoaim
# NEVER auto-fires for a mouse player (LMB drives the shot, no double-fire).
# Pure-keyboard (P2..P4) and gamepad players are NOT mouse players.
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

## Stubbed InputManager: deterministic device mirrors (KEYBOARD_MOUSE for P1/P2,
## GAMEPAD for P3) that survive _ready's mirror resync, plus configurable held
## actions. No live input or GameConfig-dependent mirror state.
class StubInput:
	extends InputManager
	var fire_held: bool = false
	var aim_held: bool = false
	var cone_held: bool = false
	var aim_vec: Vector2 = Vector2.ZERO
	var move_vec: Vector2 = Vector2.ZERO

	func _init() -> void:
		var p1: PlayerInputProfile = PlayerInputProfile.new()
		p1.device_type = PlayerInputProfile.DeviceType.KEYBOARD_MOUSE
		_profiles[1] = p1
		var p2: PlayerInputProfile = PlayerInputProfile.new()
		p2.device_type = PlayerInputProfile.DeviceType.KEYBOARD_MOUSE
		_profiles[2] = p2
		var p3: PlayerInputProfile = PlayerInputProfile.new()
		p3.device_type = PlayerInputProfile.DeviceType.GAMEPAD
		_profiles[3] = p3

	# Keep the mirrors set in _init (base _ready would resync them from GameConfig).
	func _initialize_profiles() -> void:
		pass

	func _sync_device_mirrors() -> void:
		pass

	func is_action_pressed(_player_id: int, action: String) -> bool:
		if action == "fire":
			return fire_held
		if action == "autoaim":
			return aim_held
		if action == "aim_cone":
			return cone_held
		return false

	func get_aim_vector(_player_id: int) -> Vector2:
		return aim_vec

	func get_movement_vector(_player_id: int) -> Vector2:
		return move_vec

## Forces the authoritative GameConfig profiles to a deterministic state for the
## test (P1 keyboard+mouse, P2 keyboard) without persisting anything.
func _force_gameconfig_profiles(cfg: Node) -> void:
	var p1: InputProfile = cfg.call("get_profile", 1) as InputProfile
	p1.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
	p1.reset_defaults()
	var p2: InputProfile = cfg.call("get_profile", 2) as InputProfile
	p2.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
	p2.reset_defaults()

func run_test() -> void:
	print("== KEYBOARD+MOUSE AIM / AIM-CONE TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	var stub: StubInput = StubInput.new()
	root.add_child(stub)

	var cfg: Node = get_root().get_node_or_null("GameConfig")
	_check(cfg != null, "GameConfig autoload present in tree")
	if cfg != null:
		_force_gameconfig_profiles(cfg)

	# ── [1] P1 keyboard+mouse default bindings (from InputProfile data) ──
	print("--- [1] P1 keyboard defaults: LMB fire, RMB aim_cone, KB utilities ---")
	var prof: InputProfile = InputProfile.new()
	prof.player_id = 1
	prof.set_device(InputProfile.DeviceKind.KEYBOARD, -1)
	prof.reset_defaults()
	var fire_ev: InputEventMouseButton = prof.get_events("fire")[0] as InputEventMouseButton
	_check(fire_ev != null and fire_ev.button_index == MOUSE_BUTTON_LEFT,
		"P1 fire defaults to MOUSE_BUTTON_LEFT")
	var cone_ev: InputEventMouseButton = prof.get_events("aim_cone")[0] as InputEventMouseButton
	_check(cone_ev != null and cone_ev.button_index == MOUSE_BUTTON_RIGHT,
		"P1 aim_cone defaults to MOUSE_BUTTON_RIGHT (aim camera)")
	_check(not prof.has_binding("autoaim"), "P1 keyboard has NO autoaim binding (LMB replaces it)")
	var dash_ev: InputEventKey = prof.get_events("dash")[0] as InputEventKey
	_check(dash_ev != null and dash_ev.keycode == KEY_SHIFT, "P1 dash defaults to SHIFT")
	var drone_ev: InputEventKey = prof.get_events("drone_mode")[0] as InputEventKey
	_check(drone_ev != null and drone_ev.keycode == KEY_SPACE, "P1 drone_mode defaults to SPACE")
	var ability_ev: InputEventKey = prof.get_events("ability")[0] as InputEventKey
	_check(ability_ev != null and ability_ev.keycode == KEY_E, "P1 ability defaults to E")

	# ── [2] Mouse-player detection: keyboard+mouse yes, pure-keyboard no, pad no ──
	print("--- [2] _is_using_mouse() detection ---")
	var player: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	player.player_id = 1
	player.team_id = OperatorBase.TEAM_ATTACKERS
	player.position = Vector3(0.0, 0.0, 0.0)
	player._input_manager = stub
	root.add_child(player)
	player.set_physics_process(false)

	var p2: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	p2.player_id = 2
	p2.team_id = OperatorBase.TEAM_ATTACKERS
	p2.position = Vector3(40.0, 0.0, 0.0)
	p2._input_manager = stub
	root.add_child(p2)
	p2.set_physics_process(false)

	var p3: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	p3.player_id = 3
	p3.team_id = OperatorBase.TEAM_ATTACKERS
	p3.position = Vector3(40.0, 0.0, 40.0)
	p3._input_manager = stub
	root.add_child(p3)
	p3.set_physics_process(false)

	for i in range(8):
		await get_root().get_tree().physics_frame

	_check(player.weapon != null, "player weapon is the GRAVITY-1 profile")
	_check(player._is_using_mouse(), "P1 (keyboard+mouse, LMB fire) IS a mouse player")
	_check(not p2._is_using_mouse(), "P2 pure-keyboard is NOT a mouse player (KB_MOUSE mirror alone is not enough)")
	_check(not p3._is_using_mouse(), "P3 gamepad mirror is NOT a mouse player")

	# ── [3] Cursor -> floor projection steers the aim (full 360°) ──
	print("--- [3] Mouse aim: cursor projected onto the floor plane ---")
	var cam: Camera3D = Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 20.0
	cam.position = Vector3(0.0, 30.0, 0.0)
	cam.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	root.add_child(cam)
	player._mouse_camera_override = cam

	var view_size: Vector2 = get_root().get_visible_rect().size
	var center: Vector2 = view_size * 0.5
	var cursors: Array[Vector2] = [
		center + Vector2(0.0, -200.0),  # screen-up -> world north (-Z)
		center + Vector2(200.0, 0.0),   # screen-right -> world east (+X)
		center + Vector2(-200.0, 0.0),  # screen-left -> world west (-X)
		center + Vector2(0.0, 200.0)    # screen-down -> world south (+Z)
	]
	var cursor_labels: Array[String] = ["north", "east", "west", "south"]
	for idx: int in range(cursors.size()):
		var cursor: Vector2 = cursors[idx]
		player._mouse_cursor_override = cursor
		var world: Vector3 = OperatorBase._project_cursor_to_floor(cam, cursor, player.global_position.y)
		var finite: bool = world.is_finite()
		var local: Vector3 = world - player.global_position
		local.y = 0.0
		var target_yaw: float = atan2(-local.x, -local.z)
		_check(finite and local.length_squared() > 0.0001,
			"%s cursor projects to a finite floor point" % cursor_labels[idx])
		player.aim_yaw = wrapf(target_yaw + PI, -PI, PI)
		player._aim_source = OperatorBase.AimSource.MOVEMENT
		for i: int in range(40):
			player._update_aim(0.03)
		_check(absf(wrapf(player.aim_yaw - target_yaw, -PI, PI)) < 0.02,
			"%s cursor: aim converges onto the projected world point" % cursor_labels[idx])
		_check(player._aim_source == OperatorBase.AimSource.MOUSE,
			"%s cursor: aim source is MOUSE after mouse steering" % cursor_labels[idx])
	_check(player._mouse_aim_active, "mouse aim channel is active after cursor steering")
	_check(not player._gamepad_aim_active, "mouse aim never touches the gamepad aim channel")

	# Ground truth for ONE known case: an ortho camera looking straight down maps
	# screen-right to world +X, so the east cursor MUST project with x > 0.
	player._mouse_cursor_override = center + Vector2(200.0, 0.0)
	var east_world: Vector3 = OperatorBase._project_cursor_to_floor(cam, center + Vector2(200.0, 0.0), 0.0)
	_check(east_world.x > 2.0, "east cursor projects to world +X (ground-truth camera mapping)")

	# ── [4] RMB aim_cone: tactical cone WITHOUT PRECISION_AIM, normal speeds ──
	print("--- [4] RMB cone: visible, FREE_AIM, normal rotation/movement speed ---")
	stub.cone_held = true
	for i: int in range(6):
		player._update_precision_aim()
	_check(player._mouse_cone_active, "RMB held sets _mouse_cone_active")
	_check(player._mouse_cone_blend > 0.5, "RMB held fades the mouse cone blend in")
	_check(player._aim_state == OperatorBase.AimState.FREE_AIM, "RMB never enters PRECISION_AIM")
	_check(player._get_effective_movement_mult() == 1.0, "RMB keeps movement speed at 1.0")
	_check(absf(player._get_effective_rotation_speed() - player.rotation_speed) < 0.001,
		"RMB keeps rotation speed at the FREE_AIM value")
	var tactical_cone: MeshInstance3D = player._tactical_cone as MeshInstance3D
	_check(tactical_cone != null and tactical_cone.visible, "RMB shows the tactical cone")

	# Cone geometry faces the authoritative aim_direction (single source of truth).
	if tactical_cone != null and tactical_cone.mesh != null:
		var verts: PackedVector3Array = tactical_cone.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array
		var avg: Vector3 = Vector3.ZERO
		var n: int = 0
		for v: Vector3 in verts:
			if Vector2(v.x, v.z).length_squared() > 1.0:
				avg += v
				n += 1
		if n > 0:
			avg /= float(n)
			var cone_dir: Vector3 = Vector3(avg.x, 0.0, avg.z).normalized()
			_check(cone_dir.angle_to(player.aim_direction) < 0.35,
				"cone fan geometry points along aim_direction (single source of truth)")
		else:
			_check(false, "cone mesh produced no far vertices to measure")
	else:
		_check(false, "tactical cone mesh exists for geometry check")

	# One-frame rotation check: a single mouse-aim step must move by the FREE_AIM
	# factor (rotation_speed * 1/60), NOT the PRECISION_AIM factor.
	player.aim_yaw = 0.0
	player._sync_aim_direction()
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._mouse_cursor_override = center + Vector2(200.0, 0.0)  # target -PI/2 (east)
	player._update_aim(0.03)
	var expected_move: float = (-PI * 0.5) * (player.rotation_speed * player.get_physics_process_delta_time())
	_check(absf(player.aim_yaw - expected_move) < 0.02,
		"one RMB+aim frame moves at FULL rotation speed (%.3f rad, not precision-scaled)" % player.aim_yaw)

	# RMB release fades the cone back out and hides it.
	stub.cone_held = false
	for i: int in range(30):
		player._update_precision_aim()
	_check(not player._mouse_cone_active, "RMB released clears _mouse_cone_active")
	_check(player._mouse_cone_blend < 0.01, "RMB released fades the mouse cone blend out")
	if tactical_cone != null:
		_check(not tactical_cone.visible, "RMB released hides the tactical cone")

	# ── [5] LMB fire -> cone-constrained AUTO_AIM acquisition ──
	print("--- [5] LMB autoaim: locks ONLY enemies inside the shown cone ---")
	var enemy1: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	enemy1.player_id = 4
	enemy1.team_id = OperatorBase.TEAM_DEFENDERS
	enemy1.position = Vector3(8.0, 0.0, 0.0)   # east -> INSIDE cone when aiming east
	root.add_child(enemy1)

	var enemy2: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	enemy2.player_id = 3
	enemy2.team_id = OperatorBase.TEAM_DEFENDERS
	enemy2.position = Vector3(0.0, 0.0, 8.0)   # +Z (south) -> OUTSIDE cone when aiming east (90 deg)
	root.add_child(enemy2)

	for i in range(8):
		await get_root().get_tree().physics_frame

	player.aim_yaw = 0.0
	player._sync_aim_direction()
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._autoaim_target = null
	stub.cone_held = true
	stub.aim_held = true
	stub.fire_held = true
	player._mouse_cursor_override = center + Vector2(200.0, 0.0)  # aim east
	for i: int in range(12):
		player._update_autoaim()
		player._update_aim(0.03)
	_check(player._aim_source == OperatorBase.AimSource.AUTO_AIM, "Focus / Auto-aim enters the AUTO_AIM channel")
	_check(player._autoaim_active, "Focus keeps autoaim active")
	_check(player._autoaim_target == enemy1, "Focus acquired the enemy INSIDE the cone (east)")
	var e1_yaw: float = atan2(-8.0, 0.0)
	_check(absf(wrapf(player.aim_yaw - e1_yaw, -PI, PI)) < 0.2, "Focus-steered aim points at the acquired enemy")

	# ── [6] Cone gates ACQUISITION in the opposite direction ──
	# While a lock is held the aim steers onto the target (so it stays in-cone by
	# construction); the cone constraint is what picks WHICH enemy can be locked.
	# Aiming south (+Z) must lock only the south enemy — the east one is outside.
	print("--- [6] Cone gates acquisition (aiming south: only the +Z enemy is lockable) ---")
	stub.fire_held = false
	stub.aim_held = false
	stub.cone_held = false
	player._update_autoaim()
	_check(player._aim_source == OperatorBase.AimSource.MOUSE, "release before re-aim returns to MOUSE")
	player.aim_yaw = 0.0
	player._sync_aim_direction()
	player._aim_source = OperatorBase.AimSource.MOVEMENT
	player._autoaim_target = null
	stub.cone_held = true
	stub.aim_held = true
	stub.fire_held = true
	player._mouse_cursor_override = center + Vector2(0.0, 200.0)  # aim south (+Z)
	for i: int in range(12):
		player._update_autoaim()
		player._update_aim(0.03)
	_check(player._autoaim_target == enemy2, "aiming south: Focus acquired the enemy INSIDE the cone (+Z)")
	_check(player._autoaim_target != enemy1, "aiming south: the east enemy was NOT acquired (outside the cone)")

	var e2_yaw: float = atan2(0.0, -8.0)
	_check(absf(wrapf(player.aim_yaw - e2_yaw, -PI, PI)) < 0.2, "aim steers onto the in-cone lock")
	_check(not player._is_valid_autoaim_target(enemy1),
		"east enemy is INVALID as a lock while aiming south (outside the cone)")

	# ── [7] Mouse autoaim NEVER auto-fires (LMB drives the shot) ──
	print("--- [7] No double-fire for mouse players ---")
	player.auto_fire_enabled = true
	_check(not player._autoaim_should_fire(), "mouse player never auto-fires, even with a valid lock + enabled auto-fire")

	# ── [8] Release: back to mouse aim, lock cleared ──
	print("--- [8] LMB release returns to mouse aim ---")
	stub.fire_held = false
	stub.aim_held = false
	stub.cone_held = false
	player.focus_timer = 0.0
	player._update_autoaim()
	_check(player._aim_source == OperatorBase.AimSource.MOUSE, "release returns the aim source to MOUSE")
	_check(not player._autoaim_active, "release clears autoaim active")
	_check(player._autoaim_target == null, "release drops the autoaim lock")


	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
