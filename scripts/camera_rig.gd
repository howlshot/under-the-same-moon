extends Node3D

# Under the Same Moon - Third-Person Camera Rig
# Smooth positional follow with configurable lag.
# Mouse look with correct sensitivity. SpringArm handles clipping.

@export var follow_speed: float = 10.0        # position follow responsiveness
@export var orbit_sensitivity: float = 0.25   # degrees per pixel of mouse movement
@export var pitch_min: float = -20.0
@export var pitch_max: float = 55.0
@export var arm_length: float = 6.0
@export var height_offset: float = 1.4        # look at point above character root

@onready var h_pivot: Node3D = $HPivot
@onready var v_pivot: Node3D = $HPivot/VPivot
@onready var spring_arm: SpringArm3D = $HPivot/VPivot/SpringArm3D
@onready var camera: Camera3D = $HPivot/VPivot/SpringArm3D/Camera3D

var _target: Node3D = null
var _yaw: float = 180.0   # start facing toward the player from behind
var _pitch: float = -18.0 # slight downward angle

func set_target(node: Node3D) -> void:
	_target = node
	if _target:
		global_position = _target.global_position

func _ready() -> void:
	spring_arm.spring_length = arm_length
	spring_arm.margin = 0.3
	_apply_orbit()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw   -= event.relative.x * orbit_sensitivity
		_pitch  = clamp(_pitch - event.relative.y * orbit_sensitivity, pitch_min, pitch_max)

	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if _target == null:
		return

	# Follow target with smooth lag - use exp decay for frame-rate independence
	var target_pos := _target.global_position + Vector3(0, height_offset, 0)
	global_position = global_position.lerp(target_pos, 1.0 - exp(-follow_speed * delta))

	_apply_orbit()

	# Feed camera basis to player for movement-relative input
	if _target.has_method("set_camera_basis"):
		_target.set_camera_basis(camera.global_transform.basis)

func _apply_orbit() -> void:
	h_pivot.rotation.y = deg_to_rad(_yaw)
	v_pivot.rotation.x = deg_to_rad(_pitch)
