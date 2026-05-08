extends Control

const MAIN_SCENE_PATH: String = "res://scenes/main/main.tscn"
const SettingsMenuScene: PackedScene = preload("res://scenes/ui/settings_menu.tscn")
const ControlsHelpScene: PackedScene = preload("res://scenes/ui/controls_help.tscn")

var _settings_menu: Control
var _controls_help: CanvasLayer


func _ready() -> void:
	size = get_viewport_rect().size
	_build_menu()


func _build_menu() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = ColonyUITheme.BG_DARK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 380)
	panel.add_theme_stylebox_override("panel", ColonyUITheme.panel_style(6, true))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 16)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Ant Colony Wars"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ColonyUITheme.style_label(title, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_TITLE)
	rows.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Build, feed, and defend the colony."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ColonyUITheme.style_label(subtitle, ColonyUITheme.TEXT_MUTED, ColonyUITheme.FONT_PRIMARY)
	rows.add_child(subtitle)

	_add_button(rows, "New Game", Callable(self, "_on_new_game_pressed"))
	_add_button(rows, "Controls", Callable(self, "_on_controls_pressed"))
	_add_button(rows, "Settings", Callable(self, "_on_settings_pressed"))
	_add_button(rows, "Quit", Callable(self, "_on_quit_pressed"))

	_settings_menu = SettingsMenuScene.instantiate()
	_settings_menu.visible = false
	_settings_menu.back_requested.connect(_on_settings_back_requested)
	add_child(_settings_menu)

	_controls_help = ControlsHelpScene.instantiate()
	add_child(_controls_help)


func _on_controls_pressed() -> void:
	_controls_help.show_help()


func _add_button(parent: VBoxContainer, button_text: String, callback: Callable) -> void:
	var button := Button.new()
	button.text = button_text
	button.custom_minimum_size = Vector2(0, 42)
	ColonyUITheme.style_button(button)
	button.pressed.connect(callback)
	parent.add_child(button)


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_settings_pressed() -> void:
	_settings_menu.visible = true


func _on_settings_back_requested() -> void:
	_settings_menu.visible = false


func _on_quit_pressed() -> void:
	get_tree().quit()
