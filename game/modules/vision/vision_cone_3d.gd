# vision_cone_3d.gd
# Technical Rationale: Modular 3D Vision Cone component.
# Computes angular field-of-view, range filtering, and LoS raycasting against potential targets.
# Architecture designed for shared consumption by Operators, Drones (Gen 1), and AI entities.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name VisionCone3D
extends Node3D

## Signals
signal target_detected(target: Node3D)
signal target_lost(target: Node3D)
signal vision_updated(detected_targets: Array[Node3D])

## Maximum sight range in meters
@export var view_range: float = 16.0

## Field of view angle in degrees (e.g. 90.0)
@export_range(10.0, 360.0) var field_of_view_degrees: float = 90.0

## Collision mask for LoS obstacles (Layer 1 = World geometry)
@export_flags_3d_physics var obstacle_collision_mask: int = 1

## Scan interval in seconds (throttles raycasts for performance)
@export var scan_interval: float = 0.1

## Currently detected targets within LoS and Vision Cone
var _detected_targets: Array[Node3D] = []

## Timer accumulator for throttled physics scanning
var _scan_timer: float = 0.0

## List of target groups to evaluate (default: "players", "enemies")
@export var target_groups: Array[String] = ["players", "enemies"]

func _physics_process(delta: float) -> void:
	_scan_timer += delta
	if _scan_timer >= scan_interval:
		_scan_timer = 0.0
		_perform_vision_scan()

## Returns array of currently visible targets inside vision cone
func get_detected_targets() -> Array[Node3D]:
	return _detected_targets.duplicate()

## Checks if a specific Node3D target is currently visible inside the cone
func is_target_visible(target: Node3D) -> bool:
	return _detected_targets.has(target)

## Scans world targets against angle, distance, and physics LoS
func _perform_vision_scan() -> void:
	var newly_detected: Array[Node3D] = []
	var parent_rid: RID = _get_parent_rid()
	var exclude_list: Array[RID] = []
	if parent_rid.is_valid():
		exclude_list.append(parent_rid)

	for group_name: String in target_groups:
		var candidates: Array[Node] = get_tree().get_nodes_in_group(group_name)
		for candidate: Node in candidates:
			if candidate == get_parent() or not (candidate is Node3D):
				continue
				
			var target_node: Node3D = candidate as Node3D
			if _evaluate_candidate(target_node, exclude_list):
				newly_detected.append(target_node)

	_update_detection_states(newly_detected)

## Evaluates whether a candidate Node3D lies inside angular cone, distance, and clear LoS
func _evaluate_candidate(target: Node3D, exclude_rids: Array[RID]) -> bool:
	if target == null or not target.is_inside_tree() or not target.visible:
		return false

	var origin: Vector3 = global_position
	var target_pos: Vector3 = target.global_position + Vector3(0.0, 0.9, 0.0) # Aim at chest height
	
	var to_target: Vector3 = target_pos - origin
	var dist: float = to_target.length()

	# 1. Distance check
	if dist > view_range or dist < 0.1:
		return false

	# 2. Angle check relative to forward direction (-Z axis in local space)
	var forward: Vector3 = -global_transform.basis.z.normalized()
	var dir_to_target: Vector3 = to_target.normalized()
	var angle_rad: float = forward.angle_to(dir_to_target)
	var half_fov_rad: float = deg_to_rad(field_of_view_degrees * 0.5)

	if angle_rad > half_fov_rad:
		return false

	# 3. Line of Sight raycast check
	var los_res: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		self,
		origin,
		target_pos,
		exclude_rids,
		obstacle_collision_mask
	)

	return los_res.is_visible

## Updates detection list and fires signals on state changes
func _update_detection_states(current_scan_hits: Array[Node3D]) -> void:
	# Check for lost targets
	var i: int = _detected_targets.size() - 1
	while i >= 0:
		var old_target: Node3D = _detected_targets[i]
		if not current_scan_hits.has(old_target):
			_detected_targets.remove_at(i)
			target_lost.emit(old_target)
		i -= 1

	# Check for newly detected targets
	for new_target: Node3D in current_scan_hits:
		if not _detected_targets.has(new_target):
			_detected_targets.append(new_target)
			target_detected.emit(new_target)

	vision_updated.emit(_detected_targets.duplicate())

## Helper to retrieve parent PhysicsBody RID for raycast exclusion
func _get_parent_rid() -> RID:
	var p: Node = get_parent()
	if p is CollisionObject3D:
		return (p as CollisionObject3D).get_rid()
	return RID()
