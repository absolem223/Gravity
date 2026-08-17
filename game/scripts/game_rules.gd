# game_rules.gd
# Technical Rationale: Centralized game rules module for GRAVITY.
# Stores global match settings (friendly fire, respawn times, invulnerability)
# so rules belong to the game match rather than individual character instances.
# Strictly a configuration module with no gameplay logic execution.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name GameRules
extends Node

@export_category("Combat Rules")
@export_group("Damage & Combat")
## Friendly Fire: when false, damage between teammates is blocked
@export var friendly_fire_enabled: bool = false

@export_category("Match Lifecycles")
@export_group("Respawn Parameters")
## Respawn duration in seconds
@export_range(1.0, 30.0, 0.5) var respawn_time: float = 5.0

## Temporary invulnerability duration upon respawning (seconds)
@export_range(0.0, 10.0, 0.5) var invulnerability_time: float = 2.0

@export_group("Health Parameters")
## Default starting health for operators
@export_range(10.0, 500.0, 10.0) var starting_health: float = 100.0

func _ready() -> void:
	add_to_group("game_rules")
	print("[GameRules] Initialized. FriendlyFire: %s | RespawnTime: %.1fs | InvulnerabilityTime: %.1fs" % [
		str(friendly_fire_enabled), respawn_time, invulnerability_time
	])

## Helper to discover the GameRules instance from any tree node
static func get_rules(node: Node) -> GameRules:
	if node == null or not node.is_inside_tree():
		return null
	var nodes: Array[Node] = node.get_tree().get_nodes_in_group("game_rules")
	for n: Node in nodes:
		if not n.is_queued_for_deletion():
			return n as GameRules
	return null
