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
	CUSTOM0_X,
	CUSTOM0_Y,
	CUSTOM0_Z,
	CUSTOM0_W,
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
@export_range(0, 10, 0.001, "or_greater") var width_orientation_lerp_distance : float

@export_group("Ends")
@export_range(0, 100, 0.001, "or_greater") var end_length : float
@export var end_sub_divisions : int = 8
@export var end_width_multiplier : Curve

@export_group("UV Mapping")
@export var uv_path_length_normalized : UVMapping = UVMapping.UV_Y
@export var uv_path_length : UVMapping
@export var uv_sub_division : UVMapping
@export var uv_path_point : UVMapping
@export var uv_line_mesh_around : UVMapping = UVMapping.UV_X
@export var uv_line_original_width : UVMapping
@export var uv_line_mesh_width : UVMapping
@export var uv_line_mesh_height : UVMapping

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
	var uv = PackedVector2Array()
	var uv2 = PackedVector2Array()
	var custom0 = PackedFloat32Array()
	var custom1 = PackedFloat32Array()
	var indices = PackedInt32Array()
	
	var uv_path_length_normalized_array = []
	var uv_path_length_array = []
	var uv_sub_division_array = []
	var uv_path_point_array = []
	var uv_line_mesh_around_array = []
	var uv_line_original_width_array = []
	var uv_line_mesh_width_array = []
	var uv_line_mesh_height_array = []
	
	var point_offsets = []
	for i in range(path_3d.curve.point_count):
		point_offsets.push_back(path_3d.curve.get_closest_offset(path_3d.curve.sample(i, 0.0)))
	
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
		var offset_reference_transform = path_3d.curve.sample_baked_with_rotation(offset, false, true)
		
		if i==0:
			sub_division_transforms.push_back(offset_reference_transform.looking_at(path_3d.curve.sample_baked(sub_divisions[i+1]), offset_reference_transform.basis.y))
		elif i==len(sub_divisions)-1:
			sub_division_transforms.push_back(offset_reference_transform.looking_at(path_3d.curve.sample_baked(sub_divisions[i-1]), offset_reference_transform.basis.y, true))
		else:
			var direction_to_next = offset_reference_transform.origin.direction_to(path_3d.curve.sample_baked(sub_divisions[i+1]))
			var direction_from_prev = path_3d.curve.sample_baked(sub_divisions[i-1]).direction_to(offset_reference_transform.origin)
			
			if width_orientation_lerp_distance > 0 and is_zero_approx(direction_from_prev.angle_to(direction_to_next)):
				sub_division_transforms.push_back(null)
			else:
				sub_division_transforms.push_back(offset_reference_transform.looking_at(offset_reference_transform.origin + direction_to_next + direction_from_prev, offset_reference_transform.basis.y))
	
	var last_known_transform = null
	var last_known_i = -1
	for i in range(len(sub_division_transforms)):
		if sub_division_transforms[i] != null:
			if last_known_transform != null and last_known_i+1 != i:
				var last_offset = sub_divisions[last_known_i]
				var lerp_distance = min(width_orientation_lerp_distance, (sub_divisions[i] - last_offset)/2.0)
				for j in range(last_known_i+1, i):
					var reference_transform = path_3d.curve.sample_baked_with_rotation(sub_divisions[j], false, true)
					reference_transform = reference_transform.looking_at(path_3d.curve.sample_baked(sub_divisions[j+1]), reference_transform.basis.y)
					
					var sub_division_basis = reference_transform.basis
					
					if inverse_lerp(last_offset, sub_divisions[i], sub_divisions[j]) < 0.5:
						sub_division_basis = sub_division_transforms[last_known_i].basis.slerp(sub_division_basis, clamp(inverse_lerp(last_offset, last_offset+lerp_distance, sub_divisions[j]), 0.0, 1.0))
					else:
						sub_division_basis = sub_division_transforms[i].basis.slerp(sub_division_basis, clamp(inverse_lerp(sub_divisions[i], sub_divisions[i]-lerp_distance, sub_divisions[j]), 0.0, 1.0))
					
					sub_division_transforms[j] = Transform3D(sub_division_basis,path_3d.curve.sample_baked(sub_divisions[j]))
			last_known_transform = sub_division_transforms[i]
			last_known_i = i
	
	var face_groups = []
	var face_around_groups = []
	var vertice_count_per_sub_division = 0
	
	if mesh_format & MeshFormat.TUBE:
		face_groups.push_back([]);
		face_around_groups.push_back([]);
		
		var maxAxis = 0.0
		
		if(faces < 3):
			push_warning("Unable to create tube with less than 3 faces")
			return null
		
		for f in range(faces+1):
			
			var f_delta = (1 - faces % 2) * 0.5
			var v = Vector3(sin(TAU * (f+f_delta)/faces), cos(TAU * (f+f_delta)/faces), 0.0) * 0.5
			face_groups[0].push_back(v)
			face_around_groups[0].push_back(float(f)/faces)
			maxAxis = max(maxAxis, v.x)
			vertice_count_per_sub_division += 1
		for f in range(len(face_groups[0])):
			face_groups[0][f] *= 0.5 / maxAxis
	elif mesh_format & MeshFormat.CROSS:
		for f in range(faces):
			var f_delta = (faces % 2) * 0.5
			var v = Vector3(sin(PI * (f+f_delta)/faces), cos(PI * (f+f_delta)/faces), 0.0) * 0.5
			face_groups.push_back([-v, v]);
			face_around_groups.push_back([
				(f/2.0)/faces,
				0.5 + ((f+1)/2.0)/faces
			])
			vertice_count_per_sub_division += 2
	
	print(face_around_groups)
	
	var min_face_vertex_x = INF
	var min_face_vertex_y = INF
	var max_face_vertex_x = -INF
	var max_face_vertex_y = -INF
	
	for group in face_groups:
		for face_vertex in group:
			min_face_vertex_x = min(min_face_vertex_x, face_vertex.x)
			min_face_vertex_y = min(min_face_vertex_y, face_vertex.y)
			max_face_vertex_x = max(max_face_vertex_x, face_vertex.x)
			max_face_vertex_y = max(max_face_vertex_y, face_vertex.y)
	
	for group_i in range(len(face_groups)):
		var group = face_groups[group_i]
		for face_vertex_i in range(len(group)):
			var face_vertex = group[face_vertex_i]
			vertices.push_back(sub_division_transforms[0].translated_local(face_vertex * sub_division_widths[0]).origin)
			custom1.push_back(sub_division_transforms[0].origin.x)
			custom1.push_back(sub_division_transforms[0].origin.y)
			custom1.push_back(sub_division_transforms[0].origin.z)
			custom1.push_back(0)
			
			uv_path_length_normalized_array.push_back(sub_divisions[0] / length)
			uv_path_length_array.push_back(sub_divisions[0])
			uv_sub_division_array.push_back(0)
			uv_path_point_array.push_back(0)
			
			uv_line_mesh_around_array.push_back(face_around_groups[group_i][face_vertex_i])
			uv_line_original_width_array.push_back(sub_division_widths[0] / width)
			uv_line_mesh_width_array.push_back(inverse_lerp(min_face_vertex_x, max_face_vertex_x, face_vertex.x))
			uv_line_mesh_height_array.push_back(inverse_lerp(min_face_vertex_y, max_face_vertex_y, face_vertex.y))
	
	for i in range(1, len(sub_divisions)):
		if sub_division_widths[i]==0 and sub_division_widths[i-1]==0 and sub_division_widths[i+1]==0:
			continue
		
		for group_i in range(len(face_groups)):
			var group = face_groups[group_i]
			for face_vertex_i in range(len(group)):
				var face_vertex = group[face_vertex_i]
				
				if sub_division_widths[i]!=0 or sub_division_widths[i-1]!=0:
					if face_vertex_i < len(group)-1:
						indices.append_array([len(vertices), 1+len(vertices)-vertice_count_per_sub_division, len(vertices)-vertice_count_per_sub_division])
						indices.append_array([len(vertices), 1+len(vertices), 1+len(vertices)-vertice_count_per_sub_division])
				
				var vertex_position = sub_division_transforms[i].translated_local(face_vertex * sub_division_widths[i]).origin
				
				if width_around==WidthAround.EDGES and sub_division_widths[i] > 0 and i < len(sub_divisions)-1:
					var a = sub_division_transforms[i].origin.direction_to(sub_division_transforms[i-1].origin)
					var b = sub_division_transforms[i].origin.direction_to(sub_division_transforms[i+1].origin)
					var scale_multiplier = 1.0/sin(a.angle_to(b)/2)
					
					if not is_equal_approx(scale_multiplier,1):
						var scale_direction = (a+b).normalized()
						
						vertex_position -= sub_division_transforms[i].origin
						vertex_position = vertex_position.slide(scale_direction) + vertex_position.project(scale_direction)*scale_multiplier
						vertex_position += sub_division_transforms[i].origin
				
				vertices.push_back(vertex_position)
				custom1.push_back(sub_division_transforms[i].origin.x)
				custom1.push_back(sub_division_transforms[i].origin.y)
				custom1.push_back(sub_division_transforms[i].origin.z)
				custom1.push_back(0)
				
				uv_path_length_normalized_array.push_back(sub_divisions[i] / length)
				uv_path_length_array.push_back(sub_divisions[i])
				uv_sub_division_array.push_back(i)
				print(point_offsets)
				if i == len(sub_divisions)-1:
					uv_path_point_array.push_back(len(point_offsets)-1)
				else:
					for point_offset_i in range(len(point_offsets)):
						if point_offset_i == len(point_offsets)-1:
							uv_path_point_array.push_back(point_offset_i)
						elif sub_divisions[i] <= point_offsets[point_offset_i+1]:
							uv_path_point_array.push_back(lerp(point_offset_i, point_offset_i+1, inverse_lerp(point_offsets[point_offset_i], point_offsets[point_offset_i+1], sub_divisions[i])))
							break
				
				uv_line_mesh_around_array.push_back(face_around_groups[group_i][face_vertex_i])
				uv_line_original_width_array.push_back(sub_division_widths[i] / width)
				uv_line_mesh_width_array.push_back(inverse_lerp(min_face_vertex_x, max_face_vertex_x, face_vertex.x))
				uv_line_mesh_height_array.push_back(inverse_lerp(min_face_vertex_y, max_face_vertex_y, face_vertex.y))
	
	if mesh_format == MeshFormat.TUBE:
		for group in face_groups:
			var cap = Geometry2D.triangulate_polygon(group)
			
			for c in cap:
				indices.push_back(len(vertices) + c - len(group))
			
			cap.reverse()
			indices.append_array(cap)
	
	var uv_map = {}
	uv_map[uv_path_length_normalized] = uv_path_length_normalized_array
	uv_map[uv_path_length] = uv_path_length_array
	uv_map[uv_sub_division] = uv_sub_division_array
	uv_map[uv_path_point] = uv_path_point_array
	uv_map[uv_line_mesh_around] = uv_line_mesh_around_array
	uv_map[uv_line_original_width] = uv_line_original_width_array
	uv_map[uv_line_mesh_width] = uv_line_mesh_width_array
	uv_map[uv_line_mesh_height] = uv_line_mesh_height_array
	
	for i in range(len(vertices)):
		uv.push_back(Vector2(
			uv_map[UVMapping.UV_X][i] if UVMapping.UV_X in uv_map else 0.0,
			uv_map[UVMapping.UV_Y][i] if UVMapping.UV_Y in uv_map else 0.0
		))
		uv2.push_back(Vector2(
			uv_map[UVMapping.UV2_X][i] if UVMapping.UV2_X in uv_map else 0.0,
			uv_map[UVMapping.UV2_Y][i] if UVMapping.UV2_Y in uv_map else 0.0
		))
		custom0.append_array([
			uv_map[UVMapping.CUSTOM0_X][i] if UVMapping.CUSTOM0_X in uv_map else 0.0,
			uv_map[UVMapping.CUSTOM0_Y][i] if UVMapping.CUSTOM0_Y in uv_map else 0.0,
			uv_map[UVMapping.CUSTOM0_Z][i] if UVMapping.CUSTOM0_Z in uv_map else 0.0,
			uv_map[UVMapping.CUSTOM0_W][i] if UVMapping.CUSTOM0_W in uv_map else 0.0
		])
	
	var array_mesh = ArrayMesh.new()
	
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	arrays[Mesh.ARRAY_CUSTOM0] = custom0
	arrays[Mesh.ARRAY_CUSTOM1] = custom1
	
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from_arrays(arrays)
	surface_tool.generate_normals()
	arrays = surface_tool.commit_to_arrays()
	
	array_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Mesh.ArrayCustomFormat.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ArrayFormat.ARRAY_FORMAT_CUSTOM0_SHIFT | Mesh.ArrayCustomFormat.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ArrayFormat.ARRAY_FORMAT_CUSTOM1_SHIFT)
	return array_mesh
