# test_arena_reconstruction.gd
# Arena Reconstruction v2: validates the rebuilt arena against the LDD spec and
# prints a top-down ASCII map for visual comparison with the blueprint.
extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

const CELL_M: float = 2.0
const COLS: int = 37
const ROWS: int = 29
const COL_OFFSET: int = 18
const ROW_OFFSET: int = 14

func _init() -> void:
	call_deferred("run_test")

func _check(cond: bool, label: String) -> void:
	if cond:
		_pass_count += 1
		print("  [PASS] ", label)
	else:
		_fail_count += 1
		print("  [FAIL] ", label)

func run_test() -> void:
	print("== ARENA RECONSTRUCTION TEST (LDD v1) ==")
	var arena: Arena = (load("res://scenes/arena.tscn") as PackedScene).instantiate() as Arena
	get_root().add_child(arena)
	for i: int in range(5):
		await physics_frame

	_test_layout_counts(arena)
	_test_terminal_visuals(arena)
	_test_recharge_visuals(arena)
	_test_sponsor_cubicles(arena)
	_test_spawn_rooms(arena)
	await _test_spawn_protection(arena)
	_print_ascii_map(arena)

	arena.queue_free()
	for i: int in range(3):
		await physics_frame
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)

func _test_layout_counts(arena: Arena) -> void:
	print("--- [1] Layout counts (LDD) ---")
	_check(get_nodes_in_group(Arena.GROUP_SPAWN_POINTS).size() == 4, "4 spawn points")
	_check(get_nodes_in_group(Arena.GROUP_TERMINAL_IA).size() == 3, "3 IA terminals")
	_check(get_nodes_in_group(Arena.GROUP_RECHARGE_POINTS).size() == 2, "2 recharge points")
	_check(get_nodes_in_group(Arena.GROUP_SPONSORS).size() == 4, "4 sponsor cubicles")
	_check(arena.get_cover_count() == 30, "30 covers (unchanged layout)")
	_check(arena.get_bush_count() == 20, "20 bushes (unchanged layout)")

	var terminals: Array[Node] = get_nodes_in_group(Arena.GROUP_TERMINAL_IA)
	for t: Node in terminals:
		var tn: Node3D = t as Node3D
		if t.name.ends_with("_A"):
			_check(absf(tn.global_position.x) < 2.0, "Terminal A at center")
		elif t.name.ends_with("_B"):
			_check(tn.global_position.x < 0.0, "Terminal B west")
		elif t.name.ends_with("_C"):
			_check(tn.global_position.x > 0.0, "Terminal C east")

	var recharge: Array[Node] = get_nodes_in_group(Arena.GROUP_RECHARGE_POINTS)
	for r: Node in recharge:
		_check(absf((r as Node3D).global_position.x) > 12.0 and absf((r as Node3D).global_position.z) > 6.0,
			"%s in mid flank (x=%.1f z=%.1f)" % [r.name, (r as Node3D).global_position.x, (r as Node3D).global_position.z])

	var sponsors: Array[Node] = get_nodes_in_group(Arena.GROUP_SPONSORS)
	for s: Node in sponsors:
		var sp: Node3D = s as Node3D
		_check(absf(sp.global_position.x) > 26.0 and absf(sp.global_position.z) > 18.0,
			"%s in corner sector (x=%.1f z=%.1f)" % [s.name, sp.global_position.x, sp.global_position.z])

func _find_emissive_mesh(root: Node) -> MeshInstance3D:
	for child: Node in root.get_children():
		if child is MeshInstance3D:
			var mi: MeshInstance3D = child as MeshInstance3D
			if mi.mesh != null:
				var sm: StandardMaterial3D = _get_standard_material(mi)
				if sm != null and sm.emission_enabled:
					return mi
		if child.get_child_count() > 0:
			var found: MeshInstance3D = _find_emissive_mesh(child)
			if found != null:
				return found
	return null

func _get_standard_material(mi: MeshInstance3D) -> StandardMaterial3D:
	if mi.mesh != null and mi.mesh is BoxMesh:
		var bm: BoxMesh = mi.mesh as BoxMesh
		if bm.material is StandardMaterial3D:
			return bm.material as StandardMaterial3D
	if mi.mesh != null and mi.mesh is CylinderMesh:
		var cm: CylinderMesh = mi.mesh as CylinderMesh
		if cm.material is StandardMaterial3D:
			return cm.material as StandardMaterial3D
	if mi.mesh != null and mi.mesh is SphereMesh:
		var sm: SphereMesh = mi.mesh as SphereMesh
		if sm.material is StandardMaterial3D:
			return sm.material as StandardMaterial3D
	return null

func _test_terminal_visuals(arena: Arena) -> void:
	print("--- [2] Terminal visual pass ---")
	for name: String in ["TerminalIA_A", "TerminalIA_B", "TerminalIA_C"]:
		var tn: Node3D = arena.get_node_or_null(name) as Node3D
		if tn == null:
			_check(false, "%s exists" % name)
			continue
		var has_label: bool = false
		var label_text: String = ""
		var has_light: bool = false
		var static_bodies: int = 0
		for child: Node in tn.get_children():
			if child is Label3D:
				has_label = true
				label_text = (child as Label3D).text
			elif child is OmniLight3D:
				has_light = true
			elif child is StaticBody3D:
				static_bodies += 1
		_check(has_label and label_text.begins_with("TERMINAL"), "%s has TERMINAL label ('%s')" % [name, label_text])
		_check(has_light, "%s has cold accent light" % name)
		_check(static_bodies >= 2, "%s has platform + core colliders" % name)
		_check(_find_emissive_mesh(tn) != null, "%s has emissive core" % name)

func _test_recharge_visuals(arena: Arena) -> void:
	print("--- [3] Recharge point visual pass ---")
	var nodes: Array[Node] = get_nodes_in_group(Arena.GROUP_RECHARGE_POINTS)
	for n: Node in nodes:
		var pr: Node3D = n as Node3D
		var has_label: bool = false
		var has_light: bool = false
		for child: Node in pr.get_children():
			if child is Label3D and (child as Label3D).text == "PR":
				has_label = true
			elif child is OmniLight3D:
				has_light = true
		_check(has_label, "%s has PR label" % pr.name)
		_check(has_light, "%s has light pillar light" % pr.name)
		_check(_find_emissive_mesh(pr) != null, "%s has emissive pad/pillar" % pr.name)

func _test_sponsor_cubicles(arena: Arena) -> void:
	print("--- [4] Sponsor cubicles (open, integrated sign) ---")
	var nodes: Array[Node] = get_nodes_in_group(Arena.GROUP_SPONSORS)
	var brands: Array[String] = ["REDLINE", "NOVA", "VORTEX", "ECLIPSE"]
	for n: Node in nodes:
		var sp: Node3D = n as Node3D
		var posts: int = 0
		var wall_bodies: int = 0
		var sign_found: bool = false
		var sign_y: float = 0.0
		var label_found: bool = false
		var label_text: String = ""
		var has_light: bool = false
		for child: Node in sp.get_children():
			if child is MeshInstance3D:
				var mi: MeshInstance3D = child as MeshInstance3D
				if mi.mesh is BoxMesh:
					var bm: BoxMesh = mi.mesh as BoxMesh
					if bm.size.y > 2.0:
						posts += 1
					elif bm.size.y < 1.5 and absf(bm.size.z) < 0.2:
						var sm: StandardMaterial3D = _get_standard_material(mi)
						if sm != null and sm.emission_enabled:
							sign_found = true
							sign_y = mi.global_position.y
			elif child is StaticBody3D:
				wall_bodies += 1
			elif child is Label3D:
				label_found = true
				label_text = (child as Label3D).text
			elif child is OmniLight3D:
				has_light = true
		_check(posts == 4, "%s has 4 corner posts (%d)" % [sp.name, posts])
		_check(wall_bodies >= 2, "%s has floor + interior wall" % sp.name)
		_check(sign_found and sign_y > 1.5, "%s sign integrated high on wall (y=%.1f)" % [sp.name, sign_y])
		_check(label_found and brands.has(label_text), "%s sign label '%s'" % [sp.name, label_text])
		_check(has_light, "%s brand light" % sp.name)

func _test_spawn_rooms(arena: Arena) -> void:
	print("--- [5] Hexagonal spawn rooms (walls + barriers + zone) ---")
	for name: String in ["SpawnRoom_North", "SpawnRoom_South"]:
		var room: Node3D = arena.get_node_or_null(name) as Node3D
		if room == null:
			_check(false, "%s exists" % name)
			continue
		var walls: int = 0
		var barriers: int = 0
		var zone: SpawnZone = room.get_node_or_null("SpawnZone") as SpawnZone
		for child: Node in room.get_children():
			if child is EnergyBarrier:
				barriers += 1
			elif child is StaticBody3D:
				walls += 1
		_check(walls == 3, "%s has 3 solid walls (%d)" % [name, walls])
		_check(barriers == 3, "%s has 3 energy barriers (%d)" % [name, barriers])
		var expected_team: int = OperatorBase.TEAM_ATTACKERS if name == "SpawnRoom_North" else OperatorBase.TEAM_DEFENDERS
		_check(zone != null, "%s has SpawnZone" % name)
		if zone != null:
			_check(zone.team_id == expected_team, "%s zone owns team %d" % [name, expected_team])
			_check(zone.protection_radius >= 5.0, "%s protection radius %.1f" % [name, zone.protection_radius])
			for child: Node in room.get_children():
				if child is EnergyBarrier:
					var barrier: EnergyBarrier = child as EnergyBarrier
					_check(barrier.team_id == expected_team, "%s/%s owns team %d" % [name, child.name, expected_team])
					_check(barrier.collision_layer == EnergyBarrier.barrier_collision_layer(expected_team),
						"%s/%s on layer %d" % [name, child.name, barrier.collision_layer])

func _test_spawn_protection(arena: Arena) -> void:
	print("--- [6] Spawn protection + per-team barrier mask ---")
	var north: Node3D = arena.get_node_or_null("SpawnRoom_North") as Node3D
	if north == null:
		_check(false, "SpawnRoom_North exists for protection test")
		return
	var room_center: Vector3 = north.global_position

	# Team 0 operator spawned inside its own room: invulnerable, cannot be damaged.
	var op: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	op.player_id = 5
	op.is_ai_controlled = true
	op.team_id = OperatorBase.TEAM_ATTACKERS
	op.position = room_center + Vector3(0.0, 1.5, 0.0)
	arena.add_child(op)
	for i: int in range(10):
		await physics_frame

	_check(op.is_in_spawn_zone(), "operator inside own spawn is protected")
	_check(op.collision_mask == op._team_collision_mask(op.team_id), "operator collision_mask matches team barrier mask")
	var own_layer: int = EnergyBarrier.barrier_collision_layer(OperatorBase.TEAM_ATTACKERS)
	var enemy_layer: int = EnergyBarrier.barrier_collision_layer(OperatorBase.TEAM_DEFENDERS)
	_check((op.collision_mask & own_layer) == 0, "own barrier layer NOT in mask (passes through own barrier)")
	_check((op.collision_mask & enemy_layer) != 0, "enemy barrier layer IS in mask (blocked by enemy barrier)")

	var hp_before: float = op.health_current
	op.take_damage(25.0)
	for i: int in range(3):
		await physics_frame
	_check(op.health_current == hp_before, "damage blocked while inside spawn")

	# Step outside the room: protection ends, damage applies.
	op.global_position = room_center + Vector3(0.0, 1.5, 12.0)
	for i: int in range(10):
		await physics_frame
	_check(not op.is_in_spawn_zone(), "operator outside spawn is not protected")
	op.take_damage(25.0)
	for i: int in range(3):
		await physics_frame
	_check(op.health_current == hp_before - 25.0, "damage applies outside spawn")

	# Enemy team (defenders) standing inside the attackers room is NOT protected.
	var foe: OperatorBase = preload("res://scenes/operator_placeholder.tscn").instantiate() as OperatorBase
	foe.player_id = 6
	foe.is_ai_controlled = true
	foe.team_id = OperatorBase.TEAM_DEFENDERS
	foe.position = room_center + Vector3(0.0, 1.5, 2.0)
	arena.add_child(foe)
	for i: int in range(10):
		await physics_frame
	_check(not foe.is_in_spawn_zone(), "enemy team inside foreign spawn is not protected")

	# Stop vision cones before deletion to avoid stale detection-frame crashes.
	var cone: Node3D = op.get_node_or_null("VisionCone3D") as Node3D
	if cone != null:
		cone.set_physics_process(false)
	var foe_cone: Node3D = foe.get_node_or_null("VisionCone3D") as Node3D
	if foe_cone != null:
		foe_cone.set_physics_process(false)
	op.queue_free()
	foe.queue_free()
	for i: int in range(10):
		await physics_frame

func _map_set(grid: Array[String], x: float, z: float, ch: String) -> void:
	var c: int = int(roundf(x / CELL_M)) + COL_OFFSET
	var r: int = ROW_OFFSET - int(roundf(z / CELL_M))
	if r >= 0 and r < ROWS and c >= 0 and c < COLS:
		grid[r] = grid[r].substr(0, c) + ch + grid[r].substr(c + 1)

func _map_edge(grid: Array[String], a: Vector3, b: Vector3, ch: String) -> void:
	var steps: int = int(ceil(a.distance_to(b) / CELL_M)) * 2
	for i: int in range(steps + 1):
		var t: float = float(i) / float(steps)
		_map_set(grid, lerpf(a.x, b.x, t), lerpf(a.z, b.z, t), ch)

func _rasterize_box(grid: Array[String], pos: Vector3, size: Vector3, rot_y: float, ch: String) -> void:
	var cosr: float = cos(rot_y)
	var sinr: float = sin(rot_y)
	for sx: int in [-1, 1]:
		for sz: int in [-1, 1]:
			var gx: float = pos.x + float(sx) * size.x * 0.5 * cosr + float(sz) * size.z * 0.5 * (-sinr)
			var gz: float = pos.z + float(sx) * size.x * 0.5 * sinr + float(sz) * size.z * 0.5 * cosr
			_map_set(grid, gx, gz, ch)

func _draw_hex_room(grid: Array[String], center: Vector3, solid_edges: Array[int], door_edges: Dictionary, radius: float) -> void:
	var verts: Array[Vector3] = []
	for i: int in range(6):
		var a: float = deg_to_rad(60.0 * i)
		verts.append(center + Vector3(cos(a) * radius, 0.0, sin(a) * radius))
	var edges: Array[Array] = [
		[verts[0], verts[1]],
		[verts[1], verts[2]],
		[verts[2], verts[3]],
		[verts[3], verts[4]],
		[verts[4], verts[5]],
		[verts[5], verts[0]],
	]
	for i: int in solid_edges:
		_map_edge(grid, edges[i][0], edges[i][1], "=")
	for key: String in door_edges:
		var idx: int = door_edges[key] as int
		_map_edge(grid, edges[idx][0], edges[idx][1], "D")

func _get_box_size(body: StaticBody3D) -> Vector3:
	for child: Node in body.get_children():
		if child is CollisionShape3D:
			var cs: CollisionShape3D = child as CollisionShape3D
			if cs.shape is BoxShape3D:
				return (cs.shape as BoxShape3D).size
	return Vector3(1.0, 1.0, 1.0)

func _print_ascii_map(arena: Arena) -> void:
	print("--- [7] ASCII top-down map (1 cell = 2m) ---")
	var grid: Array[String] = []
	for r: int in range(ROWS):
		var line: String = ""
		for c: int in range(COLS):
			line += "."
		grid.append(line)

	for node: Node in get_nodes_in_group(Arena.GROUP_COVERS):
		var cn: StaticBody3D = node as StaticBody3D
		if cn != null:
			_rasterize_box(grid, cn.global_position, _get_box_size(cn), cn.global_rotation.y, "#")
	for node: Node in get_nodes_in_group(Arena.GROUP_BUSHES):
		var bn: Node3D = node as Node3D
		_map_set(grid, bn.global_position.x, bn.global_position.z, "b")
	for node: Node in get_nodes_in_group(Arena.GROUP_TERMINAL_IA):
		var tn: Node3D = node as Node3D
		_map_set(grid, tn.global_position.x, tn.global_position.z, "T")
		_rasterize_box(grid, tn.global_position, Vector3(5.0, 0.3, 5.0), 0.0, "T")
	for node: Node in get_nodes_in_group(Arena.GROUP_RECHARGE_POINTS):
		var pn: Node3D = node as Node3D
		_map_set(grid, pn.global_position.x, pn.global_position.z, "P")
	for node: Node in get_nodes_in_group(Arena.GROUP_SPONSORS):
		var sn: Node3D = node as Node3D
		_rasterize_box(grid, sn.global_position, Vector3(8.0, 0.3, 6.0), 0.0, "S")
	for node: Node in get_nodes_in_group(Arena.GROUP_SPAWN_POINTS):
		var sm: Node3D = node as Node3D
		_map_set(grid, sm.global_position.x, sm.global_position.z, "*")

	var north: Node3D = arena.get_node_or_null("SpawnRoom_North") as Node3D
	var south: Node3D = arena.get_node_or_null("SpawnRoom_South") as Node3D
	if north != null:
		_draw_hex_room(grid, north.global_position, [0, 1, 2], {"front": 4, "left": 3, "right": 5}, 5.0)
	if south != null:
		_draw_hex_room(grid, south.global_position, [3, 4, 5], {"front": 1, "left": 2, "right": 0}, 5.0)

	print("legend: # cover | b bush | T terminal | P recharge | S sponsor | = wall | D barrier | * spawn")
	print("top of map = +Z (SpawnRoom_North/Azul, attackers P1-P2); bottom = -Z (SpawnRoom_South/Rojo, defenders P3-P4)")
	for line: String in grid:
		print(line)
