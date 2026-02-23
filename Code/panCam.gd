extends Camera2D
class_name MainCamera

var zoomTarget: Vector2
var previousPosition: Vector2
var currentPosition: Vector2 = Vector2(0, 0);
var moveCamera: bool = false;
var screen_start_position
var zoomPosHelper: float = 1
var zoomMaxLimit: Vector2 = Vector2(2, 2)
var zoomMinLimit: Vector2 = Vector2(0.1,0.1)
var zoomLimitReached: bool = false
var allowedToMove: bool = true

func _ready() -> void:
	zoomTarget = zoom
	
func _input(event):
	if event.is_action("drag") and allowedToMove:
		if event.is_pressed():
			previousPosition = event.position
			screen_start_position = position
			moveCamera = true
		else:
			moveCamera = false
	elif event is InputEventMouseMotion and moveCamera and allowedToMove:
		position = zoomPosHelper * (previousPosition - event.position) + screen_start_position
		
func Zoom(_delta):
	if Input.is_action_just_pressed("scroll_up") and allowedToMove:
		zoomTarget *= 1.1
		if not zoomLimitReached:
			zoomPosHelper *= 0.9
		position = currentPosition
	elif Input.is_action_just_pressed("scroll_down") and allowedToMove:
		zoomTarget *= 0.9
		if not zoomLimitReached:
			zoomPosHelper *= 1.15
		position = currentPosition
		
func _process(delta: float) -> void:
	Zoom(delta)
	currentPosition = get_global_mouse_position()
	zoom = zoom.slerp(zoomTarget, 10 * delta)

	if $".".zoom <= zoomMinLimit:
		zoomLimitReached = true
		$".".zoom = zoomMinLimit
	elif $".".zoom >= zoomMaxLimit:
		zoomLimitReached = true
		$".".zoom = zoomMaxLimit
	else:  
		zoomLimitReached = false
	
	###debug
	
	#print(zoomPosHelper)
	#print($".".position)
	#print(zoomTarget)

func _on_manager_camera_canceler() -> void:
	allowedToMove = false

func _on_manager_camera_allower() -> void:
	allowedToMove = true
