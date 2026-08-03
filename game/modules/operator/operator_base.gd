# operator_base.gd
# Technical Rationale: Base class for all 4 operator prototypes.
# Implements CharacterBody3D locomotion, 8-direction movement, orientation, health, overhead squad badge,
# hitscan combat with cover damage mitigation, VisionCone3D, and squad vision integration.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name OperatorBase
extends CharacterBody3D

## Signals
signal health_changed(current_hp: float, max_hp: float)
signal operator_incapacitated(p_id: int)
signal weapon_fired(origin: Vector3, direction: Vector3)
signal damage_dealt(target: OperatorBase, damage: float, mitigated_by_cover: bool)

## Player Slot ID (1 to 4)
@export_range(1, 4) var player_id: int = 1:
	set(value):
		player_id = value
		_update_player_color()
		_update_overhead_badge()

## Locomotion Parameters
@export var move_speed: float = 6.5
@export var acceleration: float = 26.0
@export var deceleration: float = 32.0
@export var rotation_speed: float = 14.0

## Health & Survival Parameters
@export var health_max: float = 100.0
@export var separation_warning_distance: float = 12.0

## Combat & Firing Parameters
@export var base_damage: float = 18.0
@export var fire_rate: float = 0.25 # Seconds between shots (4 shots/sec)
@export var weapon_range: float = 20.0
@export_flags_3d_physics var combat_collision_mask: int = 1 # Environment + Bodies

## Current health points
var health_current: float = 100.0

## State Flags
var is_incapacitated: bool = false
var is_piloting_drone: bool = false
var is_separated: bool = false

## Timers
var _fire_cooldown: float = 0.0

## Child Components
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var vision_cone: VisionCone3D = $VisionCone3D if has_node("VisionCone3D") else null
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
	_setup_vision_cone()
	_update_player_color()
	_update_overhead_badge()

func _physics_process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	if is_incapacitated or is_piloting_drone:
		_apply_deceleration(delta)
		move_and_slide()
		return

	var move_vec: Vector2 = _get_input_direction()
	_process_locomotion(move_vec, delta)
	move_and_slide()

	# Process Combat Input
	if _is_firing_input_active() and _fire_cooldown <= 0.0:
		_execute_tactical_shot()

## Initializes and configures the attached VisionCone3D node
func _setup_vision_cone() -> void:
	if vision_cone == null:
		vision_cone = VisionCone3D.new()
		vision_cone.name = "VisionCone3D"
		vision_cone.position = Vector3(0.0, 1.2, 0.0) # Eye level
		vision_cone.view_range = 16.0
		vision_cone.field_of_view_degrees = 90.0
		add_child(vision_cone)

## Creates 3D overhead badge for squad identification
func _setup_overhead_badge() -> void:
	if _overhead_label == null:
		_overhead_label = Label3D.new()
		_overhead_label.name = "OverheadBadge"
		_overhead_label.position = Vector3(0.0, 2.2, 0.0)
		_overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_overhead_label.no_depth_test = true
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
		_overhead_label.modulate = Color(1.0, 0.4, 0.2)
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

## Checks if fire button is currently pressed for this player
func _is_firing_input_active() -> bool:
	if _input_manager != null:
		return _input_manager.is_action_pressed(player_id, "fire")
	return Input.is_action_pressed("p%d_fire" % player_id) or (player_id == 1 and Input.is_key_pressed(KEY_SPACE))

## Executes a hitscan shot with cover damage mitigation and LoS evaluation
func _execute_tactical_shot() -> void:
	_fire_cooldown = fire_rate
	
	# Forward direction vector based on Y rotation
	var forward_dir: Vector3 = Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)).normalized()
	var eye_pos: Vector3 = global_position + Vector3(0.0, 1.2, 0.0)
	var target_end_pos: Vector3 = eye_pos + (forward_dir * weapon_range)
	
	weapon_fired.emit(eye_pos, forward_dir)
	
	# Exclude self from raycast
	var exclude_list: Array[RID] = [get_rid()]
	var los_res: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		self,
		eye_pos,
		target_end_pos,
		exclude_list,
		combat_collision_mask
	)

	if los_res.hit_collider != null:
		var hit_target: Object = los_res.hit_collider
		if hit_target is OperatorBase and hit_target != self:
			var target_op: OperatorBase = hit_target as OperatorBase
			if not target_op.is_incapacitated:
				_apply_mitigated_damage(target_op, eye_pos)

## Calculates cover protection and applies damage to hit operator
func _apply_mitigated_damage(target_op: OperatorBase, attacker_eye_pos: Vector3) -> void:
	var target_chest: Vector3 = target_op.global_position + Vector3(0.0, 1.2, 0.0)
	var target_feet: Vector3 = target_op.global_position + Vector3(0.0, 0.1, 0.0)
	
	# Evaluate cover protection (0.0 = clear, 0.5 = low cover, 1.0 = full cover)
	var cover_protection: float = LineOfSightQuery.check_cover_protection(
		self,
		attacker_eye_pos,
		target_chest,
		target_feet,
		[get_rid()]
	)
	
	var is_mitigated: bool = cover_protection > 0.0
	var final_damage: float = base_damage * (1.0 - cover_protection)
	
	if final_damage > 0.0:
		target_op.take_damage(final_damage)
		damage_dealt.emit(target_op, final_damage, is_mitigated)

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
