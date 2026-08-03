# squad_hud.gd
# Technical Rationale: Local cooperative tactical HUD showing squad status cards (P1-P4), shared squad intel summary,
# and AI Core status strip (Etapa 6).
# Displays HP, slot color, placeholder role, device status, distance from centroid, drone status, battery percentage,
# squad target detection count, Core state, and Core progress.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SquadHUD
extends Control

## Reference to PlayerManager node
var player_manager: PlayerManager = null

## Reference to InputManager node
var input_manager: InputManager = null

## Reference to SquadVisionRegistry node
var squad_vision_registry: SquadVisionRegistry = null

## Reference to AICore module (Etapa 6)
var _ai_core: AICore = null

## Core status strip labels (built programmatically)
var _core_state_label: Label = null
var _core_percent_label: Label = null
var _core_bar: ProgressBar = null

## Core state colors
const CORE_COLOR_IDLE:      Color = Color(0.4, 0.45, 0.55)
const CORE_COLOR_HACKING:   Color = Color(0.15, 0.85, 0.45)
const CORE_COLOR_CONTESTED: Color = Color(0.95, 0.65, 0.15)
const CORE_COLOR_DEGRADED:  Color = Color(0.85, 0.25, 0.25)
const CORE_COLOR_CAPTURED:  Color = Color(0.2, 0.65, 1.0)

## Container for player status cards
@onready var cards_container: HBoxContainer = $MarginContainer/CardsContainer if has_node("MarginContainer/CardsContainer") else null

## Intel header label
@onready var intel_label: Label = $TopMarginContainer/IntelLabel if has_node("TopMarginContainer/IntelLabel") else null

## Array of created card nodes
var _player_cards: Dictionary = {}

## Palette colors per player slot (P1: Red, P2: Blue, P3: Green, P4: Yellow)
const SLOT_COLORS: Array[Color] = [
	Color(0.9, 0.25, 0.25), # P1
	Color(0.25, 0.5, 0.95), # P2
	Color(0.25, 0.85, 0.35),# P3
	Color(0.95, 0.85, 0.25) # P4
]

const ROLE_NAMES: Array[String] = [
	"P1 Recon",
	"P2 Vanguard",
	"P3 Disruptor",
	"P4 Engineer"
]

func _ready() -> void:
	pass

func _process(_delta: float) -> void:
	_update_hud_state()

## Sets up HUD references and constructs status cards
func setup_hud(p_mgr: PlayerManager, in_mgr: InputManager, vision_reg: SquadVisionRegistry = null) -> void:
	player_manager = p_mgr
	input_manager = in_mgr
	squad_vision_registry = vision_reg
	_build_player_cards()
	_build_core_strip()

## Injects AICore reference for Core status display (Etapa 6)
func set_ai_core(core: AICore) -> void:
	_ai_core = core

## Updates core status strip from SandboxTestScene callbacks
func update_core_status(progress: float, state: HackController.CoreState) -> void:
	if _core_bar != null:
		_core_bar.value = progress
	if _core_percent_label != null:
		_core_percent_label.text = "%d%%" % int(progress)
	var col: Color = _core_state_to_color(state)
	var label_text: String = _core_state_to_label(state)
	if _core_state_label != null:
		_core_state_label.text = label_text
		_core_state_label.add_theme_color_override("font_color", col)
	if _core_percent_label != null:
		_core_percent_label.add_theme_color_override("font_color", col)
	if _core_bar != null:
		_core_bar.modulate = col

## Programmatically constructs 4 player status cards in bottom HUD
func _build_player_cards() -> void:
	if cards_container == null:
		return
		
	for child: Node in cards_container.get_children():
		child.queue_free()
	_player_cards.clear()

	for p_id: int in range(1, 5):
		var card: PanelContainer = PanelContainer.new()
		card.name = "PlayerCard_P%d" % p_id
		card.custom_minimum_size = Vector2(240, 85)
		
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.08, 0.09, 0.12, 0.85)
		style.border_color = SLOT_COLORS[p_id - 1]
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		style.content_margin_left = 12
		style.content_margin_top = 8
		style.content_margin_right = 12
		style.content_margin_bottom = 8
		card.add_theme_stylebox_override("panel", style)

		var vbox: VBoxContainer = VBoxContainer.new()
		
		# Header: Role Name & Player Badge
		var header_label: Label = Label.new()
		header_label.name = "HeaderLabel"
		header_label.text = ROLE_NAMES[p_id - 1]
		header_label.add_theme_color_override("font_color", SLOT_COLORS[p_id - 1])
		header_label.add_theme_font_size_override("font_size", 14)
		vbox.add_child(header_label)

		# HP Bar
		var hp_bar: ProgressBar = ProgressBar.new()
		hp_bar.name = "HPBar"
		hp_bar.max_value = 100.0
		hp_bar.value = 100.0
		hp_bar.custom_minimum_size = Vector2(0, 14)
		hp_bar.show_percentage = false
		vbox.add_child(hp_bar)

		# Sub-info: Device, Drone Mode, Distance & Shared Battery
		var info_label: Label = Label.new()
		info_label.name = "InfoLabel"
		info_label.text = "Device: Keyboard | Status: ESCORT | Dist: 0m | BAT: 100%"
		info_label.add_theme_font_size_override("font_size", 10)
		info_label.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		vbox.add_child(info_label)

		# COMPONENTS bar (Etapa 7 — resource economy)
		var comp_label: Label = Label.new()
		comp_label.name = "ComponentsLabel"
		comp_label.text = "◈ COMP: 0 / 100"
		comp_label.add_theme_font_size_override("font_size", 10)
		comp_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.55))
		vbox.add_child(comp_label)

		card.add_child(vbox)
		cards_container.add_child(card)
		_player_cards[p_id] = card

## Updates HP, device connection, distance labels, drone states, battery, and squad vision summary
func _update_hud_state() -> void:
	if player_manager == null:
		return

	var centroid: Vector3 = player_manager.get_squad_centroid()

	for p_id: int in range(1, 5):
		var card: PanelContainer = _player_cards.get(p_id, null) as PanelContainer
		if card == null:
			continue

		var op: OperatorBase = player_manager.get_operator(p_id)
		if op != null and is_instance_valid(op):
			card.visible = true
			var hp_bar: ProgressBar = card.find_child("HPBar", true, false) as ProgressBar
			if hp_bar != null:
				hp_bar.value = op.health_current
				hp_bar.max_value = op.health_max
				
				if op.is_incapacitated:
					hp_bar.modulate = Color(0.5, 0.2, 0.2)
				else:
					hp_bar.modulate = Color(1.0, 1.0, 1.0)

			var info_label: Label = card.find_child("InfoLabel", true, false) as Label
			if info_label != null:
				var dist: float = op.global_position.distance_to(centroid)
				var dev_name: String = "Keyboard"
				if input_manager != null:
					var prof: InputManager.PlayerInputProfile = input_manager.get_profile(p_id)
					if prof != null:
						dev_name = prof.get_device_name()
				
				# Get drone active mode status
				var status_str: String = "ESCORT"
				if op.is_incapacitated:
					status_str = "DOWN"
				elif not op.has_drone_active:
					status_str = "DRONE_LOST"
				elif op.is_separated:
					status_str = "SEPARATED"
				elif op.drone != null:
					match op.drone.current_mode:
						DroneBase.DroneMode.ESCORT:
							status_str = "ESCORT"
						DroneBase.DroneMode.STATIONARY:
							status_str = "STATIONARY"
						DroneBase.DroneMode.PILOT:
							status_str = "PILOT"
				
				info_label.text = "%s | %s | %.1fm | BAT: %d%%" % [dev_name, status_str, dist, int(op.battery_current)]

			## Update COMPONENTS label (Etapa 7)
			var comp_label: Label = card.find_child("ComponentsLabel", true, false) as Label
			if comp_label != null:
				var comp_amt: int = op.get_maintenance_components()
				var comp_cap: int = op.get_inventory_capacity()
				comp_label.text = "◈ COMP: %d / %d" % [comp_amt, comp_cap]
				## Color shifts toward yellow as inventory fills
				var fill_ratio: float = float(comp_amt) / float(max(comp_cap, 1))
				comp_label.add_theme_color_override("font_color", Color(0.3 + fill_ratio * 0.6, 0.9 - fill_ratio * 0.3, 0.55 - fill_ratio * 0.4))
		else:
			card.visible = false

	# Update Top Intel Summary
	if intel_label != null and squad_vision_registry != null:
		var target_count: int = squad_vision_registry.get_all_squad_detected_targets().size()
		intel_label.text = "SQUAD INTEL: %d TARGETS IN VISION" % target_count

## Builds the AI Core status strip below the intel label
func _build_core_strip() -> void:
	var strip: HBoxContainer = HBoxContainer.new()
	strip.name = "CoreStrip"
	strip.add_theme_constant_override("separation", 8)

	## Label: static title
	var title: Label = Label.new()
	title.text = "◈ CORE:"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	strip.add_child(title)

	## State label
	_core_state_label = Label.new()
	_core_state_label.name = "CoreStateLabel"
	_core_state_label.text = "IDLE"
	_core_state_label.add_theme_font_size_override("font_size", 12)
	_core_state_label.add_theme_color_override("font_color", CORE_COLOR_IDLE)
	_core_state_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_child(_core_state_label)

	## Progress bar
	_core_bar = ProgressBar.new()
	_core_bar.name = "CoreBar"
	_core_bar.max_value = 100.0
	_core_bar.value = 0.0
	_core_bar.custom_minimum_size = Vector2(120, 12)
	_core_bar.show_percentage = false
	_core_bar.modulate = CORE_COLOR_IDLE
	strip.add_child(_core_bar)

	## Percent label
	_core_percent_label = Label.new()
	_core_percent_label.name = "CorePercentLabel"
	_core_percent_label.text = "0%"
	_core_percent_label.add_theme_font_size_override("font_size", 12)
	_core_percent_label.add_theme_color_override("font_color", CORE_COLOR_IDLE)
	strip.add_child(_core_percent_label)

	## Attach below IntelLabel in the TopMarginContainer
	if has_node("TopMarginContainer"):
		$TopMarginContainer.add_child(strip)
	else:
		add_child(strip)

func _core_state_to_color(state: HackController.CoreState) -> Color:
	match state:
		HackController.CoreState.HACKING:   return CORE_COLOR_HACKING
		HackController.CoreState.CONTESTED: return CORE_COLOR_CONTESTED
		HackController.CoreState.DEGRADED:  return CORE_COLOR_DEGRADED
		HackController.CoreState.CAPTURED:  return CORE_COLOR_CAPTURED
		_:                                  return CORE_COLOR_IDLE

func _core_state_to_label(state: HackController.CoreState) -> String:
	match state:
		HackController.CoreState.HACKING:   return "HACKING"
		HackController.CoreState.CONTESTED: return "CONTESTED"
		HackController.CoreState.DEGRADED:  return "DEGRADING"
		HackController.CoreState.CAPTURED:  return "CAPTURED"
		_:                                  return "IDLE"
