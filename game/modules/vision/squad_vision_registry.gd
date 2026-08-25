# squad_vision_registry.gd
# Technical Rationale: Data layer for shared squad vision and tactical intelligence.
# Aggregates vision feeds from active Operators, Drones, and Stationary Cameras into
# a unified squad map, scoped per team so fog-of-war can be enforced.
# Arena Reconstruction v2 adds team-scoped detection and enemy visibility sync:
# an enemy operator/drone whose mesh is not detected by the friendly team's vision
# union is hidden (fog of war). Detection still respects the VisionCone3D LoS raycasts.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SquadVisionRegistry
extends Node

## Signal emitted when squad intelligence map is updated
signal squad_intel_updated(all_visible_targets: Array[Node3D])

## Registry of active VisionCone3D components contributing to squad vision
var _vision_providers: Array[VisionCone3D] = []

## Aggregated dictionary of currently detected targets with timestamp of detection
## (overall union across all teams — backward compatible with the HUD intel count).
var _squad_detected_targets: Dictionary = {}

## Per-team detected unions: team_id -> { target: timestamp }
var _team_detected: Dictionary = {}

## Throttle for the visibility sync pass.
var _visibility_sync_timer: float = 0.0
const VISIBILITY_SYNC_INTERVAL: float = 0.15

## Multiplier over the drone's existing VISUAL reveal radius (owner reveal_radius
## x FogOfWarDisplay.DRONE_REVEAL_FRACTION) used when a deployed drone acts as a
## render-reveal source for enemy operators. Detection (VisionCone3D.view_range)
## is NOT affected. 1.25 = +25% per design request.
const DRONE_RENDER_REVEAL_MULT: float = 1.25

func _ready() -> void:
	add_to_group("squad_vision_registry")
	# Deterministic visibility synchronization at lifecycle transitions (spawn,
	# LOADING/INTRO/LIVE phase changes) so enemy operators are hidden/found
	# immediately instead of waiting for the first periodic tick.
	call_deferred("_connect_lifecycle_signals")

## Connects to the Match phase signal and the PlayerManager spawn signal once,
## deferred, so current_scene and sibling nodes exist. Both connections are
## read-only observers: Match and PlayerManager behavior is never modified.
func _connect_lifecycle_signals() -> void:
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var sc: Node = tree.current_scene
	if sc != null and sc != self and sc.has_signal("phase_changed"):
		if not sc.is_connected("phase_changed", _on_match_phase_changed):
			sc.connect("phase_changed", _on_match_phase_changed)
	if sc != null:
		for child: Node in sc.get_children():
			if child is PlayerManager:
				if not child.is_connected("player_spawned", _on_player_spawned):
					child.connect("player_spawned", _on_player_spawned)
				break

## Immediate resync whenever the match phase changes (LOADING/INTRO/LIVE/END).
func _on_match_phase_changed(_phase: int) -> void:
	sync_enemy_visibility()

## Deferred resync when an operator spawns so its mesh starts in the correct
## visibility state (a fresh enemy spawn is hidden until revealed).
func _on_player_spawned(_p_id: int, _op: OperatorBase) -> void:
	call_deferred("sync_enemy_visibility")

func _process(delta: float) -> void:
	_visibility_sync_timer += delta
	if _visibility_sync_timer >= VISIBILITY_SYNC_INTERVAL:
		_visibility_sync_timer = 0.0
		sync_enemy_visibility()

## Registers a new vision provider (Operator vision cone, Drone vision cone, Stationary Camera).
## The owning team is resolved from the provider's parent chain when not provided.
func register_provider(provider: VisionCone3D, team_id: int = -1) -> void:
	if provider != null and not _vision_providers.has(provider):
		if team_id < 0:
			team_id = _resolve_provider_team(provider)
		_vision_providers.append(provider)
		if not provider.vision_updated.is_connected(_on_provider_vision_updated):
			provider.vision_updated.connect(_on_provider_vision_updated)

## Unregisters a vision provider (e.g. destroyed drone or incapacitated operator)
func unregister_provider(provider: VisionCone3D, _team_id: int = -1) -> void:
	if provider != null and _vision_providers.has(provider):
		_vision_providers.erase(provider)
		if provider.vision_updated.is_connected(_on_provider_vision_updated):
			provider.vision_updated.disconnect(_on_provider_vision_updated)
		_recalculate_squad_vision()

## Resolves the owning team of a provider from its parent chain
## (operator -> team_id, drone -> operator.team_id).
func _resolve_provider_team(provider: VisionCone3D) -> int:
	var p: Node = provider.get_parent()
	if p is OperatorBase:
		return (p as OperatorBase).team_id
	if p is DroneBase and (p as DroneBase).operator != null:
		return (p as DroneBase).operator.team_id
	return -1

## Callback when any registered provider updates its vision scan
func _on_provider_vision_updated(_targets: Array[Node3D]) -> void:
	_recalculate_squad_vision()

## Recalculates the union of all targets visible to the squad, both overall and
## scoped per team (fog of war source of truth).
func _recalculate_squad_vision() -> void:
	var new_union: Dictionary = {}
	var new_teams: Dictionary = {}

	for provider: VisionCone3D in _vision_providers:
		if is_instance_valid(provider) and provider.is_inside_tree():
			var team_id: int = _resolve_provider_team(provider)
			var detected: Array[Node3D] = provider.get_detected_targets()
			for target: Node3D in detected:
				if not is_instance_valid(target):
					continue
				new_union[target] = Time.get_ticks_msec()
				if team_id >= 0:
					var team_set: Dictionary = new_teams.get(team_id, {})
					team_set[target] = Time.get_ticks_msec()
					new_teams[team_id] = team_set

	_squad_detected_targets = new_union
	_team_detected = new_teams

	var target_list: Array[Node3D] = []
	for key: Node3D in _squad_detected_targets.keys():
		target_list.append(key)

	squad_intel_updated.emit(target_list)
	sync_enemy_visibility()

## Query: Is a specific entity currently detected by at least one squad vision source?
func is_entity_detected_by_squad(entity: Node3D) -> bool:
	return _squad_detected_targets.has(entity)

## Query: Is a specific entity detected by the vision union of a given team?
func is_entity_detected_by_team(entity: Node3D, team_id: int) -> bool:
	var team_set: Dictionary = _team_detected.get(team_id, {})
	return team_set.has(entity)

## Query: Returns array of all targets currently visible to the squad
func get_all_squad_detected_targets() -> Array[Node3D]:
	var list: Array[Node3D] = []
	for key: Variant in _squad_detected_targets.keys():
		if is_instance_valid(key):
			list.append(key as Node3D)
	return list

## ──────────────────────────────────────────────
## FOG OF WAR — ENEMY VISIBILITY SYNC
## ──────────────────────────────────────────────

## Hides enemy operators that are NOT inside any human operator's current
## Fog-of-War reveal area, and reveals them as soon as they enter it.
##
## Render-visibility policy (deliberately separate from DETECTION):
##   - Detection (VisionCone3D.view_range 32m/40m + LoS) is untouched and keeps
##     feeding _team_detected for intel/autoaim/AI. An enemy can be "detected"
##     at 32m yet not RENDERED because it stands outside the 16m reveal circle.
##   - Enemy operator render state follows the same ground-reveal geometry the
##     FogOfWarDisplay paints (reveal_radius circles around human operators).
##   - Own-team operators are always rendered (never fog-filtered).
##   - Drones (own AND enemy) are render targets against the same reveal
##     sources: own team -> visible; enemy drone -> inside a 16m operator
##     circle or an allied drone's 10m circle. Detection never renders.
##
## Performance contract: ONE pass per sync cycle collects the human operators
## AND their deployed drones as reveal sources; the per-entity test afterwards
## is a cheap XZ distance check against that small cached array (no nested
## group queries, no per-entity scans).
func sync_enemy_visibility() -> void:
	if not _should_sync_visibility():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var observing_teams: Array[int] = _observing_team_ids()
	if observing_teams.is_empty():
		return

	# Collected ONCE per cycle — never inside a per-entity loop.
	var sources: Array[Dictionary] = _collect_reveal_sources(tree)

	for node: Node in tree.get_nodes_in_group("players"):
		var op: OperatorBase = node as OperatorBase
		if op == null or op.is_queued_for_deletion():
			continue
		# Dead/downed operators are skipped by _apply_fog_visibility anyway.
		var shown: bool = false
		if not op.is_incapacitated:
			shown = _entity_render_visible(op.team_id, op.global_position, observing_teams, sources)
		_apply_fog_visibility(op, shown)
	for node: Node in tree.get_nodes_in_group("drones"):
		# Enemy drones are RENDER TARGETS evaluated against the SAME reveal
		# sources as operators: own team -> visible; else inside a human
		# operator's 16m circle or an allied drone's 10m circle. Detection
		# (view_range 24m) plays no role in render state.
		var drone: DroneBase = node as DroneBase
		if drone == null or drone.is_queued_for_deletion() or drone.operator == null:
			continue
		var shown_d: bool = _entity_render_visible(drone.operator.team_id, drone.global_position, observing_teams, sources)
		_apply_fog_visibility(drone, shown_d)

## Collects the Fog-of-War reveal sources for this sync cycle:
##   1. Every living, human-controlled operator (radius = reveal_radius).
##   2. Every deployed drone OWNED by a human operator on an observing team
##      (radius = owner.reveal_radius x DRONE_REVEAL_FRACTION x
##      DRONE_RENDER_REVEAL_MULT, i.e. the drone's existing visual ground-reveal
##      radius +25%). A drone inside its circle renders nearby enemy operators,
##      exactly like an operator does. Detection/view_range stay untouched.
## Two group queries per sync cycle total; no nested scans.
func _collect_reveal_sources(tree: SceneTree) -> Array[Dictionary]:
	var sources: Array[Dictionary] = []
	for node: Node in tree.get_nodes_in_group("players"):
		var op: OperatorBase = node as OperatorBase
		if op == null or op.is_queued_for_deletion() or op.is_ai_controlled or op.is_incapacitated:
			continue
		var r: float = op.reveal_radius
		sources.append({"team": op.team_id, "pos": op.global_position, "r2": r * r})
	for node: Node in tree.get_nodes_in_group("drones"):
		var d: DroneBase = node as DroneBase
		if d == null or not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		# Same ownership rule FogOfWarDisplay._feed_drone_vision uses: only
		# drones of HUMAN operators contribute (AI-owned drones reveal nothing).
		if d.operator == null or d.operator.is_ai_controlled:
			continue
		var dr: float = d.operator.reveal_radius * FogOfWarDisplay.DRONE_REVEAL_FRACTION * DRONE_RENDER_REVEAL_MULT
		sources.append({"team": d.operator.team_id, "pos": d.global_position, "r2": dr * dr})
	return sources

## Render-visibility decision for one RENDER TARGET (operator OR drone; cheap:
## no tree/group queries). Own team -> always visible. Otherwise visible iff
## inside the XZ reveal circle of a human operator (reveal_radius) or an allied
## human-owned drone (its +25% visual reveal radius) on an observing team.
## Mirrors FogOfWarDisplay's circle geometry, which tests dx/dz only.
func _entity_render_visible(owner_team: int, pos: Vector3, observing_teams: Array[int], sources: Array[Dictionary]) -> bool:
	if observing_teams.has(owner_team):
		return true
	for s: Dictionary in sources:
		if not observing_teams.has(int(s["team"])):
			continue
		var sp: Vector3 = s["pos"]
		var dx: float = pos.x - sp.x
		var dz: float = pos.z - sp.z
		if dx * dx + dz * dz <= float(s["r2"]):
			return true
	return false

## Teams that contain at least one human (non-AI) operator. Only these teams
## drive the fog-of-war decision on the shared local screen.
##
## Strategy 1 reads the AUTHORITATIVE lobby/session configuration (GameConfig
## autoload slots, the same source PlayerManager uses for slot.control_mode).
## This is immune to Match._start_loading()/_start_intro() temporarily forcing
## is_ai_controlled = true on every operator during LOADING/INTRO.
##
## Strategy 2 (fallback for sandbox/tests without a lobby config) scans the
## live operators' runtime AI flag — only reliable outside the pre-match freeze.
func _observing_team_ids() -> Array[int]:
	var teams: Array[int] = []
	var seen: Dictionary = {}
	var tree: SceneTree = get_tree()
	if tree == null:
		return teams

	# Strategy 1: session/lobby slots — authoritative human-team assignment.
	var session: Node = tree.root.get_node_or_null("GameConfig")
	if session != null and session.has_method("get_enabled_player_ids"):
		var enabled_ids: Array = session.call("get_enabled_player_ids")
		for p_id: int in enabled_ids:
			var slot: Variant = session.call("get_slot", p_id)
			if slot == null:
				continue
			# SessionConfig.ControlMode.HUMAN == 0 (AI == 1). Literal avoids a
			# hard dependency on the autoload script's class (none declared).
			if int(slot.control_mode) != 0:
				continue
			var t: int = int(slot.team_id)
			if not seen.has(t):
				seen[t] = true
				teams.append(t)
		if not teams.is_empty():
			return teams

	# Strategy 2: runtime detection (sandbox/tests without GameConfig config,
	# or LIVE phase when no session exists).
	for node: Node in tree.get_nodes_in_group("players"):
		var op: OperatorBase = node as OperatorBase
		if op == null or op.is_ai_controlled:
			continue
		if not seen.has(op.team_id):
			seen[op.team_id] = true
			teams.append(op.team_id)
	return teams

func _apply_fog_visibility(entity: Node3D, detected: bool) -> void:
	if entity is OperatorBase:
		var op: OperatorBase = entity as OperatorBase
		# Dead/downed operators manage their own mesh; do not fight the lifecycle.
		if op.is_incapacitated:
			return
		var mesh: MeshInstance3D = op.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh != null:
			mesh.visible = detected
		var badge: Node3D = op.get_node_or_null("OverheadBadge") as Node3D
		if badge != null:
			badge.visible = detected
	elif entity is DroneBase:
		var drone: DroneBase = entity as DroneBase
		if drone.is_queued_for_deletion():
			return
		var mesh: MeshInstance3D = drone.get_node_or_null("MeshInstance3D") as MeshInstance3D
		if mesh != null:
			mesh.visible = detected

## Fog-of-war visibility sync runs during every active match phase
## (LOADING/INTRO/LIVE) so enemies are already hidden before the countdown.
## Only MATCH_END stops it. In sandbox/tests (no Match scene) sync always runs.
func _should_sync_visibility() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var sc: Node = tree.current_scene
	if sc == null or not is_instance_valid(sc) or sc == self:
		return true
	if sc.has_method("get_phase"):
		return int(sc.call("get_phase")) != int(Match.Phase.MATCH_END)
	if sc.has_method("is_live"):
		return sc.is_live()
	return true
