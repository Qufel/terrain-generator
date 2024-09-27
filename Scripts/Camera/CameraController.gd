extends Node3D

@onready var camera : Camera3D = $CameraSocket/Camera3D

@export_group("Move")
@export var speed : float = 10.0

@export_group("Pan")
@export_range(0, 32, 4) var panMargin : int = 16
@export var panSpeed : float = 12.0

@export_group("Zoom")
var zoomDir : float = 0.0
@export var zoomSpeed : float = 40.0
@export var zoomMin : float = 10.0
@export var zoomMax : float = 25.0
@export var zoomSpeedDamp : float = 0.92

@export_group("Rotate")
@export var rotationSpeed : float = 15.0
var rotationDir : float = 0

@export_group("Flags")
@export var canMove : bool = true
@export var canPan : bool = true
@export var canZoom : bool = true
@export var canRotate : bool = true

func _process(delta):
	Move(delta)
	Zoom(delta)
	Pan(delta)
	Rotate(delta)

func _unhandled_input(event):
	if event.is_action("zoom_in"):
		zoomDir = -1
	elif event.is_action("zoom_out"):
		zoomDir = 1
		
	if event.is_action_pressed("orbit_clockwise"):
		rotationDir = -1
		canRotate = true
	elif event.is_action_pressed("orbit_counterclockwise"):
		rotationDir = 1
		canRotate = true
	elif event.is_action_released("orbit_clockwise") or event.is_action_released("orbit_counterclockwise"):
		rotationDir = 0
		canRotate = false

func Move(delta : float):
	if !canMove: return
	
	var dir = Vector3.ZERO
	
	if Input.is_action_pressed("move_up"): dir += transform.basis.z
	if Input.is_action_pressed("move_down"): dir -= transform. basis.z
	if Input.is_action_pressed("move_left"): dir += transform.basis.x
	if Input.is_action_pressed("move_right"): dir -= transform.basis.x
	
	position += dir.normalized() * delta * speed
 
func Rotate(delta : float):
	if !canRotate: return
	RotateLeftRight(delta, rotationDir)

func RotateLeftRight(delta : float, dir : float):
	rotation.y += dir * rotationSpeed * delta

func Zoom(delta : float):
	if !canZoom: return
	
	var newZoom : float = clamp(camera.position.z + zoomSpeed * zoomDir * delta, zoomMin, zoomMax)
	camera.position.z = newZoom
	zoomDir *= zoomSpeedDamp

func Pan(delta : float):
	if !canPan: return
	
	var viewport : Viewport = get_viewport()
	var panDir : Vector2 = Vector2(-1, -1)
	var viewportVisibleRect : Rect2i = Rect2i(viewport.get_visible_rect())
	var viewportSize : Vector2i = viewportVisibleRect.size
	var mousePos : Vector2 = viewport.get_mouse_position()
	
	if (mousePos.x < panMargin) or (mousePos.x > viewportSize.x - panMargin):
		if mousePos.x > viewportSize.x / 2:
			panDir.x = 1
		translate(Vector3(panDir.x * delta * panSpeed * -1,0,0))
		
	if (mousePos.y < panMargin) or (mousePos.y > viewportSize.y - panMargin):
		if mousePos.y > viewportSize.y / 2:
			panDir.y = 1
		translate(Vector3(0,0,panDir.y * delta * panSpeed * -1))
