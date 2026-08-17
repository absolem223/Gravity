# fog_of_war_display.gd
# Technical Rationale: Phase 2 rendering layer for the Fog of War system.
# A Node3D that renders the FogOfWar data layer (modules/vision/fog_of_war.gd)
# as a ground-plane texture overlay. It is completely independent of the
# CameraController, inputs and aim: it only maps a grid texture to a PlaneMesh
# sized to the arena/sandbox floor. Reads GameSettings at runtime (enabled flag,
# explored brightness, edge softness) like every other presentation system.
#
# Responsibilities:
#   - Poll the PlayerManager each physics frame and feed every HUMAN operator's
#     position + vision cone radius into the FogOfWar data layer.
#   - Rebuild a 2D image (R = explored, G = visible) from the UNION mask policy
#     and upload it to an ImageTexture sampled by fog_of_war.gdshader.
#   - Honor GameSettings.fog_of_war_enabled (hides the plane when disabled).
#   - Throttle texture rebuilds so the per-frame cost stays flat.
#
# The display never owns match logic: match.gd / the sandbox harness create it,
# pass the FogOfWar instance + PlayerManager, and forget about it.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name FogOfWarDisplay
extends Node3D

## Cadence (seconds) at which the grid texture is rebuilt from fog state.
const REBUILD_INTERVAL: float = 0.1

## Fraction of the owning operator's view range that a deployed drone reveals in
## the ground Fog of War (~1/4: operator 16m -> drone ~4m). This is presentation
## only: the drone's own VisionCone3D (enemy detection) is left untouched.
const DRONE_REVEAL_FRACTION: float = 0.25

## Shader applied to the fog overlay plane.
const FOG_SHADER: Shader = preload("res://modules/vision/fog_of_war.gdshader")

## The data layer driven by this display (injected by the host scene).
var fog: FogOfWar = null

## Source of operator positions/radii (injected by the host scene).
var player_manager: PlayerManager = null

## World-space bounds (X width, Z depth) of the fog floor.
var world_size: Vector2 = Vector2(72.0, 56.0)

## Height of the overlay plane above the floor (y=0).
const PLANE_HEIGHT: float = 0.02

## Root node whose MeshInstance3D descendants are the static map geometry that
## gets hidden in NEVER_EXPLORED cells (injected by the host scene; optional).
var _map_root: Node3D = null

## Static map geometry collected under _map_root, gated per-node against the
## UNION explored mask on every texture rebuild.
var _map_meshes: Array[MeshInstance3D] = []

## Monotonic UNION of every explored mask ever produced by a non-empty provider
## frame. Or-ed once per rebuild so a transient empty provider list (intro
## countdown, AI/PILOT switches) can never erase already-revealed ground.
var _accumulated_explored: PackedByteArray = PackedByteArray()

## Per-frame UNION of every vision circle fed THIS frame (operator circles + drone
## circles), regardless of player. The data layer's update_vision REPLACES a
## player's visible mask on every call, so feeding an operator and its drone for
## the same player_id would otherwise leave only the last circle visible. The
## display keeps its own frame union so all sources paint together.
var _frame_visible: PackedByteArray = PackedByteArray()

var _plane: MeshInstance3D = null
var _material: ShaderMaterial = null
var _image: Image = null
var _texture: ImageTexture = null
var _rebuild_accumulator: float = 0.0

## Builds the overlay plane and texture. Safe to call once after add_child().
## map_root (optional) is the container of the static map geometry (arena node
## in the match, MapGeometry in the sandbox); its meshes are gated by the fog.
func setup(fog_data: FogOfWar, pm: PlayerManager, bounds: Vector2, map_root: Node3D = null) -> void:
	fog = fog_data
	player_manager = pm
	world_size = bounds
	_map_root = map_root
	_build_plane()
	_init_fog_buffers()
	_collect_map_meshes()

## (Re)initializes the persistent explored accumulation and the per-frame visible
## union to the current grid size.
func _init_fog_buffers() -> void:
	_accumulated_explored = PackedByteArray()
	_frame_visible = PackedByteArray()
	if fog != null:
		var cell_count: int = fog.grid_cols * fog.grid_rows
		_accumulated_explored.resize(cell_count)
		_frame_visible.resize(cell_count)

func _build_plane() -> void:
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = world_size
	_plane = MeshInstance3D.new()
	_plane.mesh = plane_mesh
	_plane.position = Vector3(0.0, PLANE_HEIGHT, 0.0)
	add_child(_plane)

	_material = ShaderMaterial.new()
	_material.shader = FOG_SHADER
	_plane.material_override = _material

	# Grid-sized RGBA texture. R = explored, G = visible, B/A unused.
	if fog != null:
		_image = Image.create(fog.grid_cols, fog.grid_rows, false, Image.FORMAT_RGBA8)
		_image.fill(Color(0.0, 0.0, 0.0, 1.0))
		_texture = ImageTexture.create_from_image(_image)
		_material.set_shader_parameter("fog_map", _texture)

func _physics_process(delta: float) -> void:
	if fog == null or player_manager == null:
		return
	if not _is_fog_enabled():
		_plane.visible = false
		_show_all_map_geometry()
		return
	_plane.visible = true
	_apply_settings_uniforms()

	# Feed every human operator's current reveal circle into the data layer AND
	# into this frame's visible union. Map exploration radius is the operator's
	# reveal_radius (persistent ground fog), NOT vision_cone.view_range (transient
	# enemy detection).
	var active_ids: Array[int] = []
	_frame_visible.fill(0)
	for op: OperatorBase in player_manager.get_all_operators():
		if op == null or op.is_ai_controlled:
			continue
		_feed_circle(op.player_id, op.global_position, op.reveal_radius)
		if not active_ids.has(op.player_id):
			active_ids.append(op.player_id)

	# Every deployed drone also reveals a small circle of terrain (~1/4 of its
	# owner's reveal radius) through Fog of War, credited to the owner's
	# player_id. Enemy detection is NOT touched: the drone's VisionCone3D
	# continues to drive SquadVisionRegistry under the existing detection/LoS rules.
	_feed_drone_vision()

	# Rebuild the texture on a cadence, not every frame. The current-frame UNION
	# of active providers is OR-ed into the persistent accumulated explored mask,
	# so a frame with no human providers (intro/AI/PILOT transitions) can never
	# collapse already-revealed ground geometry. The visible tier is painted from
	# the display's own frame union so operator + drone circles for the same
	# player both stay visible together.
	_rebuild_accumulator += delta
	if _rebuild_accumulator >= REBUILD_INTERVAL:
		_rebuild_accumulator = 0.0
		var masks: Array = _compute_union_masks(active_ids)
		_accumulate_explored(masks[0] as PackedByteArray)
		_paint_masks([_accumulated_explored, _frame_visible])
		_gate_map_geometry(_accumulated_explored)

## Feeds every deployed drone's small terrain-reveal circle into the data layer
## and the frame-visible union, credited to the owning operator's player_id. Only
## human-owned drones reveal (AI operators already skip vision feeding above). The
## drone's VisionCone3D is deliberately not read here: detection keeps its own
## rules via the registry.
func _feed_drone_vision() -> void:
	if fog == null or get_tree() == null:
		return
	for node: Node in get_tree().get_nodes_in_group("drones"):
		var d: DroneBase = node as DroneBase
		if d == null or not is_instance_valid(d) or d.is_queued_for_deletion():
			continue
		if d.operator == null or d.operator.is_ai_controlled:
			continue
		_feed_circle(d.operator.player_id, d.global_position, d.operator.reveal_radius * DRONE_REVEAL_FRACTION)

## Feeds one vision circle for `player_id` into the data layer (persistent
## explored + per-player visible) AND into this frame's visible union. The two
## must stay in sync: the data layer's update_vision REPLACES a player's visible
## mask on every call, so a player fed by both its operator circle and its drone
## circle would otherwise end up showing only the last circle. The frame union
## keeps every source visible together.
func _feed_circle(player_id: int, world_pos: Vector3, radius: float) -> void:
	if fog == null:
		return
	fog.update_vision(player_id, world_pos, radius)
	if _frame_visible.size() == fog.grid_cols * fog.grid_rows:
		_fill_circle_into(_frame_visible, world_pos, radius)

## Fills every grid cell within `radius` meters of `world_pos` (X/Z only) with 1.
## Mirrors FogOfWar.update_vision's circle geometry for the display's own frame
## visible union (the data layer is not modified).
func _fill_circle_into(mask: PackedByteArray, world_pos: Vector3, radius: float) -> void:
	var r_cells: int = maxi(int(ceilf(radius / fog.cell_size)), 0)
	var center: Vector2i = fog._world_to_cell(world_pos)
	var r2: float = radius * radius
	for row: int in range(maxi(center.y - r_cells, 0), mini(center.y + r_cells + 1, fog.grid_rows)):
		var cz: float = fog._cell_center_z(row)
		for col: int in range(maxi(center.x - r_cells, 0), mini(center.x + r_cells + 1, fog.grid_cols)):
			var cx: float = fog._cell_center_x(col)
			var dx: float = cx - world_pos.x
			var dz: float = cz - world_pos.z
			if dx * dx + dz * dz <= r2:
				mask[row * fog.grid_cols + col] = 1

## Computes the UNION explored/visible bitmasks (decision #1) once per rebuild
## so both the overlay painting and the geometry gating share the same result.
func _compute_union_masks(active_ids: Array[int]) -> Array:
	var union_explored: PackedByteArray = PackedByteArray()
	var union_visible: PackedByteArray = PackedByteArray()
	var cell_count: int = fog.grid_cols * fog.grid_rows
	union_explored.resize(cell_count)
	union_visible.resize(cell_count)
	for p: int in active_ids:
		var pe: PackedByteArray = fog.get_explored_mask(p)
		var pv: PackedByteArray = fog.get_visible_mask(p)
		if pe.size() != cell_count or pv.size() != cell_count:
			continue
		for i: int in range(cell_count):
			if pe[i] == 1:
				union_explored[i] = 1
			if pv[i] == 1:
				union_visible[i] = 1
	return [union_explored, union_visible]

## ORs a freshly computed current-frame explored union into the persistent
## accumulated mask. Guards against size changes (new grid) by ignoring frames
## whose layout does not match the current FogOfWar.
func _accumulate_explored(union_explored: PackedByteArray) -> void:
	if union_explored.size() != _accumulated_explored.size():
		return
	for i: int in range(union_explored.size()):
		if union_explored[i] == 1:
			_accumulated_explored[i] = 1

## Paints the union fog state (decision #1) into the grid texture. Exploration is
## accumulated across frames: an empty active_ids list paints the previously
## explored ground (R) without any current visibility (G), never all-black.
func _paint_texture(active_ids: Array[int]) -> void:
	var masks: Array = _compute_union_masks(active_ids)
	_accumulate_explored(masks[0] as PackedByteArray)
	_paint_masks([_accumulated_explored, masks[1] as PackedByteArray])

## Paints an already-computed union mask pair into the grid texture.
func _paint_masks(masks: Array) -> void:
	if _image == null or fog == null:
		return
	var union_explored: PackedByteArray = masks[0] as PackedByteArray
	var union_visible: PackedByteArray = masks[1] as PackedByteArray
	for row: int in range(fog.grid_rows):
		for col: int in range(fog.grid_cols):
			var idx: int = row * fog.grid_cols + col
			var r: float = 1.0 if union_explored[idx] == 1 else 0.0
			var g: float = 1.0 if union_visible[idx] == 1 else 0.0
			_image.set_pixel(col, row, Color(r, g, 0.0, 1.0))
	_texture.update(_image)

## Collects the static map geometry under _map_root: every MeshInstance3D
## descendant except the terrain Ground (the fog plane already shades the
## floor). Runs once at setup; geometry is static in both match and sandbox.
func _collect_map_meshes() -> void:
	_map_meshes.clear()
	if _map_root == null:
		return
	for child: Node in _map_root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi == null:
			continue
		var parent: Node = mi.get_parent()
		if parent != null and parent.name == "Ground":
			continue
		_map_meshes.append(mi)

## Hides every map mesh whose world footprint lies entirely in NEVER_EXPLORED
## cells of the UNION explored mask. A mesh stays visible as soon as ANY cell of
## its footprint is explored, so explored geometry is never taken away.
func _gate_map_geometry(union_explored: PackedByteArray) -> void:
	for mi: MeshInstance3D in _map_meshes:
		mi.visible = _mesh_overlaps_explored(mi, union_explored)

## Restores every gated mesh (used when fog of war is disabled).
func _show_all_map_geometry() -> void:
	for mi: MeshInstance3D in _map_meshes:
		mi.visible = true

## Samples the mesh's world AABB corners (projected to the XZ floor) against
## the explored mask. Any explored corner keeps the whole mesh visible.
func _mesh_overlaps_explored(mi: MeshInstance3D, union_explored: PackedByteArray) -> bool:
	var local: AABB = mi.get_aabb()
	if local.size.x <= 0.0 or local.size.z <= 0.0:
		return false
	var t: Transform3D = mi.global_transform
	var corners: Array[Vector3] = [
		t * Vector3(local.position.x, 0.0, local.position.z),
		t * Vector3(local.position.x, 0.0, local.end.z),
		t * Vector3(local.end.x, 0.0, local.position.z),
		t * Vector3(local.end.x, 0.0, local.end.z),
		t * Vector3((local.position.x + local.end.x) * 0.5, 0.0, (local.position.z + local.end.z) * 0.5),
	]
	for c: Vector3 in corners:
		if _world_is_explored(c, union_explored):
			return true
	return false

## Maps a world position to the grid cell and checks the explored bit.
func _world_is_explored(world: Vector3, union_explored: PackedByteArray) -> bool:
	var half_x: float = world_size.x * 0.5
	var half_z: float = world_size.y * 0.5
	var col: int = int(floorf((world.x + half_x) / fog.cell_size))
	var row: int = int(floorf((world.z + half_z) / fog.cell_size))
	if col < 0 or col >= fog.grid_cols or row < 0 or row >= fog.grid_rows:
		return false
	return union_explored[row * fog.grid_cols + col] == 1

## Reads the GameSettings autoload at runtime (never a hard dependency).
func _settings_node() -> Node:
	if get_tree() == null:
		return null
	return get_tree().root.get_node_or_null("GameSettings")

func _is_fog_enabled() -> bool:
	var gs: Node = _settings_node()
	if gs == null:
		return true
	return bool(gs.get("fog_of_war_enabled"))

func _apply_settings_uniforms() -> void:
	if _material == null:
		return
	var gs: Node = _settings_node()
	if gs == null:
		return
	_material.set_shader_parameter("explored_brightness", float(gs.get("fog_explored_brightness")))
	_material.set_shader_parameter("visible_brightness", float(gs.get("fog_visible_brightness")))
	_material.set_shader_parameter("edge_softness", float(gs.get("fog_edge_softness")))