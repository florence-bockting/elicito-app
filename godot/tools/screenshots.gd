extends SceneTree
## Screenshots of the gallery, a single fit, the expert panel and the
## posterior code, for the README
## and the documentation. Needs a running server (elicito-app-server):
##   godot --path godot --resolution 1280x1000 -s res://tools/screenshots.gd -- --out=/tmp/shots
var out := "/tmp/elicito-app-screenshots"
var main: Control
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(out)
	main = load("res://app/main.tscn").instantiate()
	root.add_child(main)
	await create_timer(1.0).timeout
	await _shot("1_gallery.png")
	while not main.client.connected:
		await process_frame
	main.current.get_node("%Cards").get_child(0).opened.emit(main.catalog.case_studies[0])
	await process_frame
	var view: CaseStudyView = main.current
	await _shot("2_model.png")
	view.current_tab = 1
	await create_timer(0.3).timeout
	await _shot("3_personas.png")
	var page := view.elicitation_page
	page.play_as(main.catalog.case_studies[0].personas[1])
	view.show_page(page)
	page.autofill_button.pressed.emit()
	await create_timer(0.3).timeout
	await _shot("4_elicitation.png")
	page.fit_button.pressed.emit()
	await main.client.fit_finished
	await create_timer(0.5).timeout
	await _shot("4b_fitted.png")
	page.next_button.pressed.emit()
	await create_timer(0.3).timeout
	await _shot("5_diagnostics.png")
	view.fit_view.current_tab = 1
	await create_timer(0.3).timeout
	await _shot("6_priors.png")
	view.fit_view.current_tab = 2
	await create_timer(5.0).timeout
	await _shot("7_predictions.png")
	var panel_page := view.panel_page
	view.show_page(panel_page)
	await create_timer(0.3).timeout
	await _shot("8_panel_ready.png")
	panel_page.fit_button.pressed.emit()
	await main.client.fit_finished
	await create_timer(0.8).timeout
	await _shot("9_panel_results.png")
	panel_page.results.current_tab = 2
	await create_timer(5.0).timeout
	await _shot("10_panel_predictions.png")
	panel_page.next_button.pressed.emit()
	await create_timer(0.3).timeout
	await _shot("11_next_steps.png")
	view.next_steps.code_tabs.current_tab = 1
	await create_timer(0.3).timeout
	await _shot("12_next_steps_brms.png")
	quit(0)
func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out.path_join(file))
	print("saved ", file)
