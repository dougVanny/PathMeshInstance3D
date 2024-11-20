class_name PathMeshInstance3DEditorInspectorPlugin
extends EditorInspectorPlugin

func _can_handle(object: Object) -> bool:
	return object is PathMeshInstance3D

func _parse_category(object: Object, category: String) -> void:
	if category == "path_mesh_instance_3d.gd":
		var generate_mesh_button = Button.new()
		generate_mesh_button.text = "Generate Mesh"
		generate_mesh_button.pressed.connect(object.generate_and_assign)
		add_custom_control(generate_mesh_button)
