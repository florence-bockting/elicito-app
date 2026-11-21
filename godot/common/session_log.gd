class_name SessionLog
extends RefCounted
## Audit trail of one elicitation session: every chip move, fit request
## and fit result, with timestamps. Saved as JSON after each fit, so the
## elicitation can be reported and reproduced.

var case_id := ""
var started_at := ""
var events: Array = []
var path := ""


func _init(case_id_: String = "") -> void:
	case_id = case_id_
	started_at = Time.get_datetime_string_from_system(true)


func log_event(kind: String, data: Dictionary = {}) -> void:
	events.append({
		"time_utc": Time.get_datetime_string_from_system(true),
		"ms": Time.get_ticks_msec(),
		"kind": kind,
		"data": data,
	})


func count(kind: String) -> int:
	var n := 0
	for e in events:
		if e.kind == kind:
			n += 1
	return n


func to_dict() -> Dictionary:
	return {
		"app": "elicito app",
		"case_study": case_id,
		"started_at_utc": started_at,
		"fits": count("fit_result"),
		"events": events,
	}


## Writes the log to `dir` (one file per session, overwritten on each
## save). Returns the absolute path, or "" on failure.
func save(dir := "user://sessions") -> String:
	DirAccess.make_dir_recursive_absolute(dir)
	if path == "":
		var stamp := started_at.replace(":", "").replace("-", "")
		path = dir.path_join("%s_%s.json" % [case_id, stamp])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error("SessionLog: cannot write %s (%s)" % [path, error_string(FileAccess.get_open_error())])
		return ""
	file.store_string(JSON.stringify(to_dict(), "  "))
	file.close()
	return ProjectSettings.globalize_path(path)
