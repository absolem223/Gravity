# core_status_display.gd
# Technical Rationale: HUD component for the AI Core hack progress.
# Displays state name, percentage bar, color-coded feedback, blink animation on DEGRADED/CONTESTED,
# and a discrete notification strip. Completely decoupled from game logic — consumes only signals.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name CoreStatusDisplay
extends Control

## Reference to HackController (injected by AICore after initialization)
var hack_controller: HackController = null

## ──────────────────────────────────────────────
## DISPLAY CONFIGURATION
## ──────────────────────────────────────────────
@export var blink_speed: float = 2.8              ## Blink cycles per second during DEGRADED/CONTESTED
@export var bar_lerp_speed: float = 6.0           ## Smoothing speed for progress bar visual updates

## ──────────────────────────────────────────────
## STATE COLORS
## ──────────────────────────────────────────────
const COLOR_IDLE:      Color = Color(0.4, 0.45, 0.55, 1.0)
const COLOR_HACKING:   Color = Color(0.15, 0.85, 0.45, 1.0)
const COLOR_CONTESTED: Color = Color(0.95, 0.65, 0.15, 1.0)
const COLOR_DEGRADED:  Color = Color(0.85, 0.25, 0.25, 1.0)
const COLOR_CAPTURED:  Color = Color(0.2, 0.65, 1.0, 1.0)

## ──────────────────────────────────────────────
## INTERNAL NODES (built programmatically)
## ──────────────────────────────────────────────
var _panel: PanelContainer = null
var _state_label: Label = null
var _percent_label: Label = null
var _progress_bar: ProgressBar = null
var _notification_strip: Label = null

## Runtime state
var _current_display_state: HackController.CoreState = HackController.CoreState.IDLE
var _blink_accumulator: float = 0.0
var _visual_progress: float = 0.0    ## Lerped visual progress
var _is_blinking: bool = false

## ──────────────────────────────────────────────
## LIFECYCLE
## ──────────────────────────────────────────────
func _ready() -> void:
	_build_display()
	_apply_state_visuals(HackController.CoreState.IDLE, 0.0)
	print("[CoreStatusDisplay] Initialized.")

func _process(delta: float) -> void:
	_update_blink(delta)
	_update_visual_progress(delta)

## ──────────────────────────────────────────────
## BUILD UI PROGRAMMATICALLY
## ──────────────────────────────────────────────
func _build_display() -> void:
	## Root panel — top-center anchored
	_panel = PanelContainer.new()
	_panel.name = "CoreStatusPanel"
	_panel.custom_minimum_size = Vector2(320, 70)
	_panel.anchor_left   = 0.5
	_panel.anchor_right  = 0.5
	_panel.anchor_top    = 0.0
	_panel.anchor_bottom = 0.0
	_panel.offset_left   = -160.0
	_panel.offset_top    = 6.0
	_panel.offset_right  = 160.0
	_panel.offset_bottom = 76.0

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.10, 0.92)
	style.border_color = COLOR_IDLE
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	_panel.add_child(vbox)

	## Row 1: State label + percentage
	var row1: HBoxContainer = HBoxContainer.new()
	vbox.add_child(row1)

	var core_title: Label = Label.new()
	core_title.text = "◈ AI CORE"
	core_title.add_theme_font_size_override("font_size", 12)
	core_title.add_theme_color_override("font_color", Color(0.55, 0.65, 0.75))
	core_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row1.add_child(core_title)

	_percent_label = Label.new()
	_percent_label.name = "PercentLabel"
	_percent_label.text = "0%"
	_percent_label.add_theme_font_size_override("font_size", 12)
	_percent_label.add_theme_color_override("font_color", COLOR_IDLE)
	row1.add_child(_percent_label)

	## Row 2: Progress bar
	_progress_bar = ProgressBar.new()
	_progress_bar.name = "HackProgressBar"
	_progress_bar.max_value = 100.0
	_progress_bar.value = 0.0
	_progress_bar.custom_minimum_size = Vector2(0, 12)
	_progress_bar.show_percentage = false
	vbox.add_child(_progress_bar)

	## Row 3: State label
	_state_label = Label.new()
	_state_label.name = "StateLabel"
	_state_label.text = "IDLE — Awaiting squad presence"
	_state_label.add_theme_font_size_override("font_size", 10)
	_state_label.add_theme_color_override("font_color", COLOR_IDLE)
	vbox.add_child(_state_label)

	## Row 4: Notification strip (hidden by default)
	_notification_strip = Label.new()
	_notification_strip.name = "NotificationStrip"
	_notification_strip.text = ""
	_notification_strip.add_theme_font_size_override("font_size", 10)
	_notification_strip.visible = false
	vbox.add_child(_notification_strip)

## ──────────────────────────────────────────────
## PUBLIC API — SIGNAL RECEIVERS
## ──────────────────────────────────────────────

func on_hack_started(team_id: int) -> void:
	_current_display_state = HackController.CoreState.HACKING
	_is_blinking = false
	_apply_state_visuals(HackController.CoreState.HACKING, hack_controller.get_progress() if hack_controller != null else 0.0)
	_set_notification("Team %d initiated hack" % team_id, COLOR_HACKING)

func on_hack_progress_changed(progress: float, _team_id: int) -> void:
	_visual_progress = _progress_bar.value  ## Will lerp toward progress in _process
	_percent_label.text = "%d%%" % int(progress)

	if hack_controller != null:
		_current_display_state = hack_controller.get_current_state()
		_apply_state_visuals(_current_display_state, progress)

func on_hack_contested() -> void:
	if _current_display_state == HackController.CoreState.CONTESTED:
		return
	_current_display_state = HackController.CoreState.CONTESTED
	_is_blinking = true
	_apply_state_visuals(HackController.CoreState.CONTESTED, hack_controller.get_progress() if hack_controller != null else 0.0)
	_set_notification("⚠ CONTESTED — Progress frozen", COLOR_CONTESTED)

func on_hack_degrading(progress: float) -> void:
	_current_display_state = HackController.CoreState.DEGRADED
	_is_blinking = true
	_apply_state_visuals(HackController.CoreState.DEGRADED, progress)
	_set_notification("⚠ DEGRADING — Return to perimeter!", COLOR_DEGRADED)

func on_hack_completed(team_id: int) -> void:
	_current_display_state = HackController.CoreState.CAPTURED
	_is_blinking = false
	_apply_state_visuals(HackController.CoreState.CAPTURED, 100.0)
	_set_notification("✓ CORE CAPTURED — Team %d" % team_id, COLOR_CAPTURED)

## Called every frame by AICore when state returns to IDLE
func on_state_idle() -> void:
	if _current_display_state == HackController.CoreState.IDLE:
		return
	_current_display_state = HackController.CoreState.IDLE
	_is_blinking = false
	_apply_state_visuals(HackController.CoreState.IDLE, 0.0)
	_set_notification("", COLOR_IDLE)

## ──────────────────────────────────────────────
## VISUAL UPDATE INTERNALS
## ──────────────────────────────────────────────

func _apply_state_visuals(state: HackController.CoreState, progress: float) -> void:
	var col: Color = _state_to_color(state)
	var state_text: String = _state_to_label(state)

	if _state_label != null:
		_state_label.text = state_text
		_state_label.add_theme_color_override("font_color", col)

	if _percent_label != null:
		_percent_label.text = "%d%%" % int(progress)
		_percent_label.add_theme_color_override("font_color", col)

	## Update panel border color
	if _panel != null:
		var s: StyleBoxFlat = _panel.get_theme_stylebox("panel") as StyleBoxFlat
		if s != null:
			s.border_color = col

	## Update progress bar tint
	if _progress_bar != null:
		_progress_bar.modulate = col

func _update_visual_progress(delta: float) -> void:
	if hack_controller == null or _progress_bar == null:
		return
	var target: float = hack_controller.get_progress()
	_progress_bar.value = lerp(_progress_bar.value, target, bar_lerp_speed * delta)

func _update_blink(delta: float) -> void:
	if not _is_blinking or _panel == null:
		return
	_blink_accumulator += delta * blink_speed * TAU
	var alpha: float = (sin(_blink_accumulator) * 0.3) + 0.7
	_panel.modulate.a = alpha

func _set_notification(text: String, color: Color) -> void:
	if _notification_strip == null:
		return
	_notification_strip.text = text
	_notification_strip.visible = not text.is_empty()
	_notification_strip.add_theme_color_override("font_color", color)

func _state_to_color(state: HackController.CoreState) -> Color:
	match state:
		HackController.CoreState.HACKING:   return COLOR_HACKING
		HackController.CoreState.CONTESTED: return COLOR_CONTESTED
		HackController.CoreState.DEGRADED:  return COLOR_DEGRADED
		HackController.CoreState.CAPTURED:  return COLOR_CAPTURED
		_:                                  return COLOR_IDLE

func _state_to_label(state: HackController.CoreState) -> String:
	match state:
		HackController.CoreState.IDLE:      return "IDLE — Awaiting squad presence"
		HackController.CoreState.HACKING:   return "HACKING — Core access in progress"
		HackController.CoreState.CONTESTED: return "CONTESTED — Enemy interference detected"
		HackController.CoreState.DEGRADED:  return "DEGRADING — Return to maintain progress"
		HackController.CoreState.CAPTURED:  return "CAPTURED — Core under control"
		_:                                  return "UNKNOWN"
