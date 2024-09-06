@tool
extends VBoxContainer

@onready var prototype_list = $PrototypeList
var prototypes : Array[Prototype]

func _on_prototype_count_value_changed(value):
	for n in prototype_list.get_children():
		prototype_list.remove_child(n)
		n.queue_free()
	
	if int(value) != 0:
		for i in range(int(value)):
			var prototypePicker : AddonResourcePicker = AddonResourcePicker.new()
			prototype_list.add_child(prototypePicker)

#Resolve neighbours
func _on_resolve_neighbours_button_up():
	prototypes = []
	for n : EditorResourcePicker in prototype_list.get_children():
		if n.edited_resource != null:
			prototypes.append(n.edited_resource)
	
	if len(prototypes) > 0:
		for p : Prototype in prototypes:
			print(p.resource_path)
			p.neighboursList = {}
			for key : String in p.sockets.keys():
				print("Key: %s" % key)
				var value = key.substr(0, 1)
				var side = key.substr(1, 1)
				for pr : Prototype in prototypes:
					if value == "p":
						if pr.sockets["n%s" % side] == p.sockets[key]:
							print("- %s" % pr.resource_path)
							print("[%s, %s]" % [pr.sockets["n%s" % side], p.sockets[key]])
							if key not in p.neighboursList:
								p.neighboursList[key] = [pr.prototypeId]
							else:
								p.neighboursList[key].append(pr.prototypeId)
					if value == "n":
						if pr.sockets["p%s" % side] == p.sockets[key]:
							print("- %s" % pr.resource_path)
							print("[%s, %s]" % [pr.sockets["p%s" % side], p.sockets[key]])
							if key not in p.neighboursList:
								p.neighboursList[key] = [pr.prototypeId]
							else:
								p.neighboursList[key].append(pr.prototypeId)
