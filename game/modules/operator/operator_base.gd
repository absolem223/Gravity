# operator_base.gd
# Technical Rationale: Base class for all 4 operator prototypes.
# Implements CharacterBody3D locomotion, 8-direction movement, orientation, health, overhead squad badge, and distance tracking.
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
		_update_overhead_badge()

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

## Distance threshold from squad centroid to trigger "SEPARATED" warning (meters)
@export var separation_warning_distance: float = 12.0

## Current health points
var health_current: float = 100.0

## State flag for incapacitation
var is_incapacitated: bool = false

## State flag when controlling Drone in Pilot Mode
var is_piloting_drone: bool = false

## Is currently separated from squad centroid
var is_separated: bool = false

## Reference to MeshInstance3D for visual placeholder coloring
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null

## Reference to Label3D for overhead squad identification badge
var _overhead_label: Label3D = null

## Reference to InputManager node
var _input_manager: InputManager = null

const ROLE_LABELS: Array[String] = [
	"P1 RECON",
	"P2 VANGUARD",
	"P3 DISRUPTOR",
	"P4 ENGINEER"
]

const SLOT_COLORS: Array[Color] = [
	Color(0.9, 0.25, 0.25), # P1
	Color(0.25, 0.5, 0.95), # P2
	Color(0.25, 0.85, 0.35),# P3
	Color(0.95, 0.85, 0.25) # P4
]

func _ready() -> void:
	add_to_group("players")
	health_current = health_max
	_setup_overhead_badge()
	_update_player_color()
	_update_overhead_badge()

func _physics_process(delta: float) -> void:
	if is_incapacitated or is_piloting_drone:
		_apply_deceleration(delta)
		move_and_slide()
		return

	var move_vec: Vector2 = _get_input_direction()
	_process_locomotion(move_vec, delta)
	move_and_slide()

## Creates 3D overhead badge for squad identification
func _setup_overhead_badge() -> void:
	if _overhead_label == null:
		_overhead_label = Label3D.new()
		_overhead_label.name = "OverheadBadge"
		_overhead_label.position = Vector3(0.0, 2.2, 0.0)
		_overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_overhead_label.no_depth_test = true # Visible through walls for squad legibility
		_overhead_label.font_size = 28
		_overhead_label.outline_size = 8
		_overhead_label.outline_render_priority = 1
		add_child(_overhead_label)

## Updates overhead label text and color
func _update_overhead_badge() -> void:
	if _overhead_label == null or player_id < 1 or player_id > 4:
		return
		
	var label_text: String = ROLE_LABELS[player_id - 1]
	if is_separated:
		label_text += " [SEPARATED]"
		_overhead_label.modulate = Color(1.0, 0.4, 0.2) # Warning orange
	elif is_incapacitated:
		label_text += " [DOWN]"
		_overhead_label.modulate = Color(0.6, 0.6, 0.6)
	else:
		_overhead_label.modulate = SLOT_COLORS[player_id - 1]
		
	_overhead_label.text = label_text

## Updates separation status relative to squad centroid
func update_squad_separation(centroid: Vector3) -> void:
	var dist: float = global_position.distance_to(centroid)
	var newly_separated: bool = dist > separation_warning_distance
	
	if newly_separated != is_separated:
		is_separated = newly_separated
		_update_overhead_badge()

## Obtains movement direction from InputManager or Direct Input fallback
func _get_input_direction() -> Vector2:
	if _input_manager != null:
		return _input_manager.get_movement_vector(player_id)
	
	var left_act: String = "p%d_move_left" % player_id
	var right_act: String = "p%d_move_right" % player_id
	var up_act: String = "p%d_move_up" % player_id
	var down_act: String = "p%d_move_down" % player_id
	
	var vec: Vector2 = Input.get_vector(left_act, right_act, up_act, down_act)
	if vec == Vector2.ZERO and player_id == 1:
		vec = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	return vec

## Processes XZ velocity and orientation rotation based on 2D input
func _process_locomotion(input_vec: Vector2, delta: float) -> void:
	var target_dir: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y)

	if target_dir.length_squared() > 0.01:
		target_dir = target_dir.normalized()
		
		var target_velocity_x: float = target_dir.x * move_speed
		var target_velocity_z: float = target_dir.z * move_speed
		
		velocity.x = move_toward(velocity.x, target_velocity_x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_velocity_z, acceleration * delta)
		
		var target_angle: float = atan2(target_dir.x, target_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, rotation_speed * delta)
	else:
		_apply_deceleration(delta)

## Smoothly decelerates velocity to zero
func _apply_deceleration(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
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
	_update_overhead_badge()
	operator_incapacitated.emit(player_id)

## Restores health or revives operator
func revive(restore_hp_ratio: float = 0.5) -> void:
	is_incapacitated = false
	health_current = health_max * clampf(restore_hp_ratio, 0.1, 1.0)
	_update_overhead_badge()
	health_changed.emit(health_current, health_max)

## Updates placeholder mesh material color according to Player ID
func _update_player_color() -> void:
	if not is_inside_tree() or _mesh_instance == null:
		return
		
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if player_id >= 1 and player_id <= 4:
		material.albedo_color = SLOT_COLORS[player_id - 1]
	else:
		material.albedo_color = Color(0.7, 0.7, 0.7)
		
	_mesh_instance.material_override = material
