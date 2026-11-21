extends SceneTree
## Builds the app's light Theme resource in code (palette in one place):
##   godot --headless --path godot -s res://tools/build_theme.gd
## project.godot points gui/theme/custom at the result.

const BG_PANEL := Color("#fffdf8")
const BORDER := Color("#e2dccf")
const INK := Color("#1f2a44")
const TEXT := Color("#3b3b3b")
const MUTED := Color("#6b6b6b")
const ACCENT := Color("#f2b84b")
const ACCENT_SOFT := Color("#fff3d6")
const DISABLED_BG := Color("#eeeae2")
const DISABLED_TEXT := Color("#a8a39a")


func _initialize() -> void:
	var err := ResourceSaver.save(build(), "res://theme/app_theme.tres")
	print("app_theme.tres: ", error_string(err))
	quit(err)


func box(bg: Color, border := Color.TRANSPARENT, border_w := 0, radius := 6, pad := Vector4(12, 6, 12, 6)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_w)
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad.x
	s.content_margin_top = pad.y
	s.content_margin_right = pad.z
	s.content_margin_bottom = pad.w
	return s


func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15

	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("normal", "RichTextLabel", StyleBoxEmpty.new())

	# buttons
	t.set_stylebox("normal", "Button", box(BG_PANEL, BORDER, 1))
	t.set_stylebox("hover", "Button", box(ACCENT_SOFT, ACCENT, 1))
	t.set_stylebox("pressed", "Button", box(ACCENT, ACCENT, 1))
	t.set_stylebox("disabled", "Button", box(DISABLED_BG, BORDER, 1))
	var focus := box(Color.TRANSPARENT, INK, 2)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", INK)
	t.set_color("font_disabled_color", "Button", DISABLED_TEXT)

	# primary button: a type variation, used by the Fit button
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(INK, INK, 1, 6, Vector4(16, 7, 16, 7)))
	t.set_stylebox("hover", "PrimaryButton", box(INK.lightened(0.15), ACCENT, 1, 6, Vector4(16, 7, 16, 7)))
	t.set_stylebox("pressed", "PrimaryButton", box(ACCENT, ACCENT, 1, 6, Vector4(16, 7, 16, 7)))
	t.set_stylebox("disabled", "PrimaryButton", box(DISABLED_BG, BORDER, 1, 6, Vector4(16, 7, 16, 7)))
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		t.set_color(c, "PrimaryButton", Color.WHITE)
	t.set_color("font_pressed_color", "PrimaryButton", INK)

	# tabs
	t.set_stylebox("panel", "TabContainer", box(BG_PANEL, BORDER, 1, 6, Vector4(12, 10, 12, 10)))
	var sel := box(BG_PANEL, BORDER, 1, 6, Vector4(14, 6, 14, 6))
	sel.border_width_bottom = 0  # the selected tab merges into the panel
	sel.corner_radius_bottom_left = 0
	sel.corner_radius_bottom_right = 0
	t.set_stylebox("tab_selected", "TabContainer", sel)
	var unsel := box(Color("#ebe6da"), BORDER, 1, 6, Vector4(14, 6, 14, 6))
	unsel.corner_radius_bottom_left = 0
	unsel.corner_radius_bottom_right = 0
	t.set_stylebox("tab_unselected", "TabContainer", unsel)
	var hov := unsel.duplicate()
	hov.bg_color = ACCENT_SOFT
	t.set_stylebox("tab_hovered", "TabContainer", hov)
	t.set_color("font_selected_color", "TabContainer", INK)
	t.set_color("font_unselected_color", "TabContainer", MUTED)
	t.set_color("font_hovered_color", "TabContainer", INK)

	# plain panels (e.g. the expert panel box) and text fields
	t.set_stylebox("panel", "PanelContainer", box(BG_PANEL, BORDER, 1, 6, Vector4(12, 10, 12, 10)))
	t.set_stylebox("normal", "LineEdit", box(Color.WHITE, BORDER, 1, 6, Vector4(8, 5, 8, 5)))
	t.set_stylebox("focus", "LineEdit", focus)
	t.set_stylebox("read_only", "LineEdit", box(DISABLED_BG, BORDER, 1, 6, Vector4(8, 5, 8, 5)))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", DISABLED_TEXT)
	t.set_color("caret_color", "LineEdit", INK)

	# pop-up windows and dialogs (e.g. Training settings)
	var frame := box(BG_PANEL, BORDER, 1, 8, Vector4.ZERO)
	frame.expand_margin_left = 8
	frame.expand_margin_right = 8
	frame.expand_margin_bottom = 8
	frame.expand_margin_top = 34  # room for the title bar
	frame.shadow_color = Color(0, 0, 0, 0.18)
	frame.shadow_size = 10
	t.set_stylebox("embedded_border", "Window", frame)
	t.set_stylebox("embedded_unfocused_border", "Window", frame)
	t.set_color("title_color", "Window", INK)
	t.set_font_size("title_font_size", "Window", 16)
	t.set_stylebox("panel", "AcceptDialog", box(BG_PANEL, Color.TRANSPARENT, 0, 0, Vector4(16, 14, 16, 14)))

	# progress bar
	t.set_stylebox("background", "ProgressBar", box(Color("#e8e2d4"), Color.TRANSPARENT, 0, 4, Vector4.ZERO))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, Color.TRANSPARENT, 0, 4, Vector4.ZERO))
	return t
