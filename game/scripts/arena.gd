# arena.gd
# Technical Rationale: ARENA-01 "Core Arena" (Arena Reconstruction v2).
# Pure layout container rebuilt from the Arena 01 Level Design Document.
# The Arena ONLY holds terrain, obstacles, spawn rooms, terminals, sponsors,
# recharge points and decoration. All match logic lives in the Match scene,
# which dynamically loads an arena instance.
# LDD layout: 9 sectors (REDLINE/NOVA/VORTEX/ECLIPSE + spawn zones + terminals),
# hexagonal spawn rooms with 3 holographic team doors, open sponsor cubicles,
# cold abandoned-military visual style. Cover/bush layout is preserved exactly.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name Arena
extends Node3D

## Identifier shown by the Match (and debugging/tests).
@export var arena_display_name: String = "ARENA-ALPHA"

## Horizontal footprint of the playable floor (X width, Z depth).
@export var bounds_size: Vector2 = Vector2(72.0, 56.0)

## World groups used to discover POIs from the Match and from tests.
const GROUP_SPAWN_POINTS: String = "spawn_points"
const GROUP_TERMINAL_IA: String = "terminal_ia"
const GROUP_RECHARGE_POINTS: String = "recharge_points"
const GROUP_SPONSORS: String = "sponsors"
const GROUP_COVERS: String = "paintball_covers"
const GROUP_BUSHES: String = "bushes"

## LDD spawn zone identities: north = "Spawn Azul", south = "Spawn Rojo".
const TEAM_COLOR_BLUE: Color = Color(0.2, 0.55, 1.0)
const TEAM_COLOR_RED: Color = Color(1.0, 0.25, 0.2)

## Sponsor brand accents (REDLINE / NOVA / VORTEX / ECLIPSE).
const SPONSOR_REDLINE: Color = Color(0.85, 0.16, 0.2)
const SPONSOR_NOVA: Color = Color(0.1, 0.62, 0.95)
const SPONSOR_VORTEX: Color = Color(0.62, 0.25, 0.85)
const SPONSOR_ECLIPSE: Color = Color(0.9, 0.68, 0.15)

## Cover palette in the abandoned-military style (desaturated: rust, gunmetal,
## brick, olive, sand). Layout-only; the 30 cover objects keep their exact
## positions and sizes from the previous sprint.
const COVER_COLORS: Array[Color] = [
	Color(0.58, 0.36, 0.2),  # rust
	Color(0.32, 0.42, 0.5),  # gunmetal blue
	Color(0.5, 0.26, 0.24),  # brick
	Color(0.42, 0.46, 0.3),  # olive
	Color(0.62, 0.56, 0.4),  # sand
]

var _ground: StaticBody3D = null
var _spawn_markers: Array[Marker3D] = []
var _terminal_nodes: Array[Node3D] = []
var _recharge_nodes: Array[Node3D] = []
var _sponsor_nodes: Array[Node3D] = []

func _ready() -> void:
	_build_terrain()
	_build_boundary_walls()
	_build_paintball_covers()
	_build_bushes()
	_build_terminals()
	_build_recharge_points()
	_build_sponsors()
	_build_spawn_rooms()
	_build_spawn_points()
	_build_accent_lights()
	print("[Arena] %s built. Spawns=%d Terminals=%d Recharge=%d Sponsors=%d Covers=%d Bushes=%d" % [
		arena_display_name,
		_spawn_markers.size(),
		_terminal_nodes.size(),
		_recharge_nodes.size(),
		_sponsor_nodes.size(),
		get_tree().get_nodes_in_group(GROUP_COVERS).size(),
		get_tree().get_nodes_in_group(GROUP_BUSHES).size()
	])

## ──────────────────────────────────────────────
## WORLD DISCOVERY API (used by Match + tests)
## ──────────────────────────────────────────────

func get_spawn_points() -> Array[Marker3D]:
	return _spawn_markers.duplicate()

func get_terminal_nodes() -> Array[Node3D]:
	return _terminal_nodes.duplicate()

func get_recharge_points() -> Array[Node3D]:
	return _recharge_nodes.duplicate()

func get_sponsors() -> Array[Node3D]:
	return _sponsor_nodes.duplicate()

func get_cover_count() -> int:
	return get_tree().get_nodes_in_group(GROUP_COVERS).size()

func get_bush_count() -> int:
	return get_tree().get_nodes_in_group(GROUP_BUSHES).size()

## Center of the playable floor (Terminal IA A) — used by the intro camera.
func get_arena_center() -> Vector3:
	return Vector3(0.0, 0.0, 0.0)

## Attackers spawn focus (bottom side, +Z) used by the intro zoom.
func get_attackers_spawn_focus() -> Vector3:
	return Vector3(0.0, 0.0, bounds_size.y * 0.45)

## ──────────────────────────────────────────────
## CONSTRUCTION — TERRAIN & BOUNDARY
## ──────────────────────────────────────────────

func _build_terrain() -> void:
	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	ground.position = Vector3(0.0, -0.5, 0.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(bounds_size.x, 1.0, bounds_size.y)
	shape.shape = box
	ground.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var ground_mesh: BoxMesh = BoxMesh.new()
	ground_mesh.size = Vector3(bounds_size.x, 1.0, bounds_size.y)
	ground_mesh.material = _concrete_material()
	mesh.mesh = ground_mesh
	ground.add_child(mesh)
	add_child(ground)
	_ground = ground

## Invisible boundary walls so operators cannot fall off the floor.
func _build_boundary_walls() -> void:
	var half_x: float = bounds_size.x * 0.5
	var half_z: float = bounds_size.y * 0.5
	var h: float = 4.0
	var t: float = 0.5
	var configs: Array = [
		[Vector3(0.0, h * 0.5, half_z), Vector3(bounds_size.x, h, t)],
		[Vector3(0.0, h * 0.5, -half_z), Vector3(bounds_size.x, h, t)],
		[Vector3(half_x, h * 0.5, 0.0), Vector3(t, h, bounds_size.y)],
		[Vector3(-half_x, h * 0.5, 0.0), Vector3(t, h, bounds_size.y)],
	]
	for cfg: Array in configs:
		var wall: StaticBody3D = StaticBody3D.new()
		wall.position = cfg[0] as Vector3
		var wall_shape: CollisionShape3D = CollisionShape3D.new()
		var wall_box: BoxShape3D = BoxShape3D.new()
		wall_box.size = cfg[1] as Vector3
		wall_shape.shape = wall_box
		wall.add_child(wall_shape)
		var wall_mesh: MeshInstance3D = MeshInstance3D.new()
		var wm: BoxMesh = BoxMesh.new()
		wm.size = cfg[1] as Vector3
		wm.material = _steel_material()
		wall_mesh.mesh = wm
		wall.add_child(wall_mesh)
		add_child(wall)

## ──────────────────────────────────────────────
## CONSTRUCTION — COVERS & BUSHES (UNCHANGED LAYOUT)
## ──────────────────────────────────────────────

## Covers keep their exact positions and sizes (LDD: do not add/remove/move/
## rotate any cover). Only the material moved to the military palette.
func _build_paintball_covers() -> void:
	var covers: Array = [
		# Spawn protection clusters (attackers bottom / defenders top)
		[Vector3(-6.0, 0.6, 19.0), Vector3(2.4, 1.2, 1.0), 0],
		[Vector3(6.0, 0.6, 19.0), Vector3(2.4, 1.2, 1.0), 1],
		[Vector3(-6.0, 0.6, -19.0), Vector3(2.4, 1.2, 1.0), 0],
		[Vector3(6.0, 0.6, -19.0), Vector3(2.4, 1.2, 1.0), 1],

		# Center ring around Terminal A
		[Vector3(5.0, 0.6, 4.0), Vector3(2.0, 1.2, 1.0), 2],
		[Vector3(-5.0, 0.6, 4.0), Vector3(2.0, 1.2, 1.0), 2],
		[Vector3(5.0, 0.6, -4.0), Vector3(2.0, 1.2, 1.0), 3],
		[Vector3(-5.0, 0.6, -4.0), Vector3(2.0, 1.2, 1.0), 3],

		# Central route chokepoint (medium covers guarding the approach to A)
		[Vector3(0.0, 1.0, 9.0), Vector3(1.4, 2.0, 1.0), 1],
		[Vector3(0.0, 1.0, -9.0), Vector3(1.4, 2.0, 1.0), 1],

		# Midfield cover rows (attacker half)
		[Vector3(-10.0, 0.6, 12.0), Vector3(3.0, 1.2, 0.9), 4],
		[Vector3(10.0, 0.6, 12.0), Vector3(3.0, 1.2, 0.9), 4],
		[Vector3(-2.0, 0.6, 13.0), Vector3(2.0, 1.2, 0.9), 0],
		[Vector3(2.0, 0.6, 13.0), Vector3(2.0, 1.2, 0.9), 0],

		# Midfield cover rows (defender half)
		[Vector3(-10.0, 0.6, -12.0), Vector3(3.0, 1.2, 0.9), 3],
		[Vector3(10.0, 0.6, -12.0), Vector3(3.0, 1.2, 0.9), 3],
		[Vector3(-2.0, 0.6, -13.0), Vector3(2.0, 1.2, 0.9), 2],
		[Vector3(2.0, 0.6, -13.0), Vector3(2.0, 1.2, 0.9), 2],

		# Left flank route (corridor at x ~ -28, defined by cover walls)
		[Vector3(-25.0, 1.0, -9.0), Vector3(1.0, 2.0, 3.0), 0],
		[Vector3(-25.0, 1.0, -1.0), Vector3(1.0, 2.0, 3.0), 2],
		[Vector3(-25.0, 1.0, 7.0), Vector3(1.0, 2.0, 3.0), 4],
		[Vector3(-25.0, 0.6, 15.0), Vector3(1.0, 1.2, 2.4), 1],

		# Right flank route (corridor at x ~ +28)
		[Vector3(25.0, 1.0, -9.0), Vector3(1.0, 2.0, 3.0), 1],
		[Vector3(25.0, 1.0, -1.0), Vector3(1.0, 2.0, 3.0), 3],
		[Vector3(25.0, 1.0, 7.0), Vector3(1.0, 2.0, 3.0), 0],
		[Vector3(25.0, 0.6, 15.0), Vector3(1.0, 1.2, 2.4), 4],

		# Diagonal cross routes (center-left / center-right)
		[Vector3(-15.0, 0.6, -4.0), Vector3(2.2, 1.2, 0.9), 2],
		[Vector3(15.0, 0.6, -4.0), Vector3(2.2, 1.2, 0.9), 3],
		[Vector3(-15.0, 0.6, 4.0), Vector3(2.2, 1.2, 0.9), 0],
		[Vector3(15.0, 0.6, 4.0), Vector3(2.2, 1.2, 0.9), 1],
	]

	var idx: int = 0
	for entry: Array in covers:
		var pos: Vector3 = entry[0] as Vector3
		var size: Vector3 = entry[1] as Vector3
		var color: Color = COVER_COLORS[(entry[2] as int) % COVER_COLORS.size()]
		_add_cover("Cover_%02d" % idx, pos, size, color)
		idx += 1

func _add_cover(node_name: String, pos: Vector3, size: Vector3, color: Color) -> void:
	var cover: StaticBody3D = StaticBody3D.new()
	cover.name = node_name
	cover.position = pos
	var shape: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = size
	shape.shape = box
	cover.add_child(shape)
	var mesh: MeshInstance3D = MeshInstance3D.new()
	var box_mesh: BoxMesh = BoxMesh.new()
	box_mesh.size = size
	box_mesh.material = _painted_metal_material(color)
	mesh.mesh = box_mesh
	cover.add_child(mesh)
	cover.add_to_group(GROUP_COVERS)
	add_child(cover)

## Bushes keep their exact positions (LDD: vegetation unchanged).
func _build_bushes() -> void:
	var positions: Array = [
		Vector3(-20.0, 0.0, 10.0), Vector3(20.0, 0.0, 10.0),
		Vector3(-20.0, 0.0, -10.0), Vector3(20.0, 0.0, -10.0),
		Vector3(-8.0, 0.0, 7.0), Vector3(8.0, 0.0, 7.0),
		Vector3(-8.0, 0.0, -7.0), Vector3(8.0, 0.0, -7.0),
		Vector3(-28.0, 0.0, 2.0), Vector3(28.0, 0.0, 2.0),
		Vector3(-28.0, 0.0, -2.0), Vector3(28.0, 0.0, -2.0),
		Vector3(-4.0, 0.0, 16.0), Vector3(4.0, 0.0, -16.0),
		Vector3(-13.0, 0.0, -14.0), Vector3(13.0, 0.0, 14.0),
		Vector3(-13.0, 0.0, 14.0), Vector3(13.0, 0.0, -14.0),
		Vector3(0.0, 0.0, 6.0), Vector3(0.0, 0.0, -6.0),
	]
	var idx: int = 0
	for pos: Vector3 in positions:
		var bush: MeshInstance3D = MeshInstance3D.new()
		bush.name = "Bush_%02d" % idx
		bush.position = pos + Vector3(0.0, 0.55, 0.0)
		var sphere: SphereMesh = SphereMesh.new()
		sphere.radius = 0.9
		sphere.height = 1.8
		bush.mesh = sphere
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.16, 0.4, 0.2, 0.85)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 1.0
		bush.material_override = mat
		bush.scale = Vector3(1.0 + (idx % 3) * 0.35, 1.0, 0.9 + (idx % 2) * 0.4)
		bush.add_to_group(GROUP_BUSHES)
		add_child(bush)
		idx += 1

## ──────────────────────────────────────────────
## CONSTRUCTION — TERMINALS (VISUALS + CAPTURE SYSTEM)
## ──────────────────────────────────────────────

## IA terminals keep their LDD positions (A center, B west, C east). Each
## terminal hosts an independent AICore capture system (perimeter zone, hack
## progress, state, events) and improves the visual quality: steel platform,
## glowing core, corner pillars and a cold accent light.
func _build_terminals() -> void:
	_build_terminal("TerminalIA_A", Vector3(0.0, 0.0, 0.0), "A")
	_build_terminal("TerminalIA_B", Vector3(-20.0, 0.0, 0.0), "B")
	_build_terminal("TerminalIA_C", Vector3(20.0, 0.0, 0.0), "C")

func _build_terminal(node_name: String, pos: Vector3, letter: String) -> void:
	var root_node: Node3D = Node3D.new()
	root_node.name = node_name
	root_node.position = pos

	var platform: StaticBody3D = StaticBody3D.new()
	platform.position = Vector3(0.0, 0.15, 0.0)
	var shape: CollisionShape3D = CollisionShape3D.new()
	var platform_box: BoxShape3D = BoxShape3D.new()
	platform_box.size = Vector3(5.0, 0.3, 5.0)
	shape.shape = platform_box
	platform.add_child(shape)
	var platform_mesh: MeshInstance3D = MeshInstance3D.new()
	var pbox: BoxMesh = BoxMesh.new()
	pbox.size = Vector3(5.0, 0.3, 5.0)
	pbox.material = _steel_material()
	platform_mesh.mesh = pbox
	platform.add_child(platform_mesh)
	root_node.add_child(platform)

	# Emissive core column (Terminal IA brain).
	var core: StaticBody3D = StaticBody3D.new()
	core.position = Vector3(0.0, 1.5, 0.0)
	var core_shape: CollisionShape3D = CollisionShape3D.new()
	var core_box: BoxShape3D = BoxShape3D.new()
	core_box.size = Vector3(1.8, 2.0, 1.8)
	core_shape.shape = core_box
	core.add_child(core_shape)
	var core_mesh: MeshInstance3D = MeshInstance3D.new()
	var cbox: BoxMesh = BoxMesh.new()
	cbox.size = Vector3(1.8, 2.0, 1.8)
	var cmat: StandardMaterial3D = StandardMaterial3D.new()
	cmat.albedo_color = Color(0.2, 0.62, 0.78)
	cmat.emission_enabled = true
	cmat.emission = Color(0.08, 0.45, 0.6)
	cbox.material = cmat
	core_mesh.mesh = cbox
	core.add_child(core_mesh)
	root_node.add_child(core)

	# Functional capture system: one independent AICore per terminal.
	# Each core owns its own capture zone, progress, state and events.
	var ai_core: AICore = AICore.new()
	ai_core.name = "AICore_%s" % letter
	ai_core.terminal_id = "Terminal_%s" % letter
	ai_core.terminal_display_name = "TERMINAL %s" % letter
	ai_core.position = Vector3(0.0, 1.5, 0.0)
	ai_core.perimeter_size = Vector3(10.0, 3.0, 10.0)
	ai_core.build_status_display = false
	ai_core.build_core_visual = false
	root_node.add_child(ai_core)
	ai_core.bind_core_visual(core_mesh)

	# Glowing base ring.
	var ring: MeshInstance3D = MeshInstance3D.new()
	var ring_mesh: CylinderMesh = CylinderMesh.new()
	ring_mesh.top_radius = 2.6
	ring_mesh.bottom_radius = 2.6
	ring_mesh.height = 0.12
	var rmat: StandardMaterial3D = StandardMaterial3D.new()
	rmat.albedo_color = Color(0.25, 0.7, 0.85)
	rmat.emission_enabled = true
	rmat.emission = Color(0.1, 0.5, 0.65)
	ring_mesh.material = rmat
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, 0.32, 0.0)
	root_node.add_child(ring)

	# Corner pillars.
	for px: float in [-2.3, 2.3]:
		for pz: float in [-2.3, 2.3]:
			var pillar: MeshInstance3D = MeshInstance3D.new()
			var pm: BoxMesh = BoxMesh.new()
			pm.size = Vector3(0.4, 3.4, 0.4)
			pm.material = _steel_material()
			pillar.mesh = pm
			pillar.position = Vector3(px, 1.7, pz)
			root_node.add_child(pillar)

	var label: Label3D = Label3D.new()
	label.text = "TERMINAL %s" % letter
	label.position = Vector3(0.0, 3.2, 0.0)
	label.font_size = 40
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.modulate = Color(0.55, 0.9, 1.0)
	root_node.add_child(label)

	# Cold accent light.
	var light: OmniLight3D = OmniLight3D.new()
	light.position = Vector3(0.0, 3.6, 0.0)
	light.light_color = Color(0.4, 0.7, 0.95)
	light.light_energy = 2.0
	light.omni_range = 8.0
	root_node.add_child(light)

	root_node.add_to_group(GROUP_TERMINAL_IA)
	add_child(root_node)
	_terminal_nodes.append(root_node)

## ──────────────────────────────────────────────
## CONSTRUCTION — RECHARGE POINTS (VISUAL PASS ONLY)
## ──────────────────────────────────────────────

## PR keep their LDD positions in the mid flanks. Visual pass only.
func _build_recharge_points() -> void:
	var positions: Array[Vector3] = [
		Vector3(-14.0, 0.0, 8.0),
		Vector3(14.0, 0.0, 8.0),
	]
	for i: int in range(positions.size()):
		var pr: Node3D = Node3D.new()
		pr.name = "RechargePoint_%d" % (i + 1)
		pr.position = positions[i]
		var pad: MeshInstance3D = MeshInstance3D.new()
		var pad_mesh: CylinderMesh = CylinderMesh.new()
		pad_mesh.top_radius = 1.5
		pad_mesh.bottom_radius = 1.5
		pad_mesh.height = 0.12
		var mat: StandardMaterial3D = StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.7, 0.45)
		mat.emission_enabled = true
		mat.emission = Color(0.1, 0.55, 0.3)
		pad_mesh.material = mat
		pad.mesh = pad_mesh
		pad.position = Vector3(0.0, 0.06, 0.0)
		pr.add_child(pad)
		# Soft upward light pillar.
		var pillar: MeshInstance3D = MeshInstance3D.new()
		var cyl: CylinderMesh = CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.55
		cyl.height = 2.6
		var pmat: StandardMaterial3D = StandardMaterial3D.new()
		pmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		pmat.albedo_color = Color(0.2, 0.8, 0.5, 0.3)
		pmat.emission_enabled = true
		pmat.emission = Color(0.1, 0.6, 0.35)
		cyl.material = pmat
		pillar.mesh = cyl
		pillar.position = Vector3(0.0, 1.3, 0.0)
		pr.add_child(pillar)
		var label: Label3D = Label3D.new()
		label.text = "PR"
		label.position = Vector3(0.0, 2.9, 0.0)
		label.font_size = 32
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.outline_size = 6
		label.modulate = Color(0.4, 1.0, 0.7)
		pr.add_child(label)
		var light: OmniLight3D = OmniLight3D.new()
		light.position = Vector3(0.0, 1.6, 0.0)
		light.light_color = Color(0.3, 0.9, 0.6)
		light.light_energy = 1.6
		light.omni_range = 5.0
		pr.add_child(light)
		pr.add_to_group(GROUP_RECHARGE_POINTS)
		add_child(pr)
		_recharge_nodes.append(pr)

## ──────────────────────────────────────────────
## CONSTRUCTION — SPONSORS (OPEN CUBICLES)
## ──────────────────────────────────────────────

## LDD: one sponsor per corner sector (NW=REDLINE, NE=NOVA, SW=VORTEX,
## SE=ECLIPSE). Every cubicle is an identical OPEN structure (no enclosing
## walls) with the sponsor sign integrated in the upper interior wall that
## faces the arena — never a floating billboard. The four are symmetric.
func _build_sponsors() -> void:
	var configs: Array = [
		["Sponsor_REDLINE", Vector3(-30.0, 0.0, -22.0), SPONSOR_REDLINE],
		["Sponsor_NOVA", Vector3(30.0, 0.0, -22.0), SPONSOR_NOVA],
		["Sponsor_VORTEX", Vector3(-30.0, 0.0, 22.0), SPONSOR_VORTEX],
		["Sponsor_ECLIPSE", Vector3(30.0, 0.0, 22.0), SPONSOR_ECLIPSE],
	]
	for cfg: Array in configs:
		_build_sponsor_cubicle(cfg[0] as String, cfg[1] as Vector3, cfg[2] as Color)

func _build_sponsor_cubicle(node_name: String, pos: Vector3, brand_color: Color) -> void:
	var sponsor: Node3D = Node3D.new()
	sponsor.name = node_name
	sponsor.position = pos
	add_child(sponsor)
	_sponsor_nodes.append(sponsor)
	sponsor.add_to_group(GROUP_SPONSORS)

	var size_x: float = 8.0
	var size_z: float = 6.0
	var wall_height: float = 3.6

	# Floor slab + collider.
	var floor_body: StaticBody3D = StaticBody3D.new()
	floor_body.position = Vector3(0.0, 0.15, 0.0)
	var fc: CollisionShape3D = CollisionShape3D.new()
	var fbox: BoxShape3D = BoxShape3D.new()
	fbox.size = Vector3(size_x, 0.3, size_z)
	fc.shape = fbox
	floor_body.add_child(fc)
	sponsor.add_child(floor_body)
	var floor_mesh: MeshInstance3D = MeshInstance3D.new()
	var fm: BoxMesh = BoxMesh.new()
	fm.size = Vector3(size_x, 0.3, size_z)
	fm.material = _concrete_material()
	floor_mesh.mesh = fm
	floor_mesh.position = Vector3(0.0, 0.15, 0.0)
	sponsor.add_child(floor_mesh)

	# Corner posts (keep the cubicle open / without enclosing walls).
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post: MeshInstance3D = MeshInstance3D.new()
			var pmesh: BoxMesh = BoxMesh.new()
			pmesh.size = Vector3(0.4, wall_height, 0.4)
			pmesh.material = _steel_material()
			post.mesh = pmesh
			post.position = Vector3(sx * (size_x * 0.5 - 0.2), wall_height * 0.5, sz * (size_z * 0.5 - 0.2))
			sponsor.add_child(post)

	# Interior wall facing the arena center, with the integrated sponsor sign.
	var face_dir: Vector3 = Vector3(-pos.x, 0.0, -pos.z).normalized()
	var wall_center: Vector3 = face_dir * (minf(size_x, size_z) * 0.5 - 0.2)
	var wall_length: float = 4.6
	_add_sponsor_wall(sponsor, wall_center, face_dir, wall_length, wall_height, brand_color, node_name.replace("Sponsor_", ""))

func _add_sponsor_wall(parent: Node, wall_center: Vector3, face_dir: Vector3, length: float, height: float, brand_color: Color, label_text: String) -> void:
	# Tangent direction perpendicular to face_dir (horizontal).
	var tangent: Vector3 = Vector3(-face_dir.z, 0.0, face_dir.x)
	var wall_body: StaticBody3D = StaticBody3D.new()
	wall_body.position = wall_center + Vector3(0.0, height * 0.5, 0.0)
	wall_body.rotation.y = atan2(-tangent.z, tangent.x)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(length, height, 0.3)
	col.shape = box
	wall_body.add_child(col)
	parent.add_child(wall_body)

	var wall_mesh: MeshInstance3D = MeshInstance3D.new()
	var wm: BoxMesh = BoxMesh.new()
	wm.size = Vector3(length, height, 0.3)
	wm.material = _steel_material()
	wall_mesh.mesh = wm
	wall_body.add_child(wall_mesh)

	# Integrated sign panel on the upper interior face (never floating).
	var sign: MeshInstance3D = MeshInstance3D.new()
	var sign_box: BoxMesh = BoxMesh.new()
	sign_box.size = Vector3(length - 0.6, 1.0, 0.06)
	var smat: StandardMaterial3D = StandardMaterial3D.new()
	smat.albedo_color = brand_color.darkened(0.35)
	smat.emission_enabled = true
	smat.emission = brand_color * 0.85
	sign_box.material = smat
	sign.mesh = sign_box
	var sign_local: Vector3 = wall_center + face_dir * 0.21 + Vector3(0.0, height * 0.55, 0.0)
	sign.position = sign_local
	sign.rotation.y = atan2(-face_dir.z, face_dir.x)
	parent.add_child(sign)

	var label: Label3D = Label3D.new()
	label.text = label_text
	label.font_size = 34
	label.outline_size = 8
	label.modulate = Color(0.95, 0.97, 1.0)
	label.position = sign_local + face_dir * 0.06
	label.rotation.y = atan2(-face_dir.z, face_dir.x)
	parent.add_child(label)

	var light: OmniLight3D = OmniLight3D.new()
	light.position = wall_center + Vector3(0.0, 2.4, 0.0)
	light.light_color = brand_color
	light.light_energy = 1.4
	light.omni_range = 7.0
	parent.add_child(light)

## ──────────────────────────────────────────────
## CONSTRUCTION — HEXAGONAL SPAWN ROOMS
## ──────────────────────────────────────────────

## LDD: hexagonal spawn rooms at the northern and southern extremes. Each room
## has exactly three accesses (front + left + right). Every access is closed by
## a PERMANENT team-colored energy barrier: the owning team passes through
## freely (both ways) while the enemy team is physically blocked. Each room also
## hosts a SpawnZone that grants the owning team spawn protection while inside.
func _build_spawn_rooms() -> void:
	var radius: float = 5.0
	# North room (Spawn Azul, attackers team 0): front barrier faces the arena center.
	_build_spawn_room("SpawnRoom_North", Vector3(0.0, 0.0, 23.0), radius, OperatorBase.TEAM_ATTACKERS, TEAM_COLOR_BLUE, {
		"front": 4,
		"left": 3,
		"right": 5,
		"solid": [0, 1, 2],
	})
	# South room (Spawn Rojo, defenders team 1): front barrier faces the arena center.
	_build_spawn_room("SpawnRoom_South", Vector3(0.0, 0.0, -23.0), radius, OperatorBase.TEAM_DEFENDERS, TEAM_COLOR_RED, {
		"front": 1,
		"left": 2,
		"right": 0,
		"solid": [3, 4, 5],
	})

func _build_spawn_room(node_name: String, center: Vector3, radius: float, team_id: int, team_color: Color, layout: Dictionary) -> void:
	var root: Node3D = Node3D.new()
	root.name = node_name
	root.position = center
	add_child(root)

	# Spawn protection volume for the owning team (pure geometry, no Area3D).
	var zone: SpawnZone = SpawnZone.new()
	zone.name = "SpawnZone"
	zone.team_id = team_id
	zone.protection_radius = radius
	root.add_child(zone)

	# Floor disc so the room reads as an interior space.
	var floor: MeshInstance3D = MeshInstance3D.new()
	var floor_mesh: CylinderMesh = CylinderMesh.new()
	floor_mesh.top_radius = radius * 0.9
	floor_mesh.bottom_radius = radius * 0.9
	floor_mesh.height = 0.1
	floor_mesh.material = _concrete_material()
	floor.mesh = floor_mesh
	floor.position = Vector3(0.0, 0.05, 0.0)
	root.add_child(floor)

	var verts: Array[Vector3] = _hex_vertices(radius)
	var edges: Array[Array] = [
		[verts[0], verts[1]],
		[verts[1], verts[2]],
		[verts[2], verts[3]],
		[verts[3], verts[4]],
		[verts[4], verts[5]],
		[verts[5], verts[0]],
	]

	for i: int in layout["solid"]:
		_add_hex_wall(root, edges[i][0], edges[i][1], 3.0, 0.4, _steel_material())

	var door_edges: Dictionary = {
		"front": layout["front"],
		"left": layout["left"],
		"right": layout["right"],
	}
	for key: String in door_edges:
		var edge_idx: int = door_edges[key]
		_add_energy_barrier(root, edges[edge_idx][0], edges[edge_idx][1], team_id, "Barrier_%s" % key.to_upper())

func _hex_vertices(radius: float) -> Array[Vector3]:
	var verts: Array[Vector3] = []
	for i: int in range(6):
		var a: float = deg_to_rad(60.0 * i)
		verts.append(Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	return verts

func _add_hex_wall(parent: Node, a: Vector3, b: Vector3, height: float, thickness: float, material: Material) -> void:
	var mid: Vector3 = (a + b) * 0.5
	var dir: Vector3 = b - a
	var length: float = dir.length()
	var wall: StaticBody3D = StaticBody3D.new()
	wall.position = mid + Vector3(0.0, height * 0.5, 0.0)
	wall.rotation.y = atan2(-dir.z, dir.x)
	var col: CollisionShape3D = CollisionShape3D.new()
	var box: BoxShape3D = BoxShape3D.new()
	box.size = Vector3(length, height, thickness)
	col.shape = box
	wall.add_child(col)
	var wall_mesh: MeshInstance3D = MeshInstance3D.new()
	var wm: BoxMesh = BoxMesh.new()
	wm.size = Vector3(length, height, thickness)
	wm.material = material
	wall_mesh.mesh = wm
	wall.add_child(wall_mesh)
	parent.add_child(wall)

## Places a permanent team energy barrier across one hex edge (spawn access).
## The barrier owns its collision layer bit; operators' per-team collision masks
## decide passage (own team passes, enemy blocked). Always visible/active.
func _add_energy_barrier(parent: Node, a: Vector3, b: Vector3, team_id: int, barrier_name: String) -> void:
	var mid: Vector3 = (a + b) * 0.5
	var dir: Vector3 = b - a
	var barrier: EnergyBarrier = EnergyBarrier.new()
	barrier.name = barrier_name
	barrier.team_id = team_id
	barrier.barrier_size = Vector2(dir.length(), 3.0)
	barrier.position = mid + Vector3(0.0, 1.5, 0.0)
	barrier.rotation.y = atan2(-dir.z, dir.x)
	parent.add_child(barrier)

## ──────────────────────────────────────────────
## CONSTRUCTION — SPAWN MARKERS
## ──────────────────────────────────────────────

## Spawn markers sit INSIDE their hex room (never on doors). Names MUST follow
## PlayerManager's convention (Spawn_Attackers_N / Spawn_Defenders_N).
## P1/P2 (attackers) spawn at the bottom (+Z); P3/P4 (defenders) at the top (-Z).
func _build_spawn_points() -> void:
	var configs: Array = [
		["Spawn_Attackers_1", Vector3(-4.0, 0.0, 24.0)],
		["Spawn_Attackers_2", Vector3(4.0, 0.0, 24.0)],
		["Spawn_Defenders_1", Vector3(-4.0, 0.0, -24.0)],
		["Spawn_Defenders_2", Vector3(4.0, 0.0, -24.0)],
	]
	for cfg: Array in configs:
		var marker: Marker3D = Marker3D.new()
		marker.name = cfg[0] as String
		marker.position = cfg[1] as Vector3
		marker.add_to_group(GROUP_SPAWN_POINTS)
		add_child(marker)
		_spawn_markers.append(marker)

## ──────────────────────────────────────────────
## CONSTRUCTION — AMBIENT LIGHTING (cold military base)
## ──────────────────────────────────────────────

func _build_accent_lights() -> void:
	var lights: Array = [
		[Vector3(0.0, 5.0, 0.0), Color(0.5, 0.7, 0.95), 2.2, 18.0],
		[Vector3(-20.0, 4.0, 0.0), Color(0.45, 0.65, 0.9), 1.4, 10.0],
		[Vector3(20.0, 4.0, 0.0), Color(0.45, 0.65, 0.9), 1.4, 10.0],
	]
	for cfg: Array in lights:
		var light: OmniLight3D = OmniLight3D.new()
		light.position = cfg[0] as Vector3
		light.light_color = cfg[1] as Color
		light.light_energy = cfg[2] as float
		light.omni_range = cfg[3] as float
		add_child(light)

## ──────────────────────────────────────────────
## MATERIALS
## ──────────────────────────────────────────────

## Walkable terrain material: grass-like green so the arena floor reads clearly
## as open ground, distinct from the brown/gray solid structures and the colored
## covers. Used by the main ground and interior floors (spawn rooms, sponsors).
func _concrete_material() -> Material:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.52, 0.27)
	mat.roughness = 1.0
	mat.metallic = 0.0
	return mat

## Solid structure material (boundary walls, spawn-room hex walls, posts): muted
## gray-brown so buildings read as solid geometry against the green terrain.
func _steel_material() -> Material:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.37, 0.32, 0.27)
	mat.roughness = 0.85
	mat.metallic = 0.15
	return mat

func _painted_metal_material(color: Color) -> Material:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic = 0.25
	return mat
