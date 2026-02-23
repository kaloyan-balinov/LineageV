extends Node

# @onready var vbox_container : VBoxContainer = $ScrollContainer/VBoxContainer
# Make sure this is the correct path to your VBoxContainer

var json_files: Array = []
var loaded_array
var file_path: String  # The file path for the JSON

# A global variable to hold the selected JSON file's name
var selected_json_file: String = ""
var buttons = []
var latest_button
var editing: bool = true
var slidestab: bool = false
var view: bool = false
var contextMenu: bool = false
var typing: bool = false
var toolsOpen: bool = false
var contextOpen: bool = false
var last_created_button
var presentTabIndex = 0

signal cameraCanceler
signal cameraAllower
signal saved

var memberName: String
var mousePosition
@export var template_scene: PackedScene
var save_file_path = "user://buttons.json"
var slide_id: String = ""
var selected_button = null
var slide_attachment
var finalColor : Color
var workingColor : Color
var globalTheme := load("res://Assets/Themes/ButtonTheme.tres")
# var slide_manager = "res://Scenes/SlideMode/templateSlide.tscn/slideManager"
var slide_file_path_edit
var FINAL_DISPLAYED_SLIDE: String

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────
func _ready():
	load_background_path()

	if editing:
		$"../UI/Tabs/EditTab".button_pressed = true
	else:
		$"../UI/Tabs/EditTab".button_pressed = false

	# Load the JSON array
	loaded_array = load_array_from_json(save_file_path)

	# Debugging: Print the loaded array to check its contents
	print("Loaded array:", loaded_array)

	# Iterate through the array to ensure the slide path is correct
	for entry in loaded_array:
		var slide_path = entry.get("slide", "")  # Default to "" if slide is missing
		if slide_path == "":
			print("Warning: No slide path found for entry:", entry)
		else:
			print("Slide path for entry:", slide_path)

		# Now, create the button with the correct slide path
		var pos_dict = entry.get("position", {"x": 0, "y": 0})
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

	$"../UI/Tabs/PresentTab".flat = true

# ─────────────────────────────────────────────
# Slide Loading
# ─────────────────────────────────────────────
func load_slide(json_path: String) -> void:
	var slide_scene = load("res://Scenes/SlideMode/templateSlide.tscn")
	var slide_instance = slide_scene.instantiate()
	var slide_manager = slide_instance.get_node("SlideRoot/slideManager")
	slide_manager.load_slide_from_file(json_path)

	# Fullscreen
	var slide_root = slide_instance.get_node("SlideRoot")
	if slide_root is Control:
		slide_root.size = get_viewport().size

	get_tree().current_scene.add_child(slide_instance)

# ─────────────────────────────────────────────
# Tabs
# ─────────────────────────────────────────────
func _on_present_tab_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ViewMode/presentation.tscn")
	queue_free()

func _on_edit_tab_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/EditMode/workbench.tscn")
	queue_free()

# ─────────────────────────────────────────────
# File Utilities
# ─────────────────────────────────────────────
func file_exists(file_path: String) -> bool:
	var file = FileAccess.open(file_path, FileAccess.READ)
	if file:
		file.close()
		return true
	return false

# ─────────────────────────────────────────────
# Button Creation & Input
# ─────────────────────────────────────────────
#func create_button(position: Vector2, memberName: String, is_loaded: bool = false, slide_path: String = ""):
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
	# Only mark this as the latest button if it was created manually
	if not is_loaded:
		latest_button = moveable_button

func _on_button_input_event(event, moveable_button):
	selected_button = moveable_button

	if event is InputEventMouseButton:
		# Left-click pressed
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				# Start dragging the button
				for button_data in buttons:
					if button_data["button"] == moveable_button:
						# Debugging
						print("Button data:", button_data)

						if button_data.has("slide") and button_data["slide"] != "":
							FINAL_DISPLAYED_SLIDE = button_data["slide"]
							print("FROM ARRAY IN PRESENT:", FINAL_DISPLAYED_SLIDE)

							# Load the slide
							selected_json_file = FINAL_DISPLAYED_SLIDE
							load_slide(selected_json_file)
						else:
							print("The 'slide' key is empty or missing for this button.")

	# Handle dragging while the mouse moves
	if event is InputEventMouseMotion:
		for button_data in buttons:
			if button_data["dragging"]:
				button_data["button"].global_position = $"../Camera2D".get_global_mouse_position() + button_data.get("offset", Vector2.ZERO)

# ─────────────────────────────────────────────
# New Button Input
# ─────────────────────────────────────────────
func _on_new_button_pressed() -> void:
	$"../UI/NameInputWindow".show()
	typing = true

# ─────────────────────────────────────────────
# Process
# ─────────────────────────────────────────────
func _process(delta: float) -> void:
	mousePosition = $"../Camera2D".get_global_mouse_position()

	
	if $"../UI/Tabs/EditTab".button_pressed:
		$"../UI/Tabs/SlidesTab".button_pressed = false
		$"../UI/Tabs/PresentTab".button_pressed = false

	if $"../UI/Tabs/PresentTab".button_pressed and presentTabIndex == 0:
		$"../AnimationPlayer".play("DynamicTabHide")
		_on_animation_player_animation_finished("DynamicTabHide")
		presentTabIndex = 1
	#if $"../UI/Tabs/PresentTab".button_pressed and presentTabIndex == 0:
		#$"../UI/Tabs/EditTab".button_pressed = false
		#$"../AnimationPlayer".play("Reset")
		#presentTabIndex = 0

func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	pass

# ─────────────────────────────────────────────
# Camera Signals
# ─────────────────────────────────────────────
func _on_area_2d_mouse_entered() -> void:
	emit_signal("cameraCanceler")


func _on_area_2d_mouse_exited() -> void:
	emit_signal("cameraAllower")


#func _on_area_2d_area_entered(area: Area2D) -> void:
	##print("Top Bar Entered")
	#$"../AnimationPlayer".play("RESET")

func _on_area_2d_mouse_shape_entered(shape_idx: int) -> void:
	if presentTabIndex == 1:
		$"../AnimationPlayer".play_backwards("DynamicTabHide")
		presentTabIndex = 0
	else:
		pass
	

# ─────────────────────────────────────────────
# JSON Utilities
# ─────────────────────────────────────────────
func load_array_from_json(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		return []

	var file := FileAccess.open(file_path, FileAccess.READ)
	var json_data = file.get_as_text()
	file.close()

	var json = JSON.new()
	var parse_result = json.parse(json_data)
	if parse_result == OK:
		return json.get_data()
	else:
		print("Failed to parse JSON.")

	return []

func set_slide_id(id: String) -> void:
	slide_id = id
	print("Slide ID set to: ", slide_id)

func _on_slides_tab_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ViewMode/slides_overview.tscn")
	queue_free()

func _on_slide_path_ready(path: String) -> void:
	for button_data in buttons:
		if button_data["button"] == selected_button:
			button_data["slide"] = path
			print("Slide path updated:", path)
			break

# ─────────────────────────────────────────────
# Background Loader
# ─────────────────────────────────────────────
func load_background_path() -> void:
	var path = "user://Backgrounds/background_data.json"
	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return

	var text := file.get_as_text()
	file.close()

	var data: Dictionary = JSON.parse_string(text)
	if data.is_empty():
		push_error("Invalid JSON data")
		return

	if data.has("background_image_path"):
		var image_path: String = data["background_image_path"]
		var image := Image.load_from_file(image_path)
		var texture := ImageTexture.create_from_image(image)
		$"../Background/Sprite2D".texture = texture


#
# Colors
#
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
