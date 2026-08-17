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

func _ready() -> void:
	add_to_group("squad_vision_registry")

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
	for key: Node3D in _squad_detected_targets.keys():
		if is_instance_valid(key):
			list.append(key)
	return list

## ──────────────────────────────────────────────
## FOG OF WAR — ENEMY VISIBILITY SYNC
## ──────────────────────────────────────────────

## Hides enemies that are NOT detected by the observing teams' vision unions,
## and reveals them as soon as they are detected.
##
## Local co-op shares a single renderer, so hiding is a single global decision:
## an entity is shown if (a) it belongs to an observing (human) team, or (b) it is
## detected by the vision union of ANY observing team. All-AI matches disable fog.
func sync_enemy_visibility() -> void:
	if not _should_sync_visibility():
		return
	var tree: SceneTree = get_tree()
	if tree == null:
		return
	var observing_teams: Array[int] = _observing_team_ids()
	if observing_teams.is_empty():
		return

	for node: Node in tree.get_nodes_in_group("players"):
		var op: OperatorBase = node as OperatorBase
		if op == null or op.is_queued_for_deletion():
			continue
		var shown: bool = _is_entity_visible(op, op.team_id, observing_teams)
		_apply_fog_visibility(op, shown)
	for node: Node in tree.get_nodes_in_group("drones"):
		var drone: DroneBase = node as DroneBase
		if drone == null or drone.is_queued_for_deletion() or drone.operator == null:
			continue
		var shown: bool = _is_entity_visible(drone, drone.operator.team_id, observing_teams)
		_apply_fog_visibility(drone, shown)

## Teams that contain at least one human (non-AI) operator. Only these teams
## drive the fog-of-war decision on the shared local screen.
func _observing_team_ids() -> Array[int]:
	var teams: Array[int] = []
	var seen: Dictionary = {}
	var tree: SceneTree = get_tree()
	if tree == null:
		return teams
	for node: Node in tree.get_nodes_in_group("players"):
		var op: OperatorBase = node as OperatorBase
		if op == null or op.is_ai_controlled:
			continue
		if not seen.has(op.team_id):
			seen[op.team_id] = true
			teams.append(op.team_id)
	return teams

## Entity is shown when it belongs to an observing team or when any observing
## team's vision union has detected it.
func _is_entity_visible(entity: Node3D, owner_team: int, observing_teams: Array[int]) -> bool:
	for team: int in observing_teams:
		if team == owner_team:
			return true
	for team: int in observing_teams:
		if is_entity_detected_by_team(entity, team):
			return true
	return false

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

## Fog-of-war only runs while a live match is active (or when no Match scene is
## present, e.g. sandbox/tests). During the intro cinematic the Match owns the
## operators' visibility, so this sync must not fight it.
func _should_sync_visibility() -> bool:
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var sc: Node = tree.current_scene
	if sc == null or not is_instance_valid(sc) or sc == self:
		return true
	if sc.has_method("is_live"):
		return sc.is_live()
	return true
