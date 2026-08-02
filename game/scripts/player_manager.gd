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

## Preloaded Operator scene template
@export var operator_scene: PackedScene = preload("res://scenes/operator_placeholder.tscn")

## Reference to active InputManager instance
var input_manager: InputManager = null

## Active operator instances indexed by Player ID (1..4)
var _active_operators: Dictionary = {}

## Current active player count (2 to 4)
var _active_player_count: int = 4

## Spawn positions offset relative to parent node origin
var _spawn_offsets: Array[Vector3] = [
	Vector3(-2.0, 0.0, 0.0), # P1
	Vector3(2.0, 0.0, 0.0),  # P2
	Vector3(-2.0, 0.0, 3.0), # P3
	Vector3(2.0, 0.0, 3.0)   # P4
]

func _ready() -> void:
	pass

## Initializes the PlayerManager with InputManager reference and desired player count
func setup_squad(input_mgr: InputManager, initial_player_count: int = 4) -> void:
	input_manager = input_mgr
	set_active_player_count(initial_player_count)

## Dynamically sets the active player count (2 to 4) and updates spawned operators
func set_active_player_count(count: int) -> void:
	_active_player_count = clampi(count, 2, 4)
	_sync_spawned_operators()

## Synchronizes active operators with current player count
func _sync_spawned_operators() -> void:
	for p_id: int in range(1, 5):
		if p_id <= _active_player_count:
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
	op_instance.position = _spawn_offsets[p_id - 1]
	
	if input_manager != null:
		op_instance.set_input_manager(input_manager)
		
	add_child(op_instance)
	_active_operators[p_id] = op_instance
	player_spawned.emit(p_id, op_instance)

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
