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
		btn.text = _short_name(ROOM_TYPES[i])
		btn.toggle_mode = true
		btn.button_pressed = (i == _selected_index)
		btn.focus_mode = Control.FOCUS_NONE
		btn.tooltip_text = _full_name(ROOM_TYPES[i])
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


func _short_name(room_type: String) -> String:
	# Compact 2–3 letter labels — keep the panel narrow.
	match room_type:
		"nursery": return "Nur"
		"food_storage": return "Fd"
		"mushroom_farm": return "Mush"
		"guard_post": return "Grd"
		"soldier_barracks": return "Bar"
	return room_type.substr(0, 3).capitalize()


func _full_name(room_type: String) -> String:
	match room_type:
		"nursery": return "Nursery (1)"
		"food_storage": return "Food Storage (2)"
		"mushroom_farm": return "Mushroom Farm (3)"
		"guard_post": return "Guard Post (4)"
		"soldier_barracks": return "Soldier Barracks (5)"
	return room_type.capitalize()
