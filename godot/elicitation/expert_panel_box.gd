class_name ExpertPanelBox
extends PanelContainer
## Overview of the experts collected for a panel: colour, name and a
## remove button each, plus "Clear". Shows an ExpertPanel; edits go back
## to it, and the box redraws on its `changed` signal.

const C_MUTED := Color("#6b6b6b")

var panel: ExpertPanel

@onready var _list: VBoxContainer = %PanelList
@onready var _clear_button: Button = %ClearPanelButton


func _ready() -> void:
	_clear_button.pressed.connect(func() -> void: panel.clear())
	if panel:
		_rebuild()


func show_panel(panel_: ExpertPanel) -> void:
	panel = panel_
	panel.changed.connect(_rebuild)
	if is_node_ready():
		_rebuild()


func set_editable(editable: bool) -> void:
	_clear_button.disabled = not editable or panel.is_empty()
	for row in _list.get_children():
		for child in row.get_children():
			if child is Button:
				child.disabled = not editable


func _rebuild() -> void:
	for child in _list.get_children():
		child.queue_free()
	_clear_button.disabled = panel.is_empty()
	if panel.is_empty():
		var empty := Label.new()
		empty.text = "No experts yet. Add them with \"Add to expert panel\"."
		empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		empty.add_theme_color_override("font_color", C_MUTED)
		empty.add_theme_font_size_override("font_size", 13)
		_list.add_child(empty)
		return
	for i in panel.size():
		var e: Dictionary = panel.experts[i]
		var row := HBoxContainer.new()
		var swatch := ColorRect.new()
		swatch.color = e.color
		swatch.custom_minimum_size = Vector2(12, 12)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(swatch)
		var label := Label.new()
		label.text = e.name
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var remove := Button.new()
		remove.text = "Remove"
		remove.flat = true
		remove.add_theme_font_size_override("font_size", 12)
		remove.pressed.connect(panel.remove_at.bind(i))
		row.add_child(remove)
		_list.add_child(row)
