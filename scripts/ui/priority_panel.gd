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
	"digging": "Digging",
	"building": "Building",
	"nursery": "Nursery",
	"soldiers": "Soldiers",
	"defense": "Defense",
	"raid": "Raid",
	"repair": "Repair",
}

var _level_labels: Dictionary = {}


func _ready() -> void:
	_build_panel()
	GameManager.priority_changed.connect(_on_priority_changed)
	_refresh_all()


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.offset_left = 0.0
	panel.offset_top = 0.0
	panel.offset_right = 240.0
	panel.offset_bottom = 270.0
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 4)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Priorities"
	title.add_theme_font_size_override("font_size", 16)
	rows.add_child(title)

	for category in CATEGORIES:
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 24)
		rows.add_child(row)

		var name_label := Label.new()
		name_label.text = LABELS.get(category, category.capitalize())
		name_label.custom_minimum_size = Vector2(78, 0)
		row.add_child(name_label)

		var minus_button := Button.new()
		minus_button.text = "-"
		minus_button.custom_minimum_size = Vector2(28, 24)
		minus_button.pressed.connect(_cycle_priority.bind(category, -1))
		row.add_child(minus_button)

		var level_label := Label.new()
		level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		level_label.custom_minimum_size = Vector2(78, 0)
		row.add_child(level_label)
		_level_labels[category] = level_label

		var plus_button := Button.new()
		plus_button.text = "+"
		plus_button.custom_minimum_size = Vector2(28, 24)
		plus_button.pressed.connect(_cycle_priority.bind(category, 1))
		row.add_child(plus_button)


func _cycle_priority(category: String, direction: int) -> void:
	GameManager.cycle_priority(category, direction)


func _refresh_all() -> void:
	for category in CATEGORIES:
		_refresh_category(category)


func _refresh_category(category: String) -> void:
	if not (category in _level_labels):
		return
	var level: String = GameManager.colony.priorities.get(category, "normal")
	_level_labels[category].text = level.capitalize()


func _on_priority_changed(category: String, _level: String) -> void:
	_refresh_category(category)
