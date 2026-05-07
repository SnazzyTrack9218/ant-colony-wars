extends CanvasLayer

@onready var _food_label: Label = $FoodLabel
@onready var _worker_label: Label = $AntLabel
@onready var _soldier_label: Label = $SoldierLabel
@onready var _hint_label: Label = get_node_or_null("HintLabel") as Label


func _ready() -> void:
	_style_labels()
	GameManager.food_changed.connect(_on_food_changed)
	GameManager.worker_count_changed.connect(_on_worker_count_changed)
	GameManager.soldier_count_changed.connect(_on_soldier_count_changed)
	_on_food_changed(GameManager.colony.food)
	_on_worker_count_changed(GameManager.colony.worker_count, GameManager.colony.max_workers)
	_on_soldier_count_changed(GameManager.colony.soldier_count)


func _style_labels() -> void:
	_food_label.offset_left = 12.0
	_food_label.offset_top = 10.0
	_food_label.offset_right = 220.0
	_food_label.offset_bottom = 34.0
	ColonyUITheme.style_label(_food_label, ColonyUITheme.ACCENT_AMBER, ColonyUITheme.FONT_HEADER)

	_worker_label.anchor_left = 1.0
	_worker_label.anchor_right = 1.0
	_worker_label.offset_left = -200.0
	_worker_label.offset_top = 10.0
	_worker_label.offset_right = -12.0
	_worker_label.offset_bottom = 34.0
	_worker_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ColonyUITheme.style_label(_worker_label, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_HEADER)

	_soldier_label.anchor_left = 1.0
	_soldier_label.anchor_right = 1.0
	_soldier_label.offset_left = -200.0
	_soldier_label.offset_top = 34.0
	_soldier_label.offset_right = -12.0
	_soldier_label.offset_bottom = 56.0
	_soldier_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ColonyUITheme.style_label(_soldier_label, ColonyUITheme.ACCENT_RED, ColonyUITheme.FONT_PRIMARY)

	if _hint_label != null:
		_hint_label.visible = false


func _on_food_changed(amount: int) -> void:
	_food_label.text = "%d / %d food" % [amount, GameManager.colony.max_food]


func _on_worker_count_changed(count: int, max_count: int) -> void:
	_worker_label.text = "%d / %d workers" % [count, max_count]
	# Highlight in red when at cap so the player knows the nursery is idle.
	if count >= max_count:
		ColonyUITheme.style_label(_worker_label, ColonyUITheme.ACCENT_RED, ColonyUITheme.FONT_HEADER)
	else:
		ColonyUITheme.style_label(_worker_label, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_HEADER)


func _on_soldier_count_changed(count: int) -> void:
	if count == 0:
		_soldier_label.text = ""
	else:
		_soldier_label.text = "%d soldiers" % count
