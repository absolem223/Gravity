# test_fog_of_war_display.gd
# Technical Rationale: Headless validation of the Phase 2 FogOfWarDisplay:
# the ground plane is built with the correct size/height, the shader material is
# attached, and _paint_texture maps the FogOfWar union state into the grid
# texture correctly (visible = R+G, explored-only = R, never explored = black).
# No match, no camera, no inputs: the display is self-contained.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).
#
# Run: godot --headless --path game --script res://tests/test_fog_of_war_display.gd

extends SceneTree

var _pass_count: int = 0
var _fail_count: int = 0

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
	print("== FOG OF WAR DISPLAY TEST ==")
	var fog: FogOfWar = FogOfWar.new()
	fog.setup(Vector2(4.0, 4.0), 1.0)
	_check(fog.grid_cols == 4 and fog.grid_rows == 4,
		"display grid is 4x4 for 4x4 world @ 1m cells")

	var display: FogOfWarDisplay = FogOfWarDisplay.new()
	root.add_child(display)
	display.setup(fog, null, Vector2(4.0, 4.0))

	# 1. Plane geometry.
	_check(display.get_child_count() == 1, "display adds exactly one child (the plane)")
	var plane: MeshInstance3D = display.get_child(0) as MeshInstance3D
	_check(plane != null, "display child is a MeshInstance3D")
	_check(plane != null and plane.mesh is PlaneMesh,
		"display child uses a PlaneMesh")
	if plane != null and plane.mesh is PlaneMesh:
		var pm: PlaneMesh = plane.mesh as PlaneMesh
		_check(pm.size == Vector2(4.0, 4.0), "plane size matches world bounds (4x4)")
	_check(plane != null and is_equal_approx(plane.position.y, 0.02),
		"plane sits slightly above the floor (y=0.02)")
	_check(plane != null and plane.material_override is ShaderMaterial,
		"plane uses the fog ShaderMaterial")

	# 2. Material shader + fog_map parameter wired.
	if plane != null and plane.material_override is ShaderMaterial:
		var mat: ShaderMaterial = plane.material_override as ShaderMaterial
		_check(mat.shader != null, "fog material has a Shader assigned")
		_check(mat.get_shader_parameter("fog_map") is ImageTexture,
			"fog material fog_map parameter is an ImageTexture")

	# 3. Paint: P1 sees origin (col 2,row 2).
	fog.update_vision(1, Vector3(0.0, 0.0, 0.0), 1.0)
	display._paint_texture([1])
	var img: Image = display._image
	_check(img.get_pixel(2, 2).r > 0.5 and img.get_pixel(2, 2).g > 0.5,
		"origin cell is VISIBLE (R+G set) after P1 update")
	_check(img.get_pixel(0, 0).r < 0.5 and img.get_pixel(0, 0).g < 0.5,
		"far corner cell stays NEVER_EXPLORED (black)")
	_check(img.get_pixel(2, 0).r < 0.5 and img.get_pixel(2, 0).g < 0.5,
		"outside-radius cell stays black")

	# 4. Explored-but-not-visible: P1 moves away, origin keeps explored bit.
	fog.update_vision(1, Vector3(3.0, 0.0, 3.0), 1.0)
	display._paint_texture([1])
	_check(img.get_pixel(2, 2).r > 0.5 and img.get_pixel(2, 2).g < 0.5,
		"origin becomes EXPLORED_NOT_VISIBLE (R only) after P1 moves away")

	# 5. UNION policy: P2 explores its own far corner, union shows both areas.
	fog.update_vision(2, Vector3(1.5, 0.0, -1.5), 1.0)
	display._paint_texture([1, 2])
	_check(img.get_pixel(2, 2).r > 0.5, "union keeps P1 origin explored")
	_check(img.get_pixel(3, 0).r > 0.5, "union adds P2 explored cell (col 3,row 0)")
	_check(img.get_pixel(0, 0).r < 0.5, "unexplored corner stays black in union")

	# 6. An empty provider list must NOT erase accumulated exploration (fixes the
	# intro blackout): previously-explored ground keeps its R bit, G clears.
	display._paint_texture([])
	_check(img.get_pixel(2, 2).r > 0.5 and img.get_pixel(2, 2).g < 0.5,
		"empty active_ids keeps explored ground (R) but clears visibility (G)")

	# 7. Geometry gating: hidden in NEVER_EXPLORED, shown once any cell of the
	# footprint is explored, terrain Ground excluded from the gate list.
	var map_root: Node3D = Node3D.new()
	map_root.name = "Map"
	root.add_child(map_root)

	var ground: StaticBody3D = StaticBody3D.new()
	ground.name = "Ground"
	map_root.add_child(ground)
	var ground_mesh: MeshInstance3D = MeshInstance3D.new()
	ground_mesh.mesh = BoxMesh.new()
	ground.add_child(ground_mesh)

	var cover: StaticBody3D = StaticBody3D.new()
	cover.name = "Cover_00"
	cover.position = Vector3(1.0, 0.0, 1.0)
	map_root.add_child(cover)
	var cover_mesh: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(1.0, 1.0, 1.0)
	cover_mesh.mesh = box
	cover.add_child(cover_mesh)

	var gate: FogOfWarDisplay = FogOfWarDisplay.new()
	root.add_child(gate)
	gate.setup(fog, null, Vector2(4.0, 4.0), map_root)
	_check(gate._map_meshes.size() == 1,
		"map gate collects the cover mesh but excludes the Ground mesh")

	# Nothing explored yet: the cover must be hidden, Ground untouched.
	var empty_masks: Array = gate._compute_union_masks([])
	gate._gate_map_geometry(empty_masks[0] as PackedByteArray)
	_check(not cover_mesh.visible, "cover hidden while NEVER_EXPLORED")
	_check(ground_mesh.visible, "terrain Ground mesh stays visible")

	# Explore cell col 3,row 3 (world 1.5,1.5) which overlaps the cover footprint.
	fog.update_vision(1, Vector3(1.5, 0.0, 1.5), 0.6)
	var explored_masks: Array = gate._compute_union_masks([1])
	gate._gate_map_geometry(explored_masks[0] as PackedByteArray)
	_check(cover_mesh.visible, "cover visible once its footprint cell is explored")

	# 7b. Intro-fix regression: an empty current-frame provider list must not
	# collapse the accumulated explored mask, so already-revealed geometry stays
	# visible (the old all-zero union hid every map mesh during the intro).
	gate._paint_texture([1])
	gate._paint_texture([])
	gate._gate_map_geometry(gate._accumulated_explored)
	_check(cover_mesh.visible, "cover stays visible after empty active_ids (explored persists)")

	# Fog disabled restores all geometry.
	gate._show_all_map_geometry()
	_check(cover_mesh.visible, "show_all_map_geometry keeps the cover visible")

	# 8. Drone terrain reveal: a human-owned deployed drone credits a small
	# vision circle (~25% of the owner's REVEAL radius) to the owner's player_id;
	# AI operators' drones reveal nothing.
	var fog2: FogOfWar = FogOfWar.new()
	fog2.setup(Vector2(4.0, 4.0), 1.0)
	var disp2: FogOfWarDisplay = FogOfWarDisplay.new()
	root.add_child(disp2)
	disp2.setup(fog2, null, Vector2(4.0, 4.0))

	var drone_scene: PackedScene = load("res://scenes/drone.tscn")
	_check(drone_scene != null, "drone scene loads")

	var op_min: OperatorBase = OperatorBase.new()
	op_min.player_id = 1
	op_min.is_ai_controlled = false
	op_min.reveal_radius = 8.0
	op_min.vision_cone = VisionCone3D.new()
	op_min.vision_cone.view_range = 8.0
	# Drone adds itself to the "drones" group in _ready, but we keep it inert
	# (no physics) so it does not fly around during the headless run.
	var drone: DroneBase = drone_scene.instantiate() as DroneBase
	drone.operator = op_min
	drone.set_physics_process(false)
	drone.set_process(false)
	root.add_child(drone)
	drone.global_position = Vector3(0.0, 1.0, 0.0)
	_check(drone.is_in_group("drones"), "drone registers itself in the drones group")

	disp2._feed_drone_vision()
	var cell_x: int = int(round(0.0 / 1.0 + 2.0))
	var cell_z: int = int(round(0.0 / 1.0 + 2.0))
	_check(fog2.is_explored(1, cell_x, cell_z),
		"human drone reveals the terrain cell beneath it for player 1")
	_check(fog2.is_visible(1, cell_x, cell_z),
		"drone reveal also marks the cell as currently visible")

	# The drone reveals ~50% of the owner's REVEAL radius (drone fog reveal
	# is decoupled from detection): with owner reveal radius 8m the drone reveal
	# is 4m, so the far corner (dist ~2.8m) is explored.
	_check(fog2.is_explored(1, 0, 0),
		"drone reveal radius is ~50% of the owner's reveal radius")

	var op_ai: OperatorBase = OperatorBase.new()
	op_ai.player_id = 2
	op_ai.is_ai_controlled = true
	op_ai.vision_cone = VisionCone3D.new()
	op_ai.vision_cone.view_range = 8.0
	var drone_ai: DroneBase = drone_scene.instantiate() as DroneBase
	drone_ai.operator = op_ai
	drone_ai.set_physics_process(false)
	drone_ai.set_process(false)
	root.add_child(drone_ai)
	drone_ai.global_position = Vector3(1.0, 1.0, 0.0)
	disp2._feed_drone_vision()
	_check(not fog2.is_explored(2, 3, 2),
		"AI-owned drone does not reveal terrain through Fog of War")

	drone.queue_free()
	drone_ai.queue_free()
	disp2.queue_free()
	op_min.vision_cone.free()
	op_ai.vision_cone.free()
	op_min.free()
	op_ai.free()

	# 9. REGRESSION (Fix 5): an operator's own reveal circle AND its drone's
	# reveal circle for the SAME player_id must BOTH paint as VISIBLE. The data
	# layer's update_vision REPLACES a player's visible mask on every call, so
	# feeding the operator circle then the drone circle used to leave only the
	# drone's cells visible (the operator's own circle stayed explored-grey). The
	# display's frame-visible union keeps every source visible together.
	var fog4: FogOfWar = FogOfWar.new()
	fog4.setup(Vector2(4.0, 4.0), 1.0)
	var disp4: FogOfWarDisplay = FogOfWarDisplay.new()
	root.add_child(disp4)
	disp4.setup(fog4, null, Vector2(4.0, 4.0))
	var img4: Image = disp4._image

	# Operator at world (0,0) -> cell (2,2); drone at (1.5,1.5) -> cell (3,3),
	# which is OUTSIDE the operator's 2.0m circle (dist ~2.1m). Both are credited
	# to player 1, so this is the exact operator+drone same-player collision.
	disp4._frame_visible.fill(0)
	disp4._feed_circle(1, Vector3(0.0, 0.0, 0.0), 2.0)
	disp4._feed_circle(1, Vector3(1.5, 0.0, 1.5), 0.5)
	disp4._accumulate_explored(disp4._compute_union_masks([1])[0] as PackedByteArray)
	disp4._paint_masks([disp4._accumulated_explored, disp4._frame_visible])
	_check(img4.get_pixel(2, 2).g > 0.5,
		"operator's own reveal circle paints VISIBLE (same player as its drone)")
	_check(img4.get_pixel(3, 3).g > 0.5,
		"drone's reveal circle paints VISIBLE (same player as its operator)")

	# Drone moves away: both circles persist independently.
	disp4._frame_visible.fill(0)
	disp4._feed_circle(1, Vector3(0.0, 0.0, 0.0), 2.0)
	disp4._feed_circle(1, Vector3(-1.5, 0.0, -1.5), 0.5)
	disp4._paint_masks([disp4._accumulated_explored, disp4._frame_visible])
	_check(img4.get_pixel(2, 2).g > 0.5,
		"operator circle persists when the drone moves away")
	_check(img4.get_pixel(0, 0).g > 0.5,
		"drone circle stays visible far from the operator")

	disp4.queue_free()

	display.queue_free()
	gate.queue_free()
	map_root.queue_free()
	await physics_frame
	print("== RESULT: %d passed, %d failed ==" % [_pass_count, _fail_count])
	quit(1 if _fail_count > 0 else 0)