extends Control
class_name UpgradesPanel

# Bottom-left collapsible upgrade browser. Toggle with `U`.
# Each upgrade row: name, level dots, cost, [Buy] button.
# Buy button is disabled if cost > food or upgrade is maxed.

const UPGRADE_ORDER: Array[String] = [
	"dig_speed",
	"carry_capacity",
	"ant_limit",
	"faster_hatch",
	"soldier_damage",
]

var _expanded: bool = false
var _toggle_btn: Button = null
var _panel: PanelContainer = null
var _list: VBoxContainer = null
var _row_buttons: Dictionary = {}  # upgrade_id -> Button
var _row_labels: Dictionary = {}  # upgrade_id -> Dictionary {name, level, cost}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # let children handle clicks; ignore the wrapper
	_build_ui()
	_set_expanded(false)
	GameManager.upgrades.upgrade_changed.connect(_on_upgrade_changed)
	GameManager.food_changed.connect(_on_food_changed)
	_refresh_all_rows()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_U:
		_set_expanded(not _expanded)


func _build_ui() -> void:
	# Toggle button (always visible, bottom-left of viewport).
	_toggle_btn = Button.new()
	_toggle_btn.text = "Upgrades (U)"
	_toggle_btn.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_toggle_btn.offset_left = 10
	_toggle_btn.offset_top = -38
	_toggle_btn.offset_right = 130
	_toggle_btn.offset_bottom = -10
	_toggle_btn.focus_mode = Control.FOCUS_NONE
	ColonyUITheme.style_button(_toggle_btn)
	_toggle_btn.pressed.connect(func(): _set_expanded(not _expanded))
	add_child(_toggle_btn)

	# Panel above the toggle, opens upward.
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_panel.offset_left = 10
	_panel.offset_top = -330
	_panel.offset_right = 270
	_panel.offset_bottom = -44
	_panel.add_theme_stylebox_override("panel", ColonyUITheme.panel_style(4, true))
	add_child(_panel)

	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 6)
	_panel.add_child(_list)

	for upgrade_id in UPGRADE_ORDER:
		_add_row(upgrade_id)


func _add_row(upgrade_id: String) -> void:
	var config: Dictionary = GameManager.upgrades.get_config(upgrade_id)
	if config.is_empty():
		return
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_list.add_child(row)

	var name_label := Label.new()
	name_label.text = String(config.get("display_name", upgrade_id))
	name_label.custom_minimum_size = Vector2(96, 0)
	ColonyUITheme.style_label(name_label, ColonyUITheme.TEXT_PRIMARY, ColonyUITheme.FONT_PRIMARY)
	row.add_child(name_label)

	var level_label := Label.new()
	level_label.custom_minimum_size = Vector2(48, 0)
	level_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ColonyUITheme.style_label(level_label, ColonyUITheme.ACCENT_AMBER, ColonyUITheme.FONT_PRIMARY)
	row.add_child(level_label)

	var cost_label := Label.new()
	cost_label.custom_minimum_size = Vector2(40, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	ColonyUITheme.style_label(cost_label, ColonyUITheme.TEXT_MUTED, ColonyUITheme.FONT_MUTED)
	row.add_child(cost_label)

	var btn := Button.new()
	btn.text = "Buy"
	btn.focus_mode = Control.FOCUS_NONE
	btn.custom_minimum_size = Vector2(48, 0)
	ColonyUITheme.style_button(btn)
	btn.pressed.connect(func(): _on_buy_pressed(upgrade_id))
	row.add_child(btn)

	_row_buttons[upgrade_id] = btn
	_row_labels[upgrade_id] = {"level": level_label, "cost": cost_label}


func _on_buy_pressed(upgrade_id: String) -> void:
	GameManager.upgrades.purchase(upgrade_id)


func _on_upgrade_changed(upgrade_id: String, _new_level: int) -> void:
	_refresh_row(upgrade_id)


func _on_food_changed(_amount: int) -> void:
	# Refresh all buy buttons since food affects affordability.
	_refresh_all_rows()


func _refresh_all_rows() -> void:
	for upgrade_id in UPGRADE_ORDER:
		_refresh_row(upgrade_id)


func _refresh_row(upgrade_id: String) -> void:
	if not (upgrade_id in _row_buttons):
		return
	var btn: Button = _row_buttons[upgrade_id]
	var labels: Dictionary = _row_labels[upgrade_id]
	var level: int = GameManager.upgrades.get_level(upgrade_id)
	var max_level: int = GameManager.upgrades.get_max_level(upgrade_id)
	(labels["level"] as Label).text = "%d / %d" % [level, max_level]
	if GameManager.upgrades.is_maxed(upgrade_id):
		(labels["cost"] as Label).text = "MAX"
		btn.disabled = true
		btn.text = "—"
	else:
		var cost: int = GameManager.upgrades.get_next_cost(upgrade_id)
		(labels["cost"] as Label).text = "%d" % cost
		btn.disabled = not GameManager.upgrades.can_purchase(upgrade_id)
		btn.text = "Buy"


func _set_expanded(expanded: bool) -> void:
	_expanded = expanded
	if _panel != null:
		_panel.visible = _expanded
