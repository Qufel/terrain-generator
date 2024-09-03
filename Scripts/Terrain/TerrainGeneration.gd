extends Node3D

@export var terrainSize : Vector2i = Vector2i(5, 5)
@export var chunkSize : Vector2i = Vector2i(5, 5)

#@export var prototypes : Array[Prototype] = []

@export var map : Dictionary = {} # <Vector2i, Array[Prototype]>

func GenerateTerrain(sizeX : int, sizeY : int):
	map = GenerateAllPrototypesMap(sizeX, sizeY)

func GenerateAllPrototypesMap(sizeX : int, sizeY : int) -> Dictionary:
	var dict : Dictionary
	for y in sizeY:
		for x in sizeX:
			pass
			#dict[Vector2i(x, y)] = prototypes
	return dict
