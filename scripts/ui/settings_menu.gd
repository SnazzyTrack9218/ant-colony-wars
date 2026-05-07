extends Control

signal back_requested

var _master_slider: HSlider
var _sfx_slider: HSlider
var _music_slider: HSlider
var _fullscreen_check: CheckBox
var _resolution_options: OptionButton


func _ready() -> void:
	size = get_viewport_rect().size
	_build_menu()
	_load_current_values()


func _build_menu() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var shade := ColorRect.new()
	shade.color = ColonyUITheme.SHADE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(440, 430)
	panel.add_theme_stylebox_override("panel", ColonyUITheme.panel_style(6, true))
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 12)
	margin.add_child(rows)

	var title := Label.new()
	title.text = "Settings"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ColonyUITheme.style_label(title, ColonyUITheme.TEXT_PRIMARY, 24)
	rows.add_child(title)

	_master_slider = _add_slider(rows, "Master Volume", "master_volume")
	_sfx_slider = _add_slider(rows, "SFX Volume", "sfx_volume")
	_music_slider = _add_slider(rows, "Music Volume", "music_volume")
	_fullscreen_check = _add_fullscreen_toggle(rows)
	_resolution_options = _add_resolution_options(rows)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.custom_minimum_size = Vector2(0, 36)
	ColonyUITheme.style_button(back_button)
	back_button.pressed.connect(Callable(self, "_on_back_pressed"))
	rows.add_child(back_button)


func _add_slider(parent: VBoxContainer, label_text: String, setting_key: String) -> HSlider:
	var label := Label.new()
	label.text = label_text
	ColonyUITheme.style_label(label, ColonyUITheme.TEXT_MUTED, ColonyUITheme.FONT_PRIMARY)
	parent.add_child(label)

	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value_changed.connect(Callable(self, "_on_slider_changed").bind(setting_key))
	parent.add_child(slider)
	return slider


func _add_fullscreen_toggle(parent: VBoxContainer) -> CheckBox:
	var check := CheckBox.new()
	check.text = "Fullscreen"
	check.add_theme_color_override("font_color", ColonyUITheme.TEXT_PRIMARY)
	check.toggled.connect(Callable(self, "_on_fullscreen_toggled"))
	parent.add_child(check)
	return check


func _add_resolution_options(parent: VBoxContainer) -> OptionButton:
	var options := OptionButton.new()
	options.add_item("1280 x 720")
	options.add_item("1600 x 900")
	options.add_item("1920 x 1080")
	ColonyUITheme.style_button(options)
	options.item_selected.connect(Callable(self, "_on_resolution_selected"))
	parent.add_child(options)
	return options


func _load_current_values() -> void:
	_master_slider.value = float(SettingsManager.get_value("master_volume", 1.0))
	_sfx_slider.value = float(SettingsManager.get_value("sfx_volume", 1.0))
	_music_slider.value = float(SettingsManager.get_value("music_volume", 0.7))
	_fullscreen_check.button_pressed = bool(SettingsManager.get_value("fullscreen", true))

	var width: int = int(SettingsManager.get_value("resolution_width", 1280))
	var height: int = int(SettingsManager.get_value("resolution_height", 720))
	var resolution_label: String = "%d x %d" % [width, height]
	for i in range(_resolution_options.get_item_count()):
		if _resolution_options.get_item_text(i) == resolution_label:
			_resolution_options.select(i)
			return
	_resolution_options.select(0)


func _on_slider_changed(value: float, setting_key: String) -> void:
	SettingsManager.set_value(setting_key, value)


func _on_fullscreen_toggled(enabled: bool) -> void:
	SettingsManager.set_value("fullscreen", enabled)


func _on_resolution_selected(index: int) -> void:
	var text: String = _resolution_options.get_item_text(index)
	var parts: PackedStringArray = text.split(" x ")
	if parts.size() != 2:
		return
	SettingsManager.set_value("resolution_width", int(parts[0]))
	SettingsManager.set_value("resolution_height", int(parts[1]))


func _on_back_pressed() -> void:
	back_requested.emit()

