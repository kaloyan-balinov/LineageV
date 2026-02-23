extends Node

# ─────────────────────────────────────────────
# Signals
# ─────────────────────────────────────────────
signal slide_path_ready(path: String)

# ─────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────
const SLIDES_DIR := "user://slides"
const IMAGES_DIR := "user://slides/images"

# ─────────────────────────────────────────────
# Slide Data
# ─────────────────────────────────────────────
@export var title_name: String = ""
@export var info_text: String = ""
@export var slide_file_path: String = ""

# Image system (UNLIMITED)
var image_paths: Array[String] = []
var current_image_index := -1
var image_insert_index := -1

# ─────────────────────────────────────────────
# Lifecycle
# ─────────────────────────────────────────────
func _ready() -> void:
	_update_image_navigation()

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────
func _ensure_directories() -> void:
	DirAccess.make_dir_absolute(SLIDES_DIR)
	DirAccess.make_dir_absolute(IMAGES_DIR)

func _update_slide_file_path() -> void:
	slide_file_path = "%s/%s.json" % [SLIDES_DIR, title_name]

func _update_image_navigation() -> void:
	var has_images := image_paths.size() > 0

	$"../ButtonForNextImage".visible = has_images
	$"../ButtonForPreviousImage".visible = current_image_index > 0



func _clear_image() -> void:
	$"../Control/TextureRect".texture = null

# ─────────────────────────────────────────────
# Saving
# ─────────────────────────────────────────────
func save_slide_data() -> void:
	_ensure_directories()

	title_name = $"../MemberName".text
	info_text = $"../Info".text
	_update_slide_file_path()
	emit_signal("slide_path_ready", slide_file_path)

	var file := FileAccess.open(slide_file_path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open slide file for writing")
		return

	var json_data := {
		"title": title_name,
		"info": info_text,
		"images": image_paths
	}

	file.store_string(JSON.stringify(json_data))
	file.close()

	print("Slide saved:", slide_file_path)

# ─────────────────────────────────────────────
# Loading
# ─────────────────────────────────────────────
func load_data(json_path: String) -> void:
	var file := FileAccess.open(json_path, FileAccess.READ)
	if not file:
		push_error("Failed to open slide file: %s" % json_path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()

	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Invalid slide JSON format")
		return

	var data := parsed as Dictionary

	title_name = data.get("title", "")
	info_text = data.get("info", "")

	image_paths.clear()
	var raw_images: Variant = data.get("images", [])
	if raw_images is Array:
		for p in raw_images:
			if typeof(p) == TYPE_STRING:
				image_paths.append(p)

	current_image_index = -1 if image_paths.is_empty() else 0



func load_slide_data() -> void:
	$"../MemberName".text = title_name
	$"../Info".text = info_text

	_show_current_image()
	_update_image_navigation()

	print("Slide loaded:", title_name)

func load_slide_from_file(json_path: String) -> void:
	load_data(json_path)
	load_slide_data()

# ─────────────────────────────────────────────
# Image Display
# ─────────────────────────────────────────────
func _show_current_image() -> void:
	if current_image_index < 0 or current_image_index >= image_paths.size():
		return

	var path := image_paths[current_image_index]
	if FileAccess.file_exists(path):
		var img := Image.load_from_file(path)
		$"../Control/TextureRect".texture = ImageTexture.create_from_image(img)

# ─────────────────────────────────────────────
# Navigation
# ─────────────────────────────────────────────
func _on_back_button_pressed() -> void:
	save_slide_data()
	get_tree().queue_delete($"../..")

func _on_button_for_next_image_pressed() -> void:
	if image_paths.is_empty():
		_clear_image()
		return

	var next_index := current_image_index + 1

	if next_index < image_paths.size():
		current_image_index = next_index
		_show_current_image()
	else:
		current_image_index = next_index
		_clear_image()

	_update_image_navigation()

func _on_button_for_previous_image_pressed() -> void:
	if image_paths.is_empty():
		_clear_image()
		return

	var prev_index := current_image_index - 1

	if prev_index >= 0 and prev_index < image_paths.size():
		current_image_index = prev_index
		_show_current_image()
	else:
		current_image_index = prev_index
		_clear_image()

	_update_image_navigation()


# ─────────────────────────────────────────────
# Image Selection (UNLIMITED)
# ─────────────────────────────────────────────
func _on_button_for_image_pressed() -> void:
	image_insert_index = image_paths.size()
	$"../../FileDialog".show()

func _on_file_dialog_file_selected(source_path: String) -> void:
	_ensure_directories()

	var file_name := source_path.get_file()
	var target_path := "%s/%s" % [IMAGES_DIR, file_name]

	if DirAccess.copy_absolute(source_path, target_path) != OK:
		push_error("Failed to copy image file")
		return

	if image_insert_index == image_paths.size():
		image_paths.append(target_path)
	else:
		image_paths[image_insert_index] = target_path

	current_image_index = image_insert_index

	save_slide_data()
	_show_current_image()
	_update_image_navigation()

# ─────────────────────────────────────────────
# Utility
# ─────────────────────────────────────────────
func get_file_path() -> String:
	return "%s/%s.json" % [SLIDES_DIR, title_name]
