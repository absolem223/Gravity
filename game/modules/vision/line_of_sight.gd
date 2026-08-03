# line_of_sight.gd
# Technical Rationale: Reusable Line of Sight (LoS) query utility.
# Uses PhysicsDirectSpaceState3D raycasts to check visibility, cover obstruction, and distance.
# Designed for consumption by Operators, Drones, AI, Recon, and Objective systems.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name LineOfSightQuery
extends RefCounted

## Result container for a Line of Sight query
class LoSResult:
	var is_visible: bool = false
	var is_obstructed_by_cover: bool = false
	var distance: float = 0.0
	var hit_collider: Object = null
	var hit_position: Vector3 = Vector3.ZERO
	var cover_height_ratio: float = 0.0 # 0.0 = clear, 0.5 = low cover, 1.0 = full cover

## Performs a raycast check from origin to target_position in 3D physics space
static func test_los(
	world_node: Node3D,
	origin: Vector3,
	target_position: Vector3,
	exclude_rid_list: Array[RID] = [],
	collision_mask: int = 1
) -> LoSResult:
	var result: LoSResult = LoSResult.new()
	result.distance = origin.distance_to(target_position)

	if world_node == null or not world_node.is_inside_tree():
		return result

	var space_state: PhysicsDirectSpaceState3D = world_node.get_world_3d().direct_space_state
	if space_state == null:
		return result

	var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
		origin,
		target_position,
		collision_mask,
		exclude_rid_list
	)
	query.collide_with_bodies = true
	query.collide_with_areas = false

	var ray_hit: Dictionary = space_state.intersect_ray(query)

	if ray_hit.is_empty():
		# Direct line of sight with no physical obstacles
		result.is_visible = true
		result.is_obstructed_by_cover = false
		result.hit_position = target_position
	else:
		result.hit_position = ray_hit.get("position", target_position) as Vector3
		result.hit_collider = ray_hit.get("collider", null) as Object

		# If ray hit point is close to target_position, treat as visible hit
		if result.hit_position.distance_to(target_position) < 0.5:
			result.is_visible = true
			result.is_obstructed_by_cover = false
		else:
			result.is_visible = false
			result.is_obstructed_by_cover = true
			
			# Estimate cover height ratio based on hit height relative to origin/target
			var hit_height: float = result.hit_position.y - minf(origin.y, target_position.y)
			result.cover_height_ratio = clampf(hit_height / 1.8, 0.0, 1.0)

	return result

## Evaluates whether a target is behind low cover relative to an attacker position
static func check_cover_protection(
	world_node: Node3D,
	attacker_head_pos: Vector3,
	target_center_pos: Vector3,
	target_feet_pos: Vector3,
	exclude_rids: Array[RID] = []
) -> float:
	# Raycast 1: To target center/chest
	var center_res: LoSResult = test_los(world_node, attacker_head_pos, target_center_pos, exclude_rids)
	# Raycast 2: To target feet
	var feet_res: LoSResult = test_los(world_node, attacker_head_pos, target_feet_pos, exclude_rids)

	if center_res.is_visible:
		if feet_res.is_obstructed_by_cover:
			# Low cover protection: feet obstructed, chest visible -> 50% damage reduction
			return 0.5
		# Clear line of sight -> 0% cover protection
		return 0.0
	else:
		if feet_res.is_obstructed_by_cover and center_res.is_obstructed_by_cover:
			# Full cover protection -> 100% blocked
			return 1.0
		# Partial cover
		return 0.75
