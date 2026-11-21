extends GutTest
## ExpertPanel: names, colours and the request for the server.

var panel: ExpertPanel
var persona: ExpertPersona


func before_each() -> void:
	panel = ExpertPanel.new()
	persona = ExpertPersona.new()
	persona.display_name = "Cautious expert"
	persona.character_name = "Mila"
	persona.color = Color.CORNFLOWER_BLUE


func test_default_names() -> void:
	assert_eq(panel.default_name(persona), "Mila")
	assert_eq(panel.default_name(null), "Expert 1")
	panel.add("Expert 1", {}, {})
	assert_eq(panel.default_name(null), "Expert 2")


func test_duplicate_names_get_a_number() -> void:
	assert_eq(panel.add("Mila", {}, {}, persona), "Mila")
	assert_eq(panel.add("Mila", {}, {}, persona), "Mila 2")
	assert_eq(panel.add("Mila", {}, {}, persona), "Mila 3")


func test_colours() -> void:
	panel.add("Mila", {}, {}, persona)
	panel.add("Ana", {}, {})
	panel.add("Ben", {}, {})
	assert_eq(panel.experts[0].color, Color.CORNFLOWER_BLUE, "personas bring their colour")
	assert_eq(panel.experts[1].color, ExpertPanel.COLORS[0])
	assert_eq(panel.experts[2].color, ExpertPanel.COLORS[1])


func test_answers_by_name_and_changes() -> void:
	watch_signals(panel)
	panel.add("Ana", {"pumps": [1, 2, 3, 4, 5]}, {})
	panel.add("Ben", {"pumps": [2, 3, 4, 5, 6]}, {})
	assert_eq(panel.answers_by_name(), {"Ana": {"pumps": [1, 2, 3, 4, 5]}, "Ben": {"pumps": [2, 3, 4, 5, 6]}})
	panel.remove_at(0)
	assert_eq(panel.answers_by_name().keys(), ["Ben"])
	panel.clear()
	assert_true(panel.is_empty())
	assert_signal_emit_count(panel, "changed", 4)
