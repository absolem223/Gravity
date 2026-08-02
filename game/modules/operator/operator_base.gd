# operator_base.gd
# Technical Rationale: Base class for all 4 operator prototypes.
# Implements CharacterBody3D locomotion, 8-direction movement, orientation, health, and player slot assignment.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name OperatorBase
extends CharacterBody3D

## Signals
signal health_changed(current_hp: float, max_hp: float)
signal operator_incapacitated(p_id: int)

## Player Slot ID (1 to 4)
@export_range(1, 4) var player_id: int = 1:
	set(value):
		player_id = value
		_update_player_color()

## Maximum movement speed in meters/second
@export var move_speed: float = 6.5

## Acceleration rate when starting movement
@export var acceleration: float = 26.0

## Deceleration rate when stopping
@export var deceleration: float = 32.0

## Smooth rotation speed towards direction of motion (rad/sec)
@export var rotation_speed: float = 14.0

## Maximum health points
@export var health_max: float = 100.0

## Current health points
var health_current: float = 100.0

## State flag for incapacitation
var is_incapacitated: bool = false

## State flag when controlling Drone in Pilot Mode
var is_piloting_drone: bool = false

## Reference to MeshInstance3D for visual placeholder coloring
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

## Reference to InputManager node (discovered or passed)
var _input_manager: InputManager = null

func _ready() -> void:
	add_to_group("players")
	health_current = health_max
	_update_player_color()

func _physics_process(delta: float) -> void:
	if is_incapacitated or is_piloting_drone:
		# Apply gravity/friction when incapacitated or piloting
		_apply_deceleration(delta)
		move_and_slide()
		return

	var move_vec: Vector2 = _get_input_direction()
	_process_locomotion(move_vec, delta)
	move_and_slide()

## Obtains movement direction from InputManager or Direct Input fallback
func _get_input_direction() -> Vector2:
	if _input_manager != null:
		return _input_manager.get_movement_vector(player_id)
	
	# Fallback if InputManager is not assigned directly
	var left_act: String = "p%d_move_left" % player_id
	var right_act: String = "p%d_move_right" % player_id
	var up_act: String = "p%d_move_up" % player_id
	var down_act: String = "p%d_move_down" % player_id
	
	var vec: Vector2 = Input.get_vector(left_act, right_act, up_act, down_act)
	if vec == Vector2.ZERO and player_id == 1:
		# Global fallback for P1 using standard ui inputs if actions not configured
		vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return vec

## Processes XZ velocity and orientation rotation based on 2D input
func _process_locomotion(input_vec: Vector2, delta: float) -> void:
	# Top-Down camera space mapping: Vector2.x -> World 3D X, Vector2.y -> World 3D Z
	var target_dir: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y)

	if target_dir.length_squared() > 0.01:
		target_dir = target_dir.normalized()
		
		# Smoothly interpolate horizontal velocity toward target velocity
		var target_velocity_x: float = target_dir.x * move_speed
		var target_velocity_z: float = target_dir.z * move_speed
		
		velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity_z, acceleration * delta)
		
		# Smoothly rotate operator mesh to face movement direction
		var target_angle: float = atan2(target_dir.x, target_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
	else:
		_apply_deceleration(delta)

## Smoothly decelerates velocity to zero
func _apply_deceleration(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	# Apply gravity if off floor
	if not is_on_floor():
		velocity.y -= 9.8 * delta

## Assigns InputManager reference
func set_input_manager(input_mgr: InputManager) -> void:
	_input_manager = input_mgr

## Applies damage to operator and triggers signals / incapacitation
func take_damage(amount: float) -> void:
	if is_incapacitated:
		return
		
	health_current = maxf(0.0, health_current - amount)
	health_changed.emit(health_current, health_max)
	
	if health_current <= 0.0:
		_incapacitate()

## Triggers incapacitation state
func _incapacitate() -> void:
	is_incapacitated = true
	operator_incapacitated.emit(player_id)

## Restores health or revives operator
func revive(restore_hp_ratio: float = 0.5) -> void:
	is_incapacitated = false
	health_current = health_max * clampf(restore_hp_ratio, 0.1, 1.0)
	health_changed.emit(health_current, health_max)

## Updates placeholder mesh material color according to Player ID (P1: Red, P2: Blue, P3: Green, P4: Yellow)
func _update_player_color() -> void:
	if not is_inside_tree() or _mesh_instance == null:
		return
		
	var material: StandardMaterial3D = StandardMaterial3D.new()
	match player_id:
		1: material.albedo_color = Color(0.9, 0.25, 0.25) # Red (P1)
		2: material.albedo_color = Color(0.25, 0.5, 0.95) # Blue (P2)
		3: material.albedo_color = Color(0.25, 0.85, 0.35) # Green (P3)
		4: material.albedo_color = Color(0.95, 0.85, 0.25) # Yellow (P4)
		_: material.albedo_color = Color(0.7, 0.7, 0.7)
		
	_mesh_instance.material_override = material
