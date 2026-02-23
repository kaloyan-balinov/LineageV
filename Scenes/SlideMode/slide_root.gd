extends Control

var slide_id = ""
@export var slide_path : String = ""
signal slide_path_ready(path: String)

# Method for setting the slide ID
func set_slide_id(id: String) -> void:
	slide_id = id
	var file_path = "user://slides/" + slide_id + ".json"
	print("Slide ID set to:", slide_id)


func _on_slide_manager_pass_slide_file_info() -> void:
	slide_path = $slideManager.slide_file_path
	print("SlideRoot: " + slide_path)
	emit_signal("slide_path_ready", slide_path)
