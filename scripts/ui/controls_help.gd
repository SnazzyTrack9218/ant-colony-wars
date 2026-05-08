extends CanvasLayer

# Controls reference panel. Shown from the pause menu and the main-menu Settings.
# Esc / close button hides it.

const CONTROLS: Array = [
	{"keys": "Left-click dirt", "action": "Place a Dig Marker — workers will dig there."},
	{"keys": "Left-click dig marker", "action": "Cancel that dig order."},
	{"keys": "Right-click tunnel", "action": "Place a Room Plan blueprint of the selected room."},
	{"keys": "Middle-click tunnel", "action": "Place a Rally Marker — soldiers go and hold position."},
	{"keys": "Middle-click rally marker", "action": "Cancel that rally order; soldiers return to patrol."},
	{"keys": "Shift + Left-click", "action": "Repair Marker on a damaged room — workers haul food to repair."},
	{"keys": "Shift + Right-click", "action": "Emergency Marker on dirt — every idle worker drops everything to dig there."},
	{"keys": "1 – 5", "action": "Pick which room type the next right-click will place."},
	{"keys": "B", "action": "Cycle through room types."},
	{"keys": "U", "action": "Toggle the Upgrades panel."},
	{"keys": "Esc", "action": "Open the pause menu (or close this help screen)."},
	{"keys": "WASD / Arrow keys", "action": "Pan the camera around the map."},
	{"keys": "Mouse wheel", "action": "Zoom in / out."},
	{"keys": "Autopilot", "action": "The colony auto-places rooms and auto-buys upgrades on its own. You can override anytime."},
]

@onready var _bg: ColorRect = $Background
@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/VBox/Title
@onready var _grid: GridContainer = $Panel/VBox/ScrollContainer/Grid
@onready var _close_btn: Button = $Panel/VBox/Close


func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_apply_theme()
	_populate()
	_close_btn.pressed.connect(hide_help)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_H:
			hide_help()
			get_viewport().set_input_as_handled()


func _apply_theme() -> void:
	_bg.color = Color(ColonyUITheme.BG_DARK.r, ColonyUITheme.BG_DARK.g, ColonyUITheme.BG_DARK.b, 0.92)
	_panel.add_theme_stylebox_override("panel", ColonyUITheme.panel_style(6, true))
	ColonyUITheme.style_label(_title, ColonyUITheme.ACCENT_AMBER, ColonyUITheme.FONT_HEADER)
	ColonyUITheme.style_button(_close_btn)


func _populate() -> void:
	for entry in CONTROLS:
		var key_label := Label.new()
		key_label.text = String(entry["keys"])
		key_label.custom_minimum_size = Vector2(180, 0)
		ColonyUITheme.style_label(key_label, ColonyUITheme.ACCENT_AMBER, ColonyUITheme.FONT_PRIMARY)
		_grid.add_child(key_label)

		var action_label := Label.new()
		action_label.text = String(entry["action"])
		action_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		action_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ColonyUITheme.style_label(action_label, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_PRIMARY)
		_grid.add_child(action_label)


func show_help() -> void:
	visible = true


func hide_help() -> void:
	visible = false
