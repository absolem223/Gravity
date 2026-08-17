# player_manager.gd
# Technical Rationale: Centralized squad and player session lifecycle manager.
# Responsible for spawning, tracking, and managing 2-4 local operators and their slot assignments.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name PlayerManager
extends Node

## Signals
signal player_spawned(p_id: int, operator_node: OperatorBase)
signal player_despawned(p_id: int)
signal squad_updated(active_count: int)

@export_category("Squad Configuration")
@export_group("Scene References")
## Preloaded Operator scene template
@export var operator_scene: PackedScene = preload("res://scenes/operator_placeholder.tscn")

## Reference to active InputManager instance
var input_manager: InputManager = null

## Active operator instances indexed by Player ID (1..4)
var _active_operators: Dictionary = {}
var _action_runtime: ActionRuntime = null

## Player IDs that participate in this match (from SessionConfig lobby)
var _enabled_player_ids: Array[int] = [1, 2, 3, 4]

## Per-team spawn marker index when placing operators
var _team_spawn_counters: Dictionary = {}

## Spawn positions offset relative to parent node origin
var _spawn_offsets: Array[Vector3] = [
	Vector3(-2.0, 0.0, 0.0), # P1
	Vector3(2.0, 0.0, 0.0),  # P2
	Vector3(-2.0, 0.0, 3.0), # P3
	Vector3(2.0, 0.0, 3.0)   # P4
]

func _ready() -> void:
	add_to_group("player_manager")

## Initializes the PlayerManager with InputManager reference and lobby-enabled player IDs.
func setup_squad(input_mgr: InputManager, enabled_player_ids: Array[int] = []) -> void:
	input_manager = input_mgr
	_setup_action_runtime()
	if enabled_player_ids.is_empty():
		_enabled_player_ids = [1, 2, 3, 4]
	else:
		_enabled_player_ids = enabled_player_ids.duplicate()
	_sync_spawned_operators()

func _setup_action_runtime() -> void:
	var registry: ActionRegistry = ActionRegistry.new()
	var bus: GameplayEventBus = GameplayEventBus.new()
	_action_runtime = ActionRuntime.new(registry, bus)

	var sprint_action: SprintAction = SprintAction.new()
	registry.register(sprint_action)

## Public accessor for the shared squad ActionRuntime (used by OperatorBase for sprint).
func get_action_runtime() -> ActionRuntime:
	return _action_runtime

## Synchronizes spawned operators with lobby-enabled player IDs.
func _sync_spawned_operators() -> void:
	_team_spawn_counters.clear()
	for p_id: int in range(1, 5):
		if _enabled_player_ids.has(p_id):
			if not _active_operators.has(p_id):
				_spawn_operator(p_id)
		else:
			if _active_operators.has(p_id):
				_despawn_operator(p_id)

	squad_updated.emit(_active_operators.size())

## Spawns an operator for a specific Player ID
func _spawn_operator(p_id: int) -> void:
	if operator_scene == null:
		push_error("[PlayerManager] Cannot spawn operator: operator_scene is null.")
		return

	var op_instance: OperatorBase = operator_scene.instantiate() as OperatorBase
	if op_instance == null:
		push_error("[PlayerManager] Instantiated scene is not an OperatorBase.")
		return

	op_instance.name = "OperatorP%d" % p_id
	op_instance.player_id = p_id

	var slot: Variant = _get_lobby_slot(p_id)
	if slot != null:
		op_instance.team_id = slot.team_id as int
		op_instance.is_ai_controlled = int(slot.control_mode) == 1
	else:
		op_instance.team_id = OperatorBase.TEAM_ATTACKERS if p_id <= 2 else OperatorBase.TEAM_DEFENDERS
		op_instance.is_ai_controlled = false

	if _action_runtime != null:
		op_instance.set_action_runtime(_action_runtime)

	add_child(op_instance)
	op_instance.global_position = get_spawn_position(op_instance.team_id)

	if input_manager != null and not op_instance.is_ai_controlled:
		op_instance.set_input_manager(input_manager)
	if _action_runtime != null:
		op_instance.set_action_runtime(_action_runtime)
	if op_instance.is_ai_controlled:
		print("[PlayerManager] P%d spawned as AI (team %d)" % [p_id, op_instance.team_id])
	_active_operators[p_id] = op_instance
	player_spawned.emit(p_id, op_instance)

## Looks up Marker3D spawn nodes in the scene tree for the specified team (sequential index).
func get_spawn_position(team_id: int) -> Vector3:
	var count: int = int(_team_spawn_counters.get(team_id, 0))
	_team_spawn_counters[team_id] = count + 1
	var idx: int = count + 1

	var marker_name: String = "Spawn_Attackers_%d" % idx if team_id == OperatorBase.TEAM_ATTACKERS else "Spawn_Defenders_%d" % idx

	if get_tree() != null and get_tree().current_scene != null:
		var node: Node = get_tree().current_scene.find_child(marker_name, true, false)
		if node is Node3D:
			return (node as Node3D).global_position

	return _spawn_offsets[clampi(idx - 1, 0, 3)]

## Respawn position for an existing operator (does not advance lobby spawn counters).
func get_respawn_position(team_id: int, p_id: int) -> Vector3:
	var idx: int = 0
	for eid: int in _enabled_player_ids:
		var slot: Variant = _get_lobby_slot(eid)
		if slot != null and int(slot.team_id) == team_id:
			idx += 1
			if eid == p_id:
				break
	if idx <= 0:
		idx = 1

	var marker_name: String = "Spawn_Attackers_%d" % idx if team_id == OperatorBase.TEAM_ATTACKERS else "Spawn_Defenders_%d" % idx
	if get_tree() != null and get_tree().current_scene != null:
		var node: Node = get_tree().current_scene.find_child(marker_name, true, false)
		if node is Node3D:
			return (node as Node3D).global_position
	return _spawn_offsets[clampi(p_id - 1, 0, 3)]

func _session_node() -> Node:
	if get_tree() == null:
		return null
	return get_tree().root.get_node_or_null("GameConfig")

func _get_lobby_slot(player_id: int) -> Variant:
	var session: Node = _session_node()
	if session == null:
		return null
	return session.call("get_slot", player_id)

## Despawns an operator for a specific Player ID
func _despawn_operator(p_id: int) -> void:
	var op: OperatorBase = _active_operators.get(p_id, null) as OperatorBase
	if op != null:
		_active_operators.erase(p_id)
		player_despawned.emit(p_id)
		op.queue_free()

## Returns the active OperatorBase instance for a Player ID
func get_operator(p_id: int) -> OperatorBase:
	return _active_operators.get(p_id, null) as OperatorBase

## Returns array of all currently active OperatorBase instances
func get_all_operators() -> Array[OperatorBase]:
	var list: Array[OperatorBase] = []
	for op: OperatorBase in _active_operators.values():
		if is_instance_valid(op):
			list.append(op)
	return list

## Calculates center of mass (centroid) of active squad operators
func get_squad_centroid() -> Vector3:
	var ops: Array[OperatorBase] = get_all_operators()
	if ops.is_empty():
		return Vector3.ZERO
		
	var sum_pos: Vector3 = Vector3.ZERO
	for op: OperatorBase in ops:
		sum_pos += op.global_position
		
	return sum_pos / float(ops.size())
