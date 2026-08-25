# test_drone_reveal_visibility.gd
# Focused contract test for DRONE-driven enemy-operator render visibility:
#   1. Enemy outside the drone's reveal circle -> hidden.
#   2. Enemy inside the drone's reveal circle -> visible.
#   3. Drone reveal radius = owner.reveal_radius x DRONE_REVEAL_FRACTION x 1.25.
#   4. Enemy leaving that circle -> hidden again.
#   5. Drone VisionCone3D.view_range (detection) stays 24.0 — untouched.
#   6. Operator reveal_radius stays 16.0 — untouched.
#   7. Human operator/teammate normal visibility unchanged; operator-only
#      reveal circles still work exactly as before.
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

func _mesh_visible(op: OperatorBase) -> Variant:
	var mesh: MeshInstance3D = op.get_node_or_null("MeshInstance3D") as MeshInstance3D
	return null if mesh == null else mesh.visible

func run_test() -> void:
	print("== DRONE REVEAL VISIBILITY TEST ==")
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
	fbox.size = Vector3(120.0, 1.0, 120.0)
	fshape.shape = fbox
	floor_body.add_child(fshape)
	root.add_child(floor_body)

	var reg: SquadVisionRegistry = SquadVisionRegistry.new()
	root.add_child(reg)

	var op_scene: PackedScene = preload("res://scenes/operator_placeholder.tscn")

	# P1 human at origin; P2 teammate nearby; P3/P4 enemies far south.
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
	p3.position = Vector3(0.0, 0.0, -44.0)
	root.add_child(p3)

	# P1's deployed drone, scouting far from its owner (>16m away so only the
	# drone's own circle can reach the enemy in scenario [2]).
	var drone: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	drone.operator = p1
	drone.position = Vector3(0.0, 2.4, -30.0)
	root.add_child(drone)

	for i: int in range(3):
		await physics_frame

	var dvc: VisionCone3D = drone.get_node_or_null("VisionCone3D") as VisionCone3D
	_check(dvc != null and is_equal_approx(dvc.view_range, 24.0), "drone view_range starts at 24.0 (detection)")
	var expected_r: float = p1.reveal_radius * FogOfWarDisplay.DRONE_REVEAL_FRACTION * SquadVisionRegistry.DRONE_RENDER_REVEAL_MULT
	_check(is_equal_approx(expected_r, 10.0), "new drone reveal radius == 16 * 0.50 * 1.25 == 10.0m")
	_check(is_equal_approx(p1.reveal_radius, 16.0), "operator reveal_radius still 16.0")

	print("--- [1] Enemy outside both circles ---")
	reg.sync_enemy_visibility()
	_check(_mesh_visible(p3) == false, "enemy at 44m from owner / 14m from drone -> HIDDEN (14 > 10)")
	_check(_mesh_visible(p1) == true and _mesh_visible(p2) == true, "own operator + teammate visible")

	print("--- [2] Enemy inside drone circle (outside operator circle) ---")
	drone.position = Vector3(0.0, 2.4, -36.0) # drone 8m from enemy; owner still 30m+ away
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh_visible(p3) == true, "enemy 8m from drone -> VISIBLE via drone reveal")

	print("--- [3] Just beyond the new radius ---")
	drone.position = Vector3(0.0, 2.4, -33.5) # 10.5m from enemy
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh_visible(p3) == false, "enemy 10.5m from drone -> HIDDEN (beyond 10m radius)")

	print("--- [4] Back inside, then out again ---")
	drone.position = Vector3(0.0, 2.4, -36.0)
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh_visible(p3) == true, "re-entering drone circle -> VISIBLE")
	drone.position = Vector3(20.0, 2.4, -20.0) # far from enemy
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh_visible(p3) == false, "leaving drone circle -> HIDDEN again")

	print("--- [5] Operator-only reveal unchanged ---")
	p3.position = Vector3(0.0, 0.0, 12.0) # 12m from P1 (inside 16m), 40m from drone
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh_visible(p3) == true, "enemy inside operator's 16m circle -> VISIBLE (no drone needed)")

	print("--- [6] Detection values untouched after all syncs ---")
	_check(dvc != null and is_equal_approx(dvc.view_range, 24.0), "drone view_range STILL 24.0")
	_check(is_equal_approx(p1.reveal_radius, 16.0), "reveal_radius STILL 16.0")

	# ── Teardown: restore lobby slot configuration ────────────────────────
	if session != null:
		for idx: int in range(4):
			session.get_slot(idx + 1).control_mode = saved_modes[idx]
			session.get_slot(idx + 1).team_id = saved_teams[idx]

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
