extends CanvasLayer

# Pause menu — Esc toggles. Resume / Controls / Main Menu / Quit.
# When visible, paused tree, mouse confined to UI.

const ControlsHelpScene: PackedScene = preload("res://scenes/ui/controls_help.tscn")

@onready var _bg: ColorRect = $Background
@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _resume_btn: Button = $Panel/VBox/Resume
@onready var _controls_btn: Button = $Panel/VBox/Controls
@onready var _menu_btn: Button = $Panel/VBox/MainMenu
@onready var _quit_btn: Button = $Panel/VBox/Quit

var _controls_help: CanvasLayer = null


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme()
	_resume_btn.pressed.connect(_on_resume)
	_controls_btn.pressed.connect(_on_controls)
	_menu_btn.pressed.connect(_on_main_menu)
	_quit_btn.pressed.connect(_on_quit)


func _apply_theme() -> void:
	_bg.color = Color(ColonyUITheme.BG_DARK.r, ColonyUITheme.BG_DARK.g, ColonyUITheme.BG_DARK.b, 0.78)
	_panel.add_theme_stylebox_override("panel", ColonyUITheme.panel_style(6, true))
	ColonyUITheme.style_label(_title, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_HEADER)
	for btn in [_resume_btn, _controls_btn, _menu_btn, _quit_btn]:
		ColonyUITheme.style_button(btn)


func _unhandled_input(event: InputEvent) -> void:
	# Use _unhandled_input so the controls help (which uses _input + set_input_as_handled)
	# can swallow Esc first when it's open.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if visible:
		_close()
	else:
		_open()


func _open() -> void:
	visible = true
	get_tree().paused = true


func _close() -> void:
	visible = false
	get_tree().paused = false


func _on_resume() -> void:
	_close()


func _on_controls() -> void:
	if _controls_help == null:
		_controls_help = ControlsHelpScene.instantiate()
		add_child(_controls_help)
	_controls_help.show_help()


func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit() -> void:
	get_tree().quit()
