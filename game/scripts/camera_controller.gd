# camera_controller.gd
# Technical Rationale: Implements DT-01 (Top-Down Isometric Camera with Group Centroid & Dynamic Zoom).
# Designed for 2-4 local cooperative players sharing a single viewport.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name CameraController
extends Node3D

## Active targets to track (Operator CharacterBodies, Drones, or Objectives)
@export var targets: Array[Node3D] = []

## Fixed pitch angle for Top-Down Isometric perspective (DT-01: 60-70 degrees)
@export_range(45.0, 80.0) var pitch_angle_degrees: float = 65.0

## Minimum height/distance offset for closest camera zoom
@export var min_zoom_distance: float = 12.0

## Maximum height/distance offset for farthest camera zoom (when players separate)
@export var max_zoom_distance: float = 28.0

## Padding factor applied to player group bounding box to trigger zoom
@export var bounding_box_padding: float = 6.0

## Smoothing speed for camera position movement (lerp weight factor)
@export var follow_speed: float = 6.0

## Smoothing speed for camera zoom transitions
@export var zoom_speed: float = 4.0

## Node reference to child Camera3D
@onready var camera: Camera3D = $Camera3D

## Internal current target position (centroid of player group)
var _target_centroid: Vector3 = Vector3.ZERO

## Internal target distance offset along local Z axis
var _current_zoom_distance: float = 16.0

func _ready() -> void:
	_setup_camera_transform()

func _physics_process(delta: float) -> void:
	if targets.is_empty():
		_find_targets_in_group()
		if targets.is_empty():
			return

	_update_centroid_and_zoom()
	_apply_smooth_transform(delta)

## Automatically discovers nodes in the "players" group if no explicit targets are set
func _find_targets_in_group() -> void:
	var group_nodes: Array[Node] = get_tree().get_nodes_in_group("players")
	for node: Node in group_nodes:
		if node is Node3D and not targets.has(node as Node3D):
			targets.append(node as Node3D)

## Configures initial rotation and camera hierarchy
func _setup_camera_transform() -> void:
	# Set controller pitch angle
	rotation_degrees.x = -pitch_angle_degrees
	rotation_degrees.y = 0.0
	rotation_degrees.z = 0.0
	
	if camera == null:
		# Auto-instantiate Camera3D if child node is missing in scene
		camera = Camera3D.new()
		camera.name = "Camera3D"
		add_child(camera)
	
	# Position Camera3D looking down Z axis
	camera.position = Vector3(0.0, 0.0, _current_zoom_distance)
	camera.rotation_degrees = Vector3.ZERO

## Calculates centroid (center of mass) and bounding spread of all active targets
func _update_centroid_and_zoom() -> void:
	var valid_targets: int = 0
	var sum_position: Vector3 = Vector3.ZERO
	var min_pos: Vector3 = Vector3(INF, INF, INF)
	var max_pos: Vector3 = Vector3(-INF, -INF, -INF)

	for target: Node3D in targets:
		if is_instance_valid(target) and target.is_inside_tree() and target.visible:
			var pos: Vector3 = target.global_position
			sum_position += pos
			min_pos = min_pos.min(pos)
			max_pos = max_pos.max(pos)
			valid_targets += 1

	if valid_targets > 0:
		_target_centroid = sum_position / float(valid_targets)
		
		# Calculate maximum spread distance along X and Z axes
		var spread_x: float = max_pos.x - min_pos.x
		var spread_z: float = max_pos.z - min_pos.z
		var max_spread: float = max(spread_x, spread_z) + bounding_box_padding

		# Map spread to zoom distance range
		var target_zoom: float = min_zoom_distance + (max_spread * 0.8)
		_current_zoom_distance = clampf(target_zoom, min_zoom_distance, max_zoom_distance)

## Interpolates position and camera offset smoothly
func _apply_smooth_transform(delta: float) -> void:
	# Interpolate centroid position
	global_position = global_position.lerp(_target_centroid, follow_speed * delta)
	
	# Interpolate camera zoom offset along local Z
	if camera != null:
		var target_cam_pos: Vector3 = Vector3(0.0, 0.0, _current_zoom_distance)
		camera.position = camera.position.lerp(target_cam_pos, zoom_speed * delta)

## Register a new target (e.g. Drone in Pilot Mode or Objective Marker)
func add_target(new_target: Node3D) -> void:
	if new_target != null and not targets.has(new_target):
		targets.append(new_target)

## Unregister a target (e.g. when an operator is incapacitated or leaves)
func remove_target(target_to_remove: Node3D) -> void:
	targets.erase(target_to_remove)
