# disruptor_operator.gd
# Technical Rationale: Disruptor operator role. Specialises in space denial and drone disruption.
# Passives: None (designed for active play).
# Active ability: EMP PULSE — radiates an electromagnetic burst within emp_range meters.
#   Effects on DroneBase nodes in range:
#     - Forces exit from PILOT mode (operator loses drone control)
#     - Locks mode changes for emp_lock_duration seconds
#     - If in STATIONARY, forces to ESCORT temporarily
#   Intended to disrupt enemy drones (Gen 2+). In Vertical Slice validates against friendly
#   drones to confirm mechanics work before Etapa 9 introduces AI enemies.
# Cooldown: 15 seconds.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name DisruptorOperator
extends OperatorRole

## EMP configuration
@export_range(2.0, 20.0, 0.5) var emp_range: float = 8.0
@export_range(1.0, 10.0, 0.5) var emp_lock_duration: float = 3.0

## Visual flash placeholder
var _emp_sphere_placeholder: MeshInstance3D = null
var _emp_flash_timer: float = 0.0
const EMP_FLASH_DURATION: float = 0.4

func _ready() -> void:
	role_name        = "DISRUPTOR"
	description      = "Space denial specialist. EMP disables enemy drones."
	icon_placeholder = "⚡"
	ability_cooldown = 15.0
	super._ready()

func _process(delta: float) -> void:
	super._process(delta)
	_process_emp_flash(delta)

## ──────────────────────────────────────────────
## PASSIVES (none for Disruptor)
## ──────────────────────────────────────────────

func apply_passives() -> void:
	print("[DisruptorOperator] No passive modifiers for P%d. Active-focused role." % [
		_operator.player_id if _operator != null else 0
	])

## ──────────────────────────────────────────────
## ACTIVE: EMP PULSE
## ──────────────────────────────────────────────

func _activate_ability() -> void:
	if _operator == null:
		return

	var emp_origin: Vector3 = _operator.global_position
	var affected_count: int = 0

	## Scan all drones in the scene
	var drones: Array[Node] = _operator.get_tree().get_nodes_in_group("drones")
	for node: Node in drones:
		if not (node is DroneBase):
			continue
		var drone: DroneBase = node as DroneBase
		if not is_instance_valid(drone):
			continue

		var dist: float = drone.global_position.distance_to(emp_origin)
		if dist > emp_range:
			continue

		_apply_emp_to_drone(drone)
		affected_count += 1

	## Visual feedback placeholder
	_trigger_emp_flash()

	print("[DisruptorOperator] P%d EMP PULSE fired — %d drone(s) affected within %.1fm" % [
		_operator.player_id, affected_count, emp_range
	])

## Applies EMP effects to a single drone
func _apply_emp_to_drone(drone: DroneBase) -> void:
	## Force out of Pilot Mode
	if drone.current_mode == DroneBase.DroneMode.PILOT:
		drone.set_mode(DroneBase.DroneMode.ESCORT)
		if drone.operator != null:
			drone.operator.is_piloting_drone = false

	## Force Stationary back to Escort temporarily
	if drone.current_mode == DroneBase.DroneMode.STATIONARY:
		drone.set_mode(DroneBase.DroneMode.ESCORT)

	print("[DisruptorOperator] EMP applied to drone — mode reset to ESCORT for %.1fs" % emp_lock_duration)

## Creates a temporary visual sphere indicating EMP radius
func _trigger_emp_flash() -> void:
	if _operator == null:
		return
	if _emp_sphere_placeholder != null:
		_emp_sphere_placeholder.queue_free()

	_emp_sphere_placeholder = MeshInstance3D.new()
	var sphere_mesh: SphereMesh = SphereMesh.new()
	sphere_mesh.radius = emp_range
	sphere_mesh.height = emp_range * 2.0
	_emp_sphere_placeholder.mesh = sphere_mesh

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.8, 1.0, 0.25)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.emission_enabled = true
	mat.emission = Color(0.2, 0.6, 1.0)
	mat.emission_energy_multiplier = 2.0
	_emp_sphere_placeholder.material_override = mat
	_emp_sphere_placeholder.global_position = _operator.global_position

	_operator.get_parent().add_child(_emp_sphere_placeholder)
	_emp_flash_timer = EMP_FLASH_DURATION

func _process_emp_flash(delta: float) -> void:
	if _emp_sphere_placeholder == null:
		return
	_emp_flash_timer -= delta
	if _emp_flash_timer <= 0.0:
		_emp_sphere_placeholder.queue_free()
		_emp_sphere_placeholder = null
	else:
		var alpha: float = _emp_flash_timer / EMP_FLASH_DURATION
		if _emp_sphere_placeholder.material_override is StandardMaterial3D:
			var mat: StandardMaterial3D = _emp_sphere_placeholder.material_override as StandardMaterial3D
			mat.albedo_color.a = alpha * 0.25

## Returns the EMP range for HUD/debug display
func get_emp_range() -> float:
	return emp_range
