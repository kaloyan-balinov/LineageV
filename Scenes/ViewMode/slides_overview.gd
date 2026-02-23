extends Node

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
const SLIDES_DIR := "user://slides"
const SLIDE_SCENE := "res://Scenes/SlideMode/templateSlide.tscn"

# ─────────────────────────────────────────────
# Nodes
# ─────────────────────────────────────────────
@onready var vbox_container: VBoxContainer = $ScrollContainer/VBoxContainer

# ─────────────────────────────────────────────
# State
# ─────────────────────────────────────────────
var selected_slide_path: String = ""
var json_files: Array[String] = []


# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────
func _ready() -> void:
	$UI/Tabs/SlidesTab.disabled = true

	if vbox_container == null:
		push_error("VBoxContainer not found")
		return

	_clear_buttons()
	_load_slide_list()


# ─────────────────────────────────────────────
# UI Setup
# ─────────────────────────────────────────────
func _clear_buttons() -> void:
	for child in vbox_container.get_children():
		child.queue_free()


func _load_slide_list() -> void:
	if not DirAccess.dir_exists_absolute(SLIDES_DIR):
		return

	var dir := DirAccess.open(SLIDES_DIR)
	if dir == null:
		return

	dir.list_dir_begin()
	while true:
		var file_name: String = dir.get_next()
		if file_name.is_empty():
			break

		if file_name.ends_with(".json"):
			_create_slide_button(file_name)

	dir.list_dir_end()


func _create_slide_button(file_name: String) -> void:
	var button := Button.new()
	button.text = file_name
	button.theme = load("res://Assets/Themes/ButtonTheme.tres") as Theme
	button.custom_minimum_size = Vector2(250, 80)

	button.pressed.connect(
		func() -> void:
			_on_slide_selected(file_name)
	)

	vbox_container.add_child(button)


# ─────────────────────────────────────────────
# Slide Selection & Loading
# ─────────────────────────────────────────────
func _on_slide_selected(file_name: String) -> void:
	selected_slide_path = "%s/%s" % [SLIDES_DIR, file_name]
	_open_slide(selected_slide_path)


func _open_slide(slide_path: String) -> void:
	if slide_path.is_empty():
		return

	var slide_instance := preload(SLIDE_SCENE).instantiate()
	var slide_manager := slide_instance.get_node("SlideRoot/slideManager")

	# SlideManager owns all JSON logic
	slide_manager.load_slide_from_file(slide_path)

	var slide_root := slide_instance.get_node("SlideRoot")
	if slide_root is Control:
		slide_root.size = get_viewport().size

	get_tree().current_scene.add_child(slide_instance)


# ─────────────────────────────────────────────
# Navigation
# ─────────────────────────────────────────────
func _on_present_tab_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/ViewMode/presentation.tscn")
	queue_free()


func _on_edit_tab_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/EditMode/workbench.tscn")
	queue_free()
