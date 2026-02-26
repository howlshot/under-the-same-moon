extends Node3D

# Under the Same Moon - Third-Person Camera Rig
# Orbits around the player. Mouse drag or right-stick to orbit.
# Springarm prevents clipping.

@export var follow_speed: float = 8.0
@export var orbit_sensitivity: float = 0.003
@export var pitch_min: float = -25.0
@export var pitch_max: float = 60.0
@export var arm_length: float = 6.0

@onready var h_pivot: Node3D = $HPivot
@onready var v_pivot: Node3D = $HPivot/VPivot
@onready var spring_arm: SpringArm3D = $HPivot/VPivot/SpringArm3D
@onready var camera: Camera3D = $HPivot/VPivot/SpringArm3D/Camera3D

var _target: Node3D = null
var _yaw: float = 0.0
var _pitch: float = -15.0  # slight downward angle to start

func set_target(node: Node3D) -> void:
	_target = node

func _ready() -> void:
	spring_arm.spring_length = arm_length
	h_pivot.rotation.y = _yaw
	v_pivot.rotation.x = deg_to_rad(_pitch)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * orbit_sensitivity
		_pitch = clamp(_pitch - event.relative.y * orbit_sensitivity * RAD_TO_DEG,
			pitch_min, pitch_max)
	if event is InputEventKey and event.keycode == KEY_ESCAPE and event.pressed:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta: float) -> void:
	if _target == null:
		return

	# Smoothly follow target position
	global_position = global_position.lerp(_target.global_position, follow_speed * delta)

	# Apply orbit angles
	h_pivot.rotation.y = _yaw
	v_pivot.rotation.x = deg_to_rad(_pitch)

	# Feed camera basis to player for movement-relative input
	if _target.has_method("set_camera_basis"):
		_target.set_camera_basis(camera.global_transform.basis)
