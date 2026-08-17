# sandbox_test_scene.gd
# Technical Rationale: Entry script for SANDBOX-01.
# Integrates PlayerManager, SquadHUD, InputManager, CameraController, SquadVisionRegistry,
# Synthesis Points, AICore (Etapa 6), and ResourceManager + pickups (Etapa 7).
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SandboxTestScene
extends Node3D

@onready var input_manager: InputManager = $InputManager if has_node("InputManager") else null
@onready var player_manager: PlayerManager = $PlayerManager if has_node("PlayerManager") else null
@onready var camera_controller: CameraController = $CameraController if has_node("CameraController") else null
@onready var squad_hud: SquadHUD = $SquadHUD if has_node("SquadHUD") else null
@onready var squad_vision_registry: SquadVisionRegistry = $SquadVisionRegistry if has_node("SquadVisionRegistry") else null

## Fog of War overlay (Phase 2). Ground floor is 60x60 in the sandbox.
var fog_of_war_display: FogOfWarDisplay = null

## References to synthesis zones
var _synthesis_zones: Array[Area3D] = []

## AICore module reference (Etapa 6)
var ai_core: AICore = null

## ResourceManager module reference (Etapa 7)
var resource_manager: ResourceManager = null

## Action System integration references (debug-only / infrastructure)
var _action_runtime: ActionRuntime = null
var _action_bus: GameplayEventBus = null
var _test_action: TestAction = null

## Debug overlay label
var _debug_label: Label = null

## Per-operator aim cone overlays: player_id -> {mi: MeshInstance3D, imm: ImmediateMesh, op: OperatorBase}
var _aim_overlays: Dictionary = {}

func _ready() -> void:
	_initialize_game_rules()
	_initialize_etapa_4_sandbox()
	_initialize_ai_core()
	_initialize_resource_system()
	_setup_debug_overlay()
	# Temporary joystick/input diagnostic overlay (always shown).
	add_child(preload("res://scripts/runtime_input_diag.gd").new())
	_initialize_action_system_debug_probe()
	# Force window focus so keyboard input is captured immediately
	call_deferred("_grab_window_focus")

func _initialize_game_rules() -> void:
	var has_valid_rules: bool = false
	var existing: Array[Node] = get_tree().get_nodes_in_group("game_rules")
	for node: Node in existing:
		if not node.is_queued_for_deletion():
			has_valid_rules = true
			break
	if not has_valid_rules:
		var rules: GameRules = GameRules.new()
		rules.name = "GameRules"
		rules.friendly_fire_enabled = _session_friendly_fire()
		add_child(rules)
	else:
		var rules_node: GameRules = GameRules.get_rules(self)
		if rules_node != null:
			rules_node.friendly_fire_enabled = _session_friendly_fire()

func _grab_window_focus() -> void:
	get_viewport().get_window().grab_focus()

func _setup_debug_overlay() -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	_debug_label = Label.new()
	_debug_label.position = Vector2(10, 10)
	_debug_label.add_theme_font_size_override("font_size", 18)
	_debug_label.add_theme_color_override("font_color", Color(1, 1, 0))
	_debug_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_debug_label.add_theme_constant_override("shadow_offset_x", 2)
	_debug_label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(_debug_label)

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
		return
	_update_debug_overlay()
	_update_aim_overlays()
	if Input.is_action_just_pressed("debug_action_system"):
		_run_action_system_debug_probe()

func _update_debug_overlay() -> void:
	if _debug_label == null or input_manager == null:
		return
	var p1_vec: Vector2 = input_manager.get_movement_vector(1)
	var p1_firing: bool = input_manager.is_action_pressed(1, "fire")
	var win_focused: bool = get_viewport().get_window().has_focus()
	_debug_label.text = "[DEBUG] Ventana foco: %s\nP1 WASD: (%.2f, %.2f)   FIRE(Space/Click): %s\nP2 IJKL: fire=U  |  P3 Flechas: fire=/  |  F12 Action System Probe" % [
		"✓ SÍ" if win_focused else "✗ NO — hacé clic en la ventana!",
		p1_vec.x, p1_vec.y,
		"■ DISPARANDO" if p1_firing else "○"
	]

func _physics_process(_delta: float) -> void:
	if player_manager != null:
		var centroid: Vector3 = player_manager.get_squad_centroid()
		var ops: Array[OperatorBase] = player_manager.get_all_operators()
		for op: OperatorBase in ops:
			op.update_squad_separation(centroid)
			
		# Dynamic camera target updates for Pilot Mode
		_update_camera_targets()
		_process_synthesis_zones()

## Initializes Etapa 4 Managers, Vision Registry, HUD, and camera binding
func _initialize_etapa_4_sandbox() -> void:
	if input_manager == null:
		input_manager = InputManager.new()
		input_manager.name = "InputManager"
		add_child(input_manager)

	if squad_vision_registry == null:
		squad_vision_registry = SquadVisionRegistry.new()
		squad_vision_registry.name = "SquadVisionRegistry"
		add_child(squad_vision_registry)

	if player_manager == null:
		player_manager = PlayerManager.new()
		player_manager.name = "PlayerManager"
		add_child(player_manager)

	# Connect signals BEFORE setup_squad so player_spawned fires with the handler already attached
	player_manager.squad_updated.connect(_on_squad_updated)
	player_manager.player_spawned.connect(_on_player_spawned)
	var enabled_ids: Array[int] = _session_enabled_player_ids()
	if enabled_ids.is_empty():
		enabled_ids = [1, 2, 3, 4]
	player_manager.setup_squad(input_manager, enabled_ids)

	if squad_hud != null:
		squad_hud.setup_hud(player_manager, input_manager, squad_vision_registry)

	_setup_fog_of_war()

	# Locate and bind any Area3D nodes in "synthesis_points" group
	_synthesis_zones.clear()
	var zones: Array[Node] = get_tree().get_nodes_in_group("synthesis_points")
	for node: Node in zones:
		if node is Area3D:
			_synthesis_zones.append(node as Area3D)

	_on_squad_updated(enabled_ids.size())
	_spawn_boundary_walls()
	print("[SandboxTestScene] SANDBOX-01 base initialized. Drone Gen 1, Escort, Stationary, Pilot Modes active.")

## Instantiates the Fog of War overlay (Phase 2). Sandbox floor is 60x60m.
func _setup_fog_of_war() -> void:
	if fog_of_war_display != null:
		return
	var bounds: Vector2 = Vector2(60.0, 60.0)
	var fog_data: FogOfWar = FogOfWar.new()
	fog_data.setup(bounds, FogOfWar.DEFAULT_CELL_SIZE)
	fog_of_war_display = FogOfWarDisplay.new()
	fog_of_war_display.name = "FogOfWarDisplay"
	add_child(fog_of_war_display)
	fog_of_war_display.setup(fog_data, player_manager, bounds, get_node_or_null("MapGeometry"))

## Callback when a new player operator spawns
func _on_player_spawned(_p_id: int, op: OperatorBase) -> void:
	if op != null:
		if op.vision_cone != null and squad_vision_registry != null:
			squad_vision_registry.register_provider(op.vision_cone)
		op.damage_dealt.connect(_on_operator_damage_dealt)
		op.drone_status_changed.connect(_on_drone_status_changed)
		op.weapon_fired.connect(_on_weapon_fired.bind(op))
		_setup_operator_aim_cone(op)

## Callback when drone status changes (registered to shared squad vision)
func _on_drone_status_changed(p_id: int, has_drone: bool, mode: String) -> void:
	print("[SQUAD STATUS] Player P%d Drone status updated: Active = %s, Mode = %s" % [p_id, str(has_drone), mode])
	if squad_vision_registry != null:
		var op: OperatorBase = player_manager.get_operator(p_id)
		if op != null:
			if has_drone and op.drone != null and op.drone.vision_cone != null:
				squad_vision_registry.register_provider(op.drone.vision_cone)
				if not op.drone.weapon_fired.is_connected(_on_drone_weapon_fired):
					op.drone.weapon_fired.connect(_on_drone_weapon_fired.bind(op.drone))
				if not op.drone.damage_dealt.is_connected(_on_operator_damage_dealt):
					op.drone.damage_dealt.connect(_on_operator_damage_dealt)
			elif not has_drone and op.drone == null:
				# Re-evaluate vision registry
				squad_vision_registry._recalculate_squad_vision()

## Callback when damage is dealt with cover mitigation
func _on_operator_damage_dealt(target: OperatorBase, damage: float, mitigated_by_cover: bool) -> void:
	var msg: String = "[COMBAT] Operator P%d hit for %.1f damage" % [target.player_id, damage]
	if mitigated_by_cover:
		msg += " [MITIGATED BY COVER -50%]"
	print(msg)
	# Visual: floating damage number at target position
	_spawn_damage_number(target.global_position + Vector3(0.0, 2.5, 0.0), damage, mitigated_by_cover)
	# Visual: red flash on hit operator
	_flash_operator(target)

## Creates an ImmediateMesh aim cone overlay for an operator
func _setup_operator_aim_cone(op: OperatorBase) -> void:
	var mi: MeshInstance3D = MeshInstance3D.new()
	var imm: ImmediateMesh = ImmediateMesh.new()
	mi.mesh = imm
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	mi.material_override = mat
	add_child(mi)
	_aim_overlays[op.player_id] = {"mi": mi, "imm": imm, "op": op}

## Rebuilds all operator aim cone meshes based on current rotation and LoS state
func _update_aim_overlays() -> void:
	for entry: Dictionary in _aim_overlays.values():
		var imm: ImmediateMesh = entry["imm"] as ImmediateMesh
		var op: OperatorBase = entry["op"] as OperatorBase
		if not is_instance_valid(op) or imm == null:
			continue
		imm.clear_surfaces()
		if op.is_incapacitated or op.is_dead:
			continue
		_rebuild_aim_cone(imm, op)

## Draws the weapon arc with real wall occlusion using per-ray LoS clipping.
## Each ray casts from eye height; hit points project down to floor level.
## Result: the cone is trimmed exactly where walls / objects block it.
func _rebuild_aim_cone(imm: ImmediateMesh, op: OperatorBase) -> void:
	var pos: Vector3    = op.global_position + Vector3(0.0, 0.06, 0.0)
	# Follow the SAME authoritative XZ aim direction as firing/vision, so the
	# gamepad right stick points this cone horizontally exactly where it points.
	var fwd: Vector3    = op.aim_direction
	if fwd.length_squared() < 0.0001:
		fwd = Vector3(0.0, 0.0, -1.0)
	fwd = fwd.normalized()
	var yaw: float      = atan2(-fwd.x, -fwd.z)
	var range_d: float  = op.weapon_range
	var eye: Vector3    = op.global_position + Vector3(0.0, 1.2, 0.0)
	var exclude: Array[RID] = [op.get_rid()]

	# Cast one ray per step; collect hit points projected down to floor level.
	var half_rad: float    = deg_to_rad(15.0)
	var steps: int         = 20          # 1.5° per step → smooth arc
	var hit_pts: Array[Vector3] = []
	var has_enemy: bool    = false

	for i: int in range(steps + 1):
		var angle: float     = -half_rad + (float(i) / float(steps)) * 2.0 * half_rad
		var ray_dir: Vector3 = Vector3(-sin(yaw + angle), 0.0, -cos(yaw + angle))
		var ray_end: Vector3 = eye + ray_dir * range_d

		var los: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
			op, eye, ray_end, exclude, op.combat_collision_mask
		)

		var hp: Vector3
		if los.hit_collider != null:
			hp = los.hit_position
			if los.hit_collider is OperatorBase:
				has_enemy = true
		else:
			hp = ray_end
		hp.y = pos.y
		hit_pts.append(hp)

	# --- Filled cone polygon (fan from operator origin) ---
	var fill_col: Color = Color(1.0, 0.15, 0.15, 0.32) if has_enemy else Color(0.22, 0.88, 1.0, 0.2)
	imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(hit_pts.size() - 1):
		imm.surface_set_color(fill_col)
		imm.surface_add_vertex(pos)
		imm.surface_set_color(fill_col)
		imm.surface_add_vertex(hit_pts[i])
		imm.surface_set_color(fill_col)
		imm.surface_add_vertex(hit_pts[i + 1])
	imm.surface_end()

	# --- Bright arc edge along the hit-point boundary ---
	var edge_col: Color  = Color(fill_col.r, fill_col.g, fill_col.b, 0.85)
	var edge_w: float    = 0.055
	imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i: int in range(hit_pts.size() - 1):
		var p0: Vector3  = hit_pts[i]
		var p1: Vector3  = hit_pts[i + 1]
		var seg: Vector3 = (p1 - p0)
		if seg.length_squared() < 0.0001:
			continue
		var perp: Vector3 = seg.normalized().cross(Vector3.UP) * edge_w
		# Two triangles per edge quad
		imm.surface_set_color(edge_col); imm.surface_add_vertex(p0 - perp)
		imm.surface_set_color(edge_col); imm.surface_add_vertex(p0 + perp)
		imm.surface_set_color(edge_col); imm.surface_add_vertex(p1 - perp)
		imm.surface_set_color(edge_col); imm.surface_add_vertex(p0 + perp)
		imm.surface_set_color(edge_col); imm.surface_add_vertex(p1 + perp)
		imm.surface_set_color(edge_col); imm.surface_add_vertex(p1 - perp)
	imm.surface_end()

	# --- Side rays (left & right boundary lines from operator to first wall hit) ---
	var side_col: Color = Color(edge_col.r, edge_col.g, edge_col.b, 0.6)
	for side_pt: Vector3 in [hit_pts[0], hit_pts[hit_pts.size() - 1]]:
		var seg: Vector3 = side_pt - pos
		if seg.length_squared() < 0.001:
			continue
		var perp: Vector3 = seg.normalized().cross(Vector3.UP) * (edge_w * 0.6)
		imm.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
		imm.surface_set_color(side_col); imm.surface_add_vertex(pos - perp)
		imm.surface_set_color(side_col); imm.surface_add_vertex(pos + perp)
		imm.surface_set_color(side_col); imm.surface_add_vertex(side_pt - perp)
		imm.surface_set_color(side_col); imm.surface_add_vertex(pos + perp)
		imm.surface_set_color(side_col); imm.surface_add_vertex(side_pt + perp)
		imm.surface_set_color(side_col); imm.surface_add_vertex(side_pt - perp)
		imm.surface_end()

## Spawns invisible boundary walls around the 60x60 floor so operators can't fall off
func _spawn_boundary_walls() -> void:
	var half: float = 30.0
	var h: float = 4.0   # wall height
	var t: float = 0.5   # wall thickness
	var configs: Array = [
		[Vector3(0.0,    h * 0.5,  half), Vector3(60.0, h, t)],  # North
		[Vector3(0.0,    h * 0.5, -half), Vector3(60.0, h, t)],  # South
		[Vector3( half,  h * 0.5,  0.0),  Vector3(t, h, 60.0)],  # East
		[Vector3(-half,  h * 0.5,  0.0),  Vector3(t, h, 60.0)],  # West
	]
	for cfg: Array in configs:
		var wall: StaticBody3D = StaticBody3D.new()
		wall.position = cfg[0] as Vector3
		var shape_node: CollisionShape3D = CollisionShape3D.new()
		var box: BoxShape3D = BoxShape3D.new()
		box.size = cfg[1] as Vector3
		shape_node.shape = box
		wall.add_child(shape_node)
		add_child(wall)
	print("[SandboxTestScene] Boundary walls spawned (60x60 arena).")

## Visual: shot tracer stops at the actual hit point (wall or max range)
func _on_weapon_fired(origin: Vector3, direction: Vector3, shooter: OperatorBase) -> void:
	# Find real hit position — tracer should NOT pass through walls
	var ray_end: Vector3 = origin + direction * shooter.weapon_range
	var los: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		shooter, origin, ray_end, [shooter.get_rid()], shooter.combat_collision_mask
	)
	var actual_end: Vector3 = los.hit_position if los.hit_collider != null else ray_end
	_spawn_muzzle_flash(origin, shooter.player_id)
	_spawn_shot_tracer(origin, actual_end, shooter.player_id)

## Drone pilot fire feedback (same presentation path as operator rounds).
func _on_drone_weapon_fired(origin: Vector3, direction: Vector3, drone: DroneBase) -> void:
	if drone == null or not is_instance_valid(drone) or drone.weapon == null:
		return
	var ray_end: Vector3 = origin + direction * drone.weapon.range
	var los: LineOfSightQuery.LoSResult = LineOfSightQuery.test_los(
		drone, origin, ray_end, [drone.get_rid()], drone.combat_collision_mask
	)
	var actual_end: Vector3 = los.hit_position if los.hit_collider != null else ray_end
	var p_id: int = drone.operator.player_id if drone.operator != null else 1
	_spawn_muzzle_flash(origin, p_id)
	_spawn_shot_tracer(origin, actual_end, p_id)

## Spawns a brief bright sphere at the muzzle (confirms signal is firing)
func _spawn_muzzle_flash(pos: Vector3, p_id: int) -> void:
	var flash: MeshInstance3D = MeshInstance3D.new()
	var sphere: SphereMesh = SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	flash.mesh = sphere
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.emission_enabled = true
	var colors: Array[Color] = [
		Color(1.0, 0.6, 0.1), Color(0.4, 0.8, 1.0),
		Color(0.4, 1.0, 0.4), Color(1.0, 1.0, 0.2),
	]
	mat.emission = colors[clampi(p_id - 1, 0, 3)]
	mat.albedo_color = Color.WHITE
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Same overlay treatment as the tracer: stays visible above the vision cone.
	mat.no_depth_test = true
	mat.render_priority = 20
	flash.material_override = mat
	add_child(flash)
	flash.global_position = pos
	var tw: Tween = create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.1)
	tw.tween_callback(flash.queue_free)

## Spawns a thin glowing tracer box along the shot direction
func _spawn_shot_tracer(from: Vector3, to: Vector3, p_id: int) -> void:
	var dir: Vector3 = to - from
	var length: float = dir.length()
	if length < 0.01:
		return
	dir = dir.normalized()

	var tracer: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, length)   # BoxMesh extends along Z by default
	tracer.mesh = box

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.emission_enabled = true
	var colors: Array[Color] = [
		Color(1.0, 0.35, 0.35),   # P1 red
		Color(0.35, 0.65, 1.0),   # P2 blue
		Color(0.35, 1.0, 0.45),   # P3 green
		Color(1.0, 0.95, 0.25),   # P4 yellow
	]
	var col: Color = colors[clampi(p_id - 1, 0, 3)]
	mat.emission = col * 2.0
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Draw above the tactical vision cone (no_depth_test, render_priority 10) so
	# shots stay visible while the operator's RMB cone is displayed.
	mat.no_depth_test = true
	mat.render_priority = 20
	tracer.material_override = mat

	add_child(tracer)
	tracer.global_position = (from + to) * 0.5

	# Build basis: Z axis = shot direction, Y axis = up (or right if near-vertical)
	var world_up: Vector3 = Vector3.UP
	if absf(dir.dot(world_up)) > 0.99:
		world_up = Vector3.RIGHT
	var right: Vector3 = dir.cross(world_up).normalized()
	var up: Vector3 = right.cross(dir).normalized()
	tracer.global_transform.basis = Basis(right, up, dir)

	# Fade and destroy in 0.25s
	var tw: Tween = create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(tracer.queue_free)

## Spawns a floating damage number above the hit position
func _spawn_damage_number(world_pos: Vector3, damage: float, mitigated: bool) -> void:
	var lbl: Label3D = Label3D.new()
	lbl.text = "-%.0f" % damage
	if mitigated:
		lbl.text += " [COV]"
	lbl.font_size = 48
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.no_depth_test = true
	lbl.modulate = Color(1.0, 0.2, 0.2) if not mitigated else Color(1.0, 0.55, 0.1)
	lbl.outline_size = 8
	add_child(lbl)
	lbl.global_position = world_pos
	# Animate: float upward 2 units, fade to transparent over 0.9s
	var start_y: float = world_pos.y
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(y: float) -> void:
		if is_instance_valid(lbl):
			lbl.global_position.y = y
	, start_y, start_y + 2.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)

## Briefly flashes an operator's mesh white/red on hit
func _flash_operator(op: OperatorBase) -> void:
	if op == null or not is_instance_valid(op):
		return
	var mesh: MeshInstance3D = op.get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh == null:
		return
	var original_mat: Material = mesh.material_override
	var flash_mat: StandardMaterial3D = StandardMaterial3D.new()
	flash_mat.albedo_color = Color.WHITE
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.1, 0.1)
	mesh.material_override = flash_mat
	var tw: Tween = create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(func() -> void:
		if is_instance_valid(mesh):
			mesh.material_override = original_mat
	)

## Debug-only initialization for the Action System framework probe.
func _initialize_action_system_debug_probe() -> void:
	_action_bus = GameplayEventBus.new()
	_action_bus.event_emitted.connect(func(event_name: String, payload: Dictionary) -> void:
		print("[BUS] %s :: %s" % [event_name, str(payload)])
	)

	var registry: ActionRegistry = ActionRegistry.new()
	_action_runtime = ActionRuntime.new(registry, _action_bus)
	_test_action = TestAction.new()
	registry.register(_test_action)
	print("[ACTION SYSTEM] Runtime initialized in sandbox loop. Registered TestAction.")

## One-shot debug probe driven by F12. This path is intentionally isolated.
func _run_action_system_debug_probe() -> void:
	print("[ACTION SYSTEM] [1/6] ActionIntent created.")
	var intent: ActionIntent = ActionIntent.new(
		"debug_player",
		"test_action",
		"sandbox_debug_input",
		{"debug_key": "F12"},
		10,
		Time.get_ticks_msec() * 0.001
	)
	print("[ACTION SYSTEM] [1/6] Intent: actor=%s action=%s" % [intent.actor_id, intent.requested_action_id])

	print("[ACTION SYSTEM] [2/6] ActionRuntime receives Intent.")
	var resolved: Action = _action_runtime.resolve_action(intent)
	print("[ACTION SYSTEM] [3/6] ActionRegistry resolved: %s" % [resolved.action_id if resolved != null else "null"])

	print("[ACTION SYSTEM] [4/6] TestAction executes can_execute -> start -> finish.")
	var result: ActionResult = _action_runtime.submit_intent(intent)
	print("[ACTION SYSTEM] [5/6] ActionResult successful: %s | reason: %s" % [result.success, result.reason])
	print("[ACTION SYSTEM] [6/6] GameplayEventBus emitted event for completion.")

	if result.success:
		print("✓ PASS: Action System debug probe completed successfully.")
	else:
		print("✗ FAIL: Action System debug probe did not complete successfully.")

## Callback when squad player count changes
func _on_squad_updated(_active_count: int) -> void:
	_update_camera_targets()

## Recalculates CameraController targets based on active Operator/Drone pilot status
func _update_camera_targets() -> void:
	if camera_controller == null or player_manager == null:
		return

	var ops: Array[OperatorBase] = player_manager.get_all_operators()
	var node3d_targets: Array[Node3D] = []
	
	for op: OperatorBase in ops:
		# Shared camera keeps the operator as a framing anchor; the piloted
		# drone is ADDED as an extra target, never swapped in (keeps the rest
		# of the squad from appearing to slide with a far-away drone).
		node3d_targets.append(op as Node3D)
		if op.is_piloting_drone and op.drone != null and is_instance_valid(op.drone):
			node3d_targets.append(op.drone as Node3D)
			
	camera_controller.targets = node3d_targets

## Handles reconstruction logic if operator enters a Synthesis zone lacking a Drone
func _process_synthesis_zones() -> void:
	if player_manager == null:
		return

	var ops: Array[OperatorBase] = player_manager.get_all_operators()
	for op: OperatorBase in ops:
		if op.drone == null or not op.has_drone_active:
			for zone: Area3D in _synthesis_zones:
				if zone.overlaps_body(op):
					op.rebuild_drone()
					print("[SYNTHESIS] Rebuilt Drone Gen 1 for Operator P%d." % op.player_id)
					break

## ──────────────────────────────────────────────
## ETAPA 6 — AI CORE INITIALIZATION
## ──────────────────────────────────────────────

## Instantiates AICore module and places it on the CorePlatform (Z = -20)
func _initialize_ai_core() -> void:
	ai_core = AICore.new()
	ai_core.name = "AICore"
	## CorePlatform is at (0, 0.5, -20) — place Core just above it
	ai_core.position = Vector3(0.0, 1.5, -20.0)
	## Configurable parameters (exposed for future balance tuning)
	ai_core.hack_speed_percent_per_second = 5.0
	ai_core.degradation_percent_per_tick = 10.0
	ai_core.degradation_interval_seconds = 30.0
	ai_core.capture_threshold_percent = 100.0
	ai_core.perimeter_size = Vector3(10.0, 3.0, 10.0)
	add_child(ai_core)

	## Connect AICore signals for console logging and SquadHUD integration
	ai_core.hack_started.connect(_on_core_hack_started)
	ai_core.hack_progress_changed.connect(_on_core_progress_changed)
	ai_core.hack_contested.connect(_on_core_contested)
	ai_core.hack_degrading.connect(_on_core_degrading)
	ai_core.hack_completed.connect(_on_core_completed)
	ai_core.ownership_changed.connect(_on_core_ownership_changed)

	## Notify SquadHUD of the AICore reference
	if squad_hud != null:
		squad_hud.set_ai_core(ai_core)

	print("[SandboxTestScene] AICore initialized at CorePlatform (Z=-20). Perimeter: 10x3x10m.")

func _on_core_hack_started(team_id: int) -> void:
	print("[CORE] *** HACK STARTED — Team %d is hacking the AI Core ***" % team_id)

func _on_core_progress_changed(progress: float, team_id: int) -> void:
	if squad_hud != null:
		squad_hud.update_core_status(progress, ai_core.get_current_state() if ai_core != null else HackController.CoreState.IDLE)
	## Throttle to avoid log spam — only print at each 10% threshold
	var threshold: int = int(progress / 10.0) * 10
	if threshold > 0 and int(progress) % 10 < 2:
		print("[CORE] Progress: %d%% — Team %d" % [int(progress), team_id])

func _on_core_contested() -> void:
	if squad_hud != null:
		squad_hud.update_core_status(ai_core.get_progress() if ai_core != null else 0.0, HackController.CoreState.CONTESTED)

func _on_core_degrading(progress: float) -> void:
	print("[CORE] *** DEGRADATION — Progress dropping to %.1f%% ***" % progress)
	if squad_hud != null:
		squad_hud.update_core_status(progress, HackController.CoreState.DEGRADED)

func _on_core_completed(team_id: int) -> void:
	print("[CORE] *** CORE CAPTURED — Team %d controls the AI Core! ***" % team_id)
	if squad_hud != null:
		squad_hud.update_core_status(100.0, HackController.CoreState.CAPTURED)

	# Freeze all operators on match end
	if player_manager != null:
		for op: OperatorBase in player_manager.get_all_operators():
			op.is_incapacitated = true
			op.velocity = Vector3.ZERO

	_show_match_end_screen(team_id)

## Displays the end of match UI screen with winner details and "Jugar nuevamente" restart button
func _show_match_end_screen(winning_team_id: int) -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.layer = 200
	add_child(canvas)

	# Full-screen dark translucent backdrop
	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1, 0.85)
	canvas.add_child(bg)

	# Centered Vertical Box Container
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel: VBoxContainer = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 20)
	center.add_child(panel)

	# Title Label
	var title: Label = Label.new()
	title.text = "¡FIN DE PARTIDA!"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 3)
	panel.add_child(title)

	# Subtitle Label (Winner declaration)
	var winner_label: Label = Label.new()
	var team_name: String = "ATACANTES (Equipo 0)" if winning_team_id == OperatorBase.TEAM_ATTACKERS else "DEFENSORES (Equipo 1)"
	winner_label.text = "EQUIPO GANADOR:\n%s" % team_name
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 28)
	var team_col: Color = Color(0.95, 0.3, 0.3) if winning_team_id == OperatorBase.TEAM_ATTACKERS else Color(0.3, 0.6, 1.0)
	winner_label.add_theme_color_override("font_color", team_col)
	panel.add_child(winner_label)

	# Spacer
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	panel.add_child(spacer)

	# Restart Button ("Jugar nuevamente")
	var btn: Button = Button.new()
	btn.text = "Jugar nuevamente"
	btn.custom_minimum_size = Vector2(240, 55)
	btn.add_theme_font_size_override("font_size", 22)
	btn.pressed.connect(_on_restart_button_pressed)
	panel.add_child(btn)
	print("[MATCHEND] Restart button created. mouse_filter=", btn.mouse_filter, " focus_mode=", btn.focus_mode)

func _on_restart_button_pressed() -> void:
	print("[MATCHEND] >>> _on_restart_button_pressed() CALLED (button event arrived) <<<")
	get_tree().change_scene_to_file("res://scenes/sandbox_test_scene.tscn")
	print("[MATCHEND] change_scene_to_file returned (after call).")

func _on_core_ownership_changed(new_owner: int) -> void:
	print("[CORE] Ownership transferred to Team %d" % new_owner)

## ──────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_R:
				get_tree().change_scene_to_file("res://scenes/sandbox_test_scene.tscn")
			KEY_2:
				print("[SandboxTestScene] Testing 2-Player Squad")
				if player_manager != null:
					player_manager.set_active_player_count(2)
			KEY_3:
				print("[SandboxTestScene] Testing 3-Player Squad")
				if player_manager != null:
					player_manager.set_active_player_count(3)
			KEY_4:
				print("[SandboxTestScene] Testing 4-Player Squad")
				if player_manager != null:
					player_manager.set_active_player_count(4)

## ──────────────────────────────────────────────
## ETAPA 7 — RESOURCE SYSTEM INITIALIZATION
## ──────────────────────────────────────────────

## Initialises ResourceManager, pre-placed pickups and salvageable WreckSites for SANDBOX-01.
## Pickup positions chosen to validate all three routes without modifying map geometry.
func _initialize_resource_system() -> void:
	## 1. Create and register ResourceManager
	resource_manager = ResourceManager.new()
	resource_manager.name = "ResourceManager"
	add_child(resource_manager)

	## Connect signals for console telemetry
	resource_manager.pickup_collected.connect(_on_resource_collected)
	resource_manager.wreck_salvaged.connect(_on_wreck_salvaged)

	## 2. Pre-placed pickups — one per route + one at spawn
	## Spawn area (safe collection to test basic pickup)
	resource_manager.spawn_pickup(
		ResourceInventory.TYPE_MAINTENANCE, 10,
		Vector3(0.0, 0.1, 7.0), self
	)
	## Left route (Ruta Oeste — near RouteLeft_LowCover)
	resource_manager.spawn_pickup(
		ResourceInventory.TYPE_MAINTENANCE, 8,
		Vector3(-20.0, 0.1, -2.0), self
	)
	## Central route (Ruta Central — near Center_LowCover1)
	resource_manager.spawn_pickup(
		ResourceInventory.TYPE_MAINTENANCE, 12,
		Vector3(2.0, 0.1, -8.0), self
	)
	## Right route elevated platform (Ruta Derecha — top of ramp)
	resource_manager.spawn_pickup(
		ResourceInventory.TYPE_MAINTENANCE, 15,
		Vector3(18.0, 2.0, -5.0), self
	)
	## Near Core perimeter — high-value pickup, dangerous to collect
	resource_manager.spawn_pickup(
		ResourceInventory.TYPE_MAINTENANCE, 20,
		Vector3(3.0, 0.1, -18.0), self
	)

	## 3. Pre-placed WreckSalvage nodes for testing salvage mechanic
	_spawn_wreck_salvage(Vector3(-15.0, 0.1, -8.0), 8)   ## Left route wreck
	_spawn_wreck_salvage(Vector3(5.0, 0.1, -13.0), 12)  ## Central route wreck

	print("[SandboxTestScene] ResourceManager initialized. 5 pickups + 2 pre-placed wrecks spawned.")

## Spawns a WreckSalvage node at world_pos with given component yield
func _spawn_wreck_salvage(world_pos: Vector3, components: int) -> void:
	var wreck: WreckSalvage = WreckSalvage.new()
	wreck.components_per_salvage = components
	add_child(wreck)
	wreck.global_position = world_pos
	resource_manager.register_wreck_salvage(wreck)

func _on_resource_collected(resource_type: String, amount: int, collector_id: int) -> void:
	print("[RESOURCES] P%d collected %d x %s" % [collector_id, amount, resource_type])

func _on_wreck_salvaged(salvager_id: int, components: int) -> void:
	print("[RESOURCES] P%d salvaged wreck — %d maintenance components spawned" % [salvager_id, components])

func _session_root() -> Node:
	if get_tree() == null:
		return null
	return get_tree().root.get_node_or_null("GameConfig")

func _session_enabled_player_ids() -> Array[int]:
	var session: Node = _session_root()
	if session == null:
		return []
	return session.call("get_enabled_player_ids") as Array[int]

func _session_friendly_fire() -> bool:
	var session: Node = _session_root()
	if session == null:
		return false
	return session.get("friendly_fire_enabled") as bool
