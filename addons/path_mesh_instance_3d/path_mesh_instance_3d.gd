@tool
class_name PathMeshInstance3D
extends MeshInstance3D

enum MeshFormat
{
	TUBE = 0b001,
	TUBE_UNCAPPED = 0b011,
	CROSS = 0b100,
}

enum SubDivisionRule
{
	CURVE_DENSITY,
	UNIFORM
}

enum WidthAround
{
	EDGES,
	VERTICES
}

enum UVMapping
{
	NONE,
	UV_X,
	UV_Y,
	UV2_X,
	UV2_Y,
	UV3_X,
	UV3_Y,
	UV4_X,
	UV4_Y,
}

@export var path_3d : Path3D

@export var mesh_format : MeshFormat = MeshFormat.TUBE
@export_range(1, 64, 1, "or_greater") var faces : int = 6

@export_group("Sub Division Tesselation")
@export var sub_division_rule : SubDivisionRule
@export_range(0, 16) var sub_division_max_stages : int = 5
@export_range(0, 100, 0.001, "or_greater") var sub_division_max_length : float = 0;

@export_group("Width")
@export var width : float = 1.0
@export var width_multiplier : Curve
@export var width_multiplier_tile_length : float
@export var width_multiplier_tile_length_stretch_to_fit : bool = true
@export var width_around : WidthAround

@export_group("Ends")
@export_range(0, 100, 0.001, "or_greater") var end_length : float
@export var end_sub_divisions : int = 8
@export var end_width_multiplier : Curve

@export_group("UV Mapping")
@export var uv_path_length_normalized : UVMapping = UVMapping.UV_Y
@export var uv_path_length : UVMapping
@export var uv_sub_division_length : UVMapping
@export var uv_edge_length : UVMapping
@export var uv_line_mesh_around : UVMapping = UVMapping.UV_X
@export var uv_line_mesh_width : UVMapping
@export var uv_line_mesh_height : UVMapping
@export var uv_line_original_width : UVMapping

@export_group("Debug")
@export var _generate_mesh : bool:
	get:
		return false
	set(value):
		mesh = generate_mesh()

func generate_mesh() -> Mesh:
	if(path_3d.curve.point_count < 2):
		push_warning("Path needs at least 2 points")
		return null
	
	var vertices = PackedVector3Array()
	var uvs = PackedVector2Array()
	var custom0 = PackedFloat32Array()
	var custom1 = PackedFloat32Array()
	var indices = PackedInt32Array()
	
	var sub_divisions = []
	var tesselated
	if sub_division_rule == SubDivisionRule.CURVE_DENSITY:
		tesselated = path_3d.curve.tessellate(sub_division_max_stages)
	else:
		tesselated = path_3d.curve.tessellate_even_length(sub_division_max_stages)
	
	sub_divisions.push_back(0.0)
	
	var prev_offset = 0.0
	var prev_position = path_3d.curve.sample_baked(prev_offset)
	for i in range(1, len(tesselated)):
		var next_position = tesselated[i]
		var next_offset = path_3d.curve.get_closest_offset(next_position)
		
		var slices = 1 if sub_division_max_length <= 0 else ceil(prev_position.distance_to(next_position) / sub_division_max_length)
		for s in range(slices):
			sub_divisions.push_back(lerp(prev_offset, next_offset, (s+1)/slices))
		
		prev_position = next_position
		prev_offset = next_offset
	
	var length = sub_divisions[-1]
	
	var end_length_safe = 0.0
	if end_length > 0:
		end_length_safe = min(end_length, end_sub_divisions * (length / (end_sub_divisions*2.0 + 1.0)))
		var insert_position = 0
		
		for i in range(end_sub_divisions):
			var offset_to_insert = end_length_safe * ((1.0+i)/end_sub_divisions)
			while insert_position < len(sub_divisions) and sub_divisions[insert_position] <= offset_to_insert:
				insert_position += 1
			sub_divisions.insert(insert_position, offset_to_insert)
			insert_position += 1
		
		for i in range(end_sub_divisions):
			var offset_to_insert = length + end_length_safe * (float(i)/end_sub_divisions - 1)
			while insert_position < len(sub_divisions) and sub_divisions[insert_position] <= offset_to_insert:
				insert_position += 1
			sub_divisions.insert(insert_position, offset_to_insert)
			insert_position += 1
	
	var end_length_width = 0.0 if end_width_multiplier == null else end_length_safe
	var sub_division_widths = []
	for offset in sub_divisions:
		if(offset < end_length_width):
			sub_division_widths.push_back(width * end_width_multiplier.sample_baked(inverse_lerp(0.0, end_length_width, offset)))
		elif(offset > length - end_length_width):
			sub_division_widths.push_back(width * end_width_multiplier.sample_baked(inverse_lerp(length, length - end_length_width, offset)))
		elif width_multiplier == null:
			sub_division_widths.push_back(width)
		else:
			var weight_curve_t = inverse_lerp(end_length_width, length - end_length_width, offset)
			if width_multiplier_tile_length > 0:
				var mult = (length - end_length_width*2.0) / width_multiplier_tile_length
				if width_multiplier_tile_length_stretch_to_fit:
					mult = ceilf(mult)
				weight_curve_t *= mult
			if(weight_curve_t > 1.0):
				weight_curve_t -= floor(weight_curve_t)
			sub_division_widths.push_back(width * width_multiplier.sample_baked(weight_curve_t))
	
	var sub_division_transforms = []
	for i in range(len(sub_divisions)):
		var offset = sub_divisions[i]
		var offset_reference_transform = path_3d.curve.sample_baked_with_rotation(offset, true, true)
		
		if i==0:
			sub_division_transforms.push_back(offset_reference_transform.looking_at(path_3d.curve.sample_baked(sub_divisions[i+1], true), offset_reference_transform.basis.y))
		elif i==len(sub_divisions)-1:
			sub_division_transforms.push_back(offset_reference_transform.looking_at(path_3d.curve.sample_baked(sub_divisions[i-1], true), offset_reference_transform.basis.y, true))
		else:
			var direction_to_next = offset_reference_transform.origin.direction_to(path_3d.curve.sample_baked(sub_divisions[i+1], true))
			var direction_from_prev = path_3d.curve.sample_baked(sub_divisions[i-1], true).direction_to(offset_reference_transform.origin)
			sub_division_transforms.push_back(offset_reference_transform.looking_at(offset_reference_transform.origin + direction_to_next + direction_from_prev, offset_reference_transform.basis.y))
	
	var face_groups = []
	var vertice_count_per_sub_division = 0
	
	if mesh_format & MeshFormat.TUBE:
		face_groups.push_back([]);
		
		var maxAxis = 0.0
		
		if(faces < 3):
			push_warning("Unable to create tube with less than 3 faces")
			return null
		
		for f in range(faces):
			
			var f_delta = (1 - faces % 2) * 0.5
			var v = Vector3(sin(TAU * (f+f_delta)/faces), cos(TAU * (f+f_delta)/faces), 0.0) * 0.5
			face_groups[0].push_back(v)
			maxAxis = max(maxAxis, v.x)
			vertice_count_per_sub_division += 1
		for f in range(len(face_groups[0])):
			face_groups[0][f] *= 0.5 / maxAxis
	elif mesh_format & MeshFormat.CROSS:
		for f in range(faces):
			var v = Vector3(sin(PI * (f+0.5)/faces), cos(PI * (f+0.5)/faces), 0.0) * 0.5
			face_groups.push_back([-v, v]);
			vertice_count_per_sub_division += 2
	
	for group_i in range(len(face_groups)):
		var group = face_groups[group_i]
		for face_vertex_i in range(len(group)):
			var face_vertex = group[face_vertex_i]
			vertices.push_back(sub_division_transforms[0].translated_local(face_vertex * sub_division_widths[0]).origin)
	
	for i in range(1, len(sub_divisions)):
		for group_i in range(len(face_groups)):
			var group = face_groups[group_i]
			for face_vertex_i in range(len(group)):
				var face_vertex = group[face_vertex_i]
				
				if face_vertex_i == len(group)-1:
					if len(group) > 2:
						indices.append_array([len(vertices), 1+len(vertices)-vertice_count_per_sub_division*2, len(vertices)-vertice_count_per_sub_division])
						indices.append_array([len(vertices), 1+len(vertices)-vertice_count_per_sub_division, 1+len(vertices)-vertice_count_per_sub_division*2])
				else:
					indices.append_array([len(vertices), 1+len(vertices)-vertice_count_per_sub_division, len(vertices)-vertice_count_per_sub_division])
					indices.append_array([len(vertices), 1+len(vertices), 1+len(vertices)-vertice_count_per_sub_division])
				
				var vertex_position = sub_division_transforms[i].translated_local(face_vertex * sub_division_widths[i]).origin
				
				if width_around==WidthAround.EDGES and i < len(sub_divisions)-1:
					var a = sub_division_transforms[i].origin.direction_to(sub_division_transforms[i-1].origin)
					var b = sub_division_transforms[i].origin.direction_to(sub_division_transforms[i+1].origin)
					var scale_multiplier = 1.0/sin(a.angle_to(b)/2)
					var scale_direction = (a+b).normalized()
					
					vertex_position -= sub_division_transforms[i].origin
					vertex_position = vertex_position.slide(scale_direction) + vertex_position.project(scale_direction)*scale_multiplier
					vertex_position += sub_division_transforms[i].origin
				
				vertices.push_back(vertex_position)
	
	if mesh_format == MeshFormat.TUBE:
		for group in face_groups:
			var cap = Geometry2D.triangulate_polygon(group)
			
			for c in cap:
				indices.push_back(len(vertices) + c - len(group))
			
			cap.reverse()
			indices.append_array(cap)
	
	var array_mesh = ArrayMesh.new()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from_arrays(arrays)
	surface_tool.generate_normals()
	return surface_tool.commit()
