extends Control

const CATEGORIES: Array[String] = [
	"food",
	"digging",
	"building",
	"nursery",
	"soldiers",
	"defense",
	"raid",
	"repair",
]

const LABELS: Dictionary = {
	"food": "Food",
	"digging": "Dig",
	"building": "Build",
	"nursery": "Nursery",
	"soldiers": "Soldiers",
	"defense": "Defense",
	"raid": "Raid",
	"repair": "Repair",
}

var _expanded_panel: PanelContainer
var _toggle_button: Button
var _level_labels: Dictionary = {}
var _dot_nodes: Dictionary = {}
var _is_expanded: bool = false
var _panel_tween: Tween


func _ready() -> void:
	_position_bottom_right()
	_build_panel()
	GameManager.priority_changed.connect(_on_priority_changed)
	_refresh_all()
	_collapse(true)


func _position_bottom_right() -> void:
	anchor_left = 1.0
	anchor_top = 1.0
	anchor_right = 1.0
	anchor_bottom = 1.0
	offset_left = -252.0
	offset_top = -292.0
	offset_right = -12.0
	offset_bottom = -12.0
	mouse_filter = Control.MOUSE_FILTER_STOP


func _build_panel() -> void:
	_expanded_panel = PanelContainer.new()
	_expanded_panel.add_theme_stylebox_override("panel", ColonyUITheme.panel_style())
	_expanded_panel.offset_left = 0.0
	_expanded_panel.offset_top = 0.0
	_expanded_panel.offset_right = 240.0
	_expanded_panel.offset_bottom = 248.0
	add_child(_expanded_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	_expanded_panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Priorities"
	ColonyUITheme.style_label(title, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_HEADER)
	rows.add_child(title)

	for category in CATEGORIES:
		rows.add_child(_make_priority_row(category))

	_toggle_button = Button.new()
	_toggle_button.add_theme_stylebox_override("normal", ColonyUITheme.panel_style())
	_toggle_button.add_theme_stylebox_override("hover", ColonyUITheme.button_style(ColonyUITheme.PANEL_SURFACE_HOVER))
	_toggle_button.add_theme_stylebox_override("pressed", ColonyUITheme.button_style(ColonyUITheme.PANEL_SURFACE_PRESSED))
	_toggle_button.offset_left = 86.0
	_toggle_button.offset_top = 250.0
	_toggle_button.offset_right = 240.0
	_toggle_button.offset_bottom = 280.0
	_toggle_button.text = ""
	_toggle_button.pressed.connect(_toggle_expanded)
	add_child(_toggle_button)

	var dot_margin := MarginContainer.new()
	dot_margin.add_theme_constant_override("margin_left", 9)
	dot_margin.add_theme_constant_override("margin_top", 8)
	dot_margin.add_theme_constant_override("margin_right", 9)
	dot_margin.add_theme_constant_override("margin_bottom", 8)
	_toggle_button.add_child(dot_margin)

	var dots := HBoxContainer.new()
	dots.add_theme_constant_override("separation", 6)
	dot_margin.add_child(dots)
	for category in CATEGORIES:
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(8, 8)
		dot.color = ColonyUITheme.priority_color("normal")
		dots.add_child(dot)
		_dot_nodes[category] = dot


func _make_priority_row(category: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 21)
	row.add_theme_constant_override("separation", 5)

	var name_label := Label.new()
	name_label.text = LABELS.get(category, category.capitalize())
	ColonyUITheme.style_label(name_label, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_PRIMARY)
	name_label.custom_minimum_size = Vector2(68, 0)
	row.add_child(name_label)

	var minus_button := _make_button("-")
	minus_button.pressed.connect(_cycle_priority.bind(category, -1))
	row.add_child(minus_button)

	var level_label := Label.new()
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ColonyUITheme.style_label(level_label, ColonyUITheme.TEXT_MUTED, ColonyUITheme.FONT_PRIMARY)
	level_label.custom_minimum_size = Vector2(72, 0)
	row.add_child(level_label)
	_level_labels[category] = level_label

	var plus_button := _make_button("+")
	plus_button.pressed.connect(_cycle_priority.bind(category, 1))
	row.add_child(plus_button)
	return row


func _make_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(24, 21)
	ColonyUITheme.style_button(button)
	return button


func _cycle_priority(category: String, direction: int) -> void:
	GameManager.cycle_priority(category, direction)


func _refresh_all() -> void:
	for category in CATEGORIES:
		_refresh_category(category)


func _refresh_category(category: String) -> void:
	var level: String = GameManager.colony.priorities.get(category, "normal")
	var color: Color = ColonyUITheme.priority_color(level)
	if category in _level_labels:
		_level_labels[category].text = level.capitalize()
		_level_labels[category].add_theme_color_override("font_color", color)
	if category in _dot_nodes:
		_dot_nodes[category].color = color


func _on_priority_changed(category: String, _level: String) -> void:
	_refresh_category(category)


func _expand() -> void:
	if _is_expanded:
		return
	_is_expanded = true
	_expanded_panel.visible = true
	_tween_panel_alpha(1.0)


func _collapse(force: bool = false) -> void:
	if not force and not _is_expanded:
		return
	_is_expanded = false
	if force:
		_expanded_panel.visible = false
		return
	_tween_panel_alpha(0.0)


func _toggle_expanded() -> void:
	if _is_expanded:
		_collapse()
	else:
		_expand()


func _tween_panel_alpha(target_alpha: float) -> void:
	if is_instance_valid(_panel_tween):
		_panel_tween.kill()
	if target_alpha > 0.0:
		_expanded_panel.modulate.a = 0.0
	_panel_tween = create_tween()
	_panel_tween.tween_property(_expanded_panel, "modulate:a", target_alpha, 0.16)
	if target_alpha <= 0.0:
		_panel_tween.tween_callback(_hide_expanded_panel)


func _hide_expanded_panel() -> void:
	_expanded_panel.visible = false
