extends Node3D

@export var chunkNode : Resource

@export_group("Sizing")
@export var size : Vector2i
@export var chunkSize : Vector2i

#offsets for chunk positions
var offsetX : float
var offsetY : float

@export_group("Noise")
@export var terrainNoise : FastNoiseLite
@export var shoreNoise : FastNoiseLite
@export_range(0, 1, 0.01) var water : float = 0.5

@export_group("Cleaning cells")
@export var cleanDepth : int = 4

func GenerateTerrain(xSize : int, ySize : int):
	shoreNoise.seed = terrainNoise.seed
	
	#Calculate offset
	offsetX = (((size.y * chunkSize.y) / 2) - (chunkSize.y / 2))
	offsetY = (((size.y * chunkSize.y) / 2) - (chunkSize.y / 2))
	
	for y in range(ySize):
		for x in range(xSize):
			var xPos = x * chunkSize.x - offsetX
			var yPos = y * chunkSize.y - offsetY
			GenerateChunk(Vector3(xPos, 0, yPos), x, y, chunkSize.x, chunkSize.y)

func GenerateChunk(pos : Vector3, xGrid : int, yGrid : int, xSize : int, ySize : int):
	
	var landTilesCount : int = 0
	var landTilesPos : Array[Transform3D] = []
	
	var waterTilesCount : int = 0
	var waterTilesPos : Array[Transform3D] = []
	
	#Instantiate chunk node
	var chunk = chunkNode.instantiate()
	chunk.position = pos
	chunk.set_name("Chunk[%s, %s]" % [xGrid, yGrid])
	
	#Get chunk start, first cell of a chunk
	var xChunkStart = xGrid * xSize - offsetX - (xSize / 2)
	var yChunkStart = yGrid * ySize - offsetY - (ySize / 2)
	
	var chunkNoiseDict : Dictionary = {}
	var chunkLandSet : Dictionary = {}
	
	for y in range(ySize):
		for x in range(xSize):
			var xPos = x - (xSize / 2)
			var yPos = y - (ySize / 2)
			
			#Get normalized noise
			var normalized = GetNormalizedNoise(xPos + xChunkStart, yPos + yChunkStart)
			
			#Get zPos of cell based on normalized perlin value
			var zPos = 1 if normalized > water else 0
			
			chunkNoiseDict[Vector2(xPos, yPos)] = zPos
				
	add_child(chunk)
	
	for key : Vector2 in chunkNoiseDict.keys():
		var value : int = chunkNoiseDict[key]
			
		var table = [
			chunkNoiseDict.get(Vector2(key.x - 1, key.y + 1), 1 if GetNormalizedNoise(key.x + xChunkStart - 1, key.y + yChunkStart + 1) > water else 0),
			chunkNoiseDict.get(Vector2(key.x, key.y + 1), 1 if GetNormalizedNoise(key.x + xChunkStart, key.y + yChunkStart + 1) > water else 0),
			chunkNoiseDict.get(Vector2(key.x + 1, key.y + 1), 1 if GetNormalizedNoise(key.x + xChunkStart + 1, key.y + yChunkStart + 1) > water else 0),
			chunkNoiseDict.get(Vector2(key.x + 1, key.y), 1 if GetNormalizedNoise(key.x + xChunkStart + 1, key.y + yChunkStart) > water else 0),
			chunkNoiseDict.get(Vector2(key.x + 1, key.y - 1), 1 if GetNormalizedNoise(key.x + xChunkStart + 1, key.y + yChunkStart - 1) > water else 0),
			chunkNoiseDict.get(Vector2(key.x, key.y - 1), 1 if GetNormalizedNoise(key.x + xChunkStart, key.y + yChunkStart - 1) > water else 0),
			chunkNoiseDict.get(Vector2(key.x - 1, key.y - 1), 1 if GetNormalizedNoise(key.x + xChunkStart - 1, key.y + yChunkStart - 1) > water else 0),
			chunkNoiseDict.get(Vector2(key.x - 1, key.y), 1 if GetNormalizedNoise(key.x + xChunkStart - 1, key.y + yChunkStart) > water else 0),
		]
		
		var count = table.reduce(func(acc, num): return acc + num, 0)
		
		if chunkNoiseDict[key] == 1:
			chunkLandSet[key] = "LAND"
			continue
		
		if count == 0: 
			chunkLandSet[key] = "WATER"
			continue	
		
		if count > 0:
			if count >= 6:
				chunkNoiseDict[key] = 1
				chunkLandSet[key] = "LAND"
				continue
			
			if (table[1] + table[5] == 2) or (table[3] + table[7] == 2):
				chunkNoiseDict[key] = 1
				chunkLandSet[key] = "LAND"
				continue
			
			chunkLandSet[key] = "EDGE"
	
	for key in chunkLandSet.keys():
		if chunkLandSet[key] == "LAND":
			#Debug.DrawDebugSphere(chunk, Vector3(key.x, 0, key.y), Color.LIME_GREEN, 0.3)
			landTilesCount += 1
			landTilesPos.append(Transform3D(Basis(), Vector3(key.x, 0, key.y)))
		elif chunkLandSet[key] == "WATER":
			waterTilesCount += 1
			waterTilesPos.append(Transform3D(Basis(), Vector3(key.x, 0, key.y)))
			#Debug.DrawDebugSphere(chunk, Vector3(key.x, 0, key.y), Color.DODGER_BLUE, 0.3)
		elif chunkLandSet[key] == "EDGE":
			pass
			#Debug.DrawDebugSphere(chunk, Vector3(key.x, 0, key.y), Color.YELLOW, 0.3)
	
	var landTopMM : MultiMeshInstance3D = chunk.find_child("LandTopMultiMesh")
	
	landTopMM.multimesh.instance_count = landTilesCount
	for i in range(landTilesCount):
		landTopMM.multimesh.set_instance_transform(i, landTilesPos[i])
		
	var landBtmMM : MultiMeshInstance3D = chunk.find_child("LandBottomMultiMesh")
	
	landBtmMM.multimesh.instance_count = waterTilesCount
	for i in range(waterTilesCount):
		landBtmMM.multimesh.set_instance_transform(i, waterTilesPos[i])
	
	
	

func GetNormalizedNoise(x : float, y: float) -> float:
	var noise = terrainNoise.get_noise_2d(x, y) + shoreNoise.get_noise_2d(x, y)
	return ((noise + 1) / 2) 

#Debug menu functions
func setTerrainNoiseSeed(seedValue : int):
	self.terrainNoise.seed = seedValue

func setWaterThreshold(value : float):
	self.water = value

func setTerrainSize(size : Vector2i):
	self.size = size

func setChunkSize(size : Vector2i):
	self.chunkSize = size
