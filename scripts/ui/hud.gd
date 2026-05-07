extends CanvasLayer

@onready var _food_label: Label = $FoodLabel
@onready var _ant_label: Label = $AntLabel


func _ready() -> void:
	GameManager.food_changed.connect(_on_food_changed)
	GameManager.ant_count_changed.connect(_on_ant_count_changed)
	_on_food_changed(GameManager.colony.food)
	_on_ant_count_changed(GameManager.colony.ant_count)


func _on_food_changed(amount: int) -> void:
	_food_label.text = "Food: %d / %d" % [amount, GameManager.colony.max_food]


func _on_ant_count_changed(count: int) -> void:
	_ant_label.text = "Workers: %d" % count
