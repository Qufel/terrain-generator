extends Node3D

var camera : Camera3D

@export var coords : Vector2i
@export var size : Vector2i

@export var meshContainers : Array[Node3D] 

@export var data : Array

func ApplyData(xCoord : int, yCoord : int, chunkSize : Vector2i):
	coords = Vector2i(xCoord, yCoord)
	size = chunkSize

func _ready():
	camera = get_viewport().get_camera_3d()
