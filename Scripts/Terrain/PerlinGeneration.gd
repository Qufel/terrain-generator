extends Node3D

@export_group("Sizing")
@export var chunkSize : Vector2i = Vector2i (2, 2) ##Size of one chunk
@export var chunkCount : Vector2i = Vector2i(1, 1) ##Size of the terrain in chunks

@export_group("Resources")
const CELL_SIZE : float = 1
@export var chunk : PackedScene
@export_dir var cellValues : String ##Directory with cell resources
var cells : Array[Cell]

@export_group("Noise")
@export var noiseSeed : int = 0
@export var noise : FastNoiseLite

@export_range(-1, 1, 0.01) var water : float = 0.2 ##Threshold specifing border value between water and land

# INFO Offset values for chunks
var offsetX : float
var offsetY : float

func _ready():
	GenerateTerrain()

func GenerateTerrain():
	#region Initialize and check variables
	# INFO Checks if chunk scene is assigned
	assert(chunk != null, "Chunk scene is not assigned!")
	# INFO Checks if FastNoiseLite is assigned. If not, instantiate it
	if noise == null:
		noise = FastNoiseLite.new()
	noise.seed = noiseSeed
	# INFO calculate offsets
	offsetX = (((chunkCount.y * chunkSize.y) / 2) - (chunkSize.y / 2))
	offsetY = (((chunkCount.y * chunkSize.y) / 2) - (chunkSize.y / 2))
	# INFO Checks if folder with cell values exists, if so reads it's content and appends it to cells array
	var cellsDir = DirAccess.open(cellValues)
	assert(cellsDir != null, "Error: Directory with essential cell values doesn't exist!!!, ")
	cellsDir.list_dir_begin()
	var fileName = cellsDir.get_next()
	while fileName != "":
		var cell = ResourceLoader.load(cellValues + "/" + fileName, "Cell")
		assert(cell != Resource.new(), "Cell resource is bad or not found!")
		cells.append(cell)
		fileName = cellsDir.get_next()
	#endregion
	
	for y in range(chunkCount.y):
		for x in range(chunkCount.x):
			var pos : Vector3 = Vector3(
				x * chunkSize.x - offsetX,
				0,
				y * chunkSize.y - offsetY
			)
			add_child(GenerateChunk(pos, x, y))

func GenerateChunk(pos : Vector3, xCoord : int, yCoord : int):
	var chunkInstance = chunk.instantiate()
	chunkInstance.position = pos
	chunkInstance.name = "Chunk [%s, %s]" % [xCoord, yCoord]
	
	var chunkStart : Vector2 = Vector2(
		xCoord * chunkSize.x - ( offsetX + chunkSize.x / 2 ),
		yCoord * chunkSize.y - ( offsetY + chunkSize.y / 2 )
	)
	
	# INFO Dictionary <Mesh, MultiMeshInstance3D> stores multimesh instances used in terrain generation
	var meshesUsed : Dictionary = {}
	# INFO Dictionary <Mesh, Array[Transform3D]> stores positions for each mesh type
	var meshesPos : Dictionary = {}
	
	
	for y in range(chunkSize.y):
		for x in range(chunkSize.x):
			var cellPos : Vector2 = Vector2(
				x - (chunkSize.x / 2),
				y - (chunkSize.y / 2)
			)
			
			var cell = GetCellByCorners(GetCornersValue(
				cellPos.x + chunkStart.x,
				cellPos.y + chunkStart.y
			))
			
			# INFO Add/Modify multimeshes inside chunk according to which meshes are used in chunk
			# NOTE Reduces amount of nodes in each chunk. E.g. In mesh can be only one MM if there is only water
			if not meshesUsed.keys().has(cell.mesh):
				# INFO Create new MultiMeshInstance3D with proper settings
				meshesUsed[cell.mesh] = MultiMeshInstance3D.new()
				var mm = MultiMesh.new()
				mm.transform_format = MultiMesh.TRANSFORM_3D
				mm.mesh = cell.mesh
				meshesUsed[cell.mesh].multimesh = mm
			
			var multimesh : MultiMesh = meshesUsed[cell.mesh].multimesh
			multimesh.instance_count += 1
			if not meshesPos.keys().has(cell.mesh):
				meshesPos[cell.mesh] = []
				
			meshesPos[cell.mesh].append(Transform3D(
				Basis.from_euler(Vector3(0, deg_to_rad(90 * cell.rotation), 0)),
				Vector3(cellPos.x, 0, cellPos.y)
			))
			
			multimesh = null
	
	for mesh in meshesPos.keys():
		var transforms : Array = meshesPos[mesh].duplicate()
		for i in range(len(meshesPos[mesh])):
			var t = transforms.pop_front()
			meshesUsed[mesh].multimesh.set_instance_transform(i, t)
	
	# INFO Add chunk and it's multimeshes to scene tree
	for multimesh : MultiMeshInstance3D in meshesUsed.values():
		multimesh.name = "MultiMesh_%s" % multimesh.multimesh.mesh.resource_name
		chunkInstance.get_node("TerrainMeshes").add_child(multimesh)
	
	meshesUsed = {}
	meshesPos = {}
	return chunkInstance

##Function collecting perlin values of the cell corners and converting it to single int value used to get proper cell type/mesh
func GetCornersValue(x : float, y : float) -> int:
	# INFO Get values of each corner of the cell
	var corners = [
		Vector2(x + CELL_SIZE / 2, y + CELL_SIZE / 2),
		Vector2(x + CELL_SIZE / 2, y - CELL_SIZE / 2),
		Vector2(x - CELL_SIZE / 2, y - CELL_SIZE / 2),
		Vector2(x - CELL_SIZE / 2, y + CELL_SIZE / 2)
	]
	
	var cornerValues : Array[int] = []
	
	# INFO Get perlin values for every corner, create bin string and convert to dec
	for corner in corners:
		var cornerValue = 1 if GetTerrainNoise(corner) > water else 0
		cornerValues.append(cornerValue)
		
	var binaryValue = "".join(cornerValues)
	return binaryValue.bin_to_int()

func GetTerrainNoise(point : Vector2) -> float:
	# TODO Apply multiple types of terrain noise, isalnds, rivers, lakes, etc.
	return noise.get_noise_2dv(point)

##Function returns cell object according to provided corners value
func GetCellByCorners(cv : int) -> Cell:
	assert(not cells.is_empty(), "Cells array is empty!")
	
	for cell in cells:
		if cell.corners == cv:
			return cell
			
	return Cell.new()
