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
## Fired every time the drone resolves a hitscan (combat feedback/tracers).
signal weapon_fired(origin: Vector3, direction: Vector3)
## Mirrors OperatorBase.damage_dealt so the shared HUD damage-number flow works
## for drone-shot rounds against operators (same signature).
signal damage_dealt(target: OperatorBase, damage: float, mitigated_by_cover: bool)

## Drone Modes
enum DroneMode { ESCORT, STATIONARY, PILOT }

## Owner Operator
var operator: OperatorBase = null

## Maximum speed in Pilot Mode
@export var speed: float = 8.0

## Acceleration rate in Pilot Mode
@export var acceleration: float = 12.0

## Deceleration rate in Pilot Mode
@export var deceleration: float = 16.0

## Follow distance behind operator (Escort Mode)
@export var follow_distance: float = 1.8

## Height offset relative to operator (Escort Mode)
@export var follow_height_offset: float = 2.4

## Lerp factor for following operator
@export var follow_lerp_speed: float = 5.0

## Maximum operational range from operator (meters)
@export var max_range_from_operator: float = 28.0

## Maximum health points
@export var health_max: float = 500.0

## Preloaded WreckSalvage scene (Etapa 7 — extends WreckSite with salvage interaction)
@export var wreck_site_scene: PackedScene = preload("res://scenes/wreck_site.tscn")

## Current health points
var health_current: float = 500.0

# ── Drone combat (reuses WeaponBase + LineOfSightQuery infrastructure) ──────
## Drone weapon is intentionally weaker and shorter-ranged than the operator's
## GRAVITY-1 (operator: 18 dmg / 20 m). These stay exposed for scene tuning.
@export var weapon_damage: float = 8.0
@export var weapon_fire_rate: float = 0.6
@export var weapon_range: float = 12.0
## Visual Aim Cone Field of View in degrees (slightly narrower than passive 90° FOV)
@export var visual_aim_cone_fov: float = 80.0
@export var magazine_capacity: int = 16
@export var magazines_initial: int = 1
@export var reload_duration: float = 2.2
@export_flags_3d_physics var combat_collision_mask: int = 3

## Weapon System Gen 1 (ammo / reload / fire-mode authority) — same component
## chain the operators use, configured at _ready. No parallel weapon system.
var weapon: WeaponBase = null

## Combat bookkeeping.
var _fire_cooldown: float = 0.0
var _fire_input_prev: bool = false
var _auto_fire_prev: bool = false
var _burst_pending_shots: int = 0
## Autonomous-combat diagnostics (opt-in, permanent debug facility).
const AUTO_FIRE_DEBUG: bool = false
var _dbg_had_lock: bool = false
var _dbg_was_reloading: bool = false
## Autoaim: locked combat target + scan cadence (mirrors OperatorBase pattern).
var _autoaim_target: Node3D = null
var _autoaim_scan_timer: float = 0.0
const AUTO_AIM_SCAN_INTERVAL: float = 0.12
const EYE_HEIGHT: float = 0.1
const TARGET_CENTER_HEIGHT: float = 1.0

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
## Visible directional cone shown while the drone is piloted. Child of the drone,
## so it rotates with the drone's OWN aim (right stick / autoaim) — never the
## camera. Reuses the existing VisionCone3D range and field of view.
var _pilot_cone: MeshInstance3D = null

func _ready() -> void:
	add_to_group("drones")
	health_current = health_max
	_build_weapon()
	_setup_vision_cone()
	_setup_pilot_vision_cone()
	_update_visuals()

## Builds the drone's weapon from the same WeaponBase component chain the
## operators use (Magazine / AmmoReserve / ReloadState / FireMode). The drone
## gets a strictly weaker, shorter-ranged GRAVITY-D profile than GRAVITY-1.
func _build_weapon() -> void:
	weapon = WeaponBase.new()
	weapon.configure({
		"weapon_name": "GRAVITY-D",
		"base_damage": weapon_damage,
		"range": weapon_range,
		"magazine_capacity": magazine_capacity,
		"magazines_initial": magazines_initial,
		"reserve_unlimited": true,
		"reload_duration": reload_duration,
		"fire_mode_type": FireMode.Type.FULL_AUTO,
		"fire_rate": weapon_fire_rate,
		"burst_size": 1
	})
	weapon.reset()

func _physics_process(delta: float) -> void:
	if operator == null or not is_instance_valid(operator):
		return

	if weapon != null:
		weapon.tick(delta)

	_process_battery(delta)
	_process_range_checks()

	match current_mode:
		DroneMode.ESCORT:
			_process_escort_mode(delta)
			_process_autonomous_combat(delta)
		DroneMode.STATIONARY:
			_process_stationary_mode()
			_process_autonomous_combat(delta)
		DroneMode.PILOT:
			_process_pilot_mode(delta)
			_process_drone_combat(delta)

	move_and_slide()

## Initializes and configures the vision cone component
func _setup_vision_cone() -> void:
	if vision_cone == null:
		vision_cone = VisionCone3D.new()
		vision_cone.name = "VisionCone3D"
		add_child(vision_cone)
	vision_cone.view_range = 24.0
	vision_cone.field_of_view_degrees = 90.0

## Builds the visible PILOT vision cone. A flat fan that mirrors the drone's own
## VisionCone3D range/field-of-view; because it is a child of the drone it
## rotates with the drone's aim direction, independent of the shared camera.
func _setup_pilot_vision_cone() -> void:
	if _pilot_cone != null:
		return
	_pilot_cone = MeshInstance3D.new()
	_pilot_cone.name = "PilotVisionCone"
	_pilot_cone.visible = false
	_pilot_cone.mesh = _build_pilot_cone_mesh()
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.35, 0.75, 1.0, 0.16)
	mat.emission_enabled = true
	mat.emission = Color(0.25, 0.55, 0.95)
	mat.emission_energy_multiplier = 0.5
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.no_depth_test = true
	mat.render_priority = 10
	_pilot_cone.material_override = mat
	add_child(_pilot_cone)

## Procedural fan mesh in the drone's local XZ plane (forward = -Z). Reach is the
## drone's WEAPON range (the actual combat envelope), field of view from visual_aim_cone_fov,
## so the visible cone tells the player where manual shots land while passive detection
## operates with its own wider range and FOV in VisionCone3D.
func _build_pilot_cone_mesh() -> ArrayMesh:
	var vr: float = weapon.range if weapon != null else weapon_range
	var fov: float = visual_aim_cone_fov
	var half: float = deg_to_rad(fov * 0.5)
	var segs: int = 16
	var st: SurfaceTool = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center: Vector3 = Vector3(0.0, 0.1, 0.0)
	var prev: Vector3 = center + Vector3(sin(-half), 0.0, -cos(-half)) * vr
	for i: int in range(1, segs + 1):
		var a: float = -half + (2.0 * half) * (float(i) / float(segs))
		var tip: Vector3 = center + Vector3(sin(a), 0.0, -cos(a)) * vr
		st.add_vertex(center)
		st.add_vertex(prev)
		st.add_vertex(tip)
		prev = tip
	st.generate_normals()
	return st.commit()

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

## Checks range constraint relative to operator position (updates status flag without artificial mode disconnect)
func _process_range_checks() -> void:
	var dist: float = global_position.distance_to(operator.global_position)
	is_drifting = dist > max_range_from_operator

## Escort Mode movement: flies smoothly toward operator escort target using velocity-based autopilot
func _process_escort_mode(delta: float) -> void:
	var op_transform: Transform3D = operator.global_transform
	var target_offset: Vector3 = op_transform.basis.z * follow_distance
	var target_pos: Vector3 = op_transform.origin + target_offset + Vector3(0.0, follow_height_offset, 0.0)

	var to_target: Vector3 = target_pos - global_position
	var dist: float = to_target.length()

	if dist < 0.05:
		velocity = Vector3.ZERO
		global_position = target_pos
		rotation.y = lerp_angle(rotation.y, operator.rotation.y, follow_lerp_speed * delta)
		return

	var desired_dir: Vector3 = to_target / dist
	var target_speed: float = minf(speed, dist * 2.5)
	var target_velocity: Vector3 = desired_dir * target_speed

	velocity.x = move_toward(velocity.x, target_velocity.x, acceleration * delta)
	velocity.y = move_toward(velocity.y, target_velocity.y, acceleration * delta)
	velocity.z = move_toward(velocity.z, target_velocity.z, acceleration * delta)

	if dist > 0.5:
		var target_angle: float = atan2(-desired_dir.x, -desired_dir.z)
		rotation.y = lerp_angle(rotation.y, target_angle, follow_lerp_speed * delta)
	else:
		rotation.y = lerp_angle(rotation.y, operator.rotation.y, follow_lerp_speed * delta)

## Stationary Mode: locks position
func _process_stationary_mode() -> void:
	velocity = Vector3.ZERO

## Pilot Mode: direct locomotion mapping from input manager.
## LEFT stick drives movement; RIGHT stick (aim actions) drives the drone's
## facing/aim direction, fully isolated from the operator's own aim_yaw.
## True when the operator is actively holding the manual aim input (RMB / right stick)
func _is_aiming_input_active() -> bool:
	if operator == null or operator._input_manager == null:
		return false
	if operator._is_using_mouse():
		return operator._input_manager.is_action_pressed(operator.player_id, "aim_cone")
	var aim_vec: Vector2 = operator._input_manager.get_aim_vector(operator.player_id)
	return aim_vec.length_squared() > 0.01 or operator._input_manager.is_action_pressed(operator.player_id, "aim_cone") or operator._input_manager.is_action_pressed(operator.player_id, "autoaim")

## Pilot Mode: direct locomotion mapping from input manager.
## LEFT stick drives movement; RIGHT stick / RMB drives the drone's
## manual facing/aim direction, fully isolated from the operator's own aim_yaw.
func _process_pilot_mode(delta: float) -> void:
	var move_vec: Vector2 = Vector2.ZERO
	if operator._input_manager != null:
		move_vec = operator._input_manager.get_movement_vector(operator.player_id)

	var move_len: float = move_vec.length()

	if move_len > 0.01:
		var input_len: float = minf(move_len, 1.0)
		var move_dir: Vector3 = Vector3(move_vec.x, 0.0, move_vec.y) / move_len
		var target_vel_x: float = move_dir.x * speed * input_len
		var target_vel_z: float = move_dir.z * speed * input_len
		
		velocity.x = move_toward(velocity.x, target_vel_x, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_vel_z, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	
	# Manual aim input check (RMB / Right stick): visual cone is visible ONLY while actively aiming.
	var is_aiming: bool = _is_aiming_input_active()
	if _pilot_cone != null:
		_pilot_cone.visible = is_aiming

	if is_aiming:
		if operator._is_using_mouse():
			var cam: Camera3D = operator._mouse_camera_override
			if cam == null and get_viewport() != null:
				cam = get_viewport().get_camera_3d()
			if cam != null:
				var cursor: Vector2 = operator._mouse_cursor_override
				if cursor.is_equal_approx(Vector2.INF):
					var vp: Viewport = get_viewport()
					if vp != null:
						cursor = vp.get_mouse_position()
				var world: Vector3 = OperatorBase._project_cursor_to_floor(cam, cursor, global_position.y)
				if world.is_finite():
					var to_cursor: Vector3 = world - global_position
					to_cursor.y = 0.0
					if to_cursor.length_squared() > 0.0001:
						var target_yaw: float = atan2(-to_cursor.x, -to_cursor.z)
						rotation.y = lerp_angle(rotation.y, target_yaw, follow_lerp_speed * delta)
		else:
			var aim_vec: Vector2 = operator._input_manager.get_aim_vector(operator.player_id)
			if aim_vec.length_squared() > 0.01:
				var aim_angle: float = atan2(-aim_vec.x, -aim_vec.y)
				rotation.y = lerp_angle(rotation.y, aim_angle, follow_lerp_speed * delta)
	elif move_len > 0.01:
		# When not aiming, face movement direction
		var move_dir_norm: Vector3 = Vector3(move_vec.x, 0.0, move_vec.y) / move_len
		var target_angle: float = atan2(-move_dir_norm.x, -move_dir_norm.z)
		rotation.y = lerp_angle(rotation.y, target_angle, follow_lerp_speed * delta)
	
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
		# Fresh trigger state so a fire press that was already held before
		# entering Pilot does not instantly queue an extra round.
		_fire_cooldown = 0.0
		_fire_input_prev = false
		# Manual control takes over: drop any autonomous lock and trigger state.
		_release_combat_target()
		_auto_fire_prev = false
	else:
		_release_combat_target()

	if _pilot_cone != null:
		_pilot_cone.visible = false

	_update_visuals()
	mode_changed.emit(current_mode)

## ──────────────────────────────────────────────
## DRONE COMBAT (PILOT fire), reusing the existing
## WeaponBase / FireMode / LineOfSightQuery / GameRules modules. Manual hitscan
## aim along the drone's facing — NO autoaim or target lock.
## ──────────────────────────────────────────────

## True while the drone hovers inside its operator's own team protected spawn
## room. The drone is the combat unit that fires, so ITS position gates PILOT
## fire (not the operator's): a drone that has flown out of the room may fire
## even if the operator stays home, while a drone parked inside the room is
## locked out. Mirrors SpawnZone.is_protected() against the drone's position.
func _in_spawn_zone() -> bool:
	if not is_inside_tree() or operator == null:
		return false
	var tree: SceneTree = get_tree()
	if tree == null:
		return false
	var my_team: int = operator.team_id
	for node: Node in tree.get_nodes_in_group(SpawnZone.GROUP):
		var zone: SpawnZone = node as SpawnZone
		if zone != null and zone.team_id == my_team and zone.is_position_inside(global_position):
			return true
	return false

## PILOT fire loop: reads the fire action off the operator's InputManager
## and resolves manual hitscan shots along the drone's facing. Runs only while
## the drone is being piloted.
func _process_drone_combat(delta: float) -> void:
	if weapon == null:
		return
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	var fire_pressed: bool = false
	if operator != null and operator._input_manager != null:
		fire_pressed = operator._input_manager.is_action_pressed(operator.player_id, "fire")
	else:
		fire_pressed = false

	# Spawn protection: no round is consumed or resolved while the DRONE itself
	# is inside a protected room (its own spawn-room occupancy, not the
	# operator's — the drone is the firing combat unit).
	var spawn_blocked: bool = _in_spawn_zone()

	var fire_trigger: bool = false
	var effective_pressed: bool = fire_pressed and not spawn_blocked
	if weapon.fire_mode != null:
		fire_trigger = weapon.fire_mode.evaluate_trigger(effective_pressed, _fire_input_prev)
	_fire_input_prev = fire_pressed

	if fire_trigger and _fire_cooldown <= 0.0 and not spawn_blocked:
		if weapon.try_consume_round():
			_execute_drone_shot()

## ──────────────────────────────────────────────
## AUTONOMOUS COMPANION COMBAT (Escort / Stationary)
## Keeps the EXISTING combat-target infrastructure warm every frame: acquires
## the best enemy inside weapon range with clear LoS, aims the hull at the lock,
## and fires through the SAME WeaponBase / FireMode / LineOfSightQuery pipeline
## as pilot mode whenever the weapon is ready. The loop survives magazine
## exhaustion: try_consume_round() auto-starts the reload, weapon.tick()
## (called every frame in _physics_process) advances it, and firing resumes
## automatically against a still-valid target. No manual input involved.
## ──────────────────────────────────────────────
func _process_autonomous_combat(delta: float) -> void:
	if weapon == null or operator == null:
		return
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta

	# Refresh the lock on the shared cadence; _acquire_combat_target keeps a
	# still-valid lock or re-picks (range / LoS / team / alive rules included).
	_autoaim_scan_timer -= delta
	if _autoaim_scan_timer <= 0.0:
		_autoaim_scan_timer = AUTO_AIM_SCAN_INTERVAL
		_acquire_combat_target()

	var has_lock: bool = _autoaim_target != null and is_instance_valid(_autoaim_target)

	if AUTO_FIRE_DEBUG and has_lock != _dbg_had_lock:
		print("[DroneDebug] %s lock -> %s" % [name, str(_autoaim_target)])
		_dbg_had_lock = has_lock

	if has_lock:
		# Aim: rotate the hull toward the locked enemy so shots leave the nose.
		var to_target: Vector3 = _autoaim_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length_squared() > 0.0001:
			var yaw: float = atan2(-to_target.x, -to_target.z)
			rotation.y = lerp_angle(rotation.y, yaw, follow_lerp_speed * delta)

	# Spawn protection mirrors pilot mode: the drone itself must be outside.
	var spawn_blocked: bool = _in_spawn_zone()
	var want_fire: bool = has_lock and not spawn_blocked
	var trigger: bool = false
	if weapon.fire_mode != null:
		trigger = weapon.fire_mode.evaluate_trigger(want_fire, _auto_fire_prev)
	_auto_fire_prev = want_fire

	if trigger and _fire_cooldown <= 0.0 and not spawn_blocked:
		if weapon.try_consume_round():
			_execute_drone_shot(_autoaim_target)

	if AUTO_FIRE_DEBUG:
		var reloading_now: bool = weapon.is_reloading()
		if reloading_now != _dbg_was_reloading:
			if reloading_now:
				print("[DroneDebug] %s RELOAD START mag=%d/%d reserve=%d%s" % [
					name, weapon.magazine.current_rounds, weapon.magazine.capacity,
					weapon.reserve.magazines_remaining,
					" (unlimited)" if weapon.reserve.unlimited_magazines else ""])
			else:
				print("[DroneDebug] %s RELOAD DONE mag=%d/%d — resuming fire checks" % [
					name, weapon.magazine.current_rounds, weapon.magazine.capacity])
			_dbg_was_reloading = reloading_now

## Resolves one hitscan shot with cover mitigation. When `target` is provided
## (autonomous combat) the ray is resolved against the target's stance-aware
## origin — operators report their own eye height via get_vision_origin(), so a
## crouching enemy is aimed at correctly; drones are aimed at their body.
## Without a target the legacy behaviour stands: manual hitscan along the
## drone's facing, pitched down to battlefield height. Both paths reuse the same
## LineOfSightQuery + GameRules pipeline as the operator.
func _execute_drone_shot(target: Node3D = null) -> void:
	_fire_cooldown = weapon.fire_mode.fire_rate if weapon.fire_mode != null else weapon_fire_rate

	var muzzle_pos: Vector3 = global_position
	var range_dist: float = weapon.range if weapon != null else weapon_range
	var target_end_pos: Vector3
	if target != null and is_instance_valid(target):
		if target is OperatorBase and (target as OperatorBase).has_method("get_vision_origin"):
			target_end_pos = (target as OperatorBase).get_vision_origin()
		else:
			target_end_pos = target.global_position
	else:
		var horiz_dir: Vector3 = Vector3(-sin(rotation.y), 0.0, -cos(rotation.y)).normalized()
		# Pitch the 3D ray trajectory from the airborne drone (y=2.4m) toward battlefield target height (y=0.9m)
		# so shots intersect cover/walls and land visibly on ground targets.
		target_end_pos = global_position + (horiz_dir * range_dist)
		target_end_pos.y = 0.9
	var shot_dir: Vector3 = (target_end_pos - muzzle_pos).normalized()

	weapon_fired.emit(muzzle_pos, shot_dir)

	var los_res: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		self,
		muzzle_pos,
		target_end_pos,
		[get_rid()],
		combat_collision_mask
	)

	if los_res.hit_collider != null:
		var hit_target: Object = los_res.hit_collider
		if hit_target is OperatorBase and hit_target != operator:
			var target_op: OperatorBase = hit_target as OperatorBase
			if not target_op.is_incapacitated:
				_apply_combat_damage(target_op, muzzle_pos)
		elif hit_target is DroneBase and hit_target != self:
			_apply_combat_damage(hit_target as DroneBase, muzzle_pos)

## Applies cover-mitigated damage from the drone's weapon profile. Mirrors the
## operator's shared damage pipeline (friendly-fire gate, cover sampling, signal
## flow) with the drone as attacker and its own weaker damage value.
func _apply_combat_damage(target: Node3D, attacker_eye_pos: Vector3) -> void:
	var is_operator: bool = target is OperatorBase
	var is_drone: bool = target is DroneBase
	if not is_operator and not is_drone:
		return

	var my_team: int = operator.team_id if operator != null else OperatorBase.TEAM_DEFENDERS
	var target_team: int = OperatorBase.TEAM_DEFENDERS
	if is_operator:
		target_team = (target as OperatorBase).team_id
	else:
		var target_drone: DroneBase = target as DroneBase
		if target_drone.operator != null:
			target_team = target_drone.operator.team_id
	if target_team == my_team:
		var rules: GameRules = GameRules.get_rules(self)
		var ff_enabled: bool = rules.friendly_fire_enabled if rules != null else false
		if not ff_enabled:
			return

	var target_chest: Vector3
	var target_feet: Vector3
	if is_operator:
		target_chest = target.global_position + Vector3(0.0, 1.2, 0.0)
		target_feet = target.global_position + Vector3(0.0, 0.1, 0.0)
	else:
		target_chest = target.global_position
		target_feet = target.global_position - Vector3(0.0, 0.3, 0.0)

	var cover_protection: float = LineOfSightQuery.check_cover_protection(
		self,
		attacker_eye_pos,
		target_chest,
		target_feet,
		[get_rid()]
	)

	var is_mitigated: bool = cover_protection > 0.0
	var final_damage: float = weapon.base_damage * (1.0 - cover_protection)

	if final_damage > 0.0:
		if is_operator:
			var shot_dir: Vector3 = (target.global_position - attacker_eye_pos)
			shot_dir.y = 0.0
			if shot_dir.length_squared() > 0.001:
				shot_dir = shot_dir.normalized()
			(target as OperatorBase).take_damage(final_damage, shot_dir)
			damage_dealt.emit(target as OperatorBase, final_damage, is_mitigated)
		else:
			(target as DroneBase).take_damage(final_damage)

## Refreshes the drone's autoaim lock: keeps a valid lock, otherwise acquires
## the best enemy (operator or drone) inside weapon range with clear LoS.
func _acquire_combat_target() -> void:
	if not is_instance_valid(_autoaim_target):
		_release_combat_target()
		_autoaim_target = null
	if _is_combat_target_valid(_autoaim_target):
		return
	_release_combat_target()
	_autoaim_target = null

	var my_team: int = operator.team_id if operator != null else OperatorBase.TEAM_DEFENDERS
	var best: Node3D = null
	var best_score: float = INF
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node is OperatorBase and not node.is_queued_for_deletion():
			var op: OperatorBase = node as OperatorBase
			if op != operator and op.team_id != my_team and not op.is_incapacitated:
				var score: float = _combat_target_score(op)
				if score < best_score:
					best_score = score
					best = op
	for node: Node in get_tree().get_nodes_in_group("drones"):
		if node is DroneBase and not node.is_queued_for_deletion():
			var drone: DroneBase = node as DroneBase
			if drone != self and drone.operator != null and drone.operator.team_id != my_team:
				var score: float = _combat_target_score(drone)
				if score < best_score:
					best_score = score
					best = drone
	if best != null and _has_clear_los(best):
		_autoaim_target = best
		_bind_combat_target(best)

## Binds the lock's destruction/down signals for immediate retargeting.
func _bind_combat_target(target: Node3D) -> void:
	if target is DroneBase:
		(target as DroneBase).destroyed.connect(_on_combat_target_destroyed)
	elif target is OperatorBase:
		(target as OperatorBase).operator_incapacitated.connect(_on_combat_target_down)

## Drops the lock bookkeeping. Safe when no lock is active.
func _release_combat_target() -> void:
	if _autoaim_target == null:
		return
	if is_instance_valid(_autoaim_target):
		if _autoaim_target is DroneBase:
			var d: DroneBase = _autoaim_target as DroneBase
			if d.destroyed.is_connected(_on_combat_target_destroyed):
				d.destroyed.disconnect(_on_combat_target_destroyed)
		elif _autoaim_target is OperatorBase:
			var o: OperatorBase = _autoaim_target as OperatorBase
			if o.operator_incapacitated.is_connected(_on_combat_target_down):
				o.operator_incapacitated.disconnect(_on_combat_target_down)
	_autoaim_target = null

func _on_combat_target_destroyed() -> void:
	_autoaim_target = null

func _on_combat_target_down(_p_id: int) -> void:
	_autoaim_target = null

## True when the target is still a valid enemy lock for this drone.
func _is_combat_target_valid(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.is_queued_for_deletion():
		return false
	var my_team: int = operator.team_id if operator != null else OperatorBase.TEAM_DEFENDERS
	var is_enemy: bool = false
	if target is OperatorBase:
		var op: OperatorBase = target as OperatorBase
		is_enemy = op.team_id != my_team and not op.is_incapacitated
	elif target is DroneBase:
		var drone: DroneBase = target as DroneBase
		is_enemy = drone.operator != null and drone.operator.team_id != my_team
	if not is_enemy:
		return false
	if global_position.distance_to(target.global_position) > weapon.range:
		return false
	return _has_clear_los(target)

## LoS check for the drone's autoaim acquisition (clear line to target center).
func _has_clear_los(target: Node3D) -> bool:
	var eye_pos: Vector3 = global_position + Vector3(0.0, EYE_HEIGHT, 0.0)
	var target_pos: Vector3 = target.global_position + Vector3(0.0, TARGET_CENTER_HEIGHT, 0.0)
	var los: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		self, eye_pos, target_pos, [get_rid()], combat_collision_mask
	)
	return los.is_visible

## Target scoring: nearest wins.
func _combat_target_score(target: Node3D) -> float:
	var dist: float = global_position.distance_to(target.global_position)
	if dist > weapon.range:
		return INF
	return dist

## Applies damage to drone and triggers destruction on HP depletion
func take_damage(amount: float) -> void:
	health_current = maxf(0.0, health_current - amount)
	health_changed.emit(health_current, health_max)
	
	if health_current <= 0.0:
		_destroy()

## Triggers destruction and spawns WreckSalvage for resource recovery (Etapa 7)
func _destroy() -> void:
	_release_combat_target()
	destroyed.emit()
	if wreck_site_scene != null:
		var wreck: WreckSite = wreck_site_scene.instantiate() as WreckSite
		if wreck != null:
			wreck.position = global_position
			get_parent().add_child(wreck)
			## If the wreck is a WreckSalvage, register it with ResourceManager
			if wreck is WreckSalvage:
				var rm_nodes: Array[Node] = get_tree().get_nodes_in_group("resource_manager")
				if not rm_nodes.is_empty():
					var rm: ResourceManager = rm_nodes[0] as ResourceManager
					if rm != null:
						rm.register_wreck_salvage(wreck as WreckSalvage)
	
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
