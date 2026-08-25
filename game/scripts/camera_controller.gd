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
@export var min_zoom_distance: float = 8.0

## Maximum height/distance offset for farthest camera zoom (when players separate)
@export var max_zoom_distance: float = 50.0

## Tactical manual zoom tuning (Mouse Wheel)
@export var manual_zoom_step: float = 2.0
@export var manual_zoom_min_offset: float = -8.0  ## Allows zooming closer (in)
@export var manual_zoom_max_offset: float = 16.0  ## Allows zooming farther (out)

## Padding factor applied to player group bounding box to trigger zoom
@export var bounding_box_padding: float = 6.0

## Maximum spread (meters) that contributes to zoom. A piloted drone that flies
## far from the squad inflates the bounding box; capping this keeps the shared
## viewport reasonably framed on the squad instead of zooming all the way out.
@export var max_framing_spread: float = 30.0

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

## Manual zoom offset applied by player mouse wheel input
var _manual_zoom_offset: float = 0.0

func _ready() -> void:
	_setup_camera_transform()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.is_pressed():
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_in()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_out()

func zoom_in() -> void:
	_manual_zoom_offset = clampf(_manual_zoom_offset - manual_zoom_step, manual_zoom_min_offset, manual_zoom_max_offset)

func zoom_out() -> void:
	_manual_zoom_offset = clampf(_manual_zoom_offset + manual_zoom_step, manual_zoom_min_offset, manual_zoom_max_offset)

func get_current_zoom() -> float:
	return _current_zoom_distance

func get_manual_zoom_offset() -> float:
	return _manual_zoom_offset

func set_manual_zoom_offset(val: float) -> void:
	_manual_zoom_offset = clampf(val, manual_zoom_min_offset, manual_zoom_max_offset)

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
		var n3d: Node3D = node as Node3D
		if n3d == null:
			continue
		if n3d is OperatorBase and (n3d as OperatorBase).is_incapacitated:
			continue
		if n3d is DroneBase:
			var d: DroneBase = n3d as DroneBase
			if d.operator == null or not d.operator.is_piloting_drone:
				continue
		if not targets.has(n3d):
			targets.append(n3d)

## Configures initial rotation and camera hierarchy
func _setup_camera_transform() -> void:
	# Base top-down/isometric pitch. The shared camera keeps this fixed pose:
	# it is framed by player positions (centroid/zoom), never by input.
	rotation_degrees = Vector3(-pitch_angle_degrees, 0.0, 0.0)
	
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
		if not (is_instance_valid(target) and target.is_inside_tree() and target.visible):
			continue
		# Dead/downed operators are excluded from framing so the living squad
		# stays centered (P1-3). They re-join automatically on respawn.
		if target is OperatorBase and (target as OperatorBase).is_incapacitated:
			continue
		# Only a piloted drone widens framing; an orphaned escort drone must not.
		if target is DroneBase:
			var d: DroneBase = target as DroneBase
			if d.operator == null or not d.operator.is_piloting_drone or d.operator.is_incapacitated:
				continue
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
		var max_spread: float = minf(max(spread_x, spread_z), max_framing_spread) + bounding_box_padding

		# Map spread to base zoom distance range (12.0 base + spread * 0.8) + manual offset
		var base_zoom: float = 12.0 + (max_spread * 0.8)
		var target_zoom: float = base_zoom + _manual_zoom_offset
		_current_zoom_distance = clampf(target_zoom, min_zoom_distance, max_zoom_distance)

## Interpolates position and camera offset smoothly
func _apply_smooth_transform(delta: float) -> void:
	# Interpolate centroid position
	global_position = global_position.lerp(_target_centroid, follow_speed * delta)
	
	# Interpolate camera zoom offset along local Z
	if camera != null:
		var target_cam_pos: Vector3 = Vector3(0.0, 0.0, _current_zoom_distance)
		camera.position = camera.position.lerp(target_cam_pos, zoom_speed * delta)

	# Keep the fixed top-down isometric pitch. The camera is framed by player
	# positions (centroid/zoom) only; no input ever rotates it.
	rotation_degrees = Vector3(-pitch_angle_degrees, 0.0, 0.0)

## Register a new target (e.g. Drone in Pilot Mode or Objective Marker)
func add_target(new_target: Node3D) -> void:
	if new_target != null and not targets.has(new_target):
		targets.append(new_target)

## Unregister a target (e.g. when an operator is incapacitated or leaves)
func remove_target(target_to_remove: Node3D) -> void:
	targets.erase(target_to_remove)
