extends GutTest


func test_roundtrip() -> void:
	var log := SessionLog.new("test")
	log.log_event("chips", {"target": "pumps", "counts": [1, 2]})
	log.log_event("fit_result", {"priors": {}})
	assert_ne(log.save("user://test_sessions"), "")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(log.path))
	assert_eq(int(parsed.fits), 1)
	assert_eq(parsed.events.size(), 2)
	DirAccess.remove_absolute(log.path)
