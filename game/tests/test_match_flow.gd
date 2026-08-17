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

func _new_match(intro: bool) -> Match:
	var m: Match = (load("res://scenes/match.tscn") as PackedScene).instantiate() as Match
	m.intro_enabled = intro
	get_root().add_child(m)
	current_scene = m
	return m

## Forces all lobby slots to HUMAN so AI flags from a persisted settings.cfg
## cannot make the AI-controller steal terminals mid-test (determinism).
func _force_all_human() -> void:
	var session: Node = get_root().get_node_or_null("GameConfig")
	if session == null:
		return
	session.call("reset_slots_to_defaults")
	for p_id: int in range(1, 5):
		var slot: Variant = session.call("get_slot", p_id)
		if slot != null and slot.get("control_mode") != null:
			slot.control_mode = 0  # SessionConfig.ControlMode.HUMAN

func run_test() -> void:
	print("== MATCH FLOW TEST ==")
	# Deterministic: ignore any persisted lobby AI flags so P2/P3/P4 stay passive.
	_force_all_human()
	await _test_arena_layout()
	await _test_match_spawns_compat()
	await _test_intro_flow()
	await _test_match_admin()
	await _test_sprint_objectives()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)

func _test_arena_layout() -> void:
	print("--- [1] Arena layout (ARENA-ALPHA) ---")
	var arena: Arena = (load("res://scenes/arena.tscn") as PackedScene).instantiate() as Arena
	get_root().add_child(arena)
	for i in 3:
		await physics_frame

	_check(arena.get_arena_center() == Vector3.ZERO, "arena center at origin")
	var spawns: Array[Node] = get_nodes_in_group(Arena.GROUP_SPAWN_POINTS)
	_check(spawns.size() == 4, "arena has 4 spawn points (got %d)" % spawns.size())
	var terms: Array[Node] = get_nodes_in_group(Arena.GROUP_TERMINAL_IA)
	_check(terms.size() == 3, "arena has 3 IA terminals (got %d)" % terms.size())
	var rec: Array[Node] = get_nodes_in_group(Arena.GROUP_RECHARGE_POINTS)
	_check(rec.size() == 2, "arena has 2 recharge points (got %d)" % rec.size())
	var spons: Array[Node] = get_nodes_in_group(Arena.GROUP_SPONSORS)
	_check(spons.size() == 4, "arena has 4 sponsors (got %d)" % spons.size())
	_check(arena.get_cover_count() > 0, "arena has paintball covers (%d)" % arena.get_cover_count())
	_check(arena.get_bush_count() > 0, "arena has bushes (%d)" % arena.get_bush_count())

	for node in spawns:
		var sm: Marker3D = node as Marker3D
		if sm.name.begins_with("Spawn_Attackers_"):
			_check(sm.global_position.z > 0.0, "%s on attacker side (z=%.1f)" % [sm.name, sm.global_position.z])
		else:
			_check(sm.global_position.z < 0.0, "%s on defender side (z=%.1f)" % [sm.name, sm.global_position.z])

	for node in terms:
		var t: Node3D = node as Node3D
		if t.name.ends_with("_A"):
			_check(absf(t.global_position.x) < 2.0, "Terminal A at center (x=%.1f)" % t.global_position.x)
		elif t.name.ends_with("_B"):
			_check(t.global_position.x < 0.0, "Terminal B on left (x=%.1f)" % t.global_position.x)
		elif t.name.ends_with("_C"):
			_check(t.global_position.x > 0.0, "Terminal C on right (x=%.1f)" % t.global_position.x)

	arena.queue_free()
	for i in 2:
		await physics_frame

func _test_match_spawns_compat() -> void:
	print("--- [2] Match loads Arena + spawns operators (intro off) ---")
	var m: Match = _new_match(false)
	for i in 3:
		await physics_frame

	_check(m.get_phase() == Match.Phase.LIVE, "match is LIVE without intro")
	var arena: Arena = m.get_arena()
	_check(arena != null, "match loaded an Arena instance")
	_check(arena != null and arena.arena_display_name == "ARENA-ALPHA", "loaded arena is ARENA-ALPHA")
	_check(GameRules.get_rules(m) != null, "GameRules present in match tree")
	var pm: PlayerManager = m.get_player_manager()
	var ops: Array[OperatorBase] = pm.get_all_operators()
	_check(ops.size() == 4, "match spawned 4 operators (got %d)" % ops.size())
	for op in ops:
		if op.player_id <= 2:
			_check(op.global_position.z > 0.0, "P%d spawned attacker side (z=%.1f)" % [op.player_id, op.global_position.z])
		else:
			_check(op.global_position.z < 0.0, "P%d spawned defender side (z=%.1f)" % [op.player_id, op.global_position.z])
	_check(not ops[0].is_ai_controlled, "P1 has human control with intro off")
	_check(m.get_squad_hud() != null, "SquadHUD wired in match")
	var cam: CameraController = m.get_camera_controller()
	_check(cam != null and cam.targets.size() == 4, "camera tracks 4 targets (got %d)" % (cam.targets.size() if cam else -1))
	_check(get_nodes_in_group("game_rules").size() == 1, "exactly one GameRules in tree")

	var p1: OperatorBase = pm.get_operator(1)
	# P1 spawns inside the protected spawn room; step out before dealing damage.
	p1.global_position = Vector3(0.0, 0.0, 10.0)
	await physics_frame
	p1.take_damage(9999.0)
	await physics_frame
	_check(p1.is_dead, "operator can be incapacitated inside match")
	p1.respawn_timer = 0.01
	for i in 3:
		await physics_frame
	_check(not p1.is_incapacitated, "operator respawns via match GameRules")

	m.queue_free()
	for i in 2:
		await physics_frame

func _test_intro_flow() -> void:
	print("--- [3] Startup flow: LOADING splash -> countdown -> LIVE ---")
	var m: Match = _new_match(true)
	m.intro_time_scale = 20.0
	for i in 2:
		await physics_frame

	# The match boots into LOADING (splash) before the countdown. Operators are
	# visible throughout; no cinematic camera is created.
	_check(m.get_phase() == Match.Phase.LOADING, "match boots into LOADING phase")
	_check(m.find_child("IntroUI", true, false) != null, "intro UI overlay created")
	var p1: OperatorBase = m.get_player_manager().get_operator(1)
	var p1_mesh: MeshInstance3D = p1.get_node_or_null("MeshInstance3D") as MeshInstance3D
	_check(p1_mesh != null and p1_mesh.visible, "operators stay visible during loading")
	var cam: Camera3D = m.get_camera_controller().camera
	_check(cam != null and cam.current, "shared gameplay camera is current during loading")

	# Let the splash finish (2.0s sim / 20x) and reach the countdown.
	var guard: int = 0
	while m.get_phase() == Match.Phase.LOADING and guard < 30:
		await physics_frame
		guard += 1
	_check(m.get_phase() == Match.Phase.INTRO, "splash ends -> INTRO countdown (guard=%d)" % guard)

	var all_frozen: bool = true
	for op: OperatorBase in m.get_player_manager().get_all_operators():
		if not op.is_ai_controlled:
			all_frozen = false
	_check(all_frozen, "operators frozen during countdown")
	_check(p1_mesh != null and p1_mesh.visible, "operators remain visible during countdown")

	var seen_steps: Dictionary = {}
	guard = 0
	while m.get_phase() == Match.Phase.INTRO and guard < 200:
		seen_steps[m.get_intro_step()] = true
		await physics_frame
		guard += 1
	for i in 2:
		await physics_frame

	_check(m.get_phase() == Match.Phase.LIVE, "countdown reaches GO -> LIVE (guard=%d)" % guard)
	_check(m.is_live(), "match.is_live() true after GO")
	_check(seen_steps.has(Match.IntroStep.COUNTDOWN), "COUNTDOWN step reached")
	_check(seen_steps.has(Match.IntroStep.GO), "GO step reached")
	_check(p1_mesh != null and p1_mesh.visible, "operator never hidden across startup")
	_check(not p1.is_ai_controlled, "player control re-enabled only after GO")
	_check(cam != null and cam.current, "shared gameplay camera still current after GO")
	_check(m.get_match_time_left() <= m.match_duration_seconds, "match clock running after GO")

	m.queue_free()
	for i in 2:
		await physics_frame

func _test_match_admin() -> void:
	print("--- [4] Match administration: timer / score / end ---")
	var m: Match = _new_match(false)
	m.match_duration_seconds = 3.0
	for i in 3:
		await physics_frame

	var scores: Array = []
	m.score_changed.connect(func(team: int, sc: int) -> void: scores.append([team, sc]))
	m.add_score(OperatorBase.TEAM_ATTACKERS, 5)
	m.add_score(OperatorBase.TEAM_DEFENDERS, 3)
	_check(m.get_score(OperatorBase.TEAM_ATTACKERS) == 5, "attackers score 5")
	_check(m.get_score(OperatorBase.TEAM_DEFENDERS) == 3, "defenders score 3")
	_check(scores.size() == 2, "score_changed emitted twice (got %d)" % scores.size())

	var ended: Array = []
	m.match_ended.connect(func(win: int) -> void: ended.append(win))
	for i in 240:
		await physics_frame
	_check(m.get_phase() == Match.Phase.MATCH_END, "timer expiry ends the match")
	_check(ended.size() == 1, "match_ended emitted once (got %d)" % ended.size())
	_check(ended.size() == 1 and ended[0] == OperatorBase.TEAM_DEFENDERS, "timeout winner is defenders")
	_check(m.get_match_time_left() == 0.0, "match clock at zero at end")

	var all_frozen: bool = true
	for op in m.get_player_manager().get_all_operators():
		if not op.is_incapacitated:
			all_frozen = false
	_check(all_frozen, "operators frozen at match end")
	_check(m.find_child("MatchEndOverlay", true, false) != null, "end-of-match overlay shown")

	m.queue_free()
	for i in 2:
		await physics_frame

func _step_to(op: OperatorBase, target: Vector3) -> void:
	## Step the operator toward a terminal so the capture zone body_entered fires.
	op.velocity = Vector3.ZERO
	for i in range(16):
		var t: float = float(i + 1) / 16.0
		op.global_position = op.global_position.lerp(target, 0.5)
		for _f in range(2):
			await physics_frame

func _test_sprint_objectives() -> void:
	print("--- [5] Sprint: territory scoring + supremacy victory ---")
	var m: Match = _new_match(false)
	m.match_duration_seconds = 60.0
	m.supremacy_duration = 1.5
	for i in 5:
		await physics_frame

	var tm: TerminalManager = m.get_terminal_manager()
	var op1: OperatorBase = m.get_player_manager().get_operator(1)
	_check(tm != null and op1 != null, "match provides terminal manager + P1")
	var supremacy_label: Label = m.find_child("SupremacyLabel", true, false) as Label
	_check(supremacy_label != null and not supremacy_label.visible, "match HUD supremacy label hidden at start")

	# Let the CoreCaptureZone startup grace (0.5s) expire before any entry.
	for i in 45:
		await physics_frame

	# Speed up every terminal so each capture completes in ~1s.
	for letter: String in ["A", "B", "C"]:
		var core: AICore = tm.get_terminal("Terminal_%s" % letter)
		core.hack_controller.hack_speed_percent_per_second = 50.0
		core.hack_controller.capture_threshold_percent = 40.0

	# --- Hold Terminal A alone: territory score accrues +1/s ---
	var ta: Node3D = tm.get_terminal("Terminal_A")
	await _step_to(op1, ta.global_position + Vector3(2.0, 1.0, 2.0))
	for i in 120:
		await physics_frame
	_check(tm.get_state("Terminal_A") == HackController.CoreState.CAPTURED, "Terminal A CAPTURED")
	_check(tm.get_owning_team("Terminal_A") == OperatorBase.TEAM_ATTACKERS, "Terminal A owned by attackers")
	var score_1term: int = m.get_score(OperatorBase.TEAM_ATTACKERS)
	_check(score_1term >= 1, "territory scoring awards points while holding 1 terminal (%d)" % score_1term)

	# --- Add Terminal B: 2 held -> score rises faster ---
	var tb: Node3D = tm.get_terminal("Terminal_B")
	await _step_to(op1, tb.global_position + Vector3(2.0, 1.0, 2.0))
	for i in 120:
		await physics_frame
	_check(tm.get_state("Terminal_B") == HackController.CoreState.CAPTURED, "Terminal B CAPTURED")
	var score_2term: int = m.get_score(OperatorBase.TEAM_ATTACKERS)
	_check(score_2term > score_1term, "score grows while holding 2 terminals (%d -> %d)" % [score_1term, score_2term])

	# --- Capture Terminal C: all three held -> supremacy countdown -> victory ---
	var ended: Array = []
	m.match_ended.connect(func(win: int) -> void: ended.append(win))
	var tc: Node3D = tm.get_terminal("Terminal_C")
	await _step_to(op1, tc.global_position + Vector3(2.0, 1.0, 2.0))
	for i in 100:
		await physics_frame
	_check(supremacy_label != null and supremacy_label.visible, "supremacy counter visible while holding all terminals")
	if supremacy_label != null:
		_check(supremacy_label.text.begins_with("SUPREMACÍA"), "supremacy label reads 'SUPREMACÍA' ('%s')" % supremacy_label.text)
	for i in 200:
		await physics_frame
	_check(m.get_phase() == Match.Phase.MATCH_END, "supremacy ends the match")
	_check(ended.size() == 1 and ended[0] == OperatorBase.TEAM_ATTACKERS, "supremacy winner is attackers")
	_check(m.get_match_time_left() > 0.0, "match ends by supremacy, not timeout (%.1fs left)" % m.get_match_time_left())

	m.queue_free()
	for i in 2:
		await physics_frame
