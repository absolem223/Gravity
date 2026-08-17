# main_screen.gd
# Technical Rationale: Root menu (MC_MAIN). Entry point to the match-setup flow
# and app settings. Purely navigational; writes nothing to the config layer.
# Adheres to ADR-0001 (GDScript 2.x Strict Typing).

class_name MainScreen
extends UIScreen

func _ready() -> void:
	super._ready()
	screen_title = "PROJECT GRAVITY"
	_build()
	focus_first()

func _build() -> void:
	add_child(MenuFactory.make_background())

	var margin: MarginContainer = MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 96)
	margin.add_theme_constant_override("margin_top", 80)
	margin.add_theme_constant_override("margin_right", 96)
	add_child(margin)

	var outer: VBoxContainer = VBoxContainer.new()
	outer.add_theme_constant_override("separation", 22)
	margin.add_child(outer)

	outer.add_child(MenuFactory.make_title("PROJECT GRAVITY"))
	outer.add_child(MenuFactory.make_hint("Match Flow — Arena Alpha"))

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 60)
	outer.add_child(spacer)

	outer.add_child(MenuFactory.make_button("Jugar — Configurar Partida", _on_play))
	outer.add_child(MenuFactory.make_button("Ajustes", _on_settings))
	outer.add_child(MenuFactory.make_button("Salir", _on_quit))

func _on_play() -> void:
	push(MatchConfigScreen.new())

func _on_settings() -> void:
	push(SettingsScreen.new())

func _on_quit() -> void:
	get_tree().quit()