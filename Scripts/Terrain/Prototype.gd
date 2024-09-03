extends Resource
class_name Prototype

@export var mesh : Mesh
@export_range(0, 3, 1) var rotation = 0
@export_range(0, 1, 0.01) var weight = 1
@export var sockets : Dictionary = {
	"pX" : "",
	"nX" : "",
	"pY" : "",
	"nY" : ""
}
@export var neighboursList : Dictionary

func _init():
	pass
