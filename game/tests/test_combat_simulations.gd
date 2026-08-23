# test_combat_simulations.gd
# Technical Rationale: Combat BASELINE simulations (GRAVITY v0.95 audit, Phase 9).
# Runs deterministic encounters through the REAL damage pipeline (no fake
# modifiers): operator hitscan (_apply_mitigated_damage) and drone hitscan
# (_apply_combat_damage) must reach the same take_damage() path used in live
# matches, so the printed damage values and TTK math are the current game values.
# This test MEASURES and LOCKS the current balance; it does not change it.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

func _init() -> void:
	print("--- COMBAT BASELINE SIMULATIONS (Phase 9) ---")
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

## Instantiates an operator with a fixed player_id (auto-assigns the default role
## and applies its passives) and positions it in the world.
func _make_op(player_id: int, team: int, pos: Vector3, root: Node3D) -> OperatorBase:
	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = player_id
	op.team_id = team
	op.position = pos
	root.add_child(op)
	return op

## Awaits n physics frames so rigid bodies and static colliders register.
func _await_frames(n: int) -> void:
	for i: int in range(n):
		await get_root().get_tree().physics_frame

## Builds a cover wall (StaticBody3D + BoxShape3D) at the given center, sized so
## its top edge sits at `top_height`. Returns the body.
func _make_cover_wall(center: Vector3, top_height: float, root: Node3D) -> StaticBody3D:
	var body: StaticBody3D = StaticBody3D.new()
	body.collision_layer = 3
	body.collision_mask = 0
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(0.4, top_height, 4.0)
	shape.shape = box
	body.add_child(shape)
	body.position = center
	body.position.y = top_height * 0.5
	root.add_child(body)
	return body

func run_test() -> void:
	var root: Node3D = Node3D.new()
	get_root().add_child(root)

	# ── Encounter setup: P1 Recon (ATT) vs P2 Vanguard / P3 Disruptor / P4 Engineer (DEF) ──
	var p1: OperatorBase = _make_op(1, OperatorBase.TEAM_ATTACKERS, Vector3(-4.0, 0.0, 0.0), root)
	var p2: OperatorBase = _make_op(2, OperatorBase.TEAM_DEFENDERS, Vector3(4.0, 0.0, 0.0), root)
	var p3: OperatorBase = _make_op(3, OperatorBase.TEAM_DEFENDERS, Vector3(4.0, 0.0, 2.5), root)
	var p4: OperatorBase = _make_op(4, OperatorBase.TEAM_DEFENDERS, Vector3(4.0, 0.0, 5.0), root)
	await _await_frames(8)

	print("--- Survivability baseline (Phase 2) ---")
	_check(p2.health_max == 375.0, "Vanguard P2 HP base 375 (%.0f)" % p2.health_max)
	_check(absf(p2.damage_mitigation - 0.20) < 0.001,
		"Vanguard P2 mitigation 0.20 (%.2f)" % p2.damage_mitigation)
	_check(p1.health_max == 250.0 and p3.health_max == 250.0 and p4.health_max == 250.0,
		"Recon/Disruptor/Engineer HP base 250")
	_check(p1.weapon != null and p1.weapon.weapon_name == "GRAVITY-1", "P1 carries GRAVITY-1")
	_check(p1.weapon.base_damage == 18.0 and p1.weapon.range == 20.0,
		"GRAVITY-1 base 18 dmg / 20 m (%.0f/%.0f)" % [p1.weapon.base_damage, p1.weapon.range])
	_check(p1.weapon.fire_mode.fire_rate == 0.9, "GRAVITY-1 deliberate fire rate 0.9 s (%.1f s)" % p1.weapon.fire_mode.fire_rate)
	_check(p1.weapon.magazine.capacity == 30 and p1.weapon.reserve.max_magazines == 3,
		"GRAVITY-1 mag 30 / reserve 3 (120 rounds total)")

	print("--- Encounter A: P1(RECON) -> P2(VANGUARD) open field ---")
	var eye: Vector3 = p1.global_position + Vector3(0.0, 1.2, 0.0)
	var hp_before: float = p2.health_current
	p1._apply_mitigated_damage(p2, eye)
	var a_rate: float = p1.base_damage * (1.0 - p2.damage_mitigation) # 18 * 0.8 = 14.4
	print("    [probe] base 18.0 -> final %.2f/hit. HP %.0f -> %.0f. hits-to-kill = %d" % [
		a_rate, p2.health_max, p2.health_max, int(ceil(p2.health_max / a_rate))])
	_check(p2.health_current == hp_before - a_rate,
		"P2 Vanguard took 14.4 (18 * 0.80 mitigation) HP %.1f -> %.1f" % [hp_before, p2.health_current])

	print("--- Encounter B: P1 -> P3 (DISRUPTOR, no mitigation) ---")
	hp_before = p3.health_current
	p1._apply_mitigated_damage(p3, eye)
	_check(p3.health_current == hp_before - 18.0,
		"P3 Disruptor took full 18 (no mitigation) HP %.1f -> %.1f" % [hp_before, p3.health_current])

	print("--- Encounter C: P1 -> P4 (ENGINEER, no mitigation) ---")
	hp_before = p4.health_current
	p1._apply_mitigated_damage(p4, eye)
	_check(p4.health_current == hp_before - 18.0,
		"P4 Engineer took full 18 HP %.1f -> %.1f" % [hp_before, p4.health_current])

	print("--- Encounter D: AI uses the operator's OWN weapon (no separate enemy values) ---")
	_check(p3.weapon != null and p3.weapon.base_damage == 18.0,
		"AI enemy operator shares GRAVITY-1 18 dmg (%.0f)" % (p3.weapon.base_damage if p3.weapon else 0.0))
	var ai_op: OperatorBase = p3
	ai_op.is_ai_controlled = true
	ai_op.ai_aim_yaw = 0.0
	ai_op.ai_fire_input = true
	_check(ai_op._is_firing_input_active(), "AI operator reports fire input active via ai_fire_input")
	hp_before = p1.health_current
	var ai_eye: Vector3 = ai_op.global_position + Vector3(0.0, 1.2, 0.0)
	ai_op._apply_mitigated_damage(p1, ai_eye)
	_check(p1.health_current == hp_before - 18.0 * (1.0 - p1.damage_mitigation),
		"AI shot = operator shot: P1 took 18 over open field HP %.1f -> %.1f" % [hp_before, p1.health_current])

	print("--- Encounter E: Drone GRAVITY-D -> P2 (VANGUARD) 8 dmg base ---")
	var d1: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	d1.operator = p1
	d1.position = Vector3(-2.0, 0.6, 0.0)
	root.add_child(d1)
	await _await_frames(4)
	_check(d1.weapon != null and d1.weapon.weapon_name == "GRAVITY-D", "drone uses GRAVITY-D")
	_check(d1.weapon.base_damage == 8.0 and d1.weapon.range == 12.0,
		"GRAVITY-D base 8 dmg / 12 m (%.1f/%.1f)" % [d1.weapon.base_damage, d1.weapon.range])
	_check(d1.weapon.fire_mode.fire_rate == 0.6, "GRAVITY-D fire rate 0.6 s (100 RPM)")
	_check(d1.weapon.magazine.capacity == 16 and d1.weapon.reserve.max_magazines == 1,
		"GRAVITY-D mag 16 / reserve 1 (32 rounds total)")
	hp_before = p2.health_current
	d1._apply_combat_damage(p2, d1.global_position + Vector3(0.0, 0.6, 0.0))
	var drone_rate: float = 8.0 * (1.0 - p2.damage_mitigation) # 6.4
	_check(p2.health_current == hp_before - drone_rate,
		"drone -> Vanguard 6.4/hit (8 * 0.80) HP %.1f -> %.1f" % [hp_before, p2.health_current])

	print("--- Encounter F: P1 -> enemy Drone (operator can damage drones) ---")
	var d2: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	d2.operator = p3
	d2.position = Vector3(0.0, 1.2, 0.0)
	root.add_child(d2)
	await _await_frames(4)
	_check(d2.health_max == 500.0, "drone HP base 500 (%.0f)" % d2.health_max)
	hp_before = d2.health_current
	p1._apply_mitigated_damage(d2, eye)
	_check(d2.health_current == hp_before - 18.0,
		"operator hitscan damages drone: 500 -> 482 HP (%.1f)" % d2.health_current)
	d2.take_damage(482.0)
	_check(d2.health_current == 0.0 and d2.is_queued_for_deletion(),
		"drone destroyed at 0 HP (take_damage -> _destroy)")

	print("--- Encounter G: abilities deal ZERO HP damage ---")
	var p2_vanguard: VanguardOperator = p2.role as VanguardOperator
	_check(p2_vanguard != null, "Vanguard role attached to P2")
	hp_before = p2.health_current
	if p2_vanguard != null:
		p2_vanguard.try_activate_ability()
		_check(absf(p2_vanguard.get_cooldown_remaining() - 20.0) < 0.001,
			"FORTIFY cooldown 20 s")
		_check(absf(p2.damage_mitigation - 0.60) < 0.001,
			"FORTIFY raises mitigation to 0.60 (base 0.20 + 0.40)")
	_check(p2.health_current == hp_before, "FORTIFY causes zero HP damage")

	var p3_disruptor: DisruptorOperator = p3.role as DisruptorOperator
	_check(p3_disruptor != null, "Disruptor role attached to P3")
	hp_before = p3.health_current
	var enemy_drone_live: DroneBase = preload("res://scenes/drone.tscn").instantiate() as DroneBase
	enemy_drone_live.operator = p1
	# Parked beyond the GRAVITY-D engagement envelope (>12 m): with autonomous
	# companion combat active, a live enemy drone inside weapon range acquires
	# and shoots P3 during the await window below, which would contaminate the
	# zero-damage assertions. This encounter pins ABILITY damage-freeness, not
	# EMP radius interaction.
	enemy_drone_live.position = p3.global_position + Vector3(14.0, 0.6, 2.5)
	root.add_child(enemy_drone_live)
	await _await_frames(4)
	if p3_disruptor != null:
		p3_disruptor.try_activate_ability()
		_check(absf(p3_disruptor.get_cooldown_remaining() - 15.0) < 0.001, "EMP cooldown 15 s")
		_check(p3.health_current == hp_before, "EMP causes zero HP damage to the caster")
		_check(enemy_drone_live.health_current == enemy_drone_live.health_max,
			"EMP causes zero HP damage to drones (%d/%d)" % [
				int(enemy_drone_live.health_current), int(enemy_drone_live.health_max)])

	print("--- Encounter H: cover mitigation reduces damage (isolated scene) ---")
	# Isolate: operators auto-spawn a follow drone each, so we free the main root
	# and rebuild a clean pair (no drones / leftover colliders polluting cover rays).
	root.queue_free()
	await _await_frames(4)

	var cover_root: Node3D = Node3D.new()
	get_root().add_child(cover_root)
	var pca: OperatorBase = _make_op(1, OperatorBase.TEAM_ATTACKERS, Vector3(-4.0, 0.0, 0.0), cover_root)
	var pcb: OperatorBase = _make_op(2, OperatorBase.TEAM_DEFENDERS, Vector3(4.0, 0.0, 0.0), cover_root)
	await _await_frames(8)
	var ceye: Vector3 = pca.global_position + Vector3(0.0, 1.2, 0.0)

	var wall: StaticBody3D = _make_cover_wall(Vector3(-1.0, 0.0, 0.0), 0.9, cover_root)
	await _await_frames(4)
	var cover_val: float = LineOfSightQuery.check_cover_protection(
		pca, ceye,
		pcb.global_position + Vector3(0.0, 1.2, 0.0),
		pcb.global_position + Vector3(0.0, 0.1, 0.0),
		[pca.get_rid()]
	)
	print("    [probe] low-cover protection = %.2f" % cover_val)
	_check(absf(cover_val - 0.5) < 0.001, "low cover yields 0.5 protection (got %.2f)" % cover_val)
	hp_before = pcb.health_current
	pca._apply_mitigated_damage(pcb, ceye)
	var cover_final: float = 18.0 * (1.0 - cover_val) * (1.0 - pcb.damage_mitigation)
	print("    [probe] covered hit applied %.2f (cover %.2f)" % [hp_before - pcb.health_current, cover_val])
	_check(absf((hp_before - pcb.health_current) - cover_final) < 0.01,
		"covered shot = base*(1-cover)*(1-mit) (%.2f applied)" % (hp_before - pcb.health_current))
	wall.queue_free()
	await _await_frames(2)

	print("--- Encounter J: full-cover (1.0) blocks all damage (isolated header correct) ---")
	var wall_full: StaticBody3D = _make_cover_wall(Vector3(-1.0, 0.0, 0.0), 1.5, cover_root)
	await _await_frames(4)
	var cover_full: float = LineOfSightQuery.check_cover_protection(
		pca, ceye,
		pcb.global_position + Vector3(0.0, 1.2, 0.0),
		pcb.global_position + Vector3(0.0, 0.1, 0.0),
		[pca.get_rid()]
	)
	print("    [probe] full-cover protection = %.2f" % cover_full)
	_check(absf(cover_full - 1.0) < 0.001, "full cover yields 1.0 protection (got %.2f)" % cover_full)
	hp_before = pcb.health_current
	pca._apply_mitigated_damage(pcb, ceye)
	_check(pcb.health_current == hp_before, "full-cover shot deals zero damage")
	wall_full.queue_free()
	cover_root.queue_free()
	await _await_frames(4)

	print("--- Encounter K: friendly fire stays off by default (isolated same-team) ---")
	var team_root: Node3D = Node3D.new()
	get_root().add_child(team_root)
	var t1: OperatorBase = _make_op(1, OperatorBase.TEAM_ATTACKERS, Vector3(-4.0, 0.0, 0.0), team_root)
	var t2: OperatorBase = _make_op(4, OperatorBase.TEAM_ATTACKERS, Vector3(4.0, 0.0, 0.0), team_root)
	await _await_frames(8)
	hp_before = t2.health_current
	t1._apply_mitigated_damage(t2, t1.global_position + Vector3(0.0, 1.2, 0.0))
	_check(t2.health_current == hp_before, "attacker cannot damage teammate (FF defaults off)")

	print("--- Encounter I: defender inside its own spawn room is protected ---")
	var spawn_root: Node3D = Node3D.new()
	get_root().add_child(spawn_root)
	var zone: SpawnZone = SpawnZone.new()
	zone.team_id = OperatorBase.TEAM_DEFENDERS
	zone.position = Vector3(4.0, 0.0, 0.0)
	spawn_root.add_child(zone)
	var td: OperatorBase = _make_op(2, OperatorBase.TEAM_DEFENDERS, Vector3(4.0, 1.2, 0.0), spawn_root)
	var attacker: OperatorBase = _make_op(1, OperatorBase.TEAM_ATTACKERS, Vector3(-4.0, 1.2, 0.0), spawn_root)
	await _await_frames(8)
	# Neutralize the auto-spawned follow drones so they don't shove the operators
	# out of the protection volume during the (deterministic) spawn-protection check.
	if td.drone != null:
		td.drone.queue_free()
	if attacker.drone != null:
		attacker.drone.queue_free()
	await _await_frames(4)
	td.global_position = Vector3(4.0, 1.2, 0.0)
	attacker.global_position = Vector3(-4.0, 1.2, 0.0)
	await _await_frames(2)
	print("    [probe] td global_pos ", td.global_position, " team ", td.team_id)
	_check(td.is_in_spawn_zone(), "defender is inside its own spawn room")
	hp_before = td.health_current
	attacker._apply_mitigated_damage(td, attacker.global_position + Vector3(0.0, 1.2, 0.0))
	_check(td.health_current == hp_before, "spawn-protected operator takes zero incoming damage")

	spawn_root.queue_free()

	team_root.queue_free()
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)