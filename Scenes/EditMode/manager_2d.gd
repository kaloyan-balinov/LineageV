extends Node2D

@onready var line_container: Node2D = $"../LineContainer"  # Reference to container where lines will be added
var lines_data: Array = []  # Array to hold line data (e.g., dragging state, offsets)
var current_line: Line2D = null  # The line currently being manipulated
var save_file_path: String = "user://line_data.json"  # Path to the JSON file (user data folder)

func _ready():
	# Set mouse mode to visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Load the lines from the JSON file
	load_lines()

# Function to create a new line and add it to the container
func _on_new_connection_pressed() -> void:
	if line_container == null:
		print("Error: line_container is null during line creation!")
		return

	var line = create_new_line()
	line_container.add_child(line)

	# Add the newly created line's data to the lines_data array
	lines_data.append({
		"line": line,
		"dragging_start": false,
		"dragging_end": false,
		"start_point": line.points[0],
		"end_point": line.points[1],
		"offset": Vector2.ZERO,
		"angle_offset": 0.0
	})

# Helper function to create a new line
func create_new_line() -> Line2D:
	var line = Line2D.new()
	var global_mouse_pos = $"../Camera2D".global_position
	line.name = "DynamicLine"
	line.default_color = Color(0, 0, 0)  # Black color
	line.width = 4  # Line width
	line.points = [global_mouse_pos, global_mouse_pos + Vector2(200, 0)]  # Example: horizontal line starting from mouse position
	return line

# Input handling for mouse events
func _input(event: InputEvent):
	if event is InputEventMouseButton:
		handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		handle_mouse_motion()

	# Request redraw after each movement
	queue_redraw()

# Function to handle mouse button events
func handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			check_for_drag_start()
		else:
			release_dragging()
	elif event.button_index == MOUSE_BUTTON_RIGHT:  # Middle click for testing deletion
		if event.pressed:
			delete_line_on_hover()

# Check if any line start or end point is near the mouse position
func check_for_drag_start() -> void:
	for line_data in lines_data:
		var line = line_data["line"]
		var start_point = line_data["start_point"]
		var end_point = line_data["end_point"]

		if (start_point - get_local_mouse_position()).length() < 10:
			line_data["dragging_start"] = true
			current_line = line
		elif (end_point - get_local_mouse_position()).length() < 10:
			line_data["dragging_end"] = true
			current_line = line

# Release dragging states for all lines
func release_dragging() -> void:
	for line_data in lines_data:
		line_data["dragging_start"] = false
		line_data["dragging_end"] = false
	current_line = null

# Function to handle mouse motion events
func handle_mouse_motion() -> void:
	for line_data in lines_data:
		if line_data["dragging_start"]:
			line_data["start_point"] = get_local_mouse_position()
		elif line_data["dragging_end"]:
			line_data["end_point"] = get_local_mouse_position()

			# If Shift is held, snap to one of 8 directions
			if Input.is_key_pressed(KEY_SHIFT):
				line_data["end_point"] = snap_to_8_directions(line_data["start_point"], line_data["end_point"])

		# Update the line points with the new positions
		var line = line_data["line"]
		line.points = [line_data["start_point"], line_data["end_point"]]

# Function to snap the end point to one of the 8 cardinal or diagonal directions
func snap_to_8_directions(start_point: Vector2, end_point: Vector2) -> Vector2:
	# Calculate the vector from the start to the end point
	var direction = end_point - start_point
	# Get the angle of the vector (in radians)
	var angle = direction.angle()
	# Snap to one of the 8 directions (multiples of 45 degrees)
	var snapped_angle = round(angle / (PI / 4)) * (PI / 4)
	# Calculate the new direction vector from the snapped angle
	var snapped_direction = Vector2(cos(snapped_angle), sin(snapped_angle))
	# Return the new end point based on the snapped direction
	return start_point + snapped_direction * direction.length()

# Function to save the line data to a JSON file
func save_lines() -> void:
	var file = FileAccess.open(save_file_path, FileAccess.WRITE)
	if file:
		var lines_to_save = []
		for line_data in lines_data:
			var line = line_data["line"]
			lines_to_save.append({
				"start_point": {"x": line_data["start_point"].x, "y": line_data["start_point"].y},
				"end_point": {"x": line_data["end_point"].x, "y": line_data["end_point"].y},
				"color": line.default_color,
				"width": line.width
			})
		var json = JSON.new()
		var json_data = JSON.stringify(lines_to_save)
		file.store_string(json_data)
		file.close()
		print("Lines saved to JSON!")

# Function to load the line data from a JSON file
func load_lines() -> void:
	if FileAccess.file_exists(save_file_path):
		var file = FileAccess.open(save_file_path, FileAccess.READ)
		if file:
			var json_data = file.get_as_text()
			file.close()

			var json = JSON.new()
			var lines_to_load = json.parse_string(json_data)

			if lines_to_load == null:
				print("Error: Failed to parse JSON.")
				return

			# Recreate the lines based on the loaded data
			for line_data in lines_to_load:
				var line = create_new_line()
				line.width = line_data["width"]
				var start_point = Vector2(line_data["start_point"]["x"], line_data["start_point"]["y"])
				var end_point = Vector2(line_data["end_point"]["x"], line_data["end_point"]["y"])
				line.points = [start_point, end_point]

				line_container.add_child(line)

				lines_data.append({
					"line": line,
					"dragging_start": false,
					"dragging_end": false,
					"start_point": start_point,
					"end_point": end_point,
					"offset": Vector2.ZERO,
					"angle_offset": 0.0
				})

			print("Lines loaded from JSON!")
		else:
			print("Error: Could not open JSON file!")
	else:
		print("No saved lines data found.")

# Function to delete a line on middle mouse click when hovering over a line
func delete_line_on_hover() -> void:
	var mouse_position = get_local_mouse_position()

	# Check if the mouse is near any line (start or end points)
	for line_data in lines_data:
		var line = line_data["line"]
		var start_point = line_data["start_point"]
		var end_point = line_data["end_point"]

		# If the middle-click is near the start or end point of the line, delete it
		if (start_point - mouse_position).length() < 10 or (end_point - mouse_position).length() < 10:
			print("Middle-clicked on line: ", line)  # Debug print
			delete_line(line)  # Delete the selected line
			break

# Function to delete the line
func delete_line(line: Line2D) -> void:
	for i in range(lines_data.size()):
		var line_data = lines_data[i]
		if line_data["line"] == line:
			print("Deleting line: ", line)  # Debug print
			line.queue_free()  # Free the line
			lines_data.remove_at(i)  # Remove from the lines data array
			save_lines()  # Save the updated lines data
			break


func _on_manager_saved() -> void:
	save_lines()
