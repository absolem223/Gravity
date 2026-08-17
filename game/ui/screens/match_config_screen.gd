# match_config_screen.gd
# Technical Rationale: Match-level rules (MC_MATCH_CONFIG). A single lightweight step
# between the main menu and the per-player setup. Writes to GameConfig and persists.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name MatchConfigScreen
extends UIScreen

func _ready() -> void:
	super._ready()
	screen_title = "Configuración de Partida"
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

	box.add_child(MenuFactory.make_title("Configuración de Partida"))
	box.add_child(MenuFactory.make_hint("Reglas generales de la partida. A continuación definís a los jugadores."))

	var ff: CheckBox = CheckBox.new()
	ff.text = "Fuego amigo (friendly fire)"
	ff.button_pressed = GameConfig.friendly_fire_enabled
	ff.toggled.connect(_on_friendly_fire)
	box.add_child(ff)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	box.add_child(spacer)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(MenuFactory.make_button("Continuar → Jugadores", _on_next))
	row.add_child(MenuFactory.make_button("Volver", pop))
	box.add_child(row)

func _on_friendly_fire(on: bool) -> void:
	GameConfig.friendly_fire_enabled = on
	GameConfig.save_settings()

func _on_next() -> void:
	GameConfig.save_settings()
	push(PlayersConfigScreen.new())