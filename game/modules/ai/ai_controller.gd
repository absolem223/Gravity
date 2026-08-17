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

var _match: Match = null
var _player_manager: PlayerManager = null
var _terminal_manager: TerminalManager = null
var _arena: Arena = null

## Eye height used for LoS combat checks.
const EYE_HEIGHT: float = 1.2
const TARGET_CENTER_HEIGHT: float = 1.0

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

func _physics_process(_delta: float) -> void:
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
			continue
		_drive_operator(op)

## ──────────────────────────────────────────────
## PER-OPERATOR DECISION
## ──────────────────────────────────────────────

func _drive_operator(op: OperatorBase) -> void:
	if op.is_in_spawn_zone():
		_leave_spawn(op)
		return

	var enemy: Node3D = _find_combat_target(op)
	if enemy != null:
		_engage_combat(op, enemy)
		return

	var objective: AICore = _select_objective(op)
	if objective == null:
		# No objective: hold position, keep facing current aim.
		op.ai_move_input = Vector2.ZERO
		op.ai_fire_input = false
		return
	_move_to_terminal(op, objective)

## ──────────────────────────────────────────────
## SPAWN EXIT
## ──────────────────────────────────────────────

## Moves the AI from its protected spawn room toward the arena floor. The spawn
## rooms sit at the arena extremes, so steering to the arena center always
## leaves the protected radius (own barrier is passable by its team).
func _leave_spawn(op: OperatorBase) -> void:
	var target: Vector3 = Vector3.ZERO
	if _arena != null:
		target = _arena.get_arena_center()
	_steer_toward(op, target, true)

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
func _move_to_terminal(op: OperatorBase, core: AICore) -> void:
	var to_core: Vector3 = core.global_position - op.global_position
	to_core.y = 0.0
	var dist: float = to_core.length()
	op.ai_fire_input = false
	if dist <= CAPTURE_APPROACH_RADIUS:
		# Inside the perimeter: stop and face the core.
		op.ai_move_input = Vector2.ZERO
		op.ai_aim_yaw = _yaw_to_point(op.global_position, core.global_position)
		return
	_steer_toward(op, core.global_position, false)

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
		if not _has_clear_los(op, other.global_position + Vector3(0.0, TARGET_CENTER_HEIGHT, 0.0)):
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
func _engage_combat(op: OperatorBase, enemy: Node3D) -> void:
	op.ai_move_input = Vector2.ZERO
	op.ai_aim_yaw = _yaw_to_point(op.global_position, enemy.global_position)
	op.ai_fire_input = true

## ──────────────────────────────────────────────
## STEERING HELPERS
## ──────────────────────────────────────────────

## Commands a straight-line move toward a world point, facing it. move_and_slide
## (in OperatorBase) handles barrier/cover sliding for this minimal AI.
func _steer_toward(op: OperatorBase, target: Vector3, keep_aim: bool) -> void:
	var to_target: Vector3 = target - op.global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		op.ai_move_input = Vector2.ZERO
		return
	var dir: Vector3 = to_target.normalized()
	op.ai_move_input = Vector2(dir.x, dir.z)
	if not keep_aim:
		op.ai_aim_yaw = _yaw_to_point(op.global_position, target)

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
	var eye: Vector3 = op.global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var los: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		op, eye, target_pos, [op.get_rid()], op.combat_collision_mask
	)
	return los.is_visible
