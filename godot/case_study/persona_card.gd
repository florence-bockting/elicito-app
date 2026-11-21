class_name PersonaCard
extends PanelContainer
## One training persona: portrait, the participant they know, one meter
## per trait and a "Play as" button.

signal play_requested(persona: ExpertPersona)

var persona: ExpertPersona

@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %CharacterName
@onready var _role: Label = %Role
@onready var _tagline: Label = %Tagline
@onready var _meters: GridContainer = %Meters
@onready var _profile: RichTextLabel = %Profile
@onready var _play_button: Button = %PlayButton


func _ready() -> void:
	_play_button.pressed.connect(func() -> void: play_requested.emit(persona))
	if persona:
		_show()


## Call before or after the card enters the tree.
func setup(p: ExpertPersona) -> void:
	persona = p
	if is_node_ready():
		_show()


func _show() -> void:
	_portrait.texture = persona.portrait
	_name.text = persona.character_name
	_role.text = "known by the %s" % persona.display_name.to_lower()
	_tagline.text = persona.tagline
	_profile.text = persona.profile
	_play_button.text = "Play as the %s" % persona.display_name.to_lower()
	for child in _meters.get_children():
		child.queue_free()
	for t in persona.traits():
		_add_meter(t.name, t.level)

	var style := StyleBoxFlat.new()
	style.bg_color = persona.color.lerp(Color.WHITE, 0.88)
	style.border_color = persona.color
	style.border_width_top = 6
	style.set_corner_radius_all(8)
	style.set_content_margin_all(14)
	add_theme_stylebox_override("panel", style)


## One row of the meters grid: name, bar, "low/medium/high".
func _add_meter(trait_name: String, level: float) -> void:
	var label := Label.new()
	label.text = trait_name
	label.add_theme_font_size_override("font_size", 13)
	_meters.add_child(label)

	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.show_percentage = false
	bar.value = level * 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = persona.color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	_meters.add_child(bar)

	var level_label := Label.new()
	level_label.text = ExpertPersona.level_name(level)
	level_label.custom_minimum_size = Vector2(58, 0)
	level_label.add_theme_font_size_override("font_size", 13)
	_meters.add_child(level_label)
