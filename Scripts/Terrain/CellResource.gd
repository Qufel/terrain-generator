extends Resource
class_name Cell

@export var mesh : Mesh
@export_range(0, 3, 1) var rotation = 0 
@export_flags("Top Right", "Bottom Right", "Bottom Left", "Top Left") var corners : int = 0
