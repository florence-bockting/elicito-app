class_name ExpertPanel
extends RefCounted
## The experts collected for a panel fit, in the order they were added.
## Each expert: {"name", "color", "answers", "histograms", "persona"}.

signal changed

## Colours for experts who are not a persona (personas bring their own).
const COLORS: Array[Color] = [
	Color("#7b5ea7"), Color("#2a9d8f"), Color("#d1495b"), Color("#457b9d"), Color("#8d6e63"), Color("#43aa8b"),
]
const MYSELF := "myself"

var experts: Array[Dictionary] = []


func size() -> int:
	return experts.size()


func is_empty() -> bool:
	return experts.is_empty()


## Adds an expert and returns the name it got: a second "Mila" becomes "Mila 2".
## `persona` is null when the user answered as themselves.
func add(expert_name: String, answers: Dictionary, histograms: Dictionary, persona: ExpertPersona = null) -> String:
	var unique := expert_name
	var k := 2
	while has(unique):
		unique = "%s %d" % [expert_name, k]
		k += 1
	var color := persona.color if persona else COLORS[_own_count() % COLORS.size()]
	experts.append({
		"name": unique,
		"color": color,
		"answers": answers,
		"histograms": histograms,
		"persona": persona.display_name if persona else MYSELF,
	})
	changed.emit()
	return unique


func remove_at(index: int) -> void:
	experts.remove_at(index)
	changed.emit()


func clear() -> void:
	experts.clear()
	changed.emit()


func has(expert_name: String) -> bool:
	return experts.any(func(e: Dictionary) -> bool: return e.name == expert_name)


## The name an expert gets when the user types none.
func default_name(persona: ExpertPersona) -> String:
	if persona:
		return persona.character_name
	return "Expert %d" % (_own_count() + 1)


## {name: answers}, as the server expects for a panel fit.
func answers_by_name() -> Dictionary:
	var out := {}
	for e in experts:
		out[e.name] = e.answers
	return out


func _own_count() -> int:
	return experts.filter(func(e: Dictionary) -> bool: return e.persona == MYSELF).size()
