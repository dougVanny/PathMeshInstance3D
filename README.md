# PathMeshInstance3D

Node that creates a mesh based on a Path3D

![Image1](docs/image1.png)
![Image2](docs/image2.png)
![Image3](docs/image3.png)

## Enumerations

### enum MeshFormat:

Different formats a mesh can take on when generated

● **TUBE** = 1

Tube-like mesh along the set path. End of the tube will be closed of so their inside is not exposed

● **TUBE_UNCAPPED** = 3

Tube-like mesh along the set path. End of the tube will be open so their insides may be exposed

● **CROSS** = 4

Cross-like mesh. Can be used to save on triangles or to create a planar mesh

### enum SubDivisionRule:

Method to be used when tesselating the path to create it's sub divisions

● **CURVE_DENSITY** = 0

Path will be tesselated using `Curve3D.tessellate()`, making more curved parts of the curve will have a greater sub division density and will therefore follow a curved path more accurately

● **UNIFORM** = 1

Path will be tesselated using `Curve3D.tessellate_even_length()`, ignoring any curves the path makes and prioritizing having an even length between each sub division. Useful for vertex shader animations

### enum WidthAround:

Which part of the path should be used when calculating the width of the generated mesh

● **EDGES** = 0

Width will remaing constant along the whole edge connecting two sub divisions. Width on division points will be slightly wides to compensate for the curvature of the path

● **DIVISIONS** = 1

Width will be constant around each division of the path. The width on edges connecting divisions may look thinner where the path makes too sharp turns

### enum UVMapping:

Possible mapping properties to be later used in a mesh material

● **NONE** = 0

Information will be discarded

● **UV_X** = 1

Accessible via `UV.x` in fragment shaders and vertex shaders

● **UV_Y** = 2

Accessible via `UV.y` in fragment shaders and vertex shaders

● **UV2_X** = 3

Accessible via `UV2.x` in fragment shaders and vertex shaders

● **UV2_Y** = 4

Accessible via `UV2.y` in fragment shaders and vertex shaders

● **CUSTOM0_X** = 5

Accessible via `CUSTOM0.x` in vertex shaders

● **CUSTOM0_Y** = 6

Accessible via `CUSTOM0.y` in vertex shaders

● **CUSTOM0_Z** = 7

Accessible via `CUSTOM0.z` in vertex shaders

● **CUSTOM0_W** = 8

Accessible via `CUSTOM0.w` in vertex shaders


## Property Descriptions


● **float** _end_length_

The length of the path's end to be considered. Used by `PathMeshInstance3D.end_sub_divisions` and `PathMeshInstance3D.end_width_multiplier`


● **int** _end_sub_divisions_ `[default: 8]`

How many extra subdivisions should be added at the ends of the path


● **Curve** _end_width_multiplier_

Overrides the width at both ends of the path. Settings this will make `PathMeshInstance3D.width_multiplier` only use the length of the path between those ends


● **int** _faces_ `[default: 6]`

How many faces the mesh will have around its length. Depends on `PathMeshInstance3D.mesh_format`


● **MeshFormat** _mesh_format_ `[default: 1]`

Format the mesh will take on


● **Path3D** _path_3d_

Path the generated mesh will follow


● **float** _sub_division_max_length_ `[default: 0.0]`

Max length between each sub division. After tesselation, if any segment is greater than this value, it will be further broken down


● **int** _sub_division_max_stages_ `[default: 5]`

Controls how many sub divisions will be created along each segment of the path between two points. Increases exponentially. See also `Curve3D.tessellate()` and `Curve3D.tessellate_even_length()`


● **SubDivisionRule** _sub_division_rule_

Method to be used when tesselating the path to create it's sub divisions


● **UVMapping** _uv_line_mesh_around_ `[default: 1]`

Value that wraps around the mesh, specially around tube meshes, ranging from 0 to 1


● **UVMapping** _uv_line_mesh_height_

Considering the orientation of the path at each sub division, this is the height along the up axis of the path. Use set the tilt of each Curve3D point to control the path orientation


● **UVMapping** _uv_line_mesh_width_

Considering the orientation of the path at each sub division, this is the width along the right axis of the path. Use set the tilt of each Curve3D point to control the path orientation


● **UVMapping** _uv_line_original_width_

Original width of that path position within the mesh. This ignores the value stored in PathMeshInstance3D.width and reads only whatever multiplier was applied by the width curves


● **UVMapping** _uv_path_length_

Path length not normalized, ranging from 0 to whatever length the path has


● **UVMapping** _uv_path_length_normalized_ `[default: 2]`

Path length normalized, ranging from 0 to 1


● **UVMapping** _uv_path_point_

Index of each point from the original path


● **UVMapping** _uv_sub_division_

Index of each sub division created for the mesh


● **float** _width_ [default: 1.0]

Width around the path of the generated mesh. Mesh is generated around the path, so a value of 1 will generate vertices between -0.5 and 0.5


● **WidthAround** _width_around_

Which part of the path should be used when calculating the width of the generated mesh


● **Curve** _width_multiplier_

Curve that dictates the width of the mesh along the path. This heavily relies on the position of the mesh subdivisions, meaning that the less subdivions the mesh has, the less accurate it will follow this curve


● **float** _width_multiplier_tile_length_

Dictates if the width multiplier curve should be tiled along the length of the path

- A value of 0 will make the curve stretch along the whole path

- Any other value will make the curve repeat for each configured length units


● **bool** _width_multiplier_tile_length_shrink_to_fit_ `[default: true]`

Controls if the width multiplier curve should shrink to fit the whole length of the curve. Setting this to true will make the path always end at the end of the curve. Setting this to false will make the path end at any point of the curve.

Not used if PathMeshInstance3D.width_multiplier_tile_length is 0


● **float** _width_orientation_lerp_distance_

Controls the orientation of the width ring around the mesh. Rings around a straight subsection willbe parallel to the path by default. Set this to make such rings lerp towards non-straight sub divisions of the path. Use this to avoid broken meshes when you have sub divisions close to a sharp turn


Method Descriptions


● **void** generate_and_assign()

Generates a new mesh and assigns it to the MeshInstance3D


● **ArrayMesh** generate_mesh()

Generates a new mesh and returns it without assigning it to the MeshInstance3D

