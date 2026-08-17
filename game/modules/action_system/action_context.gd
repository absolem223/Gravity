class_name ActionContext
extends RefCounted

## Immutable execution frame for an action request.
var actor: Node = null
var world: Dictionary = {}
var role: Node = null
var drone: Node = null
var inventory: Node = null
var input_profile: Dictionary = {}
var delta_time: float = 0.0
var timestamp: float = 0.0
var metadata: Dictionary = {}

func _init(
	actor_value: Node = null,
	world_value: Dictionary = {},
	role_value: Node = null,
	drone_value: Node = null,
	inventory_value: Node = null,
	input_profile_value: Dictionary = {},
	delta_time_value: float = 0.0,
	timestamp_value: float = 0.0,
	metadata_value: Dictionary = {}
) -> void:
	actor = actor_value
	world = world_value
	role = role_value
	drone = drone_value
	inventory = inventory_value
	input_profile = input_profile_value
	delta_time = delta_time_value
	timestamp = timestamp_value
	metadata = metadata_value

func get_actor() -> Node:
	return actor

func get_world_state() -> Dictionary:
	return world

func get_role() -> Node:
	return role

func get_drone() -> Node:
	return drone

func get_inventory() -> Node:
	return inventory

func get_input_profile() -> Dictionary:
	return input_profile

func get_metadata() -> Dictionary:
	return metadata
