# settings_screen.gd
# Technical Rationale: App settings (CS_DZ). Reuses the shared widget factory so it
# is consistent with the match-setup screens. All edits write straight to GameConfig
# and persist automatically.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name SettingsScreen
extends UIScreen

func _ready() -> void:
	super._ready()
	screen_title = "Ajustes"
	_build()
	focus_first()

func _build() -> void:
	add_child(MenuFactory.make_background())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 60)
	margin.add_theme_constant_override("margin_right", 96)
	add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	box.add_child(MenuFactory.make_title("Ajustes"))
	box.add_child(MenuFactory.make_hint("Las preferencias se guardan automáticamente."))

	var vol: HBoxContainer = HBoxContainer.new()
	vol.add_theme_constant_override("separation", 12)
	var vol_lbl: Label = MenuFactory.make_label("Volumen maestro", 16)
	vol_lbl.custom_minimum_size = Vector2(240, 0)
	vol.add_child(vol_lbl)
	var sl: HSlider = HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = GameConfig.master_volume_linear
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(_on_volume)
	vol.add_child(sl)
	box.add_child(vol)

	var fs: CheckBox = CheckBox.new()
	fs.text = "Pantalla completa"
	fs.button_pressed = GameConfig.fullscreen_enabled
	fs.toggled.connect(_on_fullscreen)
	box.add_child(fs)

	var ff: CheckBox = CheckBox.new()
	ff.text = "Fuego amigo (friendly fire)"
	ff.button_pressed = GameConfig.friendly_fire_enabled
	ff.toggled.connect(_on_friendly_fire)
	box.add_child(ff)

	var diag_cb: CheckBox = CheckBox.new()
	diag_cb.text = "Mostrar diagnósticos de joystick"
	diag_cb.button_pressed = GameConfig.show_joystick_diagnostics
	diag_cb.toggled.connect(_on_joystick_diagnostics)
	box.add_child(diag_cb)

	# ── Control / gamepad configuration entry ──
	var controls: HBoxContainer = HBoxContainer.new()
	controls.add_theme_constant_override("separation", 12)
	var ctrl_lbl: Label = MenuFactory.make_label("Controles & Dispositivos", 16)
	ctrl_lbl.custom_minimum_size = Vector2(240, 0)
	controls.add_child(ctrl_lbl)
	controls.add_child(MenuFactory.make_button("Configurar", _on_controls, 260, 44))
	controls.add_child(MenuFactory.make_button("Diagnóstico de Gamepad", _on_gamepad_test, 260, 44))
	box.add_child(controls)

	box.add_child(MenuFactory.make_hint(
		"Definí jugadores, conectá joysticks y reasigná cada acción. Los controles se guardan automáticamente."))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(MenuFactory.make_button("Volver", pop))
	box.add_child(row)

func _on_volume(v: float) -> void:
	GameConfig.master_volume_linear = v
	GameConfig.apply_runtime_settings()
	GameConfig.save_settings()

func _on_controls() -> void:
	# "Settings → Controls" must open the real per-player configuration system.
	GameConfig.save_settings()
	push(PlayersConfigScreen.new())

func _on_gamepad_test() -> void:
	# Diagnostic-only inspector (reads raw Godot joypad API, writes nothing).
	push(GamepadTestScreen.new())

func _on_fullscreen(on: bool) -> void:
	GameConfig.fullscreen_enabled = on
	GameConfig.apply_runtime_settings()
	GameConfig.save_settings()

func _on_friendly_fire(on: bool) -> void:
	GameConfig.friendly_fire_enabled = on
	GameConfig.save_settings()

func _on_joystick_diagnostics(on: bool) -> void:
	GameConfig.show_joystick_diagnostics = on
	GameConfig.save_settings()
