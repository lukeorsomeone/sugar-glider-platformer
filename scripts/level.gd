extends Node3D
## Test level: a winding forest path with platforms, gaps to glide over, updrafts,
## fruit to collect and a goal tree at the end.
##
## Everything is laid out by "offset" (metres along the path) and height, so editing the
## level is just editing the PLATFORMS / FRUIT / UPDRAFTS lists below.

const MeshUtil := preload("res://scripts/mesh_util.gd")
const InputSetup := preload("res://scripts/input_setup.gd")
const PlayerScript := preload("res://scripts/player.gd")
const CameraScript := preload("res://scripts/path_camera.gd")

const HALF_WIDTH := 1.6         # half the width of the walkable path
const STEP_UP := 0.35           # ledges this small are walked up, not blocked
const BODY_RADIUS := 0.25       # how close the glider can get to a wall
const BODY_HEIGHT := 0.9
const KILL_HEIGHT := -9.0       # fall below this and you respawn
var kill_height := KILL_HEIGHT  # (instance copy so the player can read it)
const FOREST_FLOOR := -12.0

## [start, end, top height, solid]
## Solid blocks are ground with walls you bump into. Non-solid ones are one-way
## branches: you can jump up through them from below and land on top.
const PLATFORMS := [
	[0.0, 18.0, 0.0, true],
	[18.0, 24.0, 1.0, true],
	[24.0, 30.0, 2.0, true],
	# pit 30 - 36
	[36.0, 44.0, 1.0, true],
	[46.0, 50.0, 3.4, false],
	[52.5, 56.5, 5.2, false],
	[58.0, 66.0, 2.5, true],
	# wide gap 66 - 80 with an updraft in the middle: glide over it
	[80.0, 92.0, 0.5, true],
	[84.0, 88.0, 3.2, false],
	[92.0, 96.0, 1.6, true],
	[96.0, 100.0, 3.0, true],
	# gap 100 - 109
	[109.0, 135.0, 1.0, true],
]

## [offset, height above the ground at that spot]
const FRUIT := [
	[8.0, 1.0], [12.0, 1.0], [21.0, 2.0], [27.0, 3.3], [33.0, 4.0],
	[48.0, 4.3], [54.5, 6.1], [62.0, 3.5], [70.0, 5.5], [73.0, 7.5], [76.0, 5.5],
	[86.0, 4.1], [98.0, 4.0], [104.5, 5.0], [118.0, 2.0],
]

## [start, end, lift speed]  rising air that carries you up while gliding
const UPDRAFTS := [
	[69.0, 77.0, 7.0],
]

## Respawn points. You come back at the furthest one you've passed.
const CHECKPOINTS := [2.0, 37.0, 59.0, 81.0, 110.0]

const GOAL_OFFSET := 128.0

## Pixel-art textures made in Aseprite (tools/aseprite/level_textures.lua).
const TEX_GRASS := preload("res://assets/textures/source/grass_top.png")
const TEX_GRASS_LIP := preload("res://assets/textures/source/grass_lip.png")
const TEX_DIRT := preload("res://assets/textures/source/dirt_side.png")
const TEX_WOOD := preload("res://assets/textures/source/wood.png")
const TEX_BARK := preload("res://assets/textures/source/gum_bark.png")
const TEX_LEAVES := preload("res://assets/textures/source/leaves.png")
const TILE := 1.6               # metres covered by one 32px texture tile
const LIP := 0.5                # height of the grassy edge band on solid ground

var curve: Curve3D
var length := 0.0
var player: Node3D
var camera: Camera3D

var _fruit: Array = []          # [{node, offset, height, taken}]
var _fruit_count := 0
var _best_checkpoint := 0
var _finished := false
var _time := 0.0
var _hud_fruit: Label
var _hud_message: Label


func _ready() -> void:
	InputSetup.setup()
	_build_curve()
	_build_environment()
	_build_platforms()
	_build_trees()
	_build_fruit()
	_build_updrafts()
	_build_goal()
	_flush_trees()
	_build_hud()

	player = PlayerScript.new()
	player.level = self
	add_child(player)
	player.fell_off.connect(_respawn)
	player.place(CHECKPOINTS[0], ground_height(CHECKPOINTS[0], 50.0))

	camera = CameraScript.new()
	camera.target = player
	camera.level = self
	camera.fov = 55.0
	add_child(camera)
	camera.make_current()
	camera.snap()


func _process(delta: float) -> void:
	_time += delta
	if Input.is_action_just_pressed("restart"):
		var screen := get_node_or_null("/root/Screen")
		if screen:
			screen.reload()
		else:
			get_tree().reload_current_scene()
		return

	# Spin and bob the fruit, and collect any the glider touches.
	for f in _fruit:
		if f.taken:
			continue
		var n: Node3D = f.node
		n.rotation.y += delta * 2.5
		n.position = path_point(f.offset) + Vector3(0, f.height + sin(_time * 3.0 + f.offset) * 0.12, 0)
		if absf(player.offset - f.offset) < 0.6 and absf(player.height + 0.5 - f.height) < 0.8:
			f.taken = true
			n.visible = false
			_fruit_count += 1
			_update_hud()

	# Checkpoints.
	for i in CHECKPOINTS.size():
		if i > _best_checkpoint and player.offset >= CHECKPOINTS[i] and player.grounded:
			_best_checkpoint = i

	if not _finished and player.offset >= GOAL_OFFSET:
		_finished = true
		player.controls_enabled = false
		_hud_message.text = "BAO MADE IT HOME!\n\n%d/%d FRUIT\n\nPRESS R TO PLAY AGAIN" % [_fruit_count, _fruit.size()]
		_hud_message.visible = true


func _respawn() -> void:
	var o: float = CHECKPOINTS[_best_checkpoint]
	player.place(o, ground_height(o, 50.0))
	camera.snap()


# ---------------------------------------------------------------- path maths

func path_point(o: float) -> Vector3:
	return curve.sample_baked(clampf(o, 0.0, length), true)


## Forward direction along the path (flat).
func path_dir(o: float) -> Vector3:
	var a := path_point(o - 0.3)
	var b := path_point(o + 0.3)
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	return d.normalized() if d.length() > 0.0001 else Vector3.RIGHT


## The side of the path the camera sits on.
func path_side(o: float) -> Vector3:
	# Forward x up points to the right of travel, so a camera here looking back at the path
	# sees forwards as screen-right.
	return path_dir(o).cross(Vector3.UP).normalized()


# ---------------------------------------------------------------- collision

## Highest platform top under the glider that it could stand on (at or just above its feet).
func ground_height(o: float, feet: float) -> float:
	var best := -INF
	for p in PLATFORMS:
		if o >= p[0] - BODY_RADIUS and o <= p[1] + BODY_RADIUS and p[2] <= feet + STEP_UP:
			best = maxf(best, p[2])
	return best


## True if moving to offset o would walk into the side of a solid block.
func is_blocked(o: float, feet: float, _dir: float) -> bool:
	for p in PLATFORMS:
		if not p[3]:
			continue
		if o >= p[0] - BODY_RADIUS and o <= p[1] + BODY_RADIUS and p[2] > feet + STEP_UP:
			return true
	return false


func updraft_at(o: float, feet: float) -> float:
	for u in UPDRAFTS:
		if o >= u[0] and o <= u[1] and feet < 12.0:
			return u[2]
	return 0.0


# ---------------------------------------------------------------- building

func _build_curve() -> void:
	# A gently winding path through the forest.
	curve = Curve3D.new()
	curve.bake_interval = 0.2
	var pts: Array[Vector3] = []
	for i in 20:
		pts.append(Vector3(i * 8.0, 0.0, sin(i * 0.55) * 9.0 + sin(i * 0.23) * 6.0))
	for i in pts.size():
		var prev := pts[maxi(i - 1, 0)]
		var next := pts[mini(i + 1, pts.size() - 1)]
		var tangent := (next - prev) * 0.25
		curve.add_point(pts[i], -tangent, tangent)
	length = curve.get_baked_length()


func _build_environment() -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.45, 0.8)
	sky_mat.sky_horizon_color = Color(0.95, 0.75, 0.55)
	sky_mat.ground_horizon_color = Color(0.3, 0.4, 0.3)
	sky_mat.ground_bottom_color = Color(0.1, 0.18, 0.1)
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.75, 0.75, 0.65)
	env.fog_density = 0.0035
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.light_energy = 1.1
	sun.light_color = Color(1.0, 0.93, 0.8)
	add_child(sun)

	# Forest floor far below the path, so gaps look like real drops.
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(400, 400)
	var fm := MeshInstance3D.new()
	fm.mesh = floor_mesh
	fm.material_override = MeshUtil.tiled_material(TEX_GRASS, Color(0.45, 0.6, 0.45))
	# PlaneMesh UVs run 0..1 across it; scale them so the grass tiles at the usual size.
	fm.material_override.set_shader_parameter("uv_scale", Vector2.ONE * floor_mesh.size.x / TILE)
	var mid := path_point(length * 0.5)
	fm.position = Vector3(mid.x, FOREST_FLOOR, mid.z)
	add_child(fm)


func _build_platforms() -> void:
	var mats := {
		"grass": MeshUtil.tiled_material(TEX_GRASS),
		"lip": MeshUtil.tiled_material(TEX_GRASS_LIP),
		"dirt": MeshUtil.tiled_material(TEX_DIRT),
		"wood": MeshUtil.tiled_material(TEX_WOOD),
	}
	for p in PLATFORMS:
		var solid: bool = p[3]
		var bottom: float = FOREST_FLOOR if solid else p[2] - 0.45
		var width := HALF_WIDTH if solid else HALF_WIDTH * 0.8
		var mi := MeshInstance3D.new()
		mi.mesh = _strip_mesh(p[0], p[1], p[2], bottom, width, solid, mats)
		add_child(mi)


## A block that follows the curve from offset a to b. Solid ground gets a grass top, a
## grassy edge band and dirt sides; branches are wood all over. UVs are in world metres
## (one texture tile per TILE), so the pattern lines up from one platform to the next.
## Vertex colours (greys) shade the faces: the side facing away from the camera is darker.
func _strip_mesh(a: float, b: float, top: float, bottom: float, half: float, solid: bool, mats: Dictionary) -> ArrayMesh:
	var tools := {}
	for key in (["grass", "lip", "dirt"] if solid else ["wood"]):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = st
	var top_st: SurfaceTool = tools["grass" if solid else "wood"]
	var lip_st: SurfaceTool = tools.get("lip")
	var side_st: SurfaceTool = tools["dirt" if solid else "wood"]

	var steps := maxi(1, ceili((b - a) / 0.5))
	var rows: Array = []
	for i in steps + 1:
		var o := lerpf(a, b, float(i) / steps)
		var c := path_point(o)
		var s := path_side(o) * half
		rows.append([c - s, c + s, o])   # [far edge, camera-side edge, offset]
	var w := half * 2.0 / TILE
	var up := Vector3(0, top, 0)
	var down := Vector3(0, bottom, 0)
	var lip_h := LIP if solid else 0.0
	var edge := Vector3(0, top - lip_h, 0)
	var depth := (top - lip_h - bottom) / TILE
	const NEAR := Color(1, 1, 1)
	const FAR := Color(0.72, 0.72, 0.72)
	for i in steps:
		var l0: Vector3 = rows[i][0]
		var r0: Vector3 = rows[i][1]
		var l1: Vector3 = rows[i + 1][0]
		var r1: Vector3 = rows[i + 1][1]
		var u0: float = rows[i][2] / TILE
		var u1: float = rows[i + 1][2] / TILE
		_quad(top_st, [l0 + up, l1 + up, r1 + up, r0 + up],
			[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, w), Vector2(u0, w)], NEAR, Vector3.UP)
		if solid:
			var lip_uv := [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, 1), Vector2(u0, 1)]
			_quad(lip_st, [l0 + up, l1 + up, l1 + edge, l0 + edge], lip_uv, FAR, Vector3.FORWARD)
			_quad(lip_st, [r0 + up, r1 + up, r1 + edge, r0 + edge], lip_uv, NEAR, Vector3.BACK)
		var side_uv := [Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, depth), Vector2(u0, depth)]
		_quad(side_st, [l0 + edge, l1 + edge, l1 + down, l0 + down], side_uv, FAR, Vector3.FORWARD)
		_quad(side_st, [r0 + edge, r1 + edge, r1 + down, r0 + down], side_uv, NEAR, Vector3.BACK)
		_quad(side_st, [l0 + down, l1 + down, r1 + down, r0 + down],
			[Vector2(u0, 0), Vector2(u1, 0), Vector2(u1, w), Vector2(u0, w)], FAR * 0.7, Vector3.DOWN)
	# End caps.
	var cap_uv := [Vector2(0, 0), Vector2(w, 0), Vector2(w, (top - bottom) / TILE), Vector2(0, (top - bottom) / TILE)]
	var f: Array = rows[0]
	var e: Array = rows[steps]
	_quad(side_st, [f[0] + up, f[1] + up, f[1] + down, f[0] + down], cap_uv, Color(0.85, 0.85, 0.85), Vector3.LEFT)
	_quad(side_st, [e[0] + up, e[1] + up, e[1] + down, e[0] + down], cap_uv, Color(0.85, 0.85, 0.85), Vector3.RIGHT)

	var mesh := ArrayMesh.new()
	for key in tools:
		(tools[key] as SurfaceTool).commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mats[key])
	return mesh


func _quad(st: SurfaceTool, v: Array, uv: Array, col: Color, n: Vector3) -> void:
	st.set_color(col)
	st.set_normal(n)
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_uv(uv[i])
		st.add_vertex(v[i])


func _build_trees() -> void:
	# Eucalyptus-ish trees behind the path (the far side from the camera), rising from the forest floor.
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var o := 0.0
	while o < length:
		var c := path_point(o)
		var away := -path_side(o)
		var dist := rng.randf_range(5.0, 18.0)
		var h := rng.randf_range(23.0, 30.0)
		var base := c + away * dist + Vector3(rng.randf_range(-1, 1), FOREST_FLOOR, rng.randf_range(-1, 1))
		_add_tree(base, h, rng)
		o += rng.randf_range(2.5, 5.0)


## Queues a tree's trunk and leaves. All trees end up in two meshes (bark and leaves),
## built by _flush_trees(), so the whole forest is just two draw calls.
var _trunk_parts: Array = []
var _leaf_parts: Array = []

func _add_tree(base: Vector3, h: float, rng: RandomNumberGenerator, r: float = -1.0, leaf_size: float = -1.0) -> void:
	var shade := rng.randf_range(0.75, 1.0)
	if r < 0.0:
		r = rng.randf_range(0.35, 0.6)
	# UV scale: tiles around the trunk (circumference) and up it (height).
	var bark_uv := Vector2(maxf(1.0, roundf(TAU * r / TILE)), h / TILE)
	_trunk_parts.append([MeshUtil.cylinder(r * 0.7, r, h, 7), MeshUtil.at(base + Vector3(0, h * 0.5, 0)),
		Color(shade, shade, shade), bark_uv])
	var leaf_shade := rng.randf_range(0.7, 1.0)
	for i in 3:
		var size := leaf_size if leaf_size > 0.0 else rng.randf_range(1.8, 2.8)
		var p := Vector3(rng.randf_range(-1.2, 1.2), h + rng.randf_range(-1.0, 1.5), rng.randf_range(-1.2, 1.2))
		var leaf_uv := Vector2(roundf(TAU * size / TILE), roundf(PI * size / TILE))
		_leaf_parts.append([MeshUtil.sphere(size, 7), MeshUtil.at(base + p),
			Color(leaf_shade, leaf_shade, leaf_shade), leaf_uv])


func _flush_trees() -> void:
	for pair in [[_trunk_parts, TEX_BARK], [_leaf_parts, TEX_LEAVES]]:
		if pair[0].is_empty():
			continue
		var mi := MeshInstance3D.new()
		mi.mesh = MeshUtil.merge_parts(pair[0])
		mi.material_override = MeshUtil.tiled_material(pair[1])
		add_child(mi)
	_trunk_parts.clear()
	_leaf_parts.clear()


func _build_fruit() -> void:
	for f in FRUIT:
		var o: float = f[0]
		var g := ground_height(o, 50.0)
		var h: float = f[1] + (g if g > KILL_HEIGHT else 0.0)
		var parts := [
			[MeshUtil.sphere(0.22, 8), MeshUtil.at(Vector3.ZERO), Color(1.0, 0.55, 0.15)],
			[MeshUtil.box(Vector3(0.05, 0.14, 0.05)), MeshUtil.at(Vector3(0, 0.25, 0)), Color(0.4, 0.25, 0.1)],
			[MeshUtil.box(Vector3(0.16, 0.03, 0.08)), MeshUtil.at(Vector3(0.08, 0.27, 0)), Color(0.3, 0.7, 0.25)],
		]
		var mi := MeshInstance3D.new()
		mi.mesh = MeshUtil.merge_parts(parts)
		mi.material_override = MeshUtil.ps1_material(Color(1.0, 0.6, 0.2), 0.35)
		add_child(mi)
		mi.position = path_point(o) + Vector3(0, h, 0)
		_fruit.append({"node": mi, "offset": o, "height": h, "taken": false})


func _build_updrafts() -> void:
	for u in UPDRAFTS:
		var mid: float = (u[0] + u[1]) * 0.5
		var span: float = u[1] - u[0]
		var p := CPUParticles3D.new()
		p.amount = 50
		p.lifetime = 1.8
		p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		p.emission_box_extents = Vector3(HALF_WIDTH, 0.5, span * 0.5)
		p.direction = Vector3.UP
		p.spread = 8.0
		p.gravity = Vector3(0, 3.0, 0)
		p.initial_velocity_min = 3.0
		p.initial_velocity_max = 5.0
		p.scale_amount_min = 0.5
		p.scale_amount_max = 1.2
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1, 1, 1, 0.0))
		ramp.add_point(0.25, Color(0.9, 1.0, 0.9, 0.35))
		ramp.set_color(1, Color(1, 1, 1, 0.0))
		p.color_ramp = ramp
		var quad := QuadMesh.new()
		quad.size = Vector2(0.06, 0.35)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.vertex_color_use_as_albedo = true
		quad.material = m
		p.mesh = quad
		add_child(p)
		var c := path_point(mid)
		var d := path_dir(mid)
		p.global_transform = Transform3D(Basis.looking_at(d, Vector3.UP), c + Vector3(0, -3.0, 0))


func _build_goal() -> void:
	# A big hollow gum tree: Bao's home.
	var c := path_point(GOAL_OFFSET + 2.5)
	var g := ground_height(GOAL_OFFSET, 50.0)
	var away := -path_side(GOAL_OFFSET)
	var pos := c + away * 1.2
	var base := Vector3(pos.x, FOREST_FLOOR, pos.z)
	_trunk_parts.append([MeshUtil.cylinder(1.1, 1.5, 16.0, 9), MeshUtil.at(base + Vector3(0, 8.0, 0)),
		Color.WHITE, Vector2(6, 10)])
	_leaf_parts.append([MeshUtil.sphere(4.0, 8), MeshUtil.at(base + Vector3(0, 16.0, 0)),
		Color.WHITE, Vector2(16, 8)])
	# Glowing hollow to aim for.
	var hole := MeshInstance3D.new()
	hole.mesh = MeshUtil.sphere(0.7, 10)
	hole.material_override = MeshUtil.ps1_material(Color(1.0, 0.85, 0.4), 1.2, Color(0.2, 0.15, 0.1))
	hole.position = path_point(GOAL_OFFSET + 1.0) + Vector3(0, g + 1.2, 0)
	add_child(hole)


func _build_hud() -> void:
	# Laid out for the 320x240 screen (see screen.gd); the pixel font is crisp at sizes 8, 16, 24...
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud_fruit = Label.new()
	_hud_fruit.position = Vector2(6, 4)
	_hud_fruit.label_settings = _hud_text(8)
	layer.add_child(_hud_fruit)

	var hint := Label.new()
	hint.text = "A/D MOVE  SPACE JUMP (HOLD TO GLIDE)  R RESTART"
	hint.label_settings = _hud_text(8)
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 6
	hint.offset_top = -14
	hint.offset_bottom = -4
	layer.add_child(hint)

	_hud_message = Label.new()
	_hud_message.set_anchors_preset(Control.PRESET_FULL_RECT)
	_hud_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hud_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hud_message.label_settings = _hud_text(16)
	_hud_message.visible = false
	layer.add_child(_hud_message)
	_update_hud()


func _hud_text(size: int) -> LabelSettings:
	var ls := LabelSettings.new()
	ls.font_size = size
	ls.font_color = Color.WHITE
	ls.shadow_color = Color(0.05, 0.08, 0.05)
	ls.shadow_offset = Vector2(1, 1) * (size / 8)
	ls.shadow_size = 0
	return ls


func _update_hud() -> void:
	_hud_fruit.text = "FRUIT %d/%d" % [_fruit_count, FRUIT.size()]
