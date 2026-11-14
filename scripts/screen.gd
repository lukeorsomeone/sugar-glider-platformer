extends Node
## Autoload "Screen": renders the game into a 320x240 (4:3) SubViewport and scales it up
## to the window with crt.gdshader in its "clean" mode: sharp pixels, PS1-style 15-bit
## colour with ordered dithering, and black bars at the sides on wide screens.
## Ported from Super Snowbaoarding! (without the TV bezel, music or menus).
##
## Restart the level with Screen.reload() instead of get_tree().reload_current_scene().
## F11 toggles fullscreen.

const GAME_RES := Vector2i(320, 240)
const PixelFont := preload("res://scripts/pixel_font.gd")

## The look from Super Snowbaoarding's CLEAN screen mode. The shader also supports a
## bezel, curvature, scanlines, an RGB mask, vignette and glare if you want them later.
const CLEAN := {"show_bezel": false, "curvature": 0.0, "scanline_strength": 0.0,
	"mask_strength": 0.0, "vignette_strength": 0.0, "glare_strength": 0.0}

var viewport: SubViewport
var pixel_font: FontFile
var _scene_path := ""
var _crt: ColorRect
var _mat: ShaderMaterial


func _ready() -> void:
	pixel_font = PixelFont.build()
	ThemeDB.fallback_font = pixel_font
	ThemeDB.fallback_font_size = 8

	viewport = SubViewport.new()
	viewport.size = GAME_RES
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.msaa_3d = Viewport.MSAA_DISABLED
	viewport.audio_listener_enable_3d = true
	add_child(viewport)

	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/crt.gdshader")
	_mat.set_shader_parameter("screen_tex", viewport.get_texture())
	_mat.set_shader_parameter("game_res", Vector2(GAME_RES))
	for k in CLEAN:
		_mat.set_shader_parameter(k, CLEAN[k])
	_crt = ColorRect.new()
	_crt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crt.material = _mat
	add_child(_crt)
	_crt.resized.connect(_on_resized)
	_on_resized()

	_adopt_current_scene.call_deferred()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F11:
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
		get_viewport().set_input_as_handled()


## Swaps the game to another scene (inside the 320x240 screen).
func go(path: String) -> void:
	_scene_path = path
	for c in viewport.get_children():
		viewport.remove_child(c)
		c.queue_free()
	viewport.add_child(load(path).instantiate())


## Restarts the current scene.
func reload() -> void:
	if _scene_path != "":
		go(_scene_path)


func _adopt_current_scene() -> void:
	# Move the main scene into the low-res viewport.
	var s := get_tree().current_scene
	if s != null and s.get_parent() != viewport:
		_scene_path = s.scene_file_path
		s.get_parent().remove_child(s)
		viewport.add_child(s)


func _on_resized() -> void:
	_mat.set_shader_parameter("rect_size", _crt.size)
