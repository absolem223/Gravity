# test_enemy_drone_reveal_visibility.gd
# Focused contract test for ENEMY DRONE render visibility:
#   1. Enemy drone outside ALL reveal sources -> hidden.
#   2. Enemy drone within 16m of a human operator -> visible.
#   3. Enemy drone within 10m of an allied drone (but >16m from operators) -> visible.
#   4. Allied drone reveal radius stays exactly 10m (16 * 0.50 * 1.25).
#   5. Enemy drone leaving all sources -> hidden again.
#   6. Drone VisionCone3D.view_range stays 24.0 (detection untouched).
#   7. Operator reveal_radius stays 16.0; own operator/teammate/own drone visible.
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

func _mesh(node: Node3D) -> Variant:
	var mesh: MeshInstance3D = node.get_node_or_null("MeshInstance3D") as MeshInstance3D
	return null if mesh == null else mesh.visible

func run_test() -> void:
	print("== ENEMY DRONE REVEAL VISIBILITY TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	# Lobby slots like the standard match: P1,P2 human team0; P3,P4 AI team1.
	var session: Node = get_root().get_node_or_null("GameConfig")
	var saved_modes: Array[int] = []
	var saved_teams: Array[int] = []
	if session != null:
		for p_id: int in [1, 2, 3, 4]:
			var slot: Variant = session.call("get_slot", p_id)
			saved_modes.append(int(slot.control_mode))
			saved_teams.append(int(slot.team_id))
		session.get_slot(1).control_mode = 0
		session.get_slot(2).control_mode = 0
		session.get_slot(3).control_mode = 1
		session.get_slot(4).control_mode = 1
		session.get_slot(1).team_id = 0
		session.get_slot(2).team_id = 0
		session.get_slot(3).team_id = 1
		session.get_slot(4).team_id = 1

	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var fshape: CollisionShape3D = CollisionShape3D.new()
	var fbox: BoxShape3D = BoxShape3D.new()
	fbox.size = Vector3(160.0, 1.0, 160.0)
	fshape.shape = fbox
	floor_body.add_child(fshape)
	root.add_child(floor_body)

	var reg: SquadVisionRegistry = SquadVisionRegistry.new()
	root.add_child(reg)

	var op_scene: PackedScene = preload("res://scenes/operator_placeholder.tscn")
	var drone_scene: PackedScene = preload("res://scenes/drone.tscn")

	var p1: OperatorBase = op_scene.instantiate() as OperatorBase
	p1.player_id = 1
	p1.team_id = OperatorBase.TEAM_ATTACKERS
	p1.is_ai_controlled = false
	p1.position = Vector3.ZERO
	root.add_child(p1)

	var p2: OperatorBase = op_scene.instantiate() as OperatorBase
	p2.player_id = 2
	p2.team_id = OperatorBase.TEAM_ATTACKERS
	p2.is_ai_controlled = false
	p2.position = Vector3(2.5, 0.0, 0.0)
	root.add_child(p2)

	var p3: OperatorBase = op_scene.instantiate() as OperatorBase
	p3.player_id = 3
	p3.team_id = OperatorBase.TEAM_DEFENDERS
	p3.is_ai_controlled = true
	p3.position = Vector3(-60.0, 0.0, -60.0) # enemy operator parked far away
	root.add_child(p3)

	# My allied scouting drone (human-owned -> valid reveal source, r=10m).
	var allied: DroneBase = drone_scene.instantiate() as DroneBase
	allied.operator = p1
	allied.position = Vector3(40.0, 2.4, 40.0) # parked far from all scenarios initially
	root.add_child(allied)

	# Enemy drone owned by the AI operator (render target under test).
	var foe: DroneBase = drone_scene.instantiate() as DroneBase
	foe.operator = p3
	foe.position = Vector3(0.0, 2.4, -44.0)
	root.add_child(foe)

	for i: int in range(3):
		await physics_frame

	var dvc: VisionCone3D = foe.get_node_or_null("VisionCone3D") as VisionCone3D
	_check(dvc != null and is_equal_approx(dvc.view_range, 24.0), "enemy drone view_range starts at 24.0")
	_check(is_equal_approx(SquadVisionRegistry.DRONE_RENDER_REVEAL_MULT, 1.25), "drone multiplier still 1.25")
	var expected_r: float = p1.reveal_radius * FogOfWarDisplay.DRONE_REVEAL_FRACTION * SquadVisionRegistry.DRONE_RENDER_REVEAL_MULT
	_check(is_equal_approx(expected_r, 10.0), "allied drone reveal radius == 10.0m exactly")

	print("--- [1] Outside all reveal sources ---")
	reg.sync_enemy_visibility()
	_check(_mesh(foe) == false, "enemy drone at (0,-44): 44m from ops / >30m from allied drone -> HIDDEN")
	_check(_mesh(allied) == true, "own drone always visible")
	_check(_mesh(p1) == true and _mesh(p2) == true, "own operator + teammate visible")

	print("--- [2] Inside my operator's 16m circle ---")
	foe.position = Vector3(0.0, 2.4, 12.0) # 12m from P1/P2
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh(foe) == true, "enemy drone 12m from operator -> VISIBLE")

	print("--- [3] Inside allied drone's 10m circle only ---")
	foe.position = Vector3(0.0, 2.4, -44.0) # 44m from every operator
	allied.position = Vector3(0.0, 2.4, -36.0) # 8m from foe, far from operators
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh(foe) == true, "enemy drone 8m from allied drone (>16m from ops) -> VISIBLE")

	print("--- [4] Just beyond the 10m allied radius ---")
	allied.position = Vector3(0.0, 2.4, -33.5) # 10.5m from foe, 33.5m from P1
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh(foe) == false, "enemy drone 10.5m from allied drone -> HIDDEN")

	print("--- [5] Re-enter then leave ---")
	allied.position = Vector3(0.0, 2.4, -36.0)
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh(foe) == true, "back inside allied radius -> VISIBLE")
	allied.position = Vector3(50.0, 2.4, 50.0)
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh(foe) == false, "allied drone gone away -> HIDDEN again")

	print("--- [6] Values untouched after all syncs ---")
	_check(dvc != null and is_equal_approx(dvc.view_range, 24.0), "enemy drone view_range STILL 24.0")
	_check(is_equal_approx(p1.reveal_radius, 16.0), "operator reveal_radius STILL 16.0")

	# ── Teardown: restore lobby slot configuration ────────────────────────
	if session != null:
		for idx: int in range(4):
			session.get_slot(idx + 1).control_mode = saved_modes[idx]
			session.get_slot(idx + 1).team_id = saved_teams[idx]

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
