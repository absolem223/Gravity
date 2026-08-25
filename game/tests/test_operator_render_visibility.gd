# test_operator_render_visibility.gd
# Focused contract test for the enemy-operator RENDER visibility policy:
#   - Enemy operators render ONLY inside a human operator's Fog-of-War reveal
#     circle (reveal_radius, XZ geometry — same circles FogOfWarDisplay paints).
#   - Own-team operators always render.
#   - Observing teams come from the authoritative GameConfig lobby slots, so
#     enemies stay hidden during a simulated pre-match AI freeze.
#   - Detection state (_team_detected / is_entity_detected_by_team) is NOT
#     touched by render filtering.
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
	print("== OPERATOR RENDER VISIBILITY TEST ==")
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	# ── Configure lobby slots like the standard match setup ──────────────
	# P1,P2 = Team 0 HUMAN | P3,P4 = Team 1 AI. Originals restored at the end.
	var session: Node = get_root().get_node_or_null("GameConfig")
	var saved_modes: Array[int] = []
	var saved_teams: Array[int] = []
	if session != null:
		for p_id: int in [1, 2, 3, 4]:
			var slot: Variant = session.call("get_slot", p_id)
			saved_modes.append(int(slot.control_mode))
			saved_teams.append(int(slot.team_id))
		session.get_slot(1).control_mode = 0 # HUMAN
		session.get_slot(2).control_mode = 0 # HUMAN
		session.get_slot(3).control_mode = 1 # AI
		session.get_slot(4).control_mode = 1 # AI
		session.get_slot(1).team_id = 0
		session.get_slot(2).team_id = 0
		session.get_slot(3).team_id = 1
		session.get_slot(4).team_id = 1

	# Floor so operators rest on ground.
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.name = "Floor"
	floor_body.position = Vector3(0.0, -0.5, 0.0)
	var fshape: CollisionShape3D = CollisionShape3D.new()
	var fbox: BoxShape3D = BoxShape3D.new()
	fbox.size = Vector3(120.0, 1.0, 120.0)
	fshape.shape = fbox
	floor_body.add_child(fshape)
	root.add_child(floor_body)

	# Registry under test.
	var reg: SquadVisionRegistry = SquadVisionRegistry.new()
	root.add_child(reg)

	var op_scene: PackedScene = preload("res://scenes/operator_placeholder.tscn")
	var p1: OperatorBase = op_scene.instantiate() as OperatorBase
	p1.player_id = 1
	p1.team_id = OperatorBase.TEAM_ATTACKERS
	p1.is_ai_controlled = false
	p1.position = Vector3(0.0, 0.0, 20.0)
	root.add_child(p1)

	var p2: OperatorBase = op_scene.instantiate() as OperatorBase
	p2.player_id = 2
	p2.team_id = OperatorBase.TEAM_ATTACKERS
	p2.is_ai_controlled = false
	p2.position = Vector3(2.5, 0.0, 20.0)
	root.add_child(p2)

	var p3: OperatorBase = op_scene.instantiate() as OperatorBase
	p3.player_id = 3
	p3.team_id = OperatorBase.TEAM_DEFENDERS
	p3.is_ai_controlled = true
	p3.position = Vector3(0.0, 0.0, -24.0)
	root.add_child(p3)

	for i: int in range(3):
		await physics_frame

	print("--- [1] Enemy far outside reveal area ---")
	reg.sync_enemy_visibility()
	var m3: Variant = _mesh_visible(p3)
	_check(m3 == false, "enemy at 44m is HIDDEN (outside 16m reveal)")
	_check(_mesh_visible(p1) == true, "own operator stays visible")
	_check(_mesh_visible(p2) == true, "teammate stays visible")

	print("--- [2] Enemy enters the 16m reveal circle ---")
	p3.position = Vector3(0.0, 0.0, 10.0) # 10m from P1
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh_visible(p3) == true, "enemy at 10m becomes VISIBLE")

	print("--- [3] Enemy leaves the reveal circle ---")
	p3.position = Vector3(0.0, 0.0, -24.0)
	for i: int in range(2):
		await physics_frame
	reg.sync_enemy_visibility()
	_check(_mesh_visible(p3) == false, "enemy back at 44m is HIDDEN again")

	print("--- [4] Simulated pre-match AI freeze (LOADING/INTRO) ---")
	# Match temporarily forces is_ai_controlled=true on EVERYONE. Observing
	# teams must still resolve via GameConfig lobby slots (P1,P2 = human team 0).
	p1.is_ai_controlled = true
	p2.is_ai_controlled = true
	p3.is_ai_controlled = true
	reg.sync_enemy_visibility()
	if session != null:
		_check(_mesh_visible(p3) == false, "pre-match: enemy hidden despite global AI freeze")
		_check(_mesh_visible(p1) == true, "pre-match: own operator visible via lobby config")
	else:
		print("  [SKIP] GameConfig unavailable — pre-match assertions skipped")

	print("--- [5] Detection API untouched by render filtering ---")
	p3.is_ai_controlled = true
	_check(reg.is_entity_detected_by_team(p3, OperatorBase.TEAM_ATTACKERS) == false,
		"is_entity_detected_by_team still answers false with no vision providers")
	_check(reg.get_all_squad_detected_targets().is_empty(), "detection union empty without providers")

	# ── Teardown: restore lobby slot configuration ────────────────────────
	if session != null:
		for idx: int in range(4):
			session.get_slot(idx + 1).control_mode = saved_modes[idx]
			session.get_slot(idx + 1).team_id = saved_teams[idx]

	root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)
