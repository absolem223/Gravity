# resource_manager.gd
# Technical Rationale: Global resource administrator for the resource economy system.
# Registers and tracks all active ResourcePickups in the scene.
# Provides a centralised API for spawning, querying, and destroying pickups.
# No HUD logic — emits signals for external consumption.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name ResourceManager
extends Node

## ──────────────────────────────────────────────
## SIGNALS
## ──────────────────────────────────────────────
signal pickup_spawned(pickup: ResourcePickup)
signal pickup_collected(resource_type: String, amount: int, collector_id: int)
signal pickup_destroyed(pickup: ResourcePickup)
signal wreck_salvaged(salvager_id: int, components: int)

## ──────────────────────────────────────────────
## INTERNAL REGISTRY
## ──────────────────────────────────────────────
var _active_pickups: Array[ResourcePickup] = []
var _active_salvages: Array[WreckSalvage] = []

## ──────────────────────────────────────────────
## LIFECYCLE
## ──────────────────────────────────────────────
func _ready() -> void:
	add_to_group("resource_manager")
	print("[ResourceManager] Initialized.")

## ──────────────────────────────────────────────
## PICKUP MANAGEMENT
## ──────────────────────────────────────────────

## Spawns a ResourcePickup at world_pos and adds it to the given parent.
## Returns the created pickup.
func spawn_pickup(res_type: String, amount: int, world_pos: Vector3, parent: Node) -> ResourcePickup:
	var pickup: ResourcePickup = ResourcePickup.new()
	pickup.resource_type = res_type
	pickup.amount = amount

	parent.add_child(pickup)
	pickup.global_position = world_pos

	_register_pickup(pickup)
	return pickup

## Registers an externally created ResourcePickup.
func register_pickup(pickup: ResourcePickup) -> void:
	_register_pickup(pickup)

## Registers a WreckSalvage node for tracking.
func register_wreck_salvage(wreck: WreckSalvage) -> void:
	if _active_salvages.has(wreck):
		return
	_active_salvages.append(wreck)
	wreck.salvaged.connect(_on_wreck_salvaged)
	wreck.tree_exiting.connect(func() -> void: _active_salvages.erase(wreck))

## Destroys all tracked pickups immediately (for scene reset).
func destroy_all_pickups() -> void:
	for pickup: ResourcePickup in _active_pickups.duplicate():
		if is_instance_valid(pickup):
			pickup.queue_free()
	_active_pickups.clear()

## Returns total pickups of a given type currently active in the world.
func get_active_pickup_count(res_type: String = "") -> int:
	if res_type.is_empty():
		return _active_pickups.size()
	var count: int = 0
	for p: ResourcePickup in _active_pickups:
		if is_instance_valid(p) and p.resource_type == res_type:
			count += 1
	return count

## Returns all currently active pickups (snapshot).
func get_all_pickups() -> Array[ResourcePickup]:
	return _active_pickups.duplicate()

## ──────────────────────────────────────────────
## INTERNAL REGISTRATION
## ──────────────────────────────────────────────

func _register_pickup(pickup: ResourcePickup) -> void:
	if _active_pickups.has(pickup):
		return
	_active_pickups.append(pickup)

	## Connect signals
	pickup.collected.connect(func(rtype: String, amt: int, pid: int) -> void:
		pickup_collected.emit(rtype, amt, pid)
		_active_pickups.erase(pickup)
		pickup_destroyed.emit(pickup)
	)
	pickup.tree_exiting.connect(func() -> void:
		_active_pickups.erase(pickup)
	)

	pickup_spawned.emit(pickup)
	print("[ResourceManager] Registered pickup: %d x %s at %s" % [pickup.amount, pickup.resource_type, str(pickup.global_position)])

func _on_wreck_salvaged(salvager_id: int, components: int) -> void:
	wreck_salvaged.emit(salvager_id, components)
	print("[ResourceManager] Wreck salvaged by P%d — %d components" % [salvager_id, components])
