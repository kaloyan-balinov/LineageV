extends Button

var mouse_pos
signal move_click
var moveable: bool = false
var tween
signal left_click
signal right_click

			
func _process(delta: float) -> void:
	mouse_pos = $Camera2D.get_global_mouse_position()
	if moveable:
		print("true")
		tween = create_tween()
		var target_pos = self.position + mouse_pos
		tween.tween_property(self,"position",target_pos,0.1)
	

func _ready():
	gui_input.connect(_on_Button_gui_input)

func _on_Button_gui_input(event):
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				left_click.emit()
				moveable = true
			MOUSE_BUTTON_RIGHT:
				right_click.emit()
