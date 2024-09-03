@tool
extends EditorPlugin

var panel
const PROTOTYPE_NEIGHBOURS_RESOLVER = preload("res://Addons/prototype_neighbours_resolver/prototype_neighbours_resolver.tscn")

func _enter_tree():
	panel = PROTOTYPE_NEIGHBOURS_RESOLVER.instantiate()
	
	add_control_to_dock(EditorPlugin.DOCK_SLOT_LEFT_BL, panel)


func _exit_tree():
	remove_control_from_docks(panel)
	
	panel.queue_free()
