@tool
extends EditorPlugin

var inspector_plugin


func _enter_tree() -> void:
	inspector_plugin = PathMeshInstance3DEditorInspectorPlugin.new()
	add_inspector_plugin(inspector_plugin)


func _exit_tree() -> void:
	remove_inspector_plugin(inspector_plugin)
