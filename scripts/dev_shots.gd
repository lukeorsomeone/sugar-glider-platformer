extends Node
## Dev tool: loads the level and runs Bao right, then left, saving 320x240 screenshots
## to assets/models/source/sprite_frames/shot_*.png and printing what the sprite is doing.
## Run res://scenes/dev_shots.tscn from the editor. Safe to delete.

const OUT := "res://assets/models/source/sprite_frames/"
var level: Node


func _ready() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	level = load("res://scenes/main.tscn").instantiate()
	get_parent().add_child(level)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(OUT + "shots_report.txt"))
	await _wait(2.0)
	_report("standing")
	Input.action_press("move_right")
	await _wait(1.2)
	_report("running right")
	await _shot("run_right")
	Input.action_release("move_right")
	Input.action_press("move_left")
	await _wait(0.8)
	_report("running left")
	await _shot("run_left")
	Input.action_release("move_left")
	get_tree().quit()


func _report(label: String) -> void:
	var p: Node3D = level.player
	var cam: Camera3D = level.camera
	var sx := cam.unproject_position(p.global_position).x
	var spr: AnimatedSprite3D = p._sprite
	var line := "SHOT %s: speed=%.2f facing=%.0f screen_x=%.1f anim=%s flip_h=%s frame=%d\n" % [
		label, p.speed, p.facing, sx, spr.animation, spr.flip_h, spr.frame]
	var f := FileAccess.open(ProjectSettings.globalize_path(OUT + "shots_report.txt"), FileAccess.READ_WRITE if FileAccess.file_exists(ProjectSettings.globalize_path(OUT + "shots_report.txt")) else FileAccess.WRITE)
	f.seek_end()
	f.store_string(line)
	f.close()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := Screen.viewport.get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + "shot_%s.png" % shot_name))
