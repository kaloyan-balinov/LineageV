extends Node

# ─────────────────────────────────────────────
# Signals
# ─────────────────────────────────────────────
signal cameraCanceler
signal cameraAllower
signal saved
# ─────────────────────────────────────────────
# Grid
# ─────────────────────────────────────────────
@export var grid_size: int = 32
@export var snap_enabled: bool = true
# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────
var editing: bool = true
var typing: bool = false
var toolsOpen: bool = false
var contextOpen: bool = false
var mousePosition: Vector2
var slide_id: String = ""
var selected_button = null
var latest_button = null
var buttons: Array = []
var user_folder
var pending_slide_button: Button = null
var finalColor : Color
var workingColor : Color
var globalTheme := load("res://Assets/Themes/ButtonTheme.tres")
# ─────────────────────────────────────────────
# Exported
# ─────────────────────────────────────────────
@export var template_scene: PackedScene
var save_file_path := "user://buttons.json"
# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────
func _ready() -> void:
	$"../UI/Tabs/EditTab".disabled = true
	load_background_path()
	var sb: StyleBox = globalTheme.get_stylebox("normal", "Button")
	if sb:
		finalColor = sb.bg_color

	if file_exists(save_file_path):
		var loaded_array := load_array_from_json(save_file_path)
		for entry in loaded_array:
			var pos_dict: Dictionary = entry.get("position", {"x": 0, "y": 0})
			var pos := Vector2(pos_dict.get("x", 0), pos_dict.get("y", 0))
			var color_dict : Dictionary = entry.get("button_color", null)
			var color := finalColor
			if color_dict != null:
				color = dict_to_color(color_dict)

			create_button(
				pos,
				entry.get("name", "Unnamed"),
				color,
				true,
				entry.get("slide", "")
			)

	else:
		save_array_as_json(save_file_path, get_save_data())
# ─────────────────────────────────────────────
# Button Management
# ─────────────────────────────────────────────
func create_button(
	position: Vector2,
	memberName: String,
	buttonColor: Color,
	is_loaded: bool = false,
	slide_path: String = "",
) -> void:
	var moveable_button := Button.new()
	apply_button_color(moveable_button, buttonColor)
	moveable_button.text = memberName
	moveable_button.size = Vector2(250, 80)
	moveable_button.position = position
	moveable_button.theme = globalTheme as Theme
	add_child(moveable_button)

	buttons.append({
		"button": moveable_button,
		"dragging": false,
		"name": memberName,
		"color": buttonColor,
		"position": {"x": position.x, "y": position.y},
		"slide": slide_path,
	})


	moveable_button.connect(
		"gui_input",
		Callable(self, "_on_button_input_event").bind(moveable_button)
	)

	if not is_loaded:
		latest_button = moveable_button

func _on_button_input_event(event, moveable_button) -> void:
	selected_button = moveable_button

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			for button_data in buttons:
				if button_data["button"] == moveable_button:
					button_data["dragging"] = event.pressed
					if event.pressed:
						button_data["offset"] = moveable_button.global_position - $"../Camera2D".get_global_mouse_position()
					else:
						var snapped := snap_to_grid(moveable_button.global_position)
						moveable_button.global_position = snapped
						button_data["position"] = {
							"x": snapped.x,
							"y": snapped.y
						}
						save_array_as_json(save_file_path, get_save_data())

		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			selected_button = moveable_button
			open_context_menu()
			get_viewport().set_input_as_handled()

	if event is InputEventMouseMotion:
		for button_data in buttons:
			if button_data["dragging"]:
				var raw_pos: Vector2 = $"../Camera2D".get_global_mouse_position() + button_data["offset"]
				button_data["button"].global_position = snap_to_grid(raw_pos)

func snap_to_grid(pos: Vector2) -> Vector2:
	if not Input.is_key_pressed(KEY_SHIFT):
		return pos

	return Vector2(
		round(pos.x / grid_size) * grid_size,
		round(pos.y / grid_size) * grid_size
	)

# ─────────────────────────────────────────────
# Creation / Deletion
# ─────────────────────────────────────────────
func _on_new_button_pressed() -> void:
	$"../UI/NameInputWindow".show()
	typing = true

func _on_name_input_window_close_requested() -> void:
	$"../UI/NameInputWindow".hide()
	$"../UI/NameInputWindow/LineEdit".clear()
	typing = false

func _on_line_edit_text_submitted(memberName: String) -> void:
	for button_data in buttons:
		if button_data["name"] == memberName:
			print("Duplicate member name detected.")
			_on_name_input_window_close_requested()
			return

	create_button(mousePosition, memberName, finalColor)
	save_array_as_json(save_file_path, get_save_data())
	_on_name_input_window_close_requested()

func _on_delete_a_member_pressed() -> void:
	if selected_button == latest_button:
		print("Cannot delete the latest button.")
		close_context_menu()
		contextOpen = false
		return

	for i in range(buttons.size()):
		var button_data = buttons[i]
		if button_data["button"] == selected_button:
			selected_button.queue_free()
			buttons.remove_at(i)
			save_array_as_json(save_file_path, get_save_data())
			close_context_menu()
			contextOpen = false
			selected_button = null
			break

func _on_delete_a_slide_pressed() -> void:
	delete_slide_for_selected_button()
# ─────────────────────────────────────────────
# Slide Assignment
# ─────────────────────────────────────────────
func _on_attach_a_slide_pressed() -> void:
	if selected_button == null:
		return

	typing = true
	pending_slide_button = selected_button

	var slide_scene = load("res://Scenes/SlideMode/templateSlide.tscn")
	if slide_scene == null:
		return

	var slide_instance = slide_scene.instantiate()
	get_tree().current_scene.add_child(slide_instance)

	# Listen for the slide editor being closed
	slide_instance.tree_exited.connect(_on_slide_editor_closed)
	close_context_menu()
	contextOpen = false

func _on_slide_path_ready(path: String, target_button: Button) -> void:
	for button_data in buttons:
		if button_data["button"] == target_button:
			button_data["slide"] = path
			break
	save_array_as_json(save_file_path, get_save_data())

func _on_assign_a_slide_pressed() -> void:
	$"../FileDialogForAssigningASlide".show()

func _on_file_dialog_for_assigning_a_slide_file_selected(path: String) -> void:
	for button_data in buttons:
		if button_data["button"] == selected_button:
			button_data["slide"] = path
			break
	save_array_as_json(save_file_path, get_save_data())
	close_context_menu()
	contextOpen = false
	
func _on_slide_editor_closed() -> void:
	if pending_slide_button == null or not is_instance_valid(pending_slide_button):
		return

	# The slide manager already saved the file — we just need the path
	var slides_dir := "user://slides"
	var dir := DirAccess.open(slides_dir)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	var newest_file := ""

	while file_name != "":
		if file_name.ends_with(".json"):
			newest_file = slides_dir + "/" + file_name
		file_name = dir.get_next()

	dir.list_dir_end()

	if newest_file.is_empty():
		return

	for button_data in buttons:
		if button_data["button"] == pending_slide_button:
			button_data["slide"] = newest_file
			break

	save_array_as_json(save_file_path, get_save_data())
	pending_slide_button = null

func delete_slide_for_selected_button() -> void:
	if selected_button == null:
		return

	var slide_path := ""
	var button_index := -1

	for i in range(buttons.size()):
		if buttons[i]["button"] == selected_button:
			slide_path = buttons[i]["slide"]
			button_index = i
			break

	if slide_path.is_empty():
		print("No slide assigned to this button.")
		return

	# ─── Load slide JSON to find referenced image ───
	if FileAccess.file_exists(slide_path):
		var file := FileAccess.open(slide_path, FileAccess.READ)
		if file:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			file.close()

			if typeof(parsed) == TYPE_DICTIONARY:
				var data := parsed as Dictionary
				var image_path := data.get("image1", "") as String

				if not image_path.is_empty() and FileAccess.file_exists(image_path):
					DirAccess.remove_absolute(image_path)

		# ─── Delete slide JSON ───
		DirAccess.remove_absolute(slide_path)

	# ─── Clear button reference ───
	buttons[button_index]["slide"] = ""

	save_array_as_json(save_file_path, get_save_data())

	print("Slide deleted:", slide_path)

# ─────────────────────────────────────────────
# Background
# ─────────────────────────────────────────────
func _on_background_setter_pressed() -> void:
	$"../UI/FileDialog".show()

func _on_file_dialog_file_selected(filepath: String) -> void:
	DirAccess.make_dir_absolute("user://Backgrounds")
	var file_name := filepath.get_file()
	var target_path := "user://Backgrounds/%s" % file_name
	if DirAccess.copy_absolute(filepath, target_path) != OK:
		return

	var image := Image.load_from_file(target_path)
	$"../Background/Sprite2D".texture = ImageTexture.create_from_image(image)
	save_background_path(target_path)

func save_background_path(image_path: String) -> void:
	var file := FileAccess.open(
		"user://Backgrounds/background_data.json",
		FileAccess.WRITE
	)
	if file:
		file.store_string(JSON.stringify({"background_image_path": image_path}))
		file.close()

func load_background_path() -> void:
	if not FileAccess.file_exists("user://Backgrounds/background_data.json"):
		return

	var file := FileAccess.open(
		"user://Backgrounds/background_data.json",
		FileAccess.READ
	)
	if not file:
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var data: Dictionary = parsed

	if data.has("background_image_path"):
		var image := Image.load_from_file(data["background_image_path"])
		$"../Background/Sprite2D".texture = ImageTexture.create_from_image(image)

# ─────────────────────────────────────────────
# Utilities
# ─────────────────────────────────────────────
func _process(_delta: float) -> void:
	mousePosition = $"../Camera2D".get_global_mouse_position()

	if Input.is_action_just_pressed("tools") and not typing:
		if toolsOpen:
			$"../AnimationPlayer".play_backwards("sidebarPopup")
			toolsOpen = false
		else:
			$"../AnimationPlayer".play("sidebarPopup")
			toolsOpen = true

	if Input.is_action_just_pressed("save"):
		emit_signal("saved")
		save_array_as_json(save_file_path, get_save_data())
		
	#if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and contextOpen:
		#$"../rightClickButtonMenu".hide()
		#contextOpen = false
	#else:
		#$"../rightClickButtonMenu".show()

func _on_tools_tab_pressed() -> void:
	$"../AnimationPlayer".play("sidebarPopup")
	toolsOpen = true

func _on_back_pressed() -> void:
	$"../AnimationPlayer".play_backwards("sidebarPopup")
	toolsOpen = false

func _on_area_2d_mouse_entered() -> void:
	emit_signal("cameraCanceler")

func _on_area_2d_mouse_exited() -> void:
	emit_signal("cameraAllower")

func _on_delete_slide_pressed() -> void:
	delete_slide_for_selected_button()
	close_context_menu()
	contextOpen = false
	
func _unhandled_input(event: InputEvent) -> void:
	if not contextOpen:
		return

	if event is InputEventMouseButton and event.pressed:
		# Left OR right click outside buttons closes menu
		close_context_menu()

#----------------------------------------------
# File IO
#----------------------------------------------
func get_save_data() -> Array:
	var data: Array = []
	for b in buttons:
		data.append({
			"name": b["name"],
			"position": b["position"],
			"slide": b["slide"],
			"button_color": color_to_dict(b["color"])
		})
	return data


func save_array_as_json(file_path: String, array_to_save: Array) -> void:
	var file := FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(array_to_save))
		file.close()

func load_array_from_json(file_path: String) -> Array:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if not file:
		return []

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) == TYPE_ARRAY:
		return parsed

	return []

func file_exists(file_path: String) -> bool:
	return FileAccess.file_exists(file_path)

# ---------------------------------------------
# Navigation Tabs
# ---------------------------------------------
func _on_slides_tab_pressed() -> void:
	emit_signal("saved")
	save_array_as_json(save_file_path, get_save_data())
	get_tree().change_scene_to_file("res://Scenes/ViewMode/slides_overview.tscn")
	queue_free()

func _on_present_tab_pressed() -> void:
	emit_signal("saved")
	save_array_as_json(save_file_path, get_save_data())
	get_tree().change_scene_to_file("res://Scenes/ViewMode/presentation.tscn")
	queue_free()

func _on_save_pressed() -> void:
	emit_signal("saved")
	save_array_as_json(save_file_path, get_save_data())

# ---------------------------------------------
# UI
# ---------------------------------------------

func _on_export_pressed() -> void:
	user_folder = OS.get_user_data_dir()
	OS.shell_open(user_folder)

func _on_open_pressed() -> void:
	user_folder = OS.get_user_data_dir()
	OS.shell_open(user_folder)

func open_context_menu() -> void:
	if selected_button == null:
		return

	var blocker := $"../ContextBlocker"
	var menu := blocker.get_node("rightClickButtonMenu")

	blocker.show()
	menu.position = $"../Camera2D".get_global_mouse_position()
	menu.show()
	contextOpen = true


func close_context_menu() -> void:
	var blocker := $"../ContextBlocker"
	blocker.hide()
	contextOpen = false

func _on_context_blocker_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		close_context_menu()


#-----------------------------------------------
# Colors
#-----------------------------------------------
func _on_color_picker_pressed() -> void:
	$"../UI/colorPicker".show()

func _on_color_picker_color_changed(color: Color) -> void:
	workingColor = color

func _on_colorPicker_confirm_pressed() -> void:
	finalColor = workingColor
	print(finalColor)
	$"../UI/colorPicker".hide()
	if selected_button == latest_button:
	#	print("Cannot delete the latest button.")
		close_context_menu()
		contextOpen = false
		return

	for i in range(buttons.size()):
		var button_data = buttons[i]
		if button_data["button"] == selected_button:
			button_data["color"] = finalColor
			apply_button_color(button_data["button"], finalColor)
			save_array_as_json(save_file_path, get_save_data())
			close_context_menu()
			contextOpen = false
			break

func color_to_dict(c: Color) -> Dictionary:
	return {
		"r": c.r,
		"g": c.g,
		"b": c.b,
		"a": c.a
	}
	
func dict_to_color(d: Dictionary) -> Color:
	return Color(
		d.get("r", 1.0),
		d.get("g", 1.0),
		d.get("b", 1.0),
		d.get("a", 1.0)
	)

func apply_button_color(button: Button, color: Color) -> void:
	var base := globalTheme.get_stylebox("normal", "Button") as StyleBoxFlat
	if not base:
		return

	# Normal
	var normal := base.duplicate()
	normal.bg_color = color

	# Hover (slightly darker)
	var hover := base.duplicate()
	hover.bg_color = color.darkened(0.1)

	# Pressed (more dark)
	var pressed := base.duplicate()
	pressed.bg_color = color.darkened(0.2)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
