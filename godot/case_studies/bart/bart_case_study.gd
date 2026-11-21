class_name BartCaseStudy
extends CaseStudy
## The Balloon Analogue Risk Task: money per pump, and the chance that a
## pump pops the balloon.

## Money per pump, shown in the predictions (0 hides the money).
@export var reward_per_pump: float = 0.05
## Chance that one pump pops the balloon.
@export var burst_probability: float = 0.15
@export var currency: String = "€"


## Fills {reward} and {burst} in the intro.
func intro_text() -> String:
	return intro.format({
		"reward": money(reward_per_pump),
		"burst": "%d%%" % roundi(burst_probability * 100.0),
	})


func money(amount: float) -> String:
	return "%s%.2f" % [currency, amount]
