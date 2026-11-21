class_name ExpertPersona
extends Resource
## A role the user can play while placing chips: an expert who knows one
## kind of participant well. Each case study subclasses this to say how
## that participant behaves (simulate) and what sets them apart (traits).

@export var display_name: String = ""
@export_multiline var briefing: String = ""
@export var color: Color = Color.WHITE

@export_group("Character")
## The kind of participant this expert knows, shown on the Training personas tab.
@export var character_name: String = ""
@export var tagline: String = ""
## BBCode: the participant's cognitive attitude.
@export_multiline var profile: String = ""
@export var portrait: Texture2D
@export_group("")


## Answers of this persona: `n` simulated outcomes per target, keyed by
## target name. The same seed gives the same answer every time.
func simulate(_n: int, _seed: int = 1) -> Dictionary:
	push_error("%s must override simulate()" % resource_path)
	return {}


## What sets this participant apart, for the meters on the persona card:
## [{"name": "Risk taking", "level": 0..1}, ...].
func traits() -> Array[Dictionary]:
	return []


## "low", "medium" or "high" for a level between 0 and 1.
static func level_name(level: float) -> String:
	return "low" if level < 0.25 else ("medium" if level < 0.6 else "high")
