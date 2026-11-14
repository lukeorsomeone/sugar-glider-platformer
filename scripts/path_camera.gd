extends Camera3D
## Side-on camera that follows the glider around the curved path.
## It sits out to the side of the path and turns with it, so the world swings
## around as you run while left/right on the screen always means back/forwards.

var target: Node3D              # player.gd
var level: Node                 # level.gd

const DISTANCE := 7.0           # how far out to the side of the path
const LIFT := 1.8               # how far above the glider
const LOOK_AHEAD := 2.2         # look a little ahead in the direction you're facing
const FOLLOW := 5.0             # higher = snappier

var _focus_offset := 0.0
var _focus_height := 0.0


func snap() -> void:
	_focus_offset = target.offset
	_focus_height = target.height
	_place(1.0)


func _physics_process(delta: float) -> void:
	if target == null or level == null:
		return
	_place(minf(1.0, FOLLOW * delta))


func _place(t: float) -> void:
	var want_offset: float = target.offset + target.facing * LOOK_AHEAD
	_focus_offset = lerpf(_focus_offset, want_offset, t)
	# Follow height more lazily so small hops don't jolt the camera.
	_focus_height = lerpf(_focus_height, target.height, t * 0.7)

	var focus: Vector3 = level.path_point(_focus_offset) + Vector3(0, _focus_height + 0.8, 0)
	var side: Vector3 = level.path_side(_focus_offset)
	global_position = focus + side * DISTANCE + Vector3(0, LIFT, 0)
	look_at(focus, Vector3.UP)
