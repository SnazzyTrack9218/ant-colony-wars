extends CanvasLayer

@onready var _food_label: Label = $FoodLabel
@onready var _ant_label: Label = $AntLabel
@onready var _hint_label: Label = get_node_or_null("HintLabel") as Label


func _ready() -> void:
	_style_labels()
	GameManager.food_changed.connect(_on_food_changed)
	GameManager.ant_count_changed.connect(_on_ant_count_changed)
	_on_food_changed(GameManager.colony.food)
	_on_ant_count_changed(GameManager.colony.ant_count)


func _style_labels() -> void:
	_food_label.offset_left = 12.0
	_food_label.offset_top = 10.0
	_food_label.offset_right = 220.0
	_food_label.offset_bottom = 34.0
	ColonyUITheme.style_label(_food_label, ColonyUITheme.ACCENT_AMBER, ColonyUITheme.FONT_HEADER)

	_ant_label.anchor_left = 1.0
	_ant_label.anchor_right = 1.0
	_ant_label.offset_left = -180.0
	_ant_label.offset_top = 10.0
	_ant_label.offset_right = -12.0
	_ant_label.offset_bottom = 34.0
	_ant_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ColonyUITheme.style_label(_ant_label, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_HEADER)

	if _hint_label != null:
		_hint_label.visible = false


func _on_food_changed(amount: int) -> void:
	_food_label.text = "%d / %d food" % [amount, GameManager.colony.max_food]


func _on_ant_count_changed(count: int) -> void:
	_ant_label.text = "%d workers" % count
