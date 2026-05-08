extends PanelContainer
class_name RoomPicker

signal selection_changed(room_type: String)

# Order matches main.gd ROOM_TYPE_ORDER so keyboard 1–5 still align.
const ROOM_TYPES: Array[String] = [
	"nursery",
	"food_storage",
	"mushroom_farm",
	"guard_post",
	"soldier_barracks",
]

var _selected_index: int = 0
var _buttons: Array[Button] = []

@onready var _row: HBoxContainer = $Row


func _ready() -> void:
	add_theme_stylebox_override("panel", ColonyUITheme.panel_style(4, true))
	for i in ROOM_TYPES.size():
		var btn := Button.new()
		btn.text = _label_text(ROOM_TYPES[i], i)
		btn.toggle_mode = true
		btn.button_pressed = (i == _selected_index)
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = _tooltip_text(ROOM_TYPES[i])
		btn.custom_minimum_size = Vector2(96, 30)  # Even width across all 5 buttons.
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.clip_text = true
		ColonyUITheme.style_button(btn)
		var index: int = i
		btn.pressed.connect(_on_button_pressed.bind(index))
		_row.add_child(btn)
		_buttons.append(btn)


func set_selection(index: int) -> void:
	if index < 0 or index >= ROOM_TYPES.size():
		return
	_selected_index = index
	for i in _buttons.size():
		_buttons[i].button_pressed = (i == _selected_index)
	selection_changed.emit(ROOM_TYPES[_selected_index])


func get_selection() -> String:
	return ROOM_TYPES[_selected_index]


func _on_button_pressed(index: int) -> void:
	set_selection(index)


func _label_text(room_type: String, index: int) -> String:
	# Number prefix + clear word. All buttons same width so the row is even.
	var name: String = ""
	match room_type:
		"nursery": name = "Nursery"
		"food_storage": name = "Food"
		"mushroom_farm": name = "Farm"
		"guard_post": name = "Guard"
		"soldier_barracks": name = "Barracks"
		_: name = room_type.capitalize()
	return "%d  %s" % [index + 1, name]


func _tooltip_text(room_type: String) -> String:
	# Show full description + cost on hover.
	var config: Dictionary = {}
	if GameManager.room_manager != null and GameManager.room_manager._configs.has(room_type):
		config = GameManager.room_manager._configs[room_type]
	var display: String = String(config.get("display_name", room_type.capitalize()))
	var cost: int = int(config.get("build_cost", 0))
	return "%s — costs %d food. Right-click a tunnel tile to place." % [display, cost]
