extends Node3D

@export var target_material_name: String = ""
@export var replacement_material: Material


func _ready() -> void:
	apply_material_override()


func apply_material_override() -> void:
	if target_material_name.is_empty() or replacement_material == null:
		return

	_apply_to_node(self)


func _apply_to_node(node: Node) -> void:
	if node is MeshInstance3D:
		_apply_to_mesh_instance(node)

	for child in node.get_children():
		_apply_to_node(child)


func _apply_to_mesh_instance(mesh_instance: MeshInstance3D) -> void:
	var mesh := mesh_instance.mesh
	if mesh == null:
		return

	for surface_index in range(mesh.get_surface_count()):
		var material := mesh_instance.get_surface_override_material(surface_index)

		if material == null:
			material = mesh.surface_get_material(surface_index)

		if material != null and material.resource_name == target_material_name:
			mesh_instance.set_surface_override_material(surface_index, replacement_material)
