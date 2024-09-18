extends Node3D

const TILESET_TILE_TOP = preload("res://Assets/Terrain/Tiles/TileTop.res")

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

@export_subgroup("Water")
@export_range(-1, 1, 0.01) var water : float = 0.2 ##Threshold specifing border value between water and land
@export var waterMaterial : Material
@export var waterHeight : float = 0.5

# INFO Offset values for chunks
var offsetX : float
var offsetY : float

# NOTE High amount of max threads can bring heavy load for PC and cause crashes
var max_threads = int(OS.get_processor_count() / 2)
var generationQueue : Array = []
var workingThreads : Array = []

func GenerateMap():
	# INFO Clears previous map iteration if existed
	if get_children().size() > 0:
		ClearMap()
	
	# INFO Generates chunks
	Populate()
	# INFO Adds water to map
	GenerateWater()

	
## Clears previous map
func ClearMap():
	for n in get_children():
		remove_child(n)
		n.queue_free()

func Populate():
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
			QueueTask({
				"position" : pos,
				"x" : x,
				"y" : y
			})

func GenerateWater():
	var waterInstance = MeshInstance3D.new()
	waterInstance.mesh = PlaneMesh.new()
	waterInstance.position = Vector3(0, waterHeight, 0)
	waterInstance.scale = Vector3(chunkCount.x * chunkSize.x * CELL_SIZE / 2, 1, chunkCount.y * chunkSize.y * CELL_SIZE / 2)
	waterInstance.name = "WaterMesh"
	waterInstance.material_override = waterMaterial
	add_child(waterInstance)
	
func GenerateChunk(pos : Vector3, xCoord : int, yCoord : int, thr : Thread):
	var chunkInstance = chunk.instantiate()
	chunkInstance.position = pos
	chunkInstance.name = "Chunk [%s, %s]" % [xCoord, yCoord]
	
	# INFO Generate Terrain
	chunkInstance.add_child(GenerateTerrain(xCoord, yCoord))
	
	# INFO Generate Trees
	
	call_deferred("DisplayChunk", thr)
	return chunkInstance

## Function generating terrain cells, returns Node3D with multimeshes
func GenerateTerrain(xCoord : int, yCoord : int):
	var terrainMeshes = Node3D.new()
	terrainMeshes.name = "TerrainMeshes"
	
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
	
	# INFO Sets transforms in proper multimeshes 
	for mesh in meshesPos.keys():
		var transforms : Array = meshesPos[mesh].duplicate()
		for i in range(len(meshesPos[mesh])):
			var t = transforms.pop_front()
			meshesUsed[mesh].multimesh.set_instance_transform(i, t)
	
	# INFO Add chunk and it's multimeshes to scene tree
	for multimesh : MultiMeshInstance3D in meshesUsed.values():
		multimesh.name = "MultiMesh_%s" % multimesh.multimesh.mesh.resource_name
		terrainMeshes.add_child(multimesh)
	
	# INFO Clear variables and call deferred function
	meshesUsed = {}
	meshesPos = {}
	return terrainMeshes

## Function collecting perlin values of the cell corners and converting it to single int value used to get proper cell type/mesh
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

## Function doing funky things with perlin noise
func GetTerrainNoise(point : Vector2) -> float:
	# TODO Apply multiple types of terrain noise, isalnds, rivers, lakes, etc.
	return noise.get_noise_2dv(point)

## Function returns cell object according to provided corners value
func GetCellByCorners(cv : int) -> Cell:
	assert(not cells.is_empty(), "Cells array is empty!")
	
	for cell in cells:
		if cell.corners == cv:
			return cell
			
	return Cell.new()

#region Multithreading functions
func QueueTask(data):
	generationQueue.append(data)
	StartTask()

func StartTask():
	if workingThreads.size() < max_threads and generationQueue.size() > 0:
		var data = generationQueue.pop_front()
		var thread = Thread.new()
		workingThreads.append(thread)
		thread.start(GenerateChunk.bind(data["position"], data["x"], data["y"], thread))

func DisplayChunk(thr : Thread):
	var chunkProduct = thr.wait_to_finish()
	workingThreads.erase(thr)
	call_deferred("add_child", chunkProduct)
	StartTask()
#endregion

func _exit_tree():
	ClearMap()
	generationQueue.clear()
	if len(workingThreads) > 0:
		for thr in workingThreads:
			thr.wait_to_finish()
			workingThreads.erase(thr)
