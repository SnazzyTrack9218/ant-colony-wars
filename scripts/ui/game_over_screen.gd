extends CanvasLayer

const SettingsManagerScript = preload("res://scripts/core/settings_manager.gd")

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _subtitle: Label = $Panel/VBox/Subtitle
@onready var _restart_btn: Button = $Panel/VBox/RestartButton
@onready var _menu_btn: Button = $Panel/VBox/MenuButton
@onready var _bg: ColorRect = $Background


func _ready() -> void:
	visible = false
	_apply_theme()
	_restart_btn.pressed.connect(_on_restart_pressed)
	_menu_btn.pressed.connect(_on_menu_pressed)
	GameManager.queen_damaged.connect(_on_queen_damaged)


func _apply_theme() -> void:
	_bg.color = Color(ColonyUITheme.BG_DARK.r, ColonyUITheme.BG_DARK.g, ColonyUITheme.BG_DARK.b, 0.78)
	_panel.add_theme_stylebox_override("panel", ColonyUITheme.panel_style(6, true))
	ColonyUITheme.style_label(_title, ColonyUITheme.ACCENT_RED, ColonyUITheme.FONT_TITLE)
	ColonyUITheme.style_label(_subtitle, ColonyUITheme.TEXT_MUTED, ColonyUITheme.FONT_PRIMARY)
	ColonyUITheme.style_button(_restart_btn)
	ColonyUITheme.style_button(_menu_btn)


func _on_queen_damaged(current_hp: int, _max_hp: int) -> void:
	if current_hp <= 0:
		show_screen()


func show_screen() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _on_restart_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
