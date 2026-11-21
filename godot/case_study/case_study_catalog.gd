class_name CaseStudyCatalog
extends Resource
## The case studies the gallery shows, in order.

@export var case_studies: Array[CaseStudy] = []


## The case study with this id, or null.
func find(case_id: String) -> CaseStudy:
	for c in case_studies:
		if c.id == case_id:
			return c
	return null
