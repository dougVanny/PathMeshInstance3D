@tool
class_name PathMeshInstance3D
extends MeshInstance3D
## Node that creates a mesh based on a [Path3D]

## Different formats a mesh can take on when generated
enum MeshFormat
{
	## Tube-like mesh along the set path. End of the tube will be closed of so their inside is not exposed
	TUBE = 0b001,
	## Tube-like mesh along the set path. End of the tube will be open so their insides may be exposed
	TUBE_UNCAPPED = 0b011,
	## Cross-like mesh. Can be used to save on triangles or to create a planar mesh
	CROSS = 0b100,
}

## Method to be used when tesselating the path to create it's sub divisions
enum SubDivisionRule
{
	## Path will be tesselated using [method Curve3D.tessellate], making more curved parts of the curve will
	## have a greater sub division density and will therefore follow a curved path more accurately
	CURVE_DENSITY,
	## Path will be tesselated using [method Curve3D.tessellate_even_length], ignoring any curves the path makes
	## and prioritizing having an even length between each sub division. Useful for vertex shader animations
	UNIFORM
}

## Which part of the path should be used when calculating the width of the generated mesh
enum WidthAround
{
	## Width will remaing constant along the whole edge connecting two sub divisions.
	## Width on division points will be slightly wides to compensate for the curvature of the path
	EDGES,
	## Width will be constant around each division of the path. The width on edges connecting divisions
	## may look thinner where the path makes too sharp turns
	DIVISIONS
}

## Possible mapping properties to be later used in a mesh material
enum UVMapping
{
	## Information will be discarded
	NONE,
	## Accessible via [code]UV.x[/code] in
	## [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins]fragment shaders[/url]
	## and [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins]vertex shaders[/url]
	UV_X,
	## Accessible via [code]UV.y[/code] in
	## [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins]fragment shaders[/url]
	## and [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins]vertex shaders[/url]
	UV_Y,
	## Accessible via [code]UV2.x[/code] in
	## [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins]fragment shaders[/url]
	## and [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins]vertex shaders[/url]
	UV2_X,
	## Accessible via [code]UV2.y[/code] in
	## [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins]fragment shaders[/url]
	## and [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins]vertex shaders[/url]
	UV2_Y,
	## Accessible via [code]CUSTOM0.x[/code] in
	## [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins]vertex shaders[/url]
	CUSTOM0_X,
	## Accessible via [code]CUSTOM0.y[/code] in
	## [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins]vertex shaders[/url]
	CUSTOM0_Y,
	## Accessible via [code]CUSTOM0.z[/code] in
	## [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins]vertex shaders[/url]
	CUSTOM0_Z,
	## Accessible via [code]CUSTOM0.w[/code] in
	## [url=https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/spatial_shader.html#vertex-built-ins]vertex shaders[/url]
	CUSTOM0_W,
}

## Path the generated mesh will follow
@export var path_3d : Path3D

## Format the mesh will take on
@export var mesh_format : MeshFormat = MeshFormat.TUBE
## How many faces the mesh will have around its length. Depends on [member PathMeshInstance3D.mesh_format]
@export_range(1, 64, 1, "or_greater") var faces : int = 6

@export_group("Sub Division Tesselation")
## Method to be used when tesselating the path to create it's sub divisions
@export var sub_division_rule : SubDivisionRule
## Controls how many sub divisions will be created along each segment of the path between two points.
## Increases exponentially. See also [method Curve3D.tessellate] and [method Curve3D.tessellate_even_length]
@export_range(0, 16) var sub_division_max_stages : int = 5
## Max length between each sub division. After tesselation, if any segment is greater than this value,
## it will be further broken down
@export_range(0, 100, 0.001, "or_greater") var sub_division_max_length : float = 0;

@export_group("Width")
## Width around the path of the generated mesh. Mesh is generated around the path, so a value of [code]1[/code]
## will generate vertices between [code]-0.5[/code] and [code]0.5[/code]
@export var width : float = 1.0
## Curve that dictates the width of the mesh along the path. This heavily relies on the position of the mesh subdivisions,
## meaning that the less subdivions the mesh has, the less accurate it will follow this curve
@export var width_multiplier : Curve
## Dictates if the width multiplier curve should be tiled along the length of the path[br]
## - A value of [code]0[/code] will make the curve stretch along the whole path[br]
## - Any other value will make the curve repeat for each configured length units
@export_range(0, 10, 0.001, "or_greater") var width_multiplier_tile_length : float
## Controls if the width multiplier curve should shrink to fit the whole length of the curve. 
## Setting this to true will make the path always end at the end of the curve.
## Setting this to false will make the path end at any point of the curve.[br][br]
## Not used if [member PathMeshInstance3D.width_multiplier_tile_length] is [code]0[/code]
@export var width_multiplier_tile_length_shrink_to_fit : bool = true
## Which part of the path should be used when calculating the width of the generated mesh
@export var width_around : WidthAround
## Controls the orientation of the width ring around the mesh.
## Rings around a straight subsection willbe parallel to the path by default.
## Set this to make such rings lerp towards non-straight sub divisions of the path.
## Use this to avoid broken meshes when you have sub divisions close to a sharp turn
@export_range(0, 10, 0.001, "or_greater") var width_orientation_lerp_distance : float

@export_group("Ends")
## The length of the path's end to be considered. Used by [member PathMeshInstance3D.end_sub_divisions]
## and [member PathMeshInstance3D.end_width_multiplier]
@export_range(0, 100, 0.001, "or_greater") var end_length : float
## How many extra subdivisions should be added at the ends of the path
@export var end_sub_divisions : int = 8
## Overrides the width at both ends of the path. Settings this will make [member PathMeshInstance3D.width_multiplier]
## only use the length of the path between those ends
@export var end_width_multiplier : Curve

@export_group("UV Mapping")
## Path length normalized, ranging from [code]0[/code] to [code]1[/code]
@export var uv_path_length_normalized : UVMapping = UVMapping.UV_Y
## Path length not normalized, ranging from [code]0[/code] to whatever length the path has
@export var uv_path_length : UVMapping
## Index of each sub division created for the mesh
@export var uv_sub_division : UVMapping
## Index of each point from the original path
@export var uv_path_point : UVMapping
## Value that wraps around the mesh, specially around tube meshes, ranging from [code]0[/code] to [code]1[/code]
@export var uv_line_mesh_around : UVMapping = UVMapping.UV_X
## Original width of that path position within the mesh. This ignores the value stored in [member PathMeshInstance3D.width]
## and reads only whatever multiplier was applied by the width curves
@export var uv_line_original_width : UVMapping
## Considering the orientation of the path at each sub division, this is the width along the right axis
## of the path. Use set the [code]tilt[/code] of each [Curve3D] point to control the path orientation
@export var uv_line_mesh_width : UVMapping
## Considering the orientation of the path at each sub division, this is the height along the up axis
## of the path. Use set the [code]tilt[/code] of each [Curve3D] point to control the path orientation
@export var uv_line_mesh_height : UVMapping

func _validate_property(property: Dictionary) -> void:
	if property.name == "mesh":
		property.usage |= PROPERTY_USAGE_READ_ONLY

## Generates a new mesh and assigns it to the MeshInstance3D
func generate_and_assign():
	mesh = generate_mesh()

## Generates a new mesh and returns it without assigning it to the MeshInstance3D
func generate_mesh() -> ArrayMesh:
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
				if width_multiplier_tile_length_shrink_to_fit:
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
