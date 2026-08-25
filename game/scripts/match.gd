# match.gd
# Technical Rationale: MATCH root scene (Match Flow & Arena Foundation sprint).
# The Match administers: players, teams, HUD, match time, score, GameRules and
# victory/defeat. It loads an Arena dynamically (Part 1) so match logic never
# depends on a specific map, and runs the match intro cinematic (Part 3).
# NO new combat mechanics are introduced: this is infrastructure + presentation.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name Match
extends Node3D

## ── Signals ────────────────────────────────────────────────────────────────
signal phase_changed(phase: Phase)
signal match_timer_updated(seconds_remaining: float)
signal score_changed(team_id: int, score: int)
signal match_ended(winning_team: int)
## Emitted every physics frame while a team holds ALL terminals (-1 = cancelled).
signal supremacy_changed(team_id: int, time_left: float)

## Match lifecycle phases.
enum Phase {
	LOADING,   ## Bootstrap: arena + systems initialized; brief "LOADING" splash.
	INTRO,     ## 3-2-1 countdown. Control is frozen until GO.
	LIVE,      ## Timer running, control enabled.
	MATCH_END  ## Victory/defeat resolved.
}

## Intro steps (Part 3, countdown-only). No cinematic camera / pan / mission-start
## reveal: operators are visible from the start and the shared CameraController
## frames the squad during the countdown.
enum IntroStep {
	LOADING,   ## "LOADING" splash (Phase.LOADING). Operators visible, camera active.
	COUNTDOWN, ## 3 ... 2 ... 1
	GO,        ## "GO!" — control is enabled here and only here.
	DONE
}

## Duration (sim seconds) of each intro step, indexed by IntroStep.
const INTRO_DURATIONS: Array[float] = [2.0, 3.0, 1.2]

@export_category("Match Setup")
@export_group("Arena")
## Arena scene loaded dynamically at bootstrap (Part 1).
@export var arena_scene: PackedScene = preload("res://scenes/arena.tscn")

@export_group("Rules")
## Duration of a match in seconds before the timeout winner is declared.
@export var match_duration_seconds: float = 600.0
## Winner when the clock runs out (defenders win by default: attackers must capture).
@export var timeout_winning_team: int = OperatorBase.TEAM_DEFENDERS
## Seconds a single team must hold ALL terminals to win by Supremacy.
@export var supremacy_duration: float = 30.0

@export_group("Intro (Part 3)")
## Whether the intro cinematic plays before control is enabled.
@export var intro_enabled: bool = true
## Sim-time multiplier for the intro (1.0 = realtime). Speeds tests up.
@export var intro_time_scale: float = 1.0

@onready var input_manager: InputManager = $InputManager if has_node("InputManager") else null
@onready var player_manager: PlayerManager = $PlayerManager if has_node("PlayerManager") else null
@onready var camera_controller: CameraController = $CameraController if has_node("CameraController") else null
@onready var squad_hud: SquadHUD = $SquadHUD if has_node("SquadHUD") else null
@onready var squad_vision_registry: SquadVisionRegistry = $SquadVisionRegistry if has_node("SquadVisionRegistry") else null
@onready var arena_holder: Node3D = $ArenaHolder if has_node("ArenaHolder") else null
## Fog of War overlay (Phase 2). Created lazily in _initialize_match_systems.
var fog_of_war_display: FogOfWarDisplay = null

## Loaded arena instance (Part 1).
var _arena: Arena = null
## Coordina los objetivos capturables (Terminales IA) sin lógica propia.
var _terminal_manager: TerminalManager = null
## Minimal functional AI brain driving is_ai_controlled operators.
var _ai_controller: AIController = null
## Current lifecycle phase.
var _phase: Phase = Phase.LOADING
## Seconds left on the match clock.
var _match_time_left: float = 0.0
## Scoreboard: team_id -> points.
var team_scores: Dictionary = {}

## Territory scoring: fractional seconds accumulated per team (1/2/3 terminals = +1/+2/+3 per sec).
var _territory_accumulator: Dictionary = {}

## Supremacy state: team currently holding all terminals + countdown (-1 = none).
var _supremacy_team: int = -1
var _supremacy_time_left: float = 0.0

## Intro state.
var _intro_ui: CanvasLayer = null
var _intro_label: Label = null
var _intro_step: int = IntroStep.LOADING
var _intro_elapsed: float = 0.0
var _intro_count: int = 3
## Per-player AI flag captured at intro start so control can be restored at GO.
var _op_ai_by_id: Dictionary = {}

## Match HUD (time + score + terminal states + supremacy). Separate from the combat SquadHUD.
var _match_hud: CanvasLayer = null
var _timer_label: Label = null
var _score_label: Label = null
var _supremacy_label: Label = null
var _terminal_hud_entries: Array[Dictionary] = []

func _ready() -> void:
	# Deferred bootstrap so get_tree().current_scene is already set when the
	# arena spawn markers are looked up (robust in both change_scene flow and
	# headless tests that assign current_scene after adding the node).
	call_deferred("_bootstrap_match")

## ──────────────────────────────────────────────
## BOOTSTRAP
## ──────────────────────────────────────────────

func _bootstrap_match() -> void:
	_initialize_game_rules()
	_load_arena()
	_initialize_match_systems()
	if intro_enabled:
		_start_loading()
	else:
		_start_live()
	# Temporary joystick/input diagnostic overlay (always shown).
	add_child(preload("res://scripts/runtime_input_diag.gd").new())

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

## Part 1: instantiate the configured arena under the ArenaHolder node.
func _load_arena() -> void:
	if arena_scene == null:
		push_error("[Match] No arena_scene assigned.")
		return
	var instance: Node = arena_scene.instantiate()
	if instance == null:
		push_error("[Match] Failed to instantiate arena_scene.")
		return
	instance.name = "Arena"
	var holder: Node = arena_holder if arena_holder != null else self
	holder.add_child(instance)
	_arena = instance as Arena
	if _arena != null:
		print("[Match] Arena loaded: %s" % _arena.arena_display_name)
	else:
		print("[Match] WARNING: arena root is not an Arena script.")

func _initialize_match_systems() -> void:
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

	if _terminal_manager == null:
		_terminal_manager = TerminalManager.new()
		_terminal_manager.name = "TerminalManager"
		add_child(_terminal_manager)
	## Register every AICore objective spawned by the arena (generic: any count).
	if _arena != null:
		_terminal_manager.register_all_from_group()
	## Refresh the top HUD the moment any terminal changes owner.
	_terminal_manager.terminal_ownership_changed.connect(_on_terminal_ownership_changed)

	if _ai_controller == null:
		_ai_controller = AIController.new()
		_ai_controller.name = "AIController"
		add_child(_ai_controller)
	_ai_controller.setup(self)

	# Connect signals BEFORE setup_squad so player_spawned fires with handlers attached.
	player_manager.squad_updated.connect(_on_squad_updated)
	player_manager.player_spawned.connect(_on_player_spawned)

	var enabled_ids: Array[int] = _session_enabled_player_ids()
	if enabled_ids.is_empty():
		enabled_ids = [1, 2, 3, 4]
	player_manager.setup_squad(input_manager, enabled_ids)

	if squad_hud != null:
		squad_hud.setup_hud(player_manager, input_manager, squad_vision_registry)
		squad_hud.set_terminal_manager(_terminal_manager)

	_setup_fog_of_war()

	_create_match_hud()
	_on_squad_updated(enabled_ids.size())
	var arena_name: String = _arena.arena_display_name if _arena != null else "NONE"
	print("[Match] Systems initialized. Arena=%s | Players=%d" % [arena_name, enabled_ids.size()])

## Instantiates the Fog of War overlay (Phase 2). Uses the arena bounds as the
## world grid size; the display drives the FogOfWar data from PlayerManager.
func _setup_fog_of_war() -> void:
	if fog_of_war_display != null:
		return
	var bounds: Vector2 = _arena.bounds_size if _arena != null else Vector2(72.0, 56.0)
	var fog_data: FogOfWar = FogOfWar.new()
	fog_data.setup(bounds, FogOfWar.DEFAULT_CELL_SIZE)
	fog_of_war_display = FogOfWarDisplay.new()
	fog_of_war_display.name = "FogOfWarDisplay"
	add_child(fog_of_war_display)
	fog_of_war_display.setup(fog_data, player_manager, bounds, _arena)

## ──────────────────────────────────────────────
## LIFECYCLE / PHASES
## ──────────────────────────────────────────────

func get_phase() -> Phase:
	return _phase

func is_live() -> bool:
	return _phase == Phase.LIVE

func get_arena() -> Arena:
	return _arena

func get_player_manager() -> PlayerManager:
	return player_manager

func get_camera_controller() -> CameraController:
	return camera_controller

func get_squad_hud() -> SquadHUD:
	return squad_hud

func get_terminal_manager() -> TerminalManager:
	return _terminal_manager

func get_ai_controller() -> AIController:
	return _ai_controller

func get_match_time_left() -> float:
	return _match_time_left

func get_intro_step() -> int:
	return _intro_step

func _start_live() -> void:
	_phase = Phase.LIVE
	phase_changed.emit(_phase)
	_match_time_left = match_duration_seconds
	_update_match_hud()
	print("[Match] Intro skipped. Match is live.")

func _start_loading() -> void:
	_phase = Phase.LOADING
	phase_changed.emit(_phase)

	# Freeze all operators for the entire pre-match (LOADING + COUNTDOWN), not
	# just the countdown. Capture each operator's real AI flag FIRST so control
	# is restored correctly at GO (P1-4).
	for op: OperatorBase in player_manager.get_all_operators():
		_op_ai_by_id[op.player_id] = op.is_ai_controlled
		op.is_ai_controlled = true

	# Operators stay visible and the shared gameplay camera is already live.
	if camera_controller != null and camera_controller.camera != null:
		camera_controller.camera.current = true

	_create_intro_ui()
	_intro_step = IntroStep.LOADING
	_intro_elapsed = 0.0
	_set_intro_text("LOADING", 72)
	print("[Match] Loading splash shown; countdown follows.")

func _start_intro() -> void:
	_phase = Phase.INTRO
	phase_changed.emit(_phase)

	# Freeze all operators until GO (Part 3, step 8). They stay VISIBLE: no
	# cinematic reveal needed, the shared camera already frames the squad.
	for op: OperatorBase in player_manager.get_all_operators():
		# AI flags were already captured (and operators frozen) in _start_loading.
		op.is_ai_controlled = true

	_intro_step = IntroStep.COUNTDOWN
	_intro_elapsed = 0.0
	_intro_count = 3
	_set_intro_text("3", 220)
	print("[Match] Intro countdown: 3..2..1 -> GO")

func _finish_intro() -> void:
	_phase = Phase.LIVE
	phase_changed.emit(_phase)

	if _intro_ui != null:
		_intro_ui.queue_free()
		_intro_ui = null
		_intro_label = null

	_match_time_left = match_duration_seconds
	_update_match_hud()
	print("[Match] GO — match is live. Control enabled, timer started.")

func end_match(winning_team: int) -> void:
	if _phase == Phase.MATCH_END:
		return
	_phase = Phase.MATCH_END
	phase_changed.emit(_phase)

	if player_manager != null:
		for op: OperatorBase in player_manager.get_all_operators():
			op.is_incapacitated = true
			op.velocity = Vector3.ZERO

	match_ended.emit(winning_team)
	_play_result_music(winning_team)
	print("[Match] Match ended. Winner: %s" % _team_name(winning_team))
	_show_match_end_overlay(winning_team)

## Plays the appropriate result music (VICTORY/DEFEAT/DRAW) when the match ends.
## Victory/Defeat is relative to the human-controlled operator's team; a draw
## (winning_team < 0) or an all-AI match falls back to DRAW. Reuses the existing
## MusicController (no new audio system). INTRO/COMBAT paths are untouched.
func _play_result_music(winning_team: int) -> void:
	var music: Node = get_tree().root.get_node_or_null("MusicController")
	if music == null:
		return
	var human_team: int = -1
	if player_manager != null:
		for op: OperatorBase in player_manager.get_all_operators():
			if not op.is_ai_controlled:
				human_team = op.team_id
				break
	var state: int = MusicController.State.DRAW
	if human_team >= 0:
		state = MusicController.State.VICTORY if winning_team == human_team else MusicController.State.DEFEAT
	elif winning_team < 0:
		state = MusicController.State.DRAW
	else:
		state = MusicController.State.VICTORY
	music.set_state(state, 1.5)

func _team_name(team_id: int) -> String:
	return "ATACANTES (Equipo 0)" if team_id == OperatorBase.TEAM_ATTACKERS else "DEFENSORES (Equipo 1)"

## ──────────────────────────────────────────────
## FRAME DRIVERS
## ──────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	if player_manager != null:
		var centroid: Vector3 = player_manager.get_squad_centroid()
		for op: OperatorBase in player_manager.get_all_operators():
			op.update_squad_separation(centroid)

	match _phase:
		Phase.LOADING:
			_process_loading(delta)
		Phase.INTRO:
			_process_intro(delta)
		Phase.LIVE:
			_update_match_timer(delta)
			_update_territory_scoring(delta)
			_update_supremacy(delta)

## ──────────────────────────────────────────────
## PART 3 — INTRO
## ──────────────────────────────────────────────

func _process_loading(delta: float) -> void:
	var scaled: float = delta * intro_time_scale
	_intro_elapsed += scaled
	if _intro_elapsed >= INTRO_DURATIONS[IntroStep.LOADING]:
		_start_intro()

func _process_intro(delta: float) -> void:
	var scaled: float = delta * intro_time_scale
	_intro_elapsed += scaled
	var duration: float = INTRO_DURATIONS[_intro_step]
	while _intro_elapsed >= duration and _phase == Phase.INTRO:
		_intro_elapsed -= duration
		_advance_intro_step()
		if _phase != Phase.INTRO:
			return
		duration = INTRO_DURATIONS[_intro_step]
	if _phase != Phase.INTRO:
		return
	if _intro_step == IntroStep.COUNTDOWN:
		var n: int = clampi(3 - int(_intro_elapsed), 1, 3)
		if n != _intro_count:
			_intro_count = n
			_set_intro_text(str(n), 220)

func _advance_intro_step() -> void:
	_intro_step += 1
	match _intro_step:
		IntroStep.COUNTDOWN:
			_intro_count = 3
			_set_intro_text("3", 220)
		IntroStep.GO:
			_set_intro_text("GO!", 220)
			_restore_control()
		IntroStep.DONE:
			_finish_intro()

## Step 8 (GO): restore each operator's real AI flag captured at intro start.
func _restore_control() -> void:
	if player_manager == null:
		return
	for op: OperatorBase in player_manager.get_all_operators():
		# Default to human control when this operator's AI flag wasn't captured at
		# intro, so a missing entry can never permanently freeze the operator (Bug 4).
		op.is_ai_controlled = bool(_op_ai_by_id.get(op.player_id, false))

func _create_intro_ui() -> void:
	_intro_ui = CanvasLayer.new()
	_intro_ui.name = "IntroUI"
	_intro_ui.layer = 50
	add_child(_intro_ui)
	_intro_label = Label.new()
	_intro_label.name = "IntroLabel"
	_intro_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_intro_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_intro_label.add_theme_font_size_override("font_size", 120)
	_intro_label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85))
	_intro_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_intro_label.add_theme_constant_override("shadow_offset_x", 4)
	_intro_label.add_theme_constant_override("shadow_offset_y", 4)
	_intro_label.text = ""
	_intro_ui.add_child(_intro_label)

func _set_intro_text(text: String, font_size: int) -> void:
	if _intro_label == null:
		return
	_intro_label.text = text
	_intro_label.add_theme_font_size_override("font_size", font_size)

## ──────────────────────────────────────────────
## MATCH TIMER / SCORE (Part 1 administration)
## ──────────────────────────────────────────────

func _update_match_timer(delta: float) -> void:
	if _match_time_left <= 0.0:
		return
	_match_time_left = maxf(0.0, _match_time_left - delta)
	match_timer_updated.emit(_match_time_left)
	_update_match_hud()
	if _match_time_left <= 0.0:
		end_match(timeout_winning_team)

func add_score(team_id: int, points: int) -> void:
	team_scores[team_id] = int(team_scores.get(team_id, 0)) + points
	score_changed.emit(team_id, get_score(team_id))
	_update_match_hud()

func get_score(team_id: int) -> int:
	return int(team_scores.get(team_id, 0))

## ──────────────────────────────────────────────
## TERRITORY SCORING (continuous, per second)
## ──────────────────────────────────────────────

## Each second a team gains +N points where N = number of terminals it controls
## (1 terminal = +1, 2 = +2, 3 = +3 per second). Fractional seconds accumulate
## so the score is awarded continuously, not in discrete second jumps.
func _update_territory_scoring(delta: float) -> void:
	if _terminal_manager == null:
		return
	var team_points: Dictionary = {}
	for core: AICore in _terminal_manager.get_terminals():
		var owner: int = core.get_owning_team()
		if owner >= 0:
			team_points[owner] = int(team_points.get(owner, 0)) + 1
	for team: int in team_points.keys():
		var acc: float = float(_territory_accumulator.get(team, 0.0)) + delta * int(team_points[team])
		var whole: int = int(acc)
		if whole > 0:
			add_score(team, whole)
			acc -= float(whole)
		_territory_accumulator[team] = acc

## ──────────────────────────────────────────────
## SUPREMACY (hold all terminals to win)
## ──────────────────────────────────────────────

## Holding every terminal simultaneously starts a visible countdown
## (supremacy_duration seconds). Losing any terminal during the countdown
## resets it to zero and cancels the supremacy (immediate HUD hide).
func _update_supremacy(delta: float) -> void:
	var holder: int = _get_supremacy_holder()
	if holder >= 0:
		if _supremacy_team != holder:
			_supremacy_team = holder
			_supremacy_time_left = supremacy_duration
		_supremacy_time_left = maxf(0.0, _supremacy_time_left - delta)
		supremacy_changed.emit(_supremacy_team, _supremacy_time_left)
		if _supremacy_time_left <= 0.0:
			end_match(_supremacy_team)
	elif _supremacy_team != -1:
		_supremacy_team = -1
		_supremacy_time_left = 0.0
		supremacy_changed.emit(-1, 0.0)

## The team that currently controls every terminal (-1 if none or split).
func _get_supremacy_holder() -> int:
	if _terminal_manager == null:
		return -1
	var owner: int = -1
	for core: AICore in _terminal_manager.get_terminals():
		var t_owner: int = core.get_owning_team()
		if t_owner < 0:
			return -1
		if owner == -1:
			owner = t_owner
		elif owner != t_owner:
			return -1
	return owner

func _create_match_hud() -> void:
	_match_hud = CanvasLayer.new()
	_match_hud.name = "MatchHUD"
	_match_hud.layer = 20
	add_child(_match_hud)

	var top: HBoxContainer = HBoxContainer.new()
	top.name = "TopBar"
	top.set_anchors_preset(Control.PRESET_CENTER_TOP)
	top.offset_top = 8
	top.grow_horizontal = Control.GROW_DIRECTION_BOTH
	top.add_theme_constant_override("separation", 48)
	_match_hud.add_child(top)

	_timer_label = Label.new()
	_timer_label.name = "TimerLabel"
	_timer_label.add_theme_font_size_override("font_size", 26)
	_timer_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	_timer_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_timer_label.add_theme_constant_override("shadow_offset_x", 2)
	_timer_label.add_theme_constant_override("shadow_offset_y", 2)
	top.add_child(_timer_label)

	_score_label = Label.new()
	_score_label.name = "ScoreLabel"
	_score_label.add_theme_font_size_override("font_size", 26)
	_score_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.95))
	_score_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	_score_label.add_theme_constant_override("shadow_offset_x", 2)
	_score_label.add_theme_constant_override("shadow_offset_y", 2)
	top.add_child(_score_label)

	# Terminal state dots: A/B/C colored by the controlling team.
	for letter: String in ["A", "B", "C"]:
		var term_label: Label = Label.new()
		term_label.name = "Terminal%sLabel" % letter
		term_label.text = "%s ●" % letter
		term_label.add_theme_font_size_override("font_size", 26)
		term_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
		term_label.add_theme_constant_override("shadow_offset_x", 2)
		term_label.add_theme_constant_override("shadow_offset_y", 2)
		top.add_child(term_label)
		_terminal_hud_entries.append({"label": term_label, "terminal_id": "Terminal_%s" % letter})

	# Supremacy countdown (hidden unless a team holds every terminal).
	_supremacy_label = Label.new()
	_supremacy_label.name = "SupremacyLabel"
	_supremacy_label.text = "SUPREMACÍA"
	_supremacy_label.add_theme_font_size_override("font_size", 34)
	_supremacy_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.15))
	_supremacy_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_supremacy_label.add_theme_constant_override("shadow_offset_x", 2)
	_supremacy_label.add_theme_constant_override("shadow_offset_y", 2)
	_supremacy_label.visible = false
	top.add_child(_supremacy_label)
	# Live countdown + instant hide when supremacy is cancelled.
	supremacy_changed.connect(func(_team: int, _time_left: float) -> void: _update_supremacy_label())

	_update_match_hud()

func _update_match_hud() -> void:
	if _timer_label != null:
		var minutes: int = int(_match_time_left) / 60
		var seconds: int = int(_match_time_left) % 60
		_timer_label.text = "TIEMPO %02d:%02d" % [minutes, seconds]
	if _score_label != null:
		_score_label.text = "ATK %d : %d DEF" % [
			get_score(OperatorBase.TEAM_ATTACKERS),
			get_score(OperatorBase.TEAM_DEFENDERS)
		]
	_update_terminal_hud()
	_update_supremacy_label()

## Colors each terminal state dot by its controlling team.
func _update_terminal_hud() -> void:
	for entry: Dictionary in _terminal_hud_entries:
		var label: Label = entry["label"] as Label
		if label == null:
			continue
		var owner: int = -1
		if _terminal_manager != null:
			owner = _terminal_manager.get_owning_team(entry["terminal_id"] as String)
		label.add_theme_color_override("font_color", _terminal_owner_color(owner))

func _terminal_owner_color(owner: int) -> Color:
	match owner:
		OperatorBase.TEAM_ATTACKERS: return Color(0.3, 0.6, 1.0)
		OperatorBase.TEAM_DEFENDERS: return Color(0.95, 0.3, 0.3)
		_: return Color(0.5, 0.55, 0.6)

## Shows "SUPREMACÍA N" while a team holds all terminals; hides immediately
## otherwise (emitted supremacy_changed(-1) already reset the countdown).
func _update_supremacy_label() -> void:
	if _supremacy_label == null:
		return
	if _supremacy_team < 0:
		_supremacy_label.visible = false
		_supremacy_label.text = "SUPREMACÍA"
		return
	_supremacy_label.visible = true
	_supremacy_label.text = "SUPREMACÍA %d" % int(ceilf(_supremacy_time_left))

func _on_terminal_ownership_changed(_terminal_id: String, _owner: int) -> void:
	_update_match_hud()

## ──────────────────────────────────────────────
## MATCH END UI
## ──────────────────────────────────────────────

func _show_match_end_overlay(winning_team: int) -> void:
	var canvas: CanvasLayer = CanvasLayer.new()
	canvas.name = "MatchEndOverlay"
	canvas.layer = 200
	add_child(canvas)

	var bg: ColorRect = ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.05, 0.07, 0.1, 0.85)
	canvas.add_child(bg)

	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel: VBoxContainer = VBoxContainer.new()
	panel.add_theme_constant_override("separation", 20)
	center.add_child(panel)

	var title: Label = Label.new()
	title.text = "FIN DE PARTIDA"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	panel.add_child(title)

	var winner_label: Label = Label.new()
	winner_label.text = "EQUIPO GANADOR:\n%s" % _team_name(winning_team)
	winner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	winner_label.add_theme_font_size_override("font_size", 28)
	var team_color: Color = Color(0.95, 0.3, 0.3) if winning_team == OperatorBase.TEAM_ATTACKERS else Color(0.3, 0.6, 1.0)
	winner_label.add_theme_color_override("font_color", team_color)
	panel.add_child(winner_label)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	panel.add_child(spacer)

	var restart_btn: Button = Button.new()
	restart_btn.text = "Reiniciar partida"
	restart_btn.custom_minimum_size = Vector2(260, 55)
	restart_btn.add_theme_font_size_override("font_size", 22)
	restart_btn.pressed.connect(_on_restart_pressed)
	panel.add_child(restart_btn)

	var menu_btn: Button = Button.new()
	menu_btn.text = "Volver al menú"
	menu_btn.custom_minimum_size = Vector2(260, 55)
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.pressed.connect(_on_back_to_menu_pressed)
	panel.add_child(menu_btn)

func _on_restart_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/match.tscn")

func _on_back_to_menu_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_toggle_pause()

## ──────────────────────────────────────────────
## IN-MATCH PAUSE (PMQ3)
## ──────────────────────────────────────────────
## Pausing does NOT leave the match scene. We only freeze the SceneTree and host
## a pause menu in an always-processing overlay. Resuming unpauses the SAME Match
## instance (players, drones, arena and state stay intact).

var _paused: bool = false
var _pause_overlay: CanvasLayer = null

func _toggle_pause() -> void:
	if _phase == Phase.LOADING or _phase == Phase.MATCH_END:
		return
	if _paused:
		_resume_game()
	else:
		_pause_game()

func _pause_game() -> void:
	if _paused:
		return
	_paused = true
	get_tree().paused = true
	_build_pause_overlay()

func _build_pause_overlay() -> void:
	_pause_overlay = CanvasLayer.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.layer = 300
	# ALWAYS so the menu stays interactive while the simulation is paused.
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_overlay)

	var bg: ColorRect = ColorRect.new()
	bg.name = "PauseDimmer"
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.04, 0.06, 0.1, 0.82)
	_pause_overlay.add_child(bg)

	var stack: UIScreenStack = UIScreenStack.new()
	stack.name = "PauseStack"
	_pause_overlay.add_child(stack)
	# Dynamic load: PauseScreen has no class_name with a hard compile dependency,
	# so headless --script runs compile it lazily without cycle/autoload ordering
	# issues (it is authored as a UIScreen subclass and registered in the editor).
	var pause_script := load("res://ui/screens/pause_screen.gd") as GDScript
	if pause_script != null:
		stack.push(pause_script.new(_resume_game) as UIScreen)

func _resume_game() -> void:
	if not _paused:
		return
	_paused = false
	get_tree().paused = false
	if _pause_overlay != null and is_instance_valid(_pause_overlay):
		_pause_overlay.queue_free()
		_pause_overlay = null

## ──────────────────────────────────────────────
## SQUAD / VISION / CAMERA WIRING
## ──────────────────────────────────────────────

func _on_player_spawned(_p_id: int, op: OperatorBase) -> void:
	if op == null:
		return
	if op.vision_cone != null and squad_vision_registry != null:
		squad_vision_registry.register_provider(op.vision_cone)
	op.weapon_fired.connect(_on_weapon_fired.bind(op))
	op.damage_dealt.connect(_on_operator_damage_dealt)
	op.drone_status_changed.connect(_on_drone_status_changed)
	if not op.operator_incapacitated.is_connected(_on_operator_incapacitated):
		op.operator_incapacitated.connect(_on_operator_incapacitated.bind(op))
	if op.drone != null:
		_on_drone_status_changed(_p_id, true, "ESCORT")
	_update_camera_targets()

func _on_drone_status_changed(p_id: int, has_drone: bool, _mode: String) -> void:
	if squad_vision_registry == null or player_manager == null:
		return
	var op: OperatorBase = player_manager.get_operator(p_id)
	if op == null:
		return
	if has_drone and op.drone != null:
		if op.drone.vision_cone != null:
			squad_vision_registry.register_provider(op.drone.vision_cone)
		# Drone combat feedback uses the same presentation path as operators:
		# tracers via the drone's own handler, damage numbers via the shared one.
		if not op.drone.weapon_fired.is_connected(_on_drone_weapon_fired):
			op.drone.weapon_fired.connect(_on_drone_weapon_fired.bind(op.drone))
		if not op.drone.damage_dealt.is_connected(_on_operator_damage_dealt):
			op.drone.damage_dealt.connect(_on_operator_damage_dealt)
	elif not has_drone and op.drone == null:
		squad_vision_registry._recalculate_squad_vision()

func _on_squad_updated(_active_count: int) -> void:
	_update_camera_targets()

## Re-frames the camera and refreshes squad detection when an operator goes
## down/respawns (P0-1 / P1-3). The camera excludes incapacitated operators on
## its own each frame; this just triggers an immediate refresh.
func _on_operator_incapacitated(_p_id: int, op: OperatorBase) -> void:
	_update_camera_targets()
	if squad_vision_registry != null:
		squad_vision_registry._recalculate_squad_vision()

func _update_camera_targets() -> void:
	if camera_controller == null or player_manager == null:
		return
	var node3d_targets: Array[Node3D] = []
	for op: OperatorBase in player_manager.get_all_operators():
		# The shared camera always keeps the operator as a framing anchor. While
		# piloting, the drone is tracked as an ADDITIONAL target (never a swap),
		# so the viewport stays grounded on the squad instead of abandoning it
		# for a far-away drone (which made other players appear to slide with it).
		node3d_targets.append(op as Node3D)
		if op.is_piloting_drone and op.drone != null and is_instance_valid(op.drone):
			node3d_targets.append(op.drone as Node3D)
	camera_controller.targets = node3d_targets

## ──────────────────────────────────────────────
## COMBAT FEEDBACK (presentation only, ported from SANDBOX-01)
## ──────────────────────────────────────────────

func _on_weapon_fired(origin: Vector3, direction: Vector3, shooter: OperatorBase) -> void:
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

func _spawn_shot_tracer(from: Vector3, to: Vector3, p_id: int) -> void:
	var dir: Vector3 = to - from
	var length: float = dir.length()
	if length < 0.01:
		return
	dir = dir.normalized()
	var tracer: MeshInstance3D = MeshInstance3D.new()
	var box: BoxMesh = BoxMesh.new()
	box.size = Vector3(0.05, 0.05, length)
	tracer.mesh = box
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.emission_enabled = true
	var colors: Array[Color] = [
		Color(1.0, 0.35, 0.35), Color(0.35, 0.65, 1.0),
		Color(0.35, 1.0, 0.45), Color(1.0, 0.95, 0.25),
	]
	var col: Color = colors[clampi(p_id - 1, 0, 3)]
	mat.emission = col * 2.0
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Draw above the tactical vision cone: the cone uses no_depth_test with
	# render_priority 10, so the tracer needs both to stay visible while RMB is held.
	mat.no_depth_test = true
	mat.render_priority = 20
	tracer.material_override = mat
	add_child(tracer)
	tracer.global_position = (from + to) * 0.5
	var world_up: Vector3 = Vector3.UP
	if absf(dir.dot(world_up)) > 0.99:
		world_up = Vector3.RIGHT
	var right: Vector3 = dir.cross(world_up).normalized()
	var up: Vector3 = right.cross(dir).normalized()
	tracer.global_transform.basis = Basis(right, up, dir)
	var tw: Tween = create_tween()
	tw.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tw.tween_callback(tracer.queue_free)

func _on_operator_damage_dealt(target: OperatorBase, damage: float, mitigated_by_cover: bool) -> void:
	_spawn_damage_number(target.global_position + Vector3(0.0, 2.5, 0.0), damage, mitigated_by_cover)
	_flash_operator(target)

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
	var start_y: float = world_pos.y
	var tw: Tween = create_tween()
	tw.set_parallel(true)
	tw.tween_method(func(y: float) -> void:
		if is_instance_valid(lbl):
			lbl.global_position.y = y
	, start_y, start_y + 2.0, 0.9)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.9)
	tw.chain().tween_callback(lbl.queue_free)

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

## ──────────────────────────────────────────────
## SESSION HELPERS
## ──────────────────────────────────────────────

func _session_node() -> Node:
	if get_tree() == null:
		return null
	return get_tree().root.get_node_or_null("GameConfig")

func _session_enabled_player_ids() -> Array[int]:
	var session: Node = _session_node()
	if session == null:
		return []
	return session.call("get_enabled_player_ids") as Array[int]

func _session_friendly_fire() -> bool:
	var session: Node = _session_node()
	if session == null:
		return false
	return session.get("friendly_fire_enabled") as bool
