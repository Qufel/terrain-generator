extends Node

func DrawDebugSphere(master : Node, position : Vector3, color : Color = Color.WHITE, radius : float = 1.0):
	
	#Create mesh instance
	var meshInstance3D : MeshInstance3D = MeshInstance3D.new()
	meshInstance3D.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	#apply position to instance
	meshInstance3D.transform.origin = position

	#Create mesh
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	meshInstance3D.mesh = mesh
	
	#Create material
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	meshInstance3D.material_override = mat
	
	master.add_child(meshInstance3D)
