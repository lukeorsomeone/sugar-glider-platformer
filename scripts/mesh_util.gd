extends RefCounted
## Helpers for building chunky low-poly meshes out of primitive parts.
## Each part is [PrimitiveMesh, Transform3D, Color]; colors are baked into vertex colors
## so a whole prop is one mesh with one material (cheap to draw and to MultiMesh).

const PS1_SHADER := preload("res://shaders/ps1.gdshader")
const PS1_TEXTURED_SHADER := preload("res://shaders/ps1_textured.gdshader")
const PS1_TILED_SHADER := preload("res://shaders/ps1_tiled.gdshader")
const OUTLINE_SHADER := preload("res://shaders/outline.gdshader")

static var _vc_mat: ShaderMaterial
static var _outline_mat: ShaderMaterial


## Shared 1-pixel dark outline, used as a material's next_pass (Bao and the fruit).
static func outline_material() -> ShaderMaterial:
	if _outline_mat == null:
		_outline_mat = ShaderMaterial.new()
		_outline_mat.shader = OUTLINE_SHADER
	return _outline_mat


## Shared PS1 material (vertex colours, per-vertex lighting, vertex snapping).
static func vertex_color_material() -> ShaderMaterial:
	if _vc_mat == null:
		_vc_mat = ps1_material()
	return _vc_mat


static func ps1_material(emission: Color = Color.BLACK, energy: float = 0.0, albedo: Color = Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1_SHADER
	m.set_shader_parameter("emission_color", emission)
	m.set_shader_parameter("emission_energy", energy)
	m.set_shader_parameter("albedo", albedo)
	return m


## Swaps each surface of an imported mesh for a PS1 material: the textured version if the
## surface has a texture (hard-edged pixels), otherwise flat colour. Works on skinned meshes too.
static func apply_ps1(mi: MeshInstance3D, outline := false) -> void:
	for i in mi.mesh.get_surface_count():
		var sm := mi.get_active_material(i) as BaseMaterial3D
		var m: ShaderMaterial
		if sm != null and sm.albedo_texture != null:
			m = ShaderMaterial.new()
			m.shader = PS1_TEXTURED_SHADER
			m.set_shader_parameter("tex", sm.albedo_texture)
		else:
			var c := Color.WHITE if sm == null else sm.albedo_color
			m = ps1_material(Color.BLACK, 0.0, c)
		if outline:
			m.next_pass = outline_material()
		mi.set_surface_override_material(i, m)


## Tiling pixel-art material for level geometry (texture x vertex colour x tint).
static func tiled_material(tex: Texture2D, tint: Color = Color.WHITE) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = PS1_TILED_SHADER
	m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", tint)
	return m


## Parts are [PrimitiveMesh, Transform3D, Color] with an optional 4th Vector2 that scales
## the part's UVs (so a tiling texture repeats that many times around/along it).
static func merge_parts(parts: Array) -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for p in parts:
		var arr: Array = (p[0] as PrimitiveMesh).get_mesh_arrays()
		var xf: Transform3D = p[1]
		var c: Color = p[2]
		var uv_scale: Vector2 = p[3] if p.size() > 3 else Vector2.ONE
		var base := verts.size()
		var nb := xf.basis.inverse().transposed()
		var pv: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var pn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var pu: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
		for i in pv.size():
			verts.append(xf * pv[i])
			norms.append((nb * pn[i]).normalized())
			cols.append(c)
			uvs.append(pu[i] * uv_scale if i < pu.size() else Vector2.ZERO)
		var pi: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		for i in pi:
			idx.append(base + i)
	var out := []
	out.resize(Mesh.ARRAY_MAX)
	out[Mesh.ARRAY_VERTEX] = verts
	out[Mesh.ARRAY_NORMAL] = norms
	out[Mesh.ARRAY_COLOR] = cols
	out[Mesh.ARRAY_TEX_UV] = uvs
	out[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


static func at(pos: Vector3, basis: Basis = Basis.IDENTITY) -> Transform3D:
	return Transform3D(basis, pos)


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func sphere(radius: float, segments: int = 12) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = segments
	m.rings = maxi(segments / 2, 4)
	return m


static func capsule(radius: float, height: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 10
	m.rings = 4
	return m


static func cylinder(top: float, bottom: float, height: float, segments: int = 10) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	return m
