extends Node3D
## Bao, the sugar glider. Movement is "2.5D": Bao only moves forwards/backwards along the
## level's curved path (offset) and up/down (height). The level turns those two numbers
## into a 3D position, so the world can wind around while the controls stay 2D.
##
## Jump with Space / A. Hold jump while falling to spread your flaps and glide.

signal landed
signal jumped
signal fell_off

const MeshUtil := preload("res://scripts/mesh_util.gd")
const GLIDER_MODEL := preload("res://assets/models/sugar_glider.glb")

const RUN_SPEED := 7.5
const GROUND_ACCEL := 45.0
const GROUND_FRICTION := 38.0
const AIR_ACCEL := 24.0
const GRAVITY := 34.0
const JUMP_SPEED := 12.5
const JUMP_CUT := 0.45          # multiply upward speed by this when jump is released early
const MAX_FALL := 24.0
const GLIDE_FALL := 2.0         # top falling speed while gliding
const GLIDE_TIME := 2.4         # seconds of glide per jump (refills on landing)
const COYOTE_TIME := 0.1
const JUMP_BUFFER := 0.12
const MODEL_HEIGHT := 1.2       # the imported model is scaled to this many metres tall
const GLIDE_BANK := 40.0        # degrees of roll towards the camera while gliding

var level: Node                 # level.gd: path maths + collision queries
var controls_enabled := true

var offset := 0.0               # distance along the path
var height := 0.0               # feet height
var speed := 0.0                # along-path speed (+ = forwards)
var y_vel := 0.0
var facing := 1.0
var grounded := false
var gliding := false
var glide_left := GLIDE_TIME

var _coyote := 0.0
var _buffer := 0.0
var _yaw := 0.0
var _squash := 0.0

var _yaw_pivot: Node3D          # turns to face along the path
var _body: Node3D               # tilts forward when gliding, bobs when running
var _bank: Node3D              # rolls around the body's long axis so the flaps face the camera
var _model: Node3D
var _anim: AnimationPlayer
var _shadow: MeshInstance3D


func _ready() -> void:
	_build_model()


func place(at_offset: float, at_height: float) -> void:
	offset = at_offset
	height = at_height
	speed = 0.0
	y_vel = 0.0
	grounded = true
	gliding = false
	glide_left = GLIDE_TIME
	_update_transform(0.0, true)


func _physics_process(delta: float) -> void:
	if level == null:
		return

	var input := Input.get_axis("move_left", "move_right") if controls_enabled else 0.0
	var jump_pressed := controls_enabled and Input.is_action_just_pressed("jump")
	var jump_held := controls_enabled and Input.is_action_pressed("jump")
	var jump_released := controls_enabled and Input.is_action_just_released("jump")

	# --- Run ---
	if absf(input) > 0.1:
		facing = signf(input)
	var target := input * RUN_SPEED
	var accel: float
	if absf(input) > 0.1:
		accel = GROUND_ACCEL if grounded else AIR_ACCEL
	else:
		accel = GROUND_FRICTION if grounded else AIR_ACCEL * 0.25
	speed = move_toward(speed, target, accel * delta)

	# --- Jump (with coyote time and a small input buffer so it feels forgiving) ---
	_buffer = JUMP_BUFFER if jump_pressed else _buffer - delta
	_coyote = COYOTE_TIME if grounded else _coyote - delta
	if _buffer > 0.0 and _coyote > 0.0:
		y_vel = JUMP_SPEED
		grounded = false
		_buffer = 0.0
		_coyote = 0.0
		glide_left = GLIDE_TIME
		jumped.emit()
	if jump_released and y_vel > 0.0:
		y_vel *= JUMP_CUT

	# --- Gravity and gliding ---
	y_vel -= GRAVITY * delta
	var updraft: float = level.updraft_at(offset, height)
	gliding = not grounded and y_vel <= 0.5 and jump_held and (glide_left > 0.0 or updraft > 0.0)
	if gliding:
		if updraft > 0.0:
			# Rising air lifts you while your flaps are out, and doesn't use up glide time.
			y_vel = move_toward(y_vel, updraft, 40.0 * delta)
		else:
			glide_left -= delta
			y_vel = maxf(y_vel, -GLIDE_FALL)
	y_vel = maxf(y_vel, -MAX_FALL)

	# --- Move along the path, stopping at walls ---
	var new_offset := clampf(offset + speed * delta, 0.3, level.length - 0.3)
	if level.is_blocked(new_offset, height, signf(speed)):
		speed = 0.0
	else:
		offset = new_offset

	# --- Move up/down, landing on whatever is below ---
	var ground: float = level.ground_height(offset, height)
	var new_height := height + y_vel * delta
	if y_vel <= 0.0 and new_height <= ground:
		var was_grounded := grounded
		height = ground
		y_vel = 0.0
		grounded = true
		glide_left = GLIDE_TIME
		if not was_grounded:
			_squash = 1.0
			landed.emit()
	else:
		height = new_height
		grounded = false

	if height < level.kill_height:
		fell_off.emit()

	_update_transform(delta, false)


func _update_transform(delta: float, snap: bool) -> void:
	global_position = level.path_point(offset) + Vector3(0, height, 0)

	# Face along the path in the direction we're heading. The model faces +Z.
	var dir: Vector3 = level.path_dir(offset) * facing
	var want_yaw := atan2(dir.x, dir.z)
	_yaw = want_yaw if snap else lerp_angle(_yaw, want_yaw, minf(1.0, 14.0 * delta))
	_yaw_pivot.rotation.y = _yaw

	# Lie flat (belly down) while gliding; the glide animation spreads the arms, legs and flaps.
	var glide_pitch := deg_to_rad(72.0) if gliding else 0.0
	_body.rotation.x = glide_pitch if snap else lerpf(_body.rotation.x, glide_pitch, minf(1.0, 10.0 * delta))
	# Lift the body while flat so it pivots around its middle rather than its feet.
	_body.position.y = sin(_body.rotation.x) * MODEL_HEIGHT * 0.35
	# Bank towards the camera so you can see the spread flaps from the side.
	var bank := deg_to_rad(GLIDE_BANK) * facing if gliding else 0.0
	_bank.rotation.y = bank if snap else lerpf(_bank.rotation.y, bank, minf(1.0, 8.0 * delta))

	# Squash a little when landing.
	_squash = move_toward(_squash, 0.0, delta * 5.0)
	var sq := _squash * 0.25
	_body.scale = Vector3(1.0 + sq, 1.0 - sq, 1.0 + sq)

	# Pick the animation (made in Blender: idle, run, jump, fall, glide).
	if grounded:
		if absf(speed) > 0.5:
			_play_anim("run")
			_anim.speed_scale = clampf(absf(speed) / RUN_SPEED, 0.5, 1.3) * 1.4
		else:
			_play_anim("idle")
			_anim.speed_scale = 1.0
	else:
		_anim.speed_scale = 1.0
		if gliding:
			_play_anim("glide")
		elif y_vel > 0.0:
			_play_anim("jump")
		else:
			_play_anim("fall")

	# Blob shadow on the ground below.
	var ground: float = level.ground_height(offset, height)
	if ground > level.kill_height:
		_shadow.visible = true
		_shadow.global_position = level.path_point(offset) + Vector3(0, ground + 0.02, 0)
		var s := clampf(1.0 - (height - ground) * 0.08, 0.35, 1.0)
		_shadow.scale = Vector3(s, 1, s)
	else:
		_shadow.visible = false


func _play_anim(anim_name: String) -> void:
	if _anim and _anim.has_animation(anim_name) and _anim.current_animation != anim_name:
		_anim.play(anim_name, 0.15)


func _build_model() -> void:
	_yaw_pivot = Node3D.new()
	add_child(_yaw_pivot)
	_body = Node3D.new()
	_yaw_pivot.add_child(_body)

	# Reuse Bao's model from Super Snowboarding, without the snowboard.
	_model = GLIDER_MODEL.instantiate()
	_bank = Node3D.new()
	_body.add_child(_bank)
	_bank.add_child(_model)
	var board := _model.find_child("SugarGliderBoard", true, false)
	if board:
		board.visible = false
	for mi in _model.find_children("*", "MeshInstance3D", true, false):
		MeshUtil.apply_ps1(mi)

	# Scale the model to MODEL_HEIGHT and stand its feet on y = 0.
	var box := _visible_aabb(_model)
	if box.size.y > 0.001:
		var s := MODEL_HEIGHT / box.size.y
		_model.scale = Vector3.ONE * s
		_model.position = Vector3(-box.get_center().x * s, -box.position.y * s, -box.get_center().z * s)

	_anim = _model.find_child("AnimationPlayer", true, false)
	if _anim:
		for n in _anim.get_animation_list():
			_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_anim.play("idle")

	# PS1-style blob shadow.
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.05, 0.1, 0.05, 0.5)
	m.albedo_texture = _soft_dot()
	plane.material = m
	_shadow = MeshInstance3D.new()
	_shadow.mesh = plane
	_shadow.top_level = true
	add_child(_shadow)


## Bounding box of the visible meshes, in the model's own space.
func _visible_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var inv := root.global_transform.affine_inverse()
	for mi: MeshInstance3D in root.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var b: AABB = (inv * mi.global_transform) * mi.get_aabb()
		result = b if first else result.merge(b)
		first = false
	return result


func _soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t
