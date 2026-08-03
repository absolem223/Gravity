# squad_vision_registry.gd
# Technical Rationale: Data layer for shared squad vision and tactical intelligence.
# Aggregates vision feeds from active Operators, Drones, and Stationary Cameras into a unified squad map.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SquadVisionRegistry
extends Node

## Signal emitted when squad intelligence map is updated
signal squad_intel_updated(all_visible_targets: Array[Node3D])

## Registry of active VisionCone3D components contributing to squad vision
var _vision_providers: Array[VisionCone3D] = []

## Aggregated dictionary of currently detected targets with timestamp of detection
var _squad_detected_targets: Dictionary = {}

func _ready() -> void:
	add_to_group("squad_vision_registry")

## Registers a new vision provider (Operator vision cone, Drone vision cone, Stationary Camera)
func register_provider(provider: VisionCone3D) -> void:
	if provider != null and not _vision_providers.has(provider):
		_vision_providers.append(provider)
		if not provider.vision_updated.is_connected(_on_provider_vision_updated):
			provider.vision_updated.connect(_on_provider_vision_updated)

## Unregisters a vision provider (e.g. destroyed drone or incapacitated operator)
func unregister_provider(provider: VisionCone3D) -> void:
	if provider != null and _vision_providers.has(provider):
		_vision_providers.erase(provider)
		if provider.vision_updated.is_connected(_on_provider_vision_updated):
			provider.vision_updated.disconnect(_on_provider_vision_updated)
		_recalculate_squad_vision()

## Callback when any registered provider updates its vision scan
func _on_provider_vision_updated(_targets: Array[Node3D]) -> void:
	_recalculate_squad_vision()

## Recalculates the union of all targets visible to any squad member or drone
func _recalculate_squad_vision() -> void:
	var new_union: Dictionary = {}
	
	for provider: VisionCone3D in _vision_providers:
		if is_instance_valid(provider) and provider.is_inside_tree():
			var detected: Array[Node3D] = provider.get_detected_targets()
			for target: Node3D in detected:
				if is_instance_valid(target):
					new_union[target] = Time.get_ticks_msec()

	_squad_detected_targets = new_union
	
	var target_list: Array[Node3D] = []
	for key: Node3D in _squad_detected_targets.keys():
		target_list.append(key)

	squad_intel_updated.emit(target_list)

## Query: Is a specific entity currently detected by at least one squad vision source?
func is_entity_detected_by_squad(entity: Node3D) -> bool:
	return _squad_detected_targets.has(entity)

## Query: Returns array of all targets currently visible to the squad
func get_all_squad_detected_targets() -> Array[Node3D]:
	var list: Array[Node3D] = []
	for key: Node3D in _squad_detected_targets.keys():
		if is_instance_valid(key):
			list.append(key)
	return list
