# drone_base.gd
# Technical Rationale: Base class for the permanent Drone component (Gen 1).
# Represents a "second body" for the operator, executing Escort, Stationary, and Pilot modes.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name DroneBase
extends CharacterBody3D

## Signals
signal mode_changed(new_mode: DroneMode)
signal battery_changed(current: float, max: float)
signal health_changed(current: float, max: float)
signal destroyed()

## Drone Modes
enum DroneMode { ESCORT, STATIONARY, PILOT }

## Owner Operator
var operator: OperatorBase = null

## Maximum speed in Pilot Mode
@export var speed: float = 8.0

## Acceleration rate in Pilot Mode
@export var acceleration: float = 24.0

## Deceleration rate in Pilot Mode
@export var deceleration: float = 30.0

## Follow distance behind operator (Escort Mode)
@export var follow_distance: float = 1.8

## Height offset relative to operator (Escort Mode)
@export var follow_height_offset: float = 1.6

## Lerp factor for following operator
@export var follow_lerp_speed: float = 5.0

## Maximum operational range from operator (meters)
@export var max_range_from_operator: float = 28.0

## Maximum health points
@export var health_max: float = 50.0

## Preloaded WreckSite scene
@export var wreck_site_scene: PackedScene = preload("res://scenes/wreck_site.tscn")

## Current health points
var health_current: float = 50.0

## Current active mode
var current_mode: DroneMode = DroneMode.ESCORT

## Current shared tactical battery level (0.0 to 100.0)
var battery_current: float = 100.0
var battery_max: float = 100.0

## State flag for drift mode (when out of range)
var is_drifting: bool = false

## Dynamic Battery Drainage Rates per Second
const DRAIN_RATES: Dictionary = {
	DroneMode.ESCORT: 0.5,
	DroneMode.STATIONARY: 1.0,
	DroneMode.PILOT: 5.0
}

## Attached components
@onready var vision_cone: VisionCone3D = $VisionCone3D if has_node("VisionCone3D") else null
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null

func _ready() -> void:
	add_to_group("drones")
	health_current = health_max
	_setup_vision_cone()
	_update_visuals()

func _physics_process(delta: float) -> void:
	if operator == null or not is_instance_valid(operator):
		return

	_process_battery(delta)
	_process_range_checks()

	match current_mode:
		DroneMode.ESCORT:
			_process_escort_mode(delta)
		DroneMode.STATIONARY:
			_process_stationary_mode()
		DroneMode.PILOT:
			_process_pilot_mode(delta)

	move_and_slide()

## Initializes and configures the vision cone component
func _setup_vision_cone() -> void:
	if vision_cone == null:
		vision_cone = VisionCone3D.new()
		vision_cone.name = "VisionCone3D"
		vision_cone.view_range = 14.0
		vision_cone.field_of_view_degrees = 90.0
		add_child(vision_cone)

## Processes battery drain based on active mode
func _process_battery(delta: float) -> void:
	var rate: float = DRAIN_RATES.get(current_mode, 0.5)
	
	# If in Pilot mode, battery drains faster. 
	battery_current = maxf(0.0, battery_current - (rate * delta))
	battery_changed.emit(battery_current, battery_max)

	if battery_current <= 0.0:
		if current_mode == DroneMode.PILOT:
			# Auto-exit Pilot Mode if battery runs out
			set_mode(DroneMode.ESCORT)

## Checks range constraint relative to operator position
func _process_range_checks() -> void:
	var dist: float = global_position.distance_to(operator.global_position)
	var out_of_range: bool = dist > max_range_from_operator

	if out_of_range and not is_drifting:
		is_drifting = true
		if current_mode == DroneMode.PILOT:
			# Force disconnect Pilot Mode if drone drifts too far
			set_mode(DroneMode.ESCORT)
	elif not out_of_range and is_drifting:
		is_drifting = false

## Escort Mode movement: follows operator smoothly with obstacle avoidance stub
func _process_escort_mode(delta: float) -> void:
	var op_transform: Transform3D = operator.global_transform
	# Calculate target position behind the operator
	var target_offset: Vector3 = op_transform.basis.z * follow_distance
	var target_pos: Vector3 = op_transform.origin + target_offset + Vector3(0.0, follow_height_offset, 0.0)

	# Simple obstacle avoidance interpolation
	global_position = global_position.lerp(target_pos, follow_lerp_speed * delta)
	
	# Face operator rotation angle
	rotation.y = lerp_angle(rotation.y, operator.rotation.y, follow_lerp_speed * delta)
	velocity = Vector3.ZERO

## Stationary Mode: locks position
func _process_stationary_mode() -> void:
	velocity = Vector3.ZERO

## Pilot Mode: direct locomotion mapping from input manager
func _process_pilot_mode(delta: float) -> void:
	var move_vec: Vector2 = Vector2.ZERO
	if operator._input_manager != null:
		move_vec = operator._input_manager.get_movement_vector(operator.player_id)

	var move_dir: Vector3 = Vector3(move_vec.x, 0.0, move_vec.y)

	if move_dir.length_squared() > 0.01:
		move_dir = move_dir.normalized()
		var target_vel_x: float = move_dir.x * speed
		var target_vel_z: float = move_dir.z * speed
		
		velocity.x = move_toward(velocity.x, target_vel_x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel_z, acceleration * delta)
		
		# Rotate towards flying direction
		var target_angle: float = atan2(move_dir.x, move_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, follow_lerp_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	
	# Stabilize Y height relative to terrain in pilot mode
	velocity.y = 0.0

## Dynamically sets the active Drone mode
func set_mode(new_mode: DroneMode) -> void:
	if current_mode == new_mode:
		return
		
	# Exit pilot mode cleanups
	if current_mode == DroneMode.PILOT and operator != null:
		operator.is_piloting_drone = false
		
	current_mode = new_mode
	
	# Enter pilot mode setups
	if current_mode == DroneMode.PILOT and operator != null:
		operator.is_piloting_drone = true
		velocity = Vector3.ZERO

	_update_visuals()
	mode_changed.emit(current_mode)

## Applies damage to drone and triggers destruction on HP depletion
func take_damage(amount: float) -> void:
	health_current = maxf(0.0, health_current - amount)
	health_changed.emit(health_current, health_max)
	
	if health_current <= 0.0:
		_destroy()

## Triggers destruction and spawns WreckSite
func _destroy() -> void:
	destroyed.emit()
	if wreck_site_scene != null:
		var wreck: WreckSite = wreck_site_scene.instantiate() as WreckSite
		if wreck != null:
			wreck.position = global_position
			get_parent().add_child(wreck)
	
	if operator != null:
		operator.is_piloting_drone = false
		operator.notify_drone_destroyed()
		
	queue_free()

## Updates placeholder visuals based on slot colors & mode (Escort: standard, Stationary: pulse)
func _update_visuals() -> void:
	if _mesh_instance == null or operator == null:
		return
		
	var material: StandardMaterial3D = StandardMaterial3D.new()
	var slot_color: Color = operator.SLOT_COLORS[operator.player_id - 1]
	
	match current_mode:
		DroneMode.ESCORT:
			material.albedo_color = slot_color
		DroneMode.STATIONARY:
			# Differentiate Stationary with cyan/tint addition
			material.albedo_color = slot_color.lerp(Color(0.2, 0.9, 0.9), 0.5)
		DroneMode.PILOT:
			# Differentiate Pilot with brighter tint
			material.albedo_color = slot_color.lerp(Color(1.0, 1.0, 1.0), 0.4)
			
	_mesh_instance.material_override = material
