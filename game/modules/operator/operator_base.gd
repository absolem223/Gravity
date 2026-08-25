# operator_base.gd
# Technical Rationale: Base class for all 4 operator prototypes.
# Implements CharacterBody3D locomotion, 8-direction movement, orientation, health, overhead squad badge,
# hitscan combat with cover damage mitigation, VisionCone3D, permanent Drone, shared tactical battery,
# and ResourceInventory (Etapa 7).
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name OperatorBase
extends CharacterBody3D

## ── Inner class: Tactical Vision Cone ─────────────────────────────────────
## Visual tactical cone displayed during PRECISION_AIM. Generates procedural
## mesh from LoS raycasts that respect actual map geometry.
class TacticalVisionCone extends MeshInstance3D:
	const RAYS_PER_HALF: int = 18
	const FLOOR_OFFSET: float = 0.05
	const CONE_FILL_COLOR: Color = Color(0.12, 0.45, 0.55, 0.12)
	const WEAPON_RANGE_COLOR: Color = Color(0.95, 0.65, 0.15, 0.25)
	var _fill_material: StandardMaterial3D = null

	func _ready() -> void:
		_fill_material = StandardMaterial3D.new()
		_fill_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_fill_material.albedo_color = CONE_FILL_COLOR
		_fill_material.emission_enabled = true
		_fill_material.emission = Color(0.1, 0.3, 0.4)
		_fill_material.emission_energy_multiplier = 0.3
		_fill_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_fill_material.no_depth_test = true
		_fill_material.render_priority = 10
		material_override = _fill_material

	func update_cone(op: Node, blend: float) -> void:
		if op == null or not op.is_inside_tree():
			return
		var vc: Node = op.get_node_or_null("VisionCone3D")
		if vc == null:
			return
		var vr: float = vc.get("view_range") if vc.get("view_range") != null else 16.0
		var fov: float = vc.get("field_of_view_degrees") if vc.get("field_of_view_degrees") != null else 90.0
		var wr: float = op.weapon_range if "weapon_range" in op else 20.0
		if "weapon" in op and op.weapon != null:
			wr = op.weapon.range
		var rr: float = op.reveal_radius if "reveal_radius" in op else 16.0
		var ay: float = op.aim_yaw if "aim_yaw" in op else 0.0
		# The cone follows the SAME authoritative XZ aim direction firing uses, so
		# the gamepad right stick points the visible cone horizontally exactly
		# where it points. Mouse/keyboard aim is unchanged.
		var fwd: Vector3 = Vector3(-sin(ay), 0.0, -cos(ay))
		if "aim_direction" in op:
			var d: Vector3 = op.aim_direction as Vector3
			if d.length_squared() > 0.0001:
				fwd = d.normalized()
		if _fill_material != null:
			var a: float = CONE_FILL_COLOR.a * blend
			_fill_material.albedo_color = Color(CONE_FILL_COLOR.r, CONE_FILL_COLOR.g, CONE_FILL_COLOR.b, a)
		_build_mesh(op, vr, fov, wr, rr, fwd)

	func _build_mesh(op: Node, vr: float, fov: float, wr: float, rr: float, fwd: Vector3) -> void:
		if not op.is_inside_tree():
			return
		var st: SurfaceTool = SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		# Raycasts use world space; mesh vertices must be LOCAL to this MeshInstance3D
		# (child of the operator) so Godot's transform chain does not double-apply
		# the operator's global_position.
		var world_origin: Vector3 = op.get_vision_origin() if op.has_method("get_vision_origin") else op.global_position + Vector3(0.0, 1.35, 0.0)
		var local_origin: Vector3 = to_local(world_origin)
		# Floor-plane base: drop every vertex onto the operator's foot plane so the
		# cone lies flat on the ground.
		var floor_y: float = to_local(op.global_position).y + FLOOR_OFFSET
		var yaw: float = atan2(-fwd.x, -fwd.z)
		var hf: float = deg_to_rad(fov * 0.5)
		var up: Vector3 = Vector3.UP
		# The cone's visual reach uses reveal_radius (16m) so the visible fan matches
		# the ground fog reveal circle. Detection still uses vr (vision_cone.view_range).
		# The orange inner ring (drawn below) still marks the separate weapon fire-reach.
		var mr: float = rr
		local_origin = Vector3(local_origin.x, floor_y, local_origin.z)
		var eps: Array[Vector3] = []
		for i: int in range(-RAYS_PER_HALF, RAYS_PER_HALF + 1):
			var t: float = float(i) / float(RAYS_PER_HALF)
			var d: Vector3 = Vector3(-sin(yaw + t * hf), 0.0, -cos(yaw + t * hf))
			var world_tgt: Vector3 = world_origin + d * mr
			var ss: PhysicsDirectSpaceState3D = op.get_world_3d().direct_space_state
			if ss != null:
				var exc: Array[RID] = []
				if op is CollisionObject3D:
					exc.append(op.get_rid())
				var q: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(world_origin, world_tgt, 1, exc)
				q.collide_with_bodies = true
				q.collide_with_areas = false
				var h: Dictionary = ss.intersect_ray(q)
				if not h.is_empty():
					world_tgt = h.get("position", world_tgt) as Vector3
			var local_hit: Vector3 = to_local(world_tgt)
			local_hit.y = floor_y
			eps.append(local_hit)
		for i: int in range(eps.size() - 1):
			var pa: Vector3 = eps[i]
			var pb: Vector3 = eps[i + 1]
			st.set_normal(up); st.add_vertex(local_origin + up * FLOOR_OFFSET)
			st.set_normal(up); st.add_vertex(pa + up * FLOOR_OFFSET)
			st.set_normal(up); st.add_vertex(pb + up * FLOOR_OFFSET)
			st.set_normal(up); st.add_vertex(local_origin + up * FLOOR_OFFSET)
			st.set_normal(up); st.add_vertex(pb + up * FLOOR_OFFSET)
			st.set_normal(up); st.add_vertex(pa + up * FLOOR_OFFSET)
		if wr < mr - 0.5:
			var segs: int = 12
			var th: float = 0.15
			var inv_basis: Basis = global_transform.basis.inverse()
			for i: int in range(-segs, segs):
				var da_world: Vector3 = Vector3(-sin(yaw + float(i) / float(segs) * hf), 0.0, -cos(yaw + float(i) / float(segs) * hf))
				var db_world: Vector3 = Vector3(-sin(yaw + float(i + 1) / float(segs) * hf), 0.0, -cos(yaw + float(i + 1) / float(segs) * hf))
				var da_local: Vector3 = (inv_basis * da_world).normalized()
				var db_local: Vector3 = (inv_basis * db_world).normalized()
				var pa: Vector3 = to_local(world_origin + da_world * wr)
				var pb: Vector3 = to_local(world_origin + db_world * wr)
				pa.y = floor_y + 0.02
				pb.y = floor_y + 0.02
				st.set_normal(up); st.add_vertex(pa - da_local * th * 0.5)
				st.set_normal(up); st.add_vertex(pa + da_local * th * 0.5)
				st.set_normal(up); st.add_vertex(pb + db_local * th * 0.5)
				st.set_normal(up); st.add_vertex(pa - da_local * th * 0.5)
				st.set_normal(up); st.add_vertex(pb + db_local * th * 0.5)
				st.set_normal(up); st.add_vertex(pb - db_local * th * 0.5)
		mesh = st.commit()

## Signals
signal health_changed(current_hp: float, max_hp: float)
signal operator_incapacitated(p_id: int)
signal weapon_fired(origin: Vector3, direction: Vector3)
signal damage_dealt(target: OperatorBase, damage: float, mitigated_by_cover: bool)
signal drone_status_changed(p_id: int, has_drone: bool, mode: String)
signal resource_collected(resource_type: String, amount: int)
signal precision_aim_changed(active: bool)

## Operator State Machine (prepared for future FSM expansion)
enum OperatorState {
	ALIVE,
	DOWNED,
	DEAD
}

@export_category("Identity & Slot")
@export_group("Player Configuration")
## Player Slot ID (1 to 4)
@export_range(1, 4) var player_id: int = 1:
	set(value):
		player_id = value
		_update_player_color()
		_update_overhead_badge()

@export_category("Locomotion Parameters")
@export_group("Movement Values")
@export var move_speed: float = 6.5
@export var acceleration: float = 26.0
@export var deceleration: float = 32.0
@export var rotation_speed: float = 14.0

@export_group("Dash (Combat Feel Pass 01)")
## Dash burst duration in seconds (spec: 0.20 s).
@export var dash_duration: float = 0.20
## Horizontal distance covered by a full dash in meters (spec: ~3 m).
@export var dash_distance: float = 3.0
## Cooldown before the dash can be triggered again in seconds (spec: 2.5 s).
@export var dash_cooldown: float = 2.5

@export_category("Health & Survival")
@export_group("Vital Stats")
@export var health_max: float = 250.0
@export var separation_warning_distance: float = 12.0
@export var damage_knockback_impulse: float = 3.0

@export_category("Combat & Firing")
@export_group("Weapon Parameters")
@export var base_damage: float = 18.0
@export var fire_rate: float = 0.9
@export var weapon_range: float = 20.0
@export_flags_3d_physics var combat_collision_mask: int = 3

@export_group("Weapon System (Gen 1)")
## Rounds per magazine.
@export var magazine_capacity: int = 30
## Magazines carried at spawn.
@export var magazines_initial: int = 3
## Automatic reload duration in seconds (starts when a magazine empties).
@export var reload_duration: float = 2.0
## Rounds fired per press in BURST fire mode.
@export var weapon_burst_size: int = 3
## Time between rounds inside a single burst press (TA-TA-TA pacing).
@export var weapon_burst_interval: float = 0.1

@export_category("Vision & Fog")
@export_group("Map Exploration")
## Radius (meters) of the circular ground area this operator's movement reveals
## in the persistent Fog of War map. Decoupled from vision_cone.view_range, which
## is the transient enemy-detection range. The FogOfWarDisplay reads this value.
@export var reveal_radius: float = 16.0

@export_category("Drone Integration")
@export_group("Drone Scene")
@export var drone_scene: PackedScene = preload("res://scenes/drone.tscn")
var drone: DroneBase = null
var has_drone_active: bool = false

## Shared Tactical Battery (0.0 to 100.0)
var battery_max: float = 100.0
var battery_current: float = 100.0

## Current health points
var health_current: float = 100.0

## Resource Inventory (Etapa 7) — composed at _ready
var inventory: ResourceInventory = null

## Active Operator Role doctrine (Etapa 8 — composition)
var role: OperatorRole = null

## Damage mitigation factor (0.0 = none, 0.2 = 20%, etc.)
var damage_mitigation: float = 0.0

## Team assignment constants (0 = ATTACKERS, 1 = DEFENDERS)
const TEAM_ATTACKERS: int = 0
const TEAM_DEFENDERS: int = 1

## Default fallbacks if GameRules node is absent
const DEFAULT_RESPAWN_TIME: float = 5.0
const DEFAULT_INVULNERABILITY_TIME: float = 2.0

## ── SFX wiring (Gameplay SFX V1) ──────────────────────────────────────────────
## Footsteps use the pre-migrated operator footstep loop. dash / landing / death /
## damage have NO appropriate migrated asset yet, so their call sites are PENDING.
const FOOTSTEP_STREAM: AudioStream = preload("res://audio/sfx/operator/footsteps/operator_footsteps_01.mp3")
const GUNSHOT_STREAM: AudioStream = preload("res://audio/sfx/weapons/rifle/fire/weapons_rifle_fire_01.wav")
var _audio_manager: Node = null
var _footstep_timer: float = 0.0
var _was_moving: bool = false

## Team assignment (0 = ATTACKERS, 1 = DEFENDERS)
var team_id: int = TEAM_ATTACKERS

## When true, this operator ignores local human input (Etapa 9 AI will drive behavior).
var is_ai_controlled: bool = false

## ── AI Drive (written every physics frame by the AIController) ─────────────
## The AI brain drives AI operators through these public hooks instead of raw
## input. They are consumed only when is_ai_controlled is true and are ignored
## by (and independent of) the per-player InputProfile system.
var ai_move_input: Vector2 = Vector2.ZERO
var ai_aim_yaw: float = 0.0
var ai_fire_input: bool = false

## State Machine Instance
var current_state: OperatorState = OperatorState.ALIVE

## State convenience getters/setters for backward compatibility
var is_dead: bool:
	get:
		return current_state == OperatorState.DEAD

var is_incapacitated: bool:
	get:
		return current_state == OperatorState.DEAD or current_state == OperatorState.DOWNED
	set(val):
		if val and current_state == OperatorState.ALIVE:
			current_state = OperatorState.DOWNED
			_stop_footsteps()
		elif not val and current_state != OperatorState.ALIVE:
			current_state = OperatorState.ALIVE

var is_invulnerable: bool = false
var is_piloting_drone: bool = false
var is_separated: bool = false

## Death & Respawn Timers
var respawn_timer: float = 0.0
var invulnerability_timer: float = 0.0

## Spawn-room protection cache (badge refresh only on change).
var _spawn_protected_prev: bool = false

## Timers
var _fire_cooldown: float = 0.0
var _mode_button_press_duration: float = 0.0
var _is_pressing_mode_button: bool = false

## Weapon System Gen 1 (built from exported tuning in _ready)
var weapon: WeaponBase = null
## Previous frame fire trigger state (needed by FireMode trigger evaluation)
var _fire_input_prev: bool = false
## Rounds still owed by the current burst press (BURST pacing).
var _burst_pending_shots: int = 0

## Sprint / Crouch state
var is_sprinting: bool = false
var is_crouching: bool = false
var _crouch_prev_pressed: bool = false
var _sprint_prev_pressed: bool = false

## Dash state (replaces the previous sustained sprint)
var is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_cooldown_timer: float = 0.0
var _dash_direction: Vector3 = Vector3.FORWARD

## Shared ActionRuntime injected by PlayerManager (used for sprint via Action System)
var _action_runtime: ActionRuntime = null

## ── Aim System (decoupled from movement) ──────────────────────────────────
## Sources that can feed the canonical aim direction. The rest of the game only
## reads aim_yaw / aim_direction, so new sources (gamepad, AI, network) plug in
## without touching locomotion, firing or vision systems.
enum AimSource {
	MOVEMENT,      ## Aim follows the movement direction (legacy behaviour, default)
	AUTO_AIM,      ## Hold autoaim button: lock nearest enemy, auto-fire when in range
	MOUSE,         ## Reserved: cursor -> world direction (local player)
	GAMEPAD,       ## Reserved: right stick direction
	AI,            ## Reserved: AI controller feeds aim_yaw directly
	NETWORK,       ## Reserved: replicated aim_yaw from remote player
	PRECISION_AIM  ## Hold precision aim input: reduced sensitivity, tactical cone visible
}

## Aim state for FREE_AIM / PRECISION_AIM distinction
enum AimState {
	FREE_AIM,      ## Normal gameplay: responsive aiming, no tactical cone
	PRECISION_AIM  ## Tactical aiming: reduced sensitivity, cone visible
}

## Canonical aim yaw (radians). Single source of truth for facing & firing.
var aim_yaw: float = 0.0
## Cached XZ-normalized aim direction derived from aim_yaw. Stays FLAT (y=0) so
## the gameplay systems (firing, autoaim cone gate, fog-of-war, ground targeting)
## all read the character-owned aim direction.
var aim_direction: Vector3 = Vector3(0.0, 0.0, -1.0)

## ── Input diagnostic instrumentation (temporary overlay) ───────────────────
## Read by the temporary RuntimeInputDiag overlay. Purely presentational: never
## affects gameplay.
## How many physics frames `_update_aim_input_gamepad()` actually drove the aim.
var diag_aim_input_calls: int = 0
## Last right-stick aim vector the operator read from the InputManager.
var diag_last_aim_vec: Vector2 = Vector2.ZERO

## Diagnostic accessors for the optional overlay.
func diag_using_mouse() -> bool:
	return _is_using_mouse()

func diag_aim_source_name() -> String:
	match _aim_source:
		AimSource.MOVEMENT: return "MOVEMENT"
		AimSource.AUTO_AIM: return "AUTO_AIM"
		AimSource.MOUSE: return "MOUSE"
		AimSource.GAMEPAD: return "GAMEPAD"
		AimSource.AI: return "AI"
		AimSource.NETWORK: return "NETWORK"
		AimSource.PRECISION_AIM: return "PRECISION_AIM"
	return "?"

@export_group("Auto Aim (Vertical Slice)")
## Mode B: when true, autoaim also fires automatically while a valid threat is
## locked inside weapon range with clear LoS and the weapon is off cooldown.
## When false (Mode A), autoaim only aims; the player keeps firing manually.
@export var auto_fire_enabled: bool = true

## Focus / Concentration state duration (seconds)
var focus_timer: float = 0.0
@export var focus_duration: float = 5.0

## Active aim source for this operator.
var _aim_source: AimSource = AimSource.MOVEMENT

## Whether the autoaim button is currently held.
var _autoaim_active: bool = false
## Currently locked target (enemy operator or drone) for autoaim.
var _autoaim_target: Node3D = null
var _autoaim_scan_timer: float = 0.0
const AUTO_AIM_SCAN_INTERVAL: float = 0.1

## ── Precision Aim state ───────────────────────────────────────────────────
## Current aim state (FREE_AIM or PRECISION_AIM).
var _aim_state: AimState = AimState.FREE_AIM
## Previous aim state for transition detection.
var _aim_state_prev: AimState = AimState.FREE_AIM
## Transition progress 0.0→1.0 (used for smooth visual transitions).
var _precision_aim_blend: float = 0.0
## Tactical vision cone component (instantiated on first precision aim entry).
var _tactical_cone: TacticalVisionCone = null
## Rotation speed multiplier while in PRECISION_AIM (0.0 = frozen, 1.0 = same as free).
const PRECISION_AIM_ROTATION_MULT: float = 0.35
## Movement speed multiplier while in PRECISION_AIM.
const PRECISION_AIM_MOVEMENT_MULT: float = 0.6
## How fast the blend factor interpolates (seconds to full blend in/out).
const AIM_BLEND_SPEED: float = 6.0

## ── Gamepad aim (FREE_AIM tactical cone) ─────────────────────────────────
## True while the player's right stick is deflected beyond the deadzone. The
## TacticalVisionCone is shown in FREE_AIM during gamepad aim WITHOUT entering
## PRECISION_AIM (normal rotation/movement, cone purely informational).
var _gamepad_aim_active: bool = false
## Separate smooth fade for the gamepad-aim cone so PRECISION_AIM blending
## (which also drives the shared cone) never fights the gamepad cone.
var _gamepad_cone_blend: float = 0.0

## ── Mouse aim (keyboard+mouse) ───────────────────────────────────────────
## True while a mouse player is steering with the cursor (always active on
## keyboard+mouse: full 360° aim through the floor-plane projection).
var _mouse_aim_active: bool = false
## True while the "aim_cone" action (right mouse button) is held: the tactical
## cone shows in FREE_AIM, mirroring the gamepad right-stick behaviour.
var _mouse_cone_active: bool = false
## Smooth fade for the mouse-aim cone (independent of PRECISION_AIM blend).
var _mouse_cone_blend: float = 0.0
## Test/verification seams: when set, mouse aim reads these instead of the live
## viewport (headless runs have no active camera or physical cursor).
var _mouse_camera_override: Camera3D = null
var _mouse_cursor_override: Vector2 = Vector2.INF

## Child Components
@onready var _mesh_instance: MeshInstance3D = $MeshInstance3D if has_node("MeshInstance3D") else null
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D if has_node("CollisionShape3D") else null
@onready var vision_cone: VisionCone3D = $VisionCone3D if has_node("VisionCone3D") else null
var _overhead_label: Label3D = null
## Light-gray fill panel drawn behind the overhead text (readable over terrain).
var _badge_panel: Label3D = null

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
	# Per-team collision mask: operators pass through their OWN energy barrier
	# while being physically blocked by the enemy team's barrier.
	collision_mask = _team_collision_mask(team_id)
	_setup_overhead_badge()
	_setup_vision_cone()
	_update_player_color()
	_update_overhead_badge()
	_setup_inventory()
	_setup_default_role()

	# Keep the canonical aim in sync with the initial facing
	aim_yaw = rotation.y
	_sync_aim_direction()

	# Build the Weapon System Gen 1 from exported tuning
	_build_weapon()
	
	# Spawn permanent Drone at launch
	call_deferred("spawn_drone")

	# Cache the AudioManager autoload for SFX playback (no class_name by design).
	_audio_manager = get_node_or_null(^"/root/AudioManager")

	# Dedicated per-operator footstep voice (SFX bus). Death stops only this
	# operator's steps; other operators/drone keep playing (Issue 2).
	_footstep_player = AudioStreamPlayer.new()
	_footstep_player.name = "FootstepSFX"
	_footstep_player.bus = &"SFX"
	_footstep_player.stream = FOOTSTEP_STREAM
	add_child(_footstep_player)

	# Bug 4: on window focus loss (alt-tab / task switch) Godot can retain the
	# OS-level "key held" state, so a movement key like A stays logically pressed
	# after the key is released. Flush the input buffer and cancel motion so no
	# stale key can keep the operator moving.
	if get_window() != null:
		get_window().focus_exited.connect(_on_window_focus_lost)

## Builds the Weapon System Gen 1 from this operator's exported tuning values.
## All gameplay numbers are parametrized on the operator (scene-editable) and
## applied to the weapon through configure() — nothing is hardcoded.
func _build_weapon() -> void:
	weapon = WeaponBase.new()
	weapon.configure({
		"weapon_name": "GRAVITY-1",
		"base_damage": base_damage,
		"range": weapon_range,
		"fire_rate": fire_rate,
		"magazine_capacity": magazine_capacity,
		"magazines_initial": magazines_initial,
		"reload_duration": reload_duration,
		"fire_mode_type": FireMode.Type.SEMI_AUTO,
		"burst_size": weapon_burst_size
	})
	weapon.reset()

## Dynamically assigns a role doctrine to the operator (Etapa 8 — composition)
func assign_role(new_role: OperatorRole) -> void:
	if role != null:
		role.queue_free()
	role = new_role
	if role != null:
		if not role.is_inside_tree():
			add_child(role)
		role.assign_to(self)
		_update_overhead_badge()

## Configures the default role doctrine based on local Player ID (1: Recon, 2: Vanguard, 3: Disruptor, 4: Engineer)
func _setup_default_role() -> void:
	if role != null:
		return
	var new_role: OperatorRole = null
	match player_id:
		1: new_role = ReconOperator.new()
		2: new_role = VanguardOperator.new()
		3: new_role = DisruptorOperator.new()
		4: new_role = EngineerOperator.new()
	if new_role != null:
		assign_role(new_role)

## Initialises the per-operator ResourceInventory
func _setup_inventory() -> void:
	inventory = ResourceInventory.new()
	inventory.name = "ResourceInventory"
	add_child(inventory)
	inventory.inventory_changed.connect(_on_inventory_changed)

func _on_inventory_changed(resource_type: String, _current: int, _capacity: int) -> void:
	## Re-emit so HUD can listen on the operator signal
	resource_collected.emit(resource_type, _current)

func _physics_process(delta: float) -> void:
	if _fire_cooldown > 0.0:
		_fire_cooldown -= delta
	if _dash_cooldown_timer > 0.0:
		_dash_cooldown_timer -= delta

	# Advance the weapon's automatic reload timer every frame.
	if weapon != null:
		weapon.tick(delta)

	# Slowly recharge battery when drone is destroyed or inactive
	if not has_drone_active or drone == null:
		battery_current = minf(battery_max, battery_current + (3.0 * delta))

	if is_dead:
		respawn_timer -= delta
		_update_overhead_badge()
		if respawn_timer <= 0.0:
			var spawn_pos: Vector3 = Vector3.ZERO
			var mgr: PlayerManager = _find_player_manager()
			if mgr != null:
				spawn_pos = mgr.get_respawn_position(team_id, player_id)
			respawn(spawn_pos)
			return
		# Frozen in place on death: no gravity, no movement. The collision shape is
		# disabled (P1-6), so applying gravity/move_and_slide would drop the body
		# through the floor. The corpse proxy (spawned in die()) is the visual.
		velocity = Vector3.ZERO
		return

	if is_invulnerable:
		invulnerability_timer -= delta
		if invulnerability_timer <= 0.0:
			is_invulnerable = false

	# Refresh the overhead badge when crossing the spawn-room boundary.
	var spawn_now: bool = is_in_spawn_zone()
	if spawn_now != _spawn_protected_prev:
		_spawn_protected_prev = spawn_now
		_update_overhead_badge()

	if is_incapacitated:
		_apply_deceleration(delta)
		move_and_slide()
		return

	if focus_timer > 0.0:
		focus_timer -= delta

	# Handle active ability input check (Etapa 8 / Focus Ability)
	if _is_ability_input_just_pressed():
		trigger_focus()
		if role != null:
			role.try_activate_ability()


	# Handle Drone Mode inputs (Escort/Stationary/Pilot logic)
	_process_drone_mode_inputs(delta)

	if is_piloting_drone:
		_apply_deceleration(delta)
		move_and_slide()
		return

	var move_vec: Vector2 = _get_input_direction()
	_update_sprint_crouch()
	_update_precision_aim()
	_update_autoaim()
	_update_aim(delta)
	if is_dashing:
		_process_dash(delta)
	else:
		_process_locomotion(move_vec, delta)
	move_and_slide()

	# Process Combat Input (Disabled in pilot mode). Autoaim auto-fires when
	# a valid threat is locked inside weapon range. Every shot consumes a round;
	# the weapon refuses to fire while reloading or out of ammunition.
	# BURST rounds are queued on a fresh press and spaced by the burst interval
	# instead of firing back-to-back.
	var fire_pressed: bool = _is_firing_input_active()
	var fire_trigger: bool = _evaluate_fire_trigger(fire_pressed)
	if _is_burst_mode():
		fire_trigger = false
		if fire_pressed and not _fire_input_prev and _burst_pending_shots == 0:
			_burst_pending_shots = weapon_burst_size
	_fire_input_prev = fire_pressed
	if (fire_trigger or _autoaim_should_fire() or _burst_pending_shots > 0) and _fire_cooldown <= 0.0 and not is_in_spawn_zone():
		if weapon != null and weapon.try_consume_round():
			_execute_tactical_shot()
			if _burst_pending_shots > 0:
				_burst_pending_shots -= 1
		else:
			# Interrupted (reloading / out of ammunition): drop the rest of the burst.
			_burst_pending_shots = 0

## Initializes the vision cone
func _setup_vision_cone() -> void:
	if vision_cone == null:
		vision_cone = VisionCone3D.new()
		vision_cone.name = "VisionCone3D"
		vision_cone.position = Vector3(0.0, VISION_ORIGIN_STANDING_Y, 0.0)
		vision_cone.view_range = 32.0
		vision_cone.field_of_view_degrees = 90.0
		add_child(vision_cone)

## Creates 3D overhead badge for squad identification. The badge is a two-layer
## Label3D: a light-gray fill label with a thin subtle-green outline is drawn
## just behind the main label, whose near-black text stays readable over the
## green terrain and the bright fog overlay. Role/team identity lives in the text
## itself; the slot identity colors are untouched.
func _setup_overhead_badge() -> void:
	if _overhead_label == null:
		# Background fill/border layer: same string, light-gray glyphs with a thin
		# dark/subtle-green outline. Positioned slightly away from the camera so
		# it renders behind the text label.
		_badge_panel = Label3D.new()
		_badge_panel.name = "BadgePanel"
		_badge_panel.position = Vector3(0.0, 2.2, 0.06)
		_badge_panel.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_badge_panel.no_depth_test = true
		_badge_panel.font_size = 28
		_badge_panel.modulate = Color(0.95, 0.95, 0.95, 1.0)
		_badge_panel.outline_size = 10
		_badge_panel.outline_modulate = Color(0.08, 0.3, 0.16, 1.0)
		_badge_panel.outline_render_priority = 0
		add_child(_badge_panel)

		_overhead_label = Label3D.new()
		_overhead_label.name = "OverheadBadge"
		_overhead_label.position = Vector3(0.0, 2.2, 0.0)
		_overhead_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_overhead_label.no_depth_test = true
		_overhead_label.font_size = 28
		# Near-black text over the light-gray panel; a thin dark edge keeps the
		# glyphs crisp without overpowering the subtle-green border behind them.
		_overhead_label.outline_size = 2
		_overhead_label.outline_modulate = Color(0.02, 0.02, 0.02, 1.0)
		_overhead_label.outline_render_priority = 1
		add_child(_overhead_label)

## Spawns the permanent tactical Drone (Gen 1)
func spawn_drone() -> void:
	if drone_scene == null or has_drone_active:
		return

	var drone_instance: DroneBase = drone_scene.instantiate() as DroneBase
	if drone_instance != null:
		drone_instance.operator = self
		drone_instance.position = global_position + Vector3(0.0, 1.6, 1.0)
		drone_instance.battery_current = battery_current
		drone_instance.battery_max = battery_max
		get_parent().add_child(drone_instance)
		
		drone = drone_instance
		has_drone_active = true
		
		# Register drone vision cone to squad vision registry
		var registry_nodes: Array[Node] = get_tree().get_nodes_in_group("squad_vision_registry")
		for n: Node in registry_nodes:
			if not n.is_queued_for_deletion():
				var reg: SquadVisionRegistry = n as SquadVisionRegistry
				if reg != null and drone.vision_cone != null:
					reg.register_provider(drone.vision_cone)
				break

		_update_overhead_badge()
		drone_status_changed.emit(player_id, true, "ESCORT")

## Callback when Drone is destroyed
func notify_drone_destroyed() -> void:
	# Unregister vision cone from squad registry
	var registry_nodes: Array[Node] = get_tree().get_nodes_in_group("squad_vision_registry")
	for n: Node in registry_nodes:
		if not n.is_queued_for_deletion():
			var reg: SquadVisionRegistry = n as SquadVisionRegistry
			if reg != null and drone != null and drone.vision_cone != null:
				reg.unregister_provider(drone.vision_cone)
			break

	drone = null
	has_drone_active = false
	is_separated = false
	_update_overhead_badge()
	drone_status_changed.emit(player_id, false, "DESTROYED")

## Performs Drone synthesis/reconstruction
func rebuild_drone() -> void:
	if not has_drone_active:
		spawn_drone()

## Taps and holds input processing for Drone Mode control
func _process_drone_mode_inputs(delta: float) -> void:
	if is_ai_controlled:
		return
	if drone == null or not has_drone_active:
		return

	# Synchronize battery values with drone
	drone.battery_current = battery_current
	battery_current = drone.battery_current

	var mode_pressed: bool = _input_manager != null and _input_manager.is_action_pressed(player_id, "drone_mode")

	if mode_pressed:
		if not _is_pressing_mode_button:
			_is_pressing_mode_button = true
			_mode_button_press_duration = 0.0
		
		_mode_button_press_duration += delta
		
		# If button is held down for more than 0.35 seconds, enter Pilot Mode
		if _mode_button_press_duration > 0.35 and drone.current_mode != DroneBase.DroneMode.PILOT:
			drone.set_mode(DroneBase.DroneMode.PILOT)
			drone_status_changed.emit(player_id, true, "PILOT")
	else:
		if _is_pressing_mode_button:
			_is_pressing_mode_button = false
			# If it was a quick tap, toggle between Escort and Stationary
			if _mode_button_press_duration <= 0.35:
				if drone.current_mode == DroneBase.DroneMode.ESCORT:
					drone.set_mode(DroneBase.DroneMode.STATIONARY)
					drone_status_changed.emit(player_id, true, "STATIONARY")
				else:
					drone.set_mode(DroneBase.DroneMode.ESCORT)
					drone_status_changed.emit(player_id, true, "ESCORT")
			else:
				# Releasing hold returns to Escort Mode
				if drone.current_mode == DroneBase.DroneMode.PILOT:
					drone.set_mode(DroneBase.DroneMode.ESCORT)
					drone_status_changed.emit(player_id, true, "ESCORT")

## Updates overhead label text and color
func _update_overhead_badge() -> void:
	if _overhead_label == null or player_id < 1 or player_id > 4:
		return
		
	var team_tag: String = "[ATK]" if team_id == TEAM_ATTACKERS else "[DEF]"
	var label_text: String = "%s %s" % [team_tag, ROLE_LABELS[player_id - 1]]
	
	if is_dead:
		label_text += " [DEAD - %.0fs]" % maxf(0.0, ceilf(respawn_timer))
		_overhead_label.modulate = Color(0.5, 0.5, 0.5)
	elif is_in_spawn_zone():
		label_text += " [SPAWN]"
		_overhead_label.modulate = Color(0.3, 0.9, 1.0)
	elif is_invulnerable:
		label_text += " [INVULNERABLE]"
		_overhead_label.modulate = Color(1.0, 1.0, 0.4)
	elif not has_drone_active:
		label_text += " [DRONE LOST]"
		_overhead_label.modulate = Color(0.9, 0.2, 0.2)
	elif is_separated:
		label_text += " [SEPARATED]"
		_overhead_label.modulate = Color(1.0, 0.4, 0.2)
	elif is_incapacitated:
		label_text += " [DOWN]"
		_overhead_label.modulate = Color(0.6, 0.6, 0.6)
	else:
		_overhead_label.modulate = Color(0.04, 0.04, 0.04, 1.0)
		
	_overhead_label.text = label_text
	if _badge_panel != null:
		_badge_panel.text = label_text

## Updates separation status relative to squad centroid
func update_squad_separation(centroid: Vector3) -> void:
	# If drone is lost, we don't display separation warnings (drone is not present)
	if not has_drone_active:
		is_separated = false
		return
		
	var dist: float = global_position.distance_to(centroid)
	var newly_separated: bool = dist > separation_warning_distance
	
	if newly_separated != is_separated:
		is_separated = newly_separated
		_update_overhead_badge()

## Checks if fire button is currently pressed for this player
func _is_firing_input_active() -> bool:
	if is_ai_controlled:
		return ai_fire_input
	return _input_manager != null and _input_manager.is_action_pressed(player_id, "fire")

## ── Weapon System helpers (Gen 1) ──────────────────────────────────────────
## The weapon is the source of truth once built; fall back to the operator's
## exported tuning for robustness (e.g. tests that bypass _ready).

func _get_base_damage() -> float:
	return weapon.base_damage if weapon != null else base_damage

func _get_combat_range() -> float:
	return weapon.range if weapon != null else weapon_range

func _get_fire_rate() -> float:
	if weapon != null and weapon.fire_mode != null:
		return weapon.fire_mode.fire_rate
	return fire_rate

## True when the active weapon is configured in BURST mode.
func _is_burst_mode() -> bool:
	return weapon != null and weapon.fire_mode != null and weapon.fire_mode.type == FireMode.Type.BURST

## Time between rounds of a single burst press.
func _get_burst_interval() -> float:
	return weapon_burst_interval

## Evaluates the raw fire trigger through the weapon's FireMode (SEMI/AUTO/BURST).
func _evaluate_fire_trigger(pressed: bool) -> bool:
	if weapon != null and weapon.fire_mode != null:
		return weapon.fire_mode.evaluate_trigger(pressed, _fire_input_prev)
	return pressed

## Shot origin height above ground (meters) for standing vs crouching stances
const SHOT_ORIGIN_STANDING_Y: float = 1.35
const SHOT_ORIGIN_CROUCHING_Y: float = 0.65

## Returns the 3D shot/eye origin in world space, dynamically accounting for crouch stance.
func get_shot_origin() -> Vector3:
	var eye_h: float = SHOT_ORIGIN_CROUCHING_Y if is_crouching else SHOT_ORIGIN_STANDING_Y
	return global_position + Vector3(0.0, eye_h, 0.0)

## Vision origin height above ground (meters) for standing vs crouching stances
const VISION_ORIGIN_STANDING_Y: float = 1.35
const VISION_ORIGIN_CROUCHING_Y: float = 0.65

## Returns the 3D vision/eye origin in world space, dynamically accounting for crouch stance.
func get_vision_origin() -> Vector3:
	var eye_h: float = VISION_ORIGIN_CROUCHING_Y if is_crouching else VISION_ORIGIN_STANDING_Y
	return global_position + Vector3(0.0, eye_h, 0.0)

## Executes a hitscan shot with cover damage mitigation and LoS evaluation.
## The round is consumed by the weapon before this is called; this method only
## resolves the shot along the canonical aim direction.
func _execute_tactical_shot() -> void:
	# Spawn protection: no shot resolves while inside the protected room.
	if is_in_spawn_zone():
		_burst_pending_shots = 0
		return

	# SFX: rifle gunshot on every resolved shot (fire-and-forget, SFX bus).
	# Uses the existing AudioManager pool; no new audio system, no bus change.
	if _audio_manager != null:
		_audio_manager.play_sfx(GUNSHOT_STREAM)

	# During an active burst, rounds are spaced by the burst interval so the
	# magazine drains in a rhythmic TA-TA-TA; otherwise the base fire rate.
	_fire_cooldown = _get_burst_interval() if _burst_pending_shots > 0 else _get_fire_rate()

	# Fires along the canonical aim direction (independent of movement input).
	var forward_dir: Vector3 = aim_direction.normalized()
	var eye_pos: Vector3 = get_shot_origin()
	var target_end_pos: Vector3 = eye_pos + (forward_dir * _get_combat_range())
	target_end_pos.y = 0.9

	# Autoaim aims at a locked target's 3D body position (drone flight height
	# or operator stance height) so the shot connects with its actual elevation.
	if (_aim_source == AimSource.AUTO_AIM or is_ai_controlled) and _autoaim_target != null and is_instance_valid(_autoaim_target):
		if _autoaim_target is DroneBase:
			target_end_pos = _autoaim_target.global_position
		elif _autoaim_target is OperatorBase:
			var op_target: OperatorBase = _autoaim_target as OperatorBase
			var th: float = op_target.get_vision_origin().y - op_target.global_position.y if op_target.has_method("get_vision_origin") else 1.2
			target_end_pos = op_target.global_position + Vector3(0.0, th, 0.0)

	weapon_fired.emit(eye_pos, forward_dir)

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
		elif hit_target is DroneBase:
			_apply_mitigated_damage(hit_target as DroneBase, eye_pos)

## Applies cover-mitigated damage to the hit body (operator or drone) through a
## single shared pipeline. Only the reference points differ between the two;
## the damage math, friendly-fire gate and signal flow are not duplicated.
func _apply_mitigated_damage(target: Node3D, attacker_eye_pos: Vector3) -> void:
	var is_operator: bool = target is OperatorBase
	var is_drone: bool = target is DroneBase
	if not is_operator and not is_drone:
		return

	# Friendly fire check against GameRules module (drones share their owner's team)
	var target_team: int = TEAM_DEFENDERS
	if is_operator:
		target_team = (target as OperatorBase).team_id
	else:
		var target_drone: DroneBase = target as DroneBase
		if target_drone.operator != null:
			target_team = target_drone.operator.team_id
	if target_team == team_id:
		var rules: GameRules = GameRules.get_rules(self)
		var ff_enabled: bool = rules.friendly_fire_enabled if rules != null else false
		if not ff_enabled:
			return

	# Cover protection sample points. Drones fly above cover, so their body is
	# sampled directly instead of a chest/feet pair.
	var target_chest: Vector3
	var target_feet: Vector3
	if is_operator:
		var op_target: OperatorBase = target as OperatorBase
		var chest_h: float = op_target.get_vision_origin().y - op_target.global_position.y if op_target.has_method("get_vision_origin") else 1.2
		target_chest = target.global_position + Vector3(0.0, chest_h, 0.0)
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
	var final_damage: float = _get_base_damage() * (1.0 - cover_protection)

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

## Obtains movement direction from InputManager or Direct Input fallback
func _get_input_direction() -> Vector2:
	if is_ai_controlled:
		return ai_move_input
	if _input_manager != null:
		return _input_manager.get_movement_vector(player_id)
	return Vector2.ZERO

## Processes XZ velocity and orientation rotation based on 2D input.
## Movement velocity follows the input vector, but the body rotation always
## converges to the canonical aim direction (aim_yaw), which is decoupled from
## movement. Legacy MOVEMENT aim source keeps the old "face where you walk".
func _process_locomotion(input_vec: Vector2, delta: float) -> void:
	var target_dir: Vector3 = Vector3(input_vec.x, 0.0, input_vec.y)
	var eff_rot_speed: float = _get_effective_rotation_speed()

	if target_dir.length_squared() > 0.01:
		target_dir = target_dir.normalized()
		
		# Speed multiplier: sprint 1.7x, crouch 0.45x, normal 1.0x, precision aim 0.6x
		var speed_mult: float = 1.7 if is_sprinting else (0.45 if is_crouching else 1.0)
		speed_mult *= _get_effective_movement_mult()
		var eff_speed: float = move_speed * speed_mult
		
		velocity.x = move_toward(velocity.x, target_dir.x * eff_speed, acceleration * delta)
		velocity.z = move_toward(velocity.z, target_dir.z * eff_speed, acceleration * delta)

		# Footstep SFX cadence (only while actually moving on the ground).
		if is_on_floor():
			if not _was_moving:
				_footstep_timer = _footstep_interval()
				_was_moving = true
			_tick_footsteps(delta)
		else:
			_stop_footsteps()

		# Movement-direction aim only when no explicit aim source is active
		if _aim_source == AimSource.MOVEMENT:
			aim_yaw = atan2(-target_dir.x, -target_dir.z)
	else:
		_apply_deceleration(delta)
		_stop_footsteps()

	# Body rotation always converges to the canonical aim direction
	rotation.y = lerp_angle(rotation.y, aim_yaw, eff_rot_speed * delta)
	_sync_aim_direction()

## Dedicated per-operator footstep voice (SFX bus). Owned by this operator so a
## death stops ONLY this operator's steps — other operators (and the drone) keep
## theirs. Created in _ready. Replaces the previous shared-pool one-shot whose
## stop path (stop_all_sfx) globally muted every voice.
var _footstep_player: AudioStreamPlayer = null

## Persistent corpse proxies spawned on death (kept for the whole match).
var _corpses: Array[Node3D] = []

## ── SFX wiring (Gameplay SFX V1) ──────────────────────────────────────────────
## Footstep cadence. Throttled so a walking operator emits ~2-3 steps/sec and a
## sprinter slightly faster; never fires per physics frame. Steps start only while
## the operator is actually moving on the ground, and stop immediately when it is
## idle/airborne (no pending step, no long tail). dash/landing/death/damage are
## PENDING: no appropriate asset exists yet, so no call site is added for them.
func _footstep_interval() -> float:
	return 0.32 if is_sprinting else (0.55 if is_crouching else 0.45)

func _tick_footsteps(delta: float) -> void:
	if current_state != OperatorState.ALIVE:
		return
	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return
	_footstep_timer = _footstep_interval()
	if _footstep_player != null:
		_footstep_player.play()

## Stops ONLY this operator's footstep voice — never other operators or the drone.
func _stop_footsteps() -> void:
	if _footstep_player != null:
		_footstep_player.stop()
	_was_moving = false
	_footstep_timer = 0.0

## Smoothly decelerates velocity to zero
func _apply_deceleration(delta: float) -> void:
	velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)
	velocity.z = move_toward(velocity.z, 0.0, deceleration * delta)
	if not is_on_floor():
		velocity.y -= 9.8 * delta

## ──────────────────────────────────────────────
## SPAWN ROOM PROTECTION (Sprint: Gameplay Base)
## ──────────────────────────────────────────────

## True while the operator stands inside its own team's protected spawn room.
## Inside the room: invulnerable, cannot fire and cannot use offensive abilities.
## Protection ends the moment the boundary is crossed (no timers).
func is_in_spawn_zone() -> bool:
	return SpawnZone.is_protected(self)

## CharacterBody3D collision mask per team so each team's operators pass through
## their OWN energy barrier while the enemy team is physically blocked by it.
## Base mask bit 1 (world + operators) OR the ENEMY team's barrier layer.
func _team_collision_mask(team: int) -> int:
	return 1 | EnergyBarrier.barrier_collision_layer(1 - team)

## ──────────────────────────────────────────────
## AIM SYSTEM (decoupled from movement)
## ──────────────────────────────────────────────

## ── PRECISION AIM SYSTEM ──────────────────────────────────────────────────
## Reads the "autoaim" input and toggles PRECISION_AIM / FREE_AIM state.
## When PRECISION_AIM is active, rotation_speed is reduced and the tactical
## vision cone becomes visible.
func _update_precision_aim() -> void:
	if is_ai_controlled:
		return
	var aim_pressed: bool = false
	if _input_manager != null:
		aim_pressed = _input_manager.is_action_pressed(player_id, "autoaim")

	_aim_state_prev = _aim_state

	if aim_pressed and _aim_state == AimState.FREE_AIM:
		_enter_precision_aim()
	elif not aim_pressed and _aim_state == AimState.PRECISION_AIM:
		_exit_precision_aim()

	# Advance blend factor for smooth transitions
	var target_blend: float = 1.0 if _aim_state == AimState.PRECISION_AIM else 0.0
	_precision_aim_blend = move_toward(_precision_aim_blend, target_blend, AIM_BLEND_SPEED * get_physics_process_delta_time())

	# Gamepad right-stick aim shows the SAME tactical cone during FREE_AIM — no
	# PRECISION_AIM state change (rotation/movement stay normal).
	var aim_vec: Vector2 = Vector2.ZERO
	if _input_manager != null:
		aim_vec = _input_manager.get_aim_vector(player_id)
	_gamepad_aim_active = aim_vec.length_squared() > 0.0001
	var gp_target: float = 1.0 if _gamepad_aim_active else 0.0
	_gamepad_cone_blend = move_toward(_gamepad_cone_blend, gp_target, AIM_BLEND_SPEED * get_physics_process_delta_time())

	# Keyboard+mouse "aim camera": RMB (aim_cone) shows the SAME tactical cone in
	# FREE_AIM with normal rotation/movement — never enters PRECISION_AIM.
	var mouse_cone: bool = _is_using_mouse() and _input_manager != null \
		and _input_manager.is_action_pressed(player_id, "aim_cone")
	_mouse_cone_active = mouse_cone
	var m_target: float = 1.0 if mouse_cone else 0.0
	_mouse_cone_blend = move_toward(_mouse_cone_blend, m_target, AIM_BLEND_SPEED * get_physics_process_delta_time())

	# Update tactical cone visibility and geometry (any source may show it).
	var cone_visible: bool = _precision_aim_blend > 0.01 or _gamepad_cone_blend > 0.01 or _mouse_cone_blend > 0.01
	if _tactical_cone != null and _tactical_cone.is_inside_tree():
		_tactical_cone.set_visible(cone_visible)
		if _tactical_cone.visible:
			_tactical_cone.update_cone(self, maxf(_precision_aim_blend, maxf(_gamepad_cone_blend, _mouse_cone_blend)))
	elif cone_visible:
		# No PRECISION_AIM has ever been entered: lazily create the cone so
		# gamepad aim can display it in FREE_AIM.
		_tactical_cone = TacticalVisionCone.new()
		_tactical_cone.name = "TacticalVisionCone"
		add_child(_tactical_cone)

## Enters PRECISION_AIM state.
func _enter_precision_aim() -> void:
	_aim_state = AimState.PRECISION_AIM
	precision_aim_changed.emit(true)
	# Show tactical cone (create if needed)
	if _tactical_cone == null or not is_instance_valid(_tactical_cone):
		_tactical_cone = TacticalVisionCone.new()
		_tactical_cone.name = "TacticalVisionCone"
		add_child(_tactical_cone)
	_tactical_cone.visible = true

## Exits PRECISION_AIM state, returns to FREE_AIM.
func _exit_precision_aim() -> void:
	_aim_state = AimState.FREE_AIM
	precision_aim_changed.emit(false)
	# Hide tactical cone (deferred to allow blend-out animation)
	if _tactical_cone != null and is_instance_valid(_tactical_cone):
		_tactical_cone.visible = false

## Returns the current effective rotation speed, reduced during PRECISION_AIM.
func _get_effective_rotation_speed() -> float:
	var base: float = rotation_speed
	if _aim_state == AimState.PRECISION_AIM:
		base *= PRECISION_AIM_ROTATION_MULT
	return base

## Returns the current effective movement speed multiplier.
func _get_effective_movement_mult() -> float:
	if _aim_state == AimState.PRECISION_AIM:
		return PRECISION_AIM_MOVEMENT_MULT
	return 1.0

## True when this player's device is a gamepad. Consults the InputManager's
## authoritative device mirror first (it is already kept in sync with the
## GameConfig profiles), then falls back to the GameConfig InputProfile so the
## check works even when the mirror is not refreshed yet.
func _is_using_gamepad() -> bool:
	if _input_manager == null:
		return false
	var mirror: InputManager.PlayerInputProfile = _input_manager.get_profile(player_id) as InputManager.PlayerInputProfile
	if mirror != null:
		if mirror.device_type == InputManager.PlayerInputProfile.DeviceType.GAMEPAD:
			return true
		if mirror.device_type == InputManager.PlayerInputProfile.DeviceType.KEYBOARD_MOUSE:
			return false
	var prof: InputProfile = null
	var cfg: Node = get_tree().root.get_node_or_null("GameConfig") if get_tree() != null else null
	if cfg != null:
		prof = cfg.call("get_profile", player_id) as InputProfile
	return prof != null and prof.device_kind == InputProfile.DeviceKind.JOYSTICK

## Public accessor for presentation/debug systems: true when this player aims
## with a gamepad.
func is_gamepad_input() -> bool:
	return _is_using_gamepad()

## Returns the authoritative GameConfig InputProfile for this player.
func _get_input_profile() -> InputProfile:
	if get_tree() == null:
		return null
	var cfg: Node = get_tree().root.get_node_or_null("GameConfig")
	if cfg != null:
		return cfg.call("get_profile", player_id) as InputProfile
	return null

## True when this player aims with the mouse: a keyboard profile with a
## mouse-button binding (fire and/or aim_cone). A KEYBOARD_MOUSE device mirror
## alone is NOT enough — pure-keyboard players (P2..P4) share that same label.
func _is_using_mouse() -> bool:
	if _input_manager == null:
		return false
	var mirror: InputManager.PlayerInputProfile = _input_manager.get_profile(player_id) as InputManager.PlayerInputProfile
	if mirror != null and mirror.device_type == InputManager.PlayerInputProfile.DeviceType.GAMEPAD:
		return false
	var prof: InputProfile = _get_input_profile()
	if prof == null or not prof.is_keyboard():
		return false
	for action: String in ["fire", "aim_cone"]:
		var evs: Array[InputEvent] = prof.get_events(action)
		if not evs.is_empty() and evs[0] is InputEventMouseButton:
			return true
	return false

## Reads the autoaim input and switches the aim source accordingly. AUTO_AIM
## (target acquisition) is an OPTIONAL capability: on a gamepad it engages ONLY
## while the dedicated "autoaim" action is held (STATE B). R2 is pure fire and
## NEVER acquires by itself — with auto-aim OFF, R2 fires along the current aim
## direction (right-stick / movement); with auto-aim ON, R2 acquires a valid
## enemy inside the aim cone and the shot steers onto that target. Mouse players
## keep the existing LMB -> cone-gated autoaim steering behaviour unchanged.
## Triggers the Focus / Concentration auto-aim state (E key / ability button)
func trigger_focus(duration: float = -1.0) -> void:
	var d: float = duration if duration > 0.0 else focus_duration
	focus_timer = d
	_aim_source = AimSource.AUTO_AIM
	_autoaim_active = true

func _update_autoaim() -> void:
	if is_ai_controlled:
		# AI-controlled operators maintain their own lock through the SAME
		# shared-pipeline acquisition (_is_valid_autoaim_target re-checks team,
		# range vs _get_combat_range() and LoS on every scan), so hitscan shots
		# resolve onto the locked target's stance-aware origin via
		# _execute_tactical_shot(). No cone gating: AI has no aim device.
		_autoaim_scan_timer -= get_physics_process_delta_time()
		if _autoaim_target == null or _autoaim_scan_timer <= 0.0:
			_autoaim_scan_timer = AUTO_AIM_SCAN_INTERVAL
			_acquire_autoaim_target()
		return
	var autoaim_held: bool = false
	if _input_manager != null:
		autoaim_held = _input_manager.is_action_pressed(player_id, "autoaim")
	if focus_timer > 0.0 or autoaim_held:
		_aim_source = AimSource.AUTO_AIM
		_autoaim_active = true
	elif _aim_source == AimSource.AUTO_AIM or _autoaim_active:
		# Return to the player's own aim channel.
		if _is_using_mouse():
			_aim_source = AimSource.MOUSE
		elif _is_using_gamepad():
			_aim_source = AimSource.GAMEPAD
		else:
			_aim_source = AimSource.MOVEMENT
		_autoaim_active = false
		_release_autoaim_target()


## Updates the canonical aim direction each physics frame from the active source.
func _update_aim(delta: float) -> void:
	var eff_rot_speed: float = _get_effective_rotation_speed()
	if is_ai_controlled:
		_aim_source = AimSource.AI
		_gamepad_aim_active = false
		aim_yaw = lerp_angle(aim_yaw, ai_aim_yaw, eff_rot_speed * delta)
		_sync_aim_direction()
		return
	if _aim_source == AimSource.AUTO_AIM:
		_autoaim_scan_timer -= delta
		if _autoaim_target == null or _autoaim_scan_timer <= 0.0:
			_autoaim_scan_timer = AUTO_AIM_SCAN_INTERVAL
			_acquire_autoaim_target()
		if _autoaim_target != null and is_instance_valid(_autoaim_target):
			var to_target: Vector3 = _autoaim_target.global_position - global_position
			to_target.y = 0.0
			if to_target.length_squared() > 0.0001:
				aim_yaw = lerp_angle(aim_yaw, atan2(-to_target.x, -to_target.z), eff_rot_speed * delta)
			_gamepad_aim_active = false
			_mouse_aim_active = false
			_sync_aim_direction()
			return
	if _is_using_mouse():
		_update_aim_mouse(delta)
		_sync_aim_direction()
		return
	if _is_using_gamepad():
		_update_aim_input_gamepad()
		_sync_aim_direction()
		return
	_sync_aim_direction()


## Mouse aim driver (keyboard+mouse): the cursor projects onto the operator's
## floor plane and the canonical aim turns toward that world point (full 360°).
## An active autoaim lock overrides the facing to steer onto the target; without
## a lock the aim keeps following the cursor so LMB fire is never a dead trigger.
func _update_aim_mouse(delta: float) -> void:
	if _aim_source == AimSource.AUTO_AIM:
		_autoaim_scan_timer -= delta
		if _autoaim_target == null or _autoaim_scan_timer <= 0.0:
			_autoaim_scan_timer = AUTO_AIM_SCAN_INTERVAL
			_acquire_autoaim_target()
		if _autoaim_target != null and is_instance_valid(_autoaim_target):
			var to_target: Vector3 = _autoaim_target.global_position - global_position
			to_target.y = 0.0
			if to_target.length_squared() > 0.0001:
				aim_yaw = lerp_angle(aim_yaw, atan2(-to_target.x, -to_target.z), _get_effective_rotation_speed() * delta)
			_mouse_aim_active = false
			return
	_update_aim_input_mouse()

## Projects the cursor through the active camera onto the operator's floor plane
## and steers the canonical aim at the resulting world point. Returns true when
## mouse aim drove the facing this frame.
func _update_aim_input_mouse() -> bool:
	var cam: Camera3D = _mouse_camera_override
	if cam == null and get_viewport() != null:
		cam = get_viewport().get_camera_3d()
	if cam == null:
		return false
	var cursor: Vector2 = _mouse_cursor_override
	if cursor.is_equal_approx(Vector2.INF):
		var vp: Viewport = get_viewport()
		if vp == null:
			return false
		cursor = vp.get_mouse_position()
	var world: Vector3 = _project_cursor_to_floor(cam, cursor, global_position.y)
	if not world.is_finite():
		return false
	var to_cursor: Vector3 = world - global_position
	to_cursor.y = 0.0
	if to_cursor.length_squared() < 0.0001:
		return false
	_aim_source = AimSource.MOUSE
	_mouse_aim_active = true
	var target_yaw: float = atan2(-to_cursor.x, -to_cursor.z)
	aim_yaw = lerp_angle(aim_yaw, target_yaw, _get_effective_rotation_speed() * get_physics_process_delta_time())
	return true

## Pure camera-ray -> floor-plane projection (testable in isolation). Returns
## Vector3.INF when the ray is parallel to the plane or never reaches it.
static func _project_cursor_to_floor(cam: Camera3D, cursor: Vector2, plane_y: float) -> Vector3:
	var origin: Vector3 = cam.project_ray_origin(cursor)
	var dir: Vector3 = cam.project_ray_normal(cursor)
	if absf(dir.y) < 0.0001:
		return Vector3.INF
	var t: float = (plane_y - origin.y) / dir.y
	if t < 0.0:
		return Vector3.INF
	return origin + dir * t

## Reads the player's right-stick aim vector and feeds the canonical planar
## aim_yaw / aim_direction owned by this operator. Right stick does NOT enter
## PRECISION_AIM: FREE_AIM keeps normal rotation and movement speed while the
## tactical cone is shown by _update_precision_aim. The full analog X/Y vector
## maps to a 360-degree direction on the ground plane; Y is character aim, not
## a camera control.
## Returns true when gamepad aim is actively driving the facing this frame.
func _update_aim_input_gamepad() -> bool:
	var aim_vec: Vector2 = Vector2.ZERO
	if _input_manager != null:
		aim_vec = _input_manager.get_aim_vector(player_id)
	diag_last_aim_vec = aim_vec
	if aim_vec.length_squared() > 0.0001:
		diag_aim_input_calls += 1
		_aim_source = AimSource.GAMEPAD
		_gamepad_aim_active = true
		var target_yaw: float = atan2(-aim_vec.x, -aim_vec.y)
		aim_yaw = lerp_angle(aim_yaw, target_yaw, _get_effective_rotation_speed() * get_physics_process_delta_time())
		return true
	_gamepad_aim_active = false
	return false


## Keeps the cached aim direction consistent with aim_yaw. The XZ aim_direction
## stays flat for gameplay: vision cone, firing and autoaim all read it.
func _sync_aim_direction() -> void:
	aim_direction = Vector3(-sin(aim_yaw), 0.0, -cos(aim_yaw))

## Refreshes the locked target: keeps the current one if still valid, otherwise
## picks the best enemy (operator or drone) in range with clear LoS.
func _acquire_autoaim_target() -> void:
	# A target removed from the tree without firing its death/destroyed signal
	# leaves a dangling (freed) reference. Clear it before the typed validity
	# check, otherwise Godot errors on the parameter conversion.
	if not is_instance_valid(_autoaim_target):
		_release_autoaim_target()
		_autoaim_target = null
	if _is_valid_autoaim_target(_autoaim_target):
		return
	_release_autoaim_target()
	_autoaim_target = null
	# Aim-device players (mouse RMB "aim camera" and gamepad right-stick aim)
	# acquire targets ONLY inside the tactical cone — the cone constrains what
	# autoaim will lock. Pure-keyboard players keep the legacy non-gated pick.
	var cone_gated: bool = _is_using_mouse() or _is_using_gamepad()
	var candidates: Array[Dictionary] = []
	for node: Node in get_tree().get_nodes_in_group("players"):
		if node is OperatorBase and not node.is_queued_for_deletion():
			var op: OperatorBase = node as OperatorBase
			if op != self and op.team_id != team_id and not op.is_incapacitated and _is_target_detected_by_squad(op):
				var score: float = _autoaim_score(op)
				if score < INF and (not cone_gated or _target_within_vision_cone(op)):
					candidates.append({"score": score, "target": op})
	for node: Node in get_tree().get_nodes_in_group("drones"):
		if node is DroneBase and not node.is_queued_for_deletion():
			var drone: DroneBase = node as DroneBase
			if drone.operator != null and drone.operator != self and drone.operator.team_id != team_id and _is_target_detected_by_squad(drone):
				var drone_score: float = _autoaim_score(drone)
				if drone_score < INF and (not cone_gated or _target_within_vision_cone(drone)):
					candidates.append({"score": drone_score, "target": drone})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["score"] < b["score"])
	for entry: Dictionary in candidates:
		var t: Node3D = entry["target"] as Node3D
		if _has_clear_los(t):
			_autoaim_target = t
			_bind_autoaim_target(t)
			return

## Connects to the locked target's destruction/death signal so the lock is
## dropped the moment it dies (immediate retarget, no scan-timer wait).
func _bind_autoaim_target(target: Node3D) -> void:
	if target is DroneBase:
		var target_drone: DroneBase = target as DroneBase
		if not target_drone.destroyed.is_connected(_on_autoaim_target_destroyed):
			target_drone.destroyed.connect(_on_autoaim_target_destroyed)
	elif target is OperatorBase:
		var target_op: OperatorBase = target as OperatorBase
		if not target_op.operator_incapacitated.is_connected(_on_autoaim_target_down):
			target_op.operator_incapacitated.connect(_on_autoaim_target_down)


## Disconnects the current target's death signal and drops the lock.
func _release_autoaim_target() -> void:
	if _autoaim_target == null:
		return
	if is_instance_valid(_autoaim_target):
		if _autoaim_target is DroneBase:
			var target_drone: DroneBase = _autoaim_target as DroneBase
			if target_drone.destroyed.is_connected(_on_autoaim_target_destroyed):
				target_drone.destroyed.disconnect(_on_autoaim_target_destroyed)
		elif _autoaim_target is OperatorBase:
			var target_op: OperatorBase = _autoaim_target as OperatorBase
			if target_op.operator_incapacitated.is_connected(_on_autoaim_target_down):
				target_op.operator_incapacitated.disconnect(_on_autoaim_target_down)
	_autoaim_target = null

## True when `target` is currently detected by this operator's squad vision
## union (the same source that drives Fog-of-War enemy visibility). Kept separate
## from LoS/cone checks so targeting stays logically consistent with what the
## squad can see (Bug 2): out-of-vision enemies are never targetable.
func _is_target_detected_by_squad(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	var registry_nodes: Array[Node] = get_tree().get_nodes_in_group("squad_vision_registry")
	if registry_nodes.is_empty():
		# No registry present (isolated harness / pre-match setup): fall back to
		# the legacy cone+LoS acquisition so targeting still works there.
		return true
	var reg: SquadVisionRegistry = registry_nodes[0] as SquadVisionRegistry
	if reg == null:
		return true
	return reg.is_entity_detected_by_team(target, team_id)

## Called when the locked drone is destroyed.
func _on_autoaim_target_destroyed() -> void:
	# AI-controlled operators keep _aim_source forced to AI by _update_aim(), so
	# the lock must drop on the signal regardless of the aim source — otherwise
	# a dead target stays locked for up to one scan interval.
	if _aim_source == AimSource.AUTO_AIM or is_ai_controlled:
		_autoaim_target = null

## Called when the locked operator is downed/killed.
func _on_autoaim_target_down(_p_id: int) -> void:
	if _aim_source == AimSource.AUTO_AIM or is_ai_controlled:
		_autoaim_target = null

## Returns whether the given target is still a valid autoaim candidate.
func _is_valid_autoaim_target(target: Node3D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.is_queued_for_deletion():
		return false
	var is_enemy: bool = false
	if target is OperatorBase:
		var op: OperatorBase = target as OperatorBase
		is_enemy = op.team_id != team_id and not op.is_incapacitated
	elif target is DroneBase:
		var drone: DroneBase = target as DroneBase
		is_enemy = drone.operator != null and drone.operator.team_id != team_id
	if not is_enemy:
		return false
	# Bug 2: an enemy is only targetable while the squad can actually see it. This
	# uses the SAME detection union that drives Fog-of-War enemy visibility, so a
	# target hidden from every friendly vision source is never lockable.
	if not _is_target_detected_by_squad(target):
		return false
	if global_position.distance_to(target.global_position) > _get_combat_range():
		return false
	# Aim-device autoaim (mouse RMB aim camera and gamepad right-stick cone) is
	# cone-gated: locks only survive while the target stays inside the tactical
	# cone. The check is re-run every scan, but while a lock is held the aim
	# steers onto the target, so a locked target stays inside the cone by
	# construction and the constraint gates picking.
	if (_is_using_mouse() or _is_using_gamepad()) and not _target_within_vision_cone(target):
		return false
	return _has_clear_los(target)

## True when `target` sits inside this operator's tactical vision cone, measured
## from the authoritative aim_direction. Enforced for aim-device players (mouse
## RMB camera and gamepad right-stick cone), whose autoaim locks must stay within
## the cone shown by the aim camera.
func _target_within_vision_cone(target: Node3D) -> bool:
	if vision_cone == null or target == null or not is_instance_valid(target):
		return true
	var to_target: Vector3 = target.global_position - global_position
	to_target.y = 0.0
	if to_target.length_squared() < 0.0001:
		return true
	var fwd: Vector3 = aim_direction
	if fwd.length_squared() < 0.0001:
		return true
	var cos_angle: float = fwd.normalized().dot(to_target.normalized())
	var half_fov: float = deg_to_rad(vision_cone.field_of_view_degrees * 0.5)
	return cos_angle >= cos(half_fov)

## LoS check for autoaim acquisition (clear line to the target's chest).
func _has_clear_los(target: Node3D) -> bool:
	var eye_pos: Vector3 = get_shot_origin()
	var target_pos: Vector3 = target.global_position + Vector3(0.0, 1.0, 0.0)
	var los: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		self, eye_pos, target_pos, [get_rid()], combat_collision_mask
	)
	return los.is_visible

## Target scoring: nearest wins, with a small bias toward moving targets.
func _autoaim_score(target: Node3D) -> float:
	var dist: float = global_position.distance_to(target.global_position)
	if dist > _get_combat_range():
		return INF
	var moving: bool = false
	if target is CharacterBody3D:
		var body: CharacterBody3D = target as CharacterBody3D
		moving = body.velocity.length_squared() > 1.0
	return dist - (3.0 if moving else 0.0)

## Autoaim auto-fire (Mode B): only when auto-fire is enabled, the button is
## held, a valid target is locked inside weapon range and the weapon has ammo
## (not reloading, not out of ammunition).
func _autoaim_should_fire() -> bool:
	# Mouse players fire with LMB directly; autoaim only steers inside the cone
	# (no double-fire: the trigger evaluation drives the shot).
	if _is_using_mouse():
		return false
	if not auto_fire_enabled:
		return false
	if weapon != null and not weapon.can_fire():
		return false
	if _aim_source != AimSource.AUTO_AIM or not _autoaim_active:
		return false
	if _autoaim_target == null or not is_instance_valid(_autoaim_target):
		return false
	if global_position.distance_to(_autoaim_target.global_position) > _get_combat_range():
		return false
	return true

## Reads crouch / dash input.
## Crouch toggles on press. The dash key triggers a short explosive burst in the
## current input direction (Combat Feel Pass 01), replacing sustained sprint.
## Dash reads the "dash" action (P1 keyboard default: SHIFT).
func _update_sprint_crouch() -> void:
	if is_ai_controlled:
		return
	# Crouch: toggle on press
	var crouch_pressed: bool
	if _input_manager != null:
		crouch_pressed = _input_manager.is_action_pressed(player_id, "crouch")
	else:
		crouch_pressed = false
	
	if crouch_pressed and not _crouch_prev_pressed:
		is_crouching = not is_crouching
		_update_crouch_visual()
	_crouch_prev_pressed = crouch_pressed
	
	# Dash: press the dash key to trigger a short explosive burst in the
	# current input direction. Replaces the previous sustained sprint.
	var dash_pressed: bool
	if _input_manager != null:
		dash_pressed = _input_manager.is_action_pressed(player_id, "dash")
	else:
		dash_pressed = false

	if dash_pressed and not _sprint_prev_pressed:
		_try_start_dash()
	_sprint_prev_pressed = dash_pressed

## Adjusts mesh scale and offset when crouching
func _update_crouch_visual() -> void:
	if _mesh_instance != null:
		if is_crouching:
			_mesh_instance.scale    = Vector3(1.0, 0.55, 1.0)
			_mesh_instance.position = Vector3(0.0, 0.5, 0.0)
		else:
			_mesh_instance.scale    = Vector3(1.0, 1.0, 1.0)
			_mesh_instance.position = Vector3(0.0, 0.9, 0.0)
	if _collision_shape != null:
		if is_crouching:
			_collision_shape.scale    = Vector3(1.0, 0.55, 1.0)
			_collision_shape.position = Vector3(0.0, 0.5, 0.0)
		else:
			_collision_shape.scale    = Vector3(1.0, 1.0, 1.0)
			_collision_shape.position = Vector3(0.0, 0.9, 0.0)
	if vision_cone != null:
		vision_cone.position = Vector3(0.0, VISION_ORIGIN_CROUCHING_Y if is_crouching else VISION_ORIGIN_STANDING_Y, 0.0)
## Assigns InputManager reference
func set_input_manager(input_mgr: InputManager) -> void:
	_input_manager = input_mgr

## Assigns the shared ActionRuntime reference (injected by PlayerManager).
func set_action_runtime(runtime: ActionRuntime) -> void:
	_action_runtime = runtime

## Attempts to trigger a dash in the current movement input direction
## (8-way, diagonals included). Falls back to the aim direction when idle.
func _try_start_dash() -> void:
	if is_dashing or _dash_cooldown_timer > 0.0:
		return
	var move_vec: Vector2 = _get_input_direction()
	var dir: Vector3 = Vector3(move_vec.x, 0.0, move_vec.y)
	if dir.length_squared() < 0.0001:
		dir = aim_direction
	else:
		dir = dir.normalized()
	_dash_direction = dir
	is_dashing = true
	_dash_timer = dash_duration
	_dash_cooldown_timer = dash_cooldown
	if is_crouching:
		is_crouching = false
		_update_crouch_visual()

## Drives velocity during a dash: full dash speed in the dash direction,
## ignoring normal acceleration. Falls back to standard locomotion on expiry.
func _process_dash(delta: float) -> void:
	_dash_timer -= delta
	var dash_speed: float = _get_dash_speed()
	velocity.x = _dash_direction.x * dash_speed
	velocity.z = _dash_direction.z * dash_speed
	if _dash_timer <= 0.0:
		is_dashing = false

## Dash speed derived from the configurable distance and duration.
func _get_dash_speed() -> float:
	return dash_distance / maxf(dash_duration, 0.001)

## Applies damage to operator and triggers signals / incapacitation / visual particles / knockback impulse
func take_damage(amount: float, shot_direction: Vector3 = Vector3.ZERO) -> void:
	if is_incapacitated or is_dead or is_invulnerable or is_in_spawn_zone():
		return
	
	var mitigated_amt: float = amount * (1.0 - damage_mitigation)
	health_current = maxf(0.0, health_current - mitigated_amt)
	health_changed.emit(health_current, health_max)
	
	if mitigated_amt > 0.0:
		_spawn_damage_particles()
		if shot_direction != Vector3.ZERO:
			var knockback_dir: Vector3 = Vector3(shot_direction.x, 0.0, shot_direction.z)
			if knockback_dir.length_squared() > 0.001:
				knockback_dir = knockback_dir.normalized()
				velocity.x += knockback_dir.x * damage_knockback_impulse
				velocity.z += knockback_dir.z * damage_knockback_impulse

	if health_current <= 0.0:
		die()

## Spawns visual armor fragment particles breaking loose on hit (mechanical/armor pieces, NOT blood)
func _spawn_damage_particles(hit_pos: Vector3 = Vector3.ZERO) -> void:
	var spawn_at: Vector3 = hit_pos
	if spawn_at == Vector3.ZERO:
		spawn_at = get_vision_origin()

	var particles: CPUParticles3D = CPUParticles3D.new()
	particles.emitting = false
	particles.one_shot = true
	particles.explosiveness = 0.9
	particles.amount = 10
	particles.lifetime = 0.6
	particles.direction = Vector3(0.0, 1.0, 0.0)
	particles.spread = 75.0
	particles.initial_velocity_min = 1.5
	particles.initial_velocity_max = 3.0
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.scale_amount_min = 0.6
	particles.scale_amount_max = 1.2

	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = Vector3(0.06, 0.06, 0.06)
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.45, 0.45, 0.5)
	mat.metallic = 0.8
	mat.roughness = 0.3
	mesh.material = mat
	particles.mesh = mesh

	var parent: Node = get_parent()
	if parent != null:
		parent.add_child(particles)
		particles.global_position = spawn_at
		particles.emitting = true
		get_tree().create_timer(1.0).timeout.connect(particles.queue_free)

## Triggers death state and starts respawn timer
## Bug 4: window focus-loss handler. Flushes any retained OS key state and stops
## motion so a key released while unfocused can't keep the operator moving.
func _on_window_focus_lost() -> void:
	# Use a runtime call (not a static reference) so the build stays compatible
	# across Godot versions that may not expose this flush method.
	if Input.has_method("flush_buffered_events"):
		Input.call("flush_buffered_events")
	velocity = Vector3.ZERO

func die() -> void:
	if current_state == OperatorState.DEAD:
		return
	current_state = OperatorState.DEAD
	_stop_footsteps()
	velocity = Vector3.ZERO
	is_dashing = false
	# Drop stale input edges so the operator can't resume a held crouch/dash/fire
	# state after it returns to life (Bug 4 — transition safety).
	_crouch_prev_pressed = false
	_sprint_prev_pressed = false
	_fire_input_prev = false
	_burst_pending_shots = 0
	# Remove the body from collision so it cannot block living operators (P1-6),
	# and stop its vision cone scanning (P0-1 secondary — the registry also skips
	# incapacitated owners every recalc).
	if _collision_shape != null:
		_collision_shape.disabled = true
	if vision_cone != null:
		vision_cone.set_physics_process(false)
	# Drop a persistent, non-collidable corpse proxy at the death location so the
	# battlefield reads as a fallen operator instead of an empty void (Issue 1).
	_spawn_corpse()
	operator_incapacitated.emit(player_id)

	# Cancel any active reload while down.
	if weapon != null:
		weapon.cancel_reload()

	# Hide mesh when dead
	if _mesh_instance != null:
		_mesh_instance.visible = false

	# Hide vision cone when dead
	if vision_cone != null:
		vision_cone.visible = false

	# Hide tactical cone and exit precision aim when dead
	if _tactical_cone != null and is_instance_valid(_tactical_cone):
		_tactical_cone.visible = false
	if _aim_state == AimState.PRECISION_AIM:
		_aim_state = AimState.FREE_AIM
		precision_aim_changed.emit(false)

	# If operator is downed, force drone mode exit from pilot
	if drone != null and drone.current_mode == DroneBase.DroneMode.PILOT:
		drone.set_mode(DroneBase.DroneMode.ESCORT)

	# Obtain respawn duration from GameRules or default fallback
	var rules: GameRules = GameRules.get_rules(self)
	var rt: float = rules.respawn_time if rules != null else DEFAULT_RESPAWN_TIME
	respawn_timer = rt
	_update_overhead_badge()

## Triggers incapacitation state (for backward compatibility)
func _incapacitate() -> void:
	die()

## Respawns the operator at specified position, restoring health and state (drones NOT modified per spec)
func respawn(spawn_pos: Vector3 = Vector3.ZERO) -> void:
	current_state = OperatorState.ALIVE

	if spawn_pos != Vector3.ZERO:
		global_position = spawn_pos

	# Reset stance/sprint so the operator reappears standing (P1-7), and restore
	# the body collision + vision-cone scanning disabled on death (P1-6 / P0-1).
	is_crouching = false
	is_sprinting = false
	is_dashing = false
	velocity = Vector3.ZERO
	# Clear stale input edges carried from before death (Bug 4 — transition safety).
	_crouch_prev_pressed = false
	_sprint_prev_pressed = false
	_fire_input_prev = false
	if _collision_shape != null:
		_collision_shape.disabled = false
	if vision_cone != null:
		vision_cone.set_physics_process(true)
	_update_crouch_visual()

	health_current = health_max
	health_changed.emit(health_current, health_max)

	# Restore full ammunition on respawn.
	if weapon != null:
		weapon.reset()

	# Restore mesh visibility
	if _mesh_instance != null:
		_mesh_instance.visible = true

	# Restore vision cone visibility
	if vision_cone != null:
		vision_cone.visible = true

	# Restore tactical cone state on respawn
	_precision_aim_blend = 0.0
	if _tactical_cone != null and is_instance_valid(_tactical_cone):
		_tactical_cone.visible = false

	# Grant temporary invulnerability
	var rules: GameRules = GameRules.get_rules(self)
	var ivt: float = rules.invulnerability_time if rules != null else DEFAULT_INVULNERABILITY_TIME
	is_invulnerable = true
	invulnerability_timer = ivt

	# Respawn a new drone if the previous one was destroyed. The old wreck
	# remains in the world for salvage — spawn_drone() only acts when
	# has_drone_active is false, so this is a no-op when the drone is alive.
	if not has_drone_active:
		spawn_drone()

	_update_overhead_badge()

## Spawns a static, non-collidable corpse/body proxy at the death location.
## Purely visual: no VisionCone3D, no collision shape, not a camera target, so it
## contributes nothing to vision/detection/framing and never interferes with play.
## Corpses persist for the rest of the match (no recovery mechanic yet — Issue 1).
func _spawn_corpse() -> void:
	if _mesh_instance == null or _mesh_instance.mesh == null:
		return
	var corpse: MeshInstance3D = MeshInstance3D.new()
	corpse.name = "Corpse"
	corpse.mesh = _mesh_instance.mesh
	if _mesh_instance.material_override != null:
		corpse.material_override = _mesh_instance.material_override
	# Ground the collapsed body where the operator died (laid flat, slight lift so
	# it rests on the floor rather than clipping through it).
	corpse.global_position = Vector3(global_position.x, 0.3, global_position.z)
	corpse.rotation = Vector3(PI * 0.5, rotation.y, 0.0)
	var parent: Node = get_parent()
	if parent != null and is_instance_valid(parent):
		parent.add_child(corpse)
		_corpses.append(corpse)

## Helper to locate PlayerManager instance
func _find_player_manager() -> PlayerManager:
	if get_parent() is PlayerManager:
		return get_parent() as PlayerManager
	var nodes: Array[Node] = get_tree().get_nodes_in_group("player_manager")
	for n: Node in nodes:
		if not n.is_queued_for_deletion():
			return n as PlayerManager
	return null

## Restores health or revives operator
func revive(restore_hp_ratio: float = 0.5) -> void:
	respawn(global_position)

## Checks if the active ability input is pressed this frame (Space = ability).
func _is_ability_input_just_pressed() -> bool:
	if is_ai_controlled:
		return false
	if _input_manager != null:
		return _input_manager.is_action_just_pressed(player_id, "ability")
	return false

func _update_player_color() -> void:
	if not is_inside_tree() or _mesh_instance == null:
		return
		
	var material: StandardMaterial3D = StandardMaterial3D.new()
	if player_id >= 1 and player_id <= 4:
		material.albedo_color = SLOT_COLORS[player_id - 1]
	else:
		material.albedo_color = Color(0.7, 0.7, 0.7)
	# Keep the team identity color vivid under the arena's cool runtime lighting
	# and tonemapping (which washes saturated reds toward white): a low-energy
	# self-lit component re-emits the SAME slot color without changing the albedo
	# or the SLOT_COLORS palette.
	material.emission_enabled = true
	material.emission = material.albedo_color
	material.emission_energy_multiplier = 0.35
		
	_mesh_instance.material_override = material

## ──────────────────────────────────────────────
## RESOURCE API (Etapa 7)
## ──────────────────────────────────────────────

## Public entry point for collecting a resource (used by ResourcePickup and external systems).
## Returns the amount actually added to the inventory.
func collect_resource(resource_type: String, amount: int) -> int:
	if inventory == null or is_incapacitated:
		return 0
	return inventory.add_resource(resource_type, amount)

## Returns current maintenance component count from this operator's inventory.
func get_maintenance_components() -> int:
	if inventory == null:
		return 0
	return inventory.get_maintenance_components()

## Returns the operator's inventory capacity.
func get_inventory_capacity() -> int:
	if inventory == null:
		return 0
	return inventory.capacity

## ──────────────────────────────────────────────
## WEAPON SYSTEM ACCESSORS (Gen 1)
## ──────────────────────────────────────────────

## Rounds currently loaded in the magazine.
func get_ammo_rounds() -> int:
	if weapon == null:
		return 0
	return weapon.magazine.current_rounds

## Magazine capacity.
func get_ammo_capacity() -> int:
	if weapon == null:
		return 0
	return weapon.magazine.capacity

## Spare magazines remaining in the reserve.
func get_ammo_magazines() -> int:
	if weapon == null:
		return 0
	return weapon.reserve.magazines_remaining

## True while an automatic reload is in progress.
func is_weapon_reloading() -> bool:
	return weapon != null and weapon.is_reloading()

## Reload progress in the 0.0 .. 1.0 range (0.0 when idle).
func get_weapon_reload_progress() -> float:
	return weapon.get_reload_progress() if weapon != null else 0.0

## True when the magazine is empty and no reserve magazines remain.
func is_weapon_out_of_ammo() -> bool:
	return weapon != null and weapon.is_out_of_ammo()

## Short HUD-ready ammo status line covering rounds, magazines, reload state
## and the out-of-ammunition state.
func get_ammo_status_text() -> String:
	if weapon == null:
		return "AMMO: N/A"
	if weapon.is_out_of_ammo():
		return "AMMO: SIN MUNICIÓN"
	if weapon.is_reloading():
		return "AMMO: RECARGANDO %d%%" % int(weapon.get_reload_progress() * 100.0)
	return "AMMO: %d/%d · MAGS: %d" % [get_ammo_rounds(), get_ammo_capacity(), get_ammo_magazines()]
