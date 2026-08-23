# ai_controller.gd
# Technical Rationale: Minimal functional AI brain for the Vertical Slice.
# Drives every operator flagged is_ai_controlled through the OperatorBase AI
# drive hooks (ai_move_input / ai_aim_yaw / ai_fire_input). Behavior is kept
# deliberately simple per the sprint constraints: NO behavior trees, NO learning,
# NO optimization. The AI:
#   1. Leaves its protected spawn room on match start.
#   2. Captures a neutral terminal; if every neutral is taken, targets the
#      nearest ENEMY terminal (attack/recapture).
#   3. Fights any enemy (operator or drone) it sees in range with clear LoS.
#   4. Re-evaluates its objective every frame, so a terminal it "lost" is
#      automatically retargeted (and supremacy changes pick up instantly).
#   5. Keeps participating after death: OperatorBase respawns it and the brain
#      resumes driving from the spawn room.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name AIController
extends Node

## Distance at which the AI considers it "at" the terminal and stops to hack.
## Kept below the capture-zone half-extent (10x3x10 -> 5 m) so the operator is
## inside the perimeter and the HackController registers presence.
const CAPTURE_APPROACH_RADIUS: float = 3.0
## Margin over the weapon range used when deciding to open fire (the hitscan
## shot resolves inside _get_combat_range(), so we hold fire until inside it).
const COMBAT_RANGE_MARGIN: float = 0.0
## The GRAVITY-1 is SEMI_AUTO: evaluate_trigger() needs a fresh press edge per
## round, so the brain PULSES ai_fire_input (short synthetic press) once per
## weapon fire-rate window instead of holding it high. Holding would produce a
## single edge at engagement start and never fire again.
const FIRE_PULSE_PHYSICS_FRAMES: int = 2
## Gated diagnostic facility (opt-in): traces detection/engagement/trigger flow.
const AI_FIRE_DEBUG: bool = false

var _match: Match = null
var _player_manager: PlayerManager = null
var _terminal_manager: TerminalManager = null
var _arena: Arena = null

## Per-operator semi-auto cadence state: instance_id -> {"timer": float, "pulse": int}.
## timer counts down the current weapon fire-rate window; pulse > 0 holds the
## synthetic trigger press for that many remaining physics frames.
var _fire_cycle: Dictionary = {}

## Eye height used for LoS combat checks.
const EYE_HEIGHT: float = 1.2
const TARGET_CENTER_HEIGHT: float = 1.0

## Stuck detection and lateral recovery constants
const STUCK_CHECK_WINDOW: float = 0.5
const STUCK_MIN_DISPLACEMENT: float = 0.2
const STUCK_RECOVERY_DURATION: float = 0.8

## Per-operator stuck tracking state: op_id -> Dictionary
var _stuck_state: Dictionary = {}

func _ready() -> void:
	set_physics_process(true)

## Binds the controller to the owning Match and its subsystems.
func setup(match: Match) -> void:
	_match = match
	if match == null:
		return
	_player_manager = match.get_player_manager()
	_terminal_manager = match.get_terminal_manager()
	_arena = match.get_arena()

func _physics_process(delta: float) -> void:
	# Only drive while the match is live: during INTRO every operator is
	# temporarily marked AI to freeze control, and we must not move them then.
	if _match == null or not _match.is_live():
		return
	if _player_manager == null:
		return
	for op: OperatorBase in _player_manager.get_all_operators():
		if not op.is_ai_controlled:
			continue
		if op.is_incapacitated or op.is_dead:
			_clear_stuck_state(op)
			continue
		_drive_operator(op, delta)

## ──────────────────────────────────────────────
## PER-OPERATOR DECISION
## ──────────────────────────────────────────────

func _drive_operator(op: OperatorBase, delta: float) -> void:
	if op.is_in_spawn_zone():
		_clear_stuck_state(op)
		_leave_spawn(op, delta)
		return

	var enemy: Node3D = _find_combat_target(op)
	if enemy != null:
		_clear_stuck_state(op)
		_engage_combat(op, enemy, delta)
		return

	# Disengaged: clear the semi-auto cadence so the next engagement opens with
	# an immediate fresh trigger press (and no stale synthetic hold).
	_reset_fire_cycle(op)

	var objective: AICore = _select_objective(op)
	if objective == null:
		_clear_stuck_state(op)
		# No objective: hold position, keep facing current aim.
		op.ai_move_input = Vector2.ZERO
		op.ai_fire_input = false
		return
	_move_to_terminal(op, objective, delta)

## ──────────────────────────────────────────────
## SPAWN EXIT
## ──────────────────────────────────────────────

## Moves the AI from its protected spawn room toward the arena floor. The spawn
## rooms sit at the arena extremes, so steering to the arena center always
## leaves the protected radius (own barrier is passable by its team).
func _leave_spawn(op: OperatorBase, delta: float) -> void:
	var target: Vector3 = Vector3.ZERO
	if _arena != null:
		target = _arena.get_arena_center()
	_steer_toward(op, target, true, delta)

## ──────────────────────────────────────────────
## OBJECTIVE SELECTION
## ──────────────────────────────────────────────

## Picks the AI's capture objective: a neutral terminal first, otherwise the
## nearest ENEMY terminal. Terminals owned by the AI's own team are ignored so
## the AI keeps pushing/retaking instead of sitting on captured objectives.
## Re-evaluated every frame -> instant retarget when an objective is lost.
func _select_objective(op: OperatorBase) -> AICore:
	if _terminal_manager == null:
		return null
	var best_neutral: AICore = null
	var best_neutral_dist: float = INF
	var best_enemy: AICore = null
	var best_enemy_dist: float = INF
	for core: AICore in _terminal_manager.get_terminals():
		if core == null:
			continue
		var owner: int = core.get_owning_team()
		if owner == op.team_id:
			continue
		var dist: float = op.global_position.distance_to(core.global_position)
		if owner == -1 and dist < best_neutral_dist:
			best_neutral = core
			best_neutral_dist = dist
		elif owner != -1 and dist < best_enemy_dist:
			best_enemy = core
			best_enemy_dist = dist
	# Neutral capture has priority over recapturing an enemy terminal.
	return best_neutral if best_neutral != null else best_enemy

## ──────────────────────────────────────────────
## TERMINAL MOVEMENT
## ──────────────────────────────────────────────

## Moves the AI onto the terminal's capture perimeter and stops there so the
## CoreCaptureZone registers presence and the hack progresses. Facing the core.
func _move_to_terminal(op: OperatorBase, core: AICore, delta: float) -> void:
	var to_core: Vector3 = core.global_position - op.global_position
	to_core.y = 0.0
	var dist: float = to_core.length()
	op.ai_fire_input = false
	if dist <= CAPTURE_APPROACH_RADIUS:
		_clear_stuck_state(op)
		# Inside the perimeter: stop and face the core.
		op.ai_move_input = Vector2.ZERO
		op.ai_aim_yaw = _yaw_to_point(op.global_position, core.global_position)
		return
	_steer_toward(op, core.global_position, false, delta)

## ──────────────────────────────────────────────
## COMBAT
## ──────────────────────────────────────────────

## Nearest enemy operator or drone within weapon range with clear LoS. The
## enemy's chest height is sampled to keep the raycast consistent with the
## actual hitscan damage path.
func _find_combat_target(op: OperatorBase) -> Node3D:
	var best: Node3D = null
	var best_dist: float = INF
	var max_range: float = op._get_combat_range() + COMBAT_RANGE_MARGIN

	for node: Node in get_tree().get_nodes_in_group("players"):
		if not (node is OperatorBase) or node.is_queued_for_deletion():
			continue
		var other: OperatorBase = node as OperatorBase
		if other == op or other.team_id == op.team_id:
			continue
		if other.is_incapacitated or other.is_dead:
			continue
		var dist: float = op.global_position.distance_to(other.global_position)
		if dist > max_range or dist >= best_dist:
			continue
		var target_h: float = other.get_vision_origin().y - other.global_position.y if other.has_method("get_vision_origin") else TARGET_CENTER_HEIGHT
		if not _has_clear_los(op, other.global_position + Vector3(0.0, target_h, 0.0)):
			continue
		best = other
		best_dist = dist

	for node: Node in get_tree().get_nodes_in_group("drones"):
		if not (node is DroneBase) or node.is_queued_for_deletion():
			continue
		var drone: DroneBase = node as DroneBase
		if drone.operator == null or drone.operator == op or drone.operator.team_id == op.team_id:
			continue
		var dist: float = op.global_position.distance_to(drone.global_position)
		if dist > max_range or dist >= best_dist:
			continue
		if not _has_clear_los(op, drone.global_position):
			continue
		best = drone
		best_dist = dist

	return best

## Stops and fires at the enemy (facing it), holding position during the fight.
## The operator weapon is SEMI_AUTO: FireMode.evaluate_trigger() only fires on
## a fresh press edge, so the brain PULSES ai_fire_input (a short synthetic
## press) once per weapon fire-rate window instead of holding it high — holding
## would produce a single edge at engagement start and never fire again. The
## shot itself flows through the normal OperatorBase pipeline (FireMode ->
## WeaponBase -> _execute_tactical_shot); the shared autoaim lock that resolves
## the hitscan onto the target's stance-aware position is maintained by
## OperatorBase._update_autoaim for AI-controlled operators.
func _engage_combat(op: OperatorBase, enemy: Node3D, delta: float) -> void:
	op.ai_move_input = Vector2.ZERO
	op.ai_aim_yaw = _yaw_to_point(op.global_position, enemy.global_position)
	var op_id: int = op.get_instance_id()
	var cycle: Dictionary = _fire_cycle.get(op_id, {"timer": 0.0, "pulse": 0})
	var timer: float = float(cycle["timer"]) - delta
	var pulse: int = int(cycle["pulse"])
	if pulse > 0:
		# Synthetic press held across FIRE_PULSE_PHYSICS_FRAMES so the operator
		# observes pressed=true then released=false: one clean SEMI_AUTO edge.
		op.ai_fire_input = true
		pulse -= 1
		if pulse == 0:
			timer = maxf(0.05, op._get_fire_rate())
	else:
		op.ai_fire_input = false
		if timer <= 0.0 and not op.is_in_spawn_zone():
			pulse = FIRE_PULSE_PHYSICS_FRAMES
			if AI_FIRE_DEBUG:
				print("[AIFireDebug] P%d trigger pulse at %s" % [op.player_id, enemy.name])
	_fire_cycle[op_id] = {"timer": timer, "pulse": pulse}

## Clears semi-auto cadence bookkeeping for an operator (disengagement).
func _reset_fire_cycle(op: OperatorBase) -> void:
	if op != null:
		_fire_cycle.erase(op.get_instance_id())

## ──────────────────────────────────────────────
## STEERING HELPERS & STUCK RECOVERY
## ──────────────────────────────────────────────

## Commands a straight-line move toward a world point, facing it. Includes
## lightweight stuck detection to apply a lateral detour when blocked by cover.
func _steer_toward(op: OperatorBase, target: Vector3, keep_aim: bool, delta: float) -> void:
	var to_target: Vector3 = target - op.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		op.ai_move_input = Vector2.ZERO
		_clear_stuck_state(op)
		return
	var dir: Vector3 = to_target.normalized()
	var desired_input: Vector2 = Vector2(dir.x, dir.z)

	_update_stuck_recovery(op, target, desired_input, delta)

	if not keep_aim:
		op.ai_aim_yaw = _yaw_to_point(op.global_position, target)

## Clears stuck tracking state for an operator.
func _clear_stuck_state(op: OperatorBase) -> void:
	if op != null:
		_stuck_state.erase(op.get_instance_id())

## Tracks AI operator displacement over 0.5s windows. If continuous movement fails
## to yield >= 0.2m displacement, triggers an 0.8s lateral detour (alternating sides).
func _update_stuck_recovery(op: OperatorBase, target: Vector3, desired_input: Vector2, delta: float) -> void:
	var op_id: int = op.get_instance_id()
	var state: Dictionary = _stuck_state.get(op_id, {})
	if state.is_empty():
		state = {
			"stuck_timer": 0.0,
			"start_pos": op.global_position,
			"recovery_timer": 0.0,
			"recovery_input": Vector2.ZERO,
			"side_toggle": -1.0
		}
		_stuck_state[op_id] = state

	var recovery_timer: float = state.get("recovery_timer", 0.0) as float
	if recovery_timer > 0.0:
		recovery_timer -= delta
		state["recovery_timer"] = maxf(0.0, recovery_timer)
		op.ai_move_input = state.get("recovery_input", desired_input) as Vector2
		if recovery_timer <= 0.0:
			state["stuck_timer"] = 0.0
			state["start_pos"] = op.global_position
		return

	var stuck_timer: float = state.get("stuck_timer", 0.0) as float
	var start_pos: Vector3 = state.get("start_pos", op.global_position) as Vector3

	stuck_timer += delta
	state["stuck_timer"] = stuck_timer

	if stuck_timer >= STUCK_CHECK_WINDOW:
		var dist: float = op.global_position.distance_to(start_pos)
		if dist < STUCK_MIN_DISPLACEMENT:
			var prev_side: float = state.get("side_toggle", -1.0) as float
			var new_side: float = -1.0 if prev_side > 0.0 else 1.0
			state["side_toggle"] = new_side
			var lateral_dir: Vector2 = Vector2(-desired_input.y, desired_input.x) * new_side
			state["recovery_timer"] = STUCK_RECOVERY_DURATION
			state["recovery_input"] = lateral_dir
			state["stuck_timer"] = 0.0
			op.ai_move_input = lateral_dir
		else:
			state["stuck_timer"] = 0.0
			state["start_pos"] = op.global_position
			op.ai_move_input = desired_input
	else:
		op.ai_move_input = desired_input

## Yaw (radians) that makes aim_direction point at `point` from `from`.
func _yaw_to_point(from: Vector3, point: Vector3) -> float:
	var dir: Vector3 = point - from
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		return 0.0
	dir = dir.normalized()
	return atan2(-dir.x, -dir.z)

## LoS ray from the operator's eye to a target chest position, using the
## operator's combat collision mask (same path as the real shots).
func _has_clear_los(op: OperatorBase, target_pos: Vector3) -> bool:
	var eye: Vector3 = op.get_vision_origin() if op.has_method("get_vision_origin") else op.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var los: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		op, eye, target_pos, [op.get_rid()], op.combat_collision_mask
	)
	return los.is_visible

