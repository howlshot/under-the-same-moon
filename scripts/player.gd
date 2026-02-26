extends CharacterBody3D

# Under the Same Moon - Player Controller
# Third-person: WASD move relative to camera, Shift to run, camera-relative rotation

@export var walk_speed: float = 4.0
@export var run_speed: float = 8.0
@export var rotation_speed: float = 10.0
@export var gravity: float = 20.0
@export var jump_velocity: float = 0.0  # no jumping for now

@onready var mesh_pivot: Node3D = $MeshPivot

var _camera_basis: Basis = Basis.IDENTITY

func set_camera_basis(basis: Basis) -> void:
	_camera_basis = basis

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Input
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_forward", "move_back")

	var is_running := Input.is_action_pressed("run")
	var speed := run_speed if is_running else walk_speed

	# Camera-relative movement
	var cam_forward := -_camera_basis.z
	var cam_right := _camera_basis.x
	cam_forward.y = 0.0
	cam_right.y = 0.0
	cam_forward = cam_forward.normalized()
	cam_right = cam_right.normalized()

	var move_dir := (cam_forward * -input_dir.y + cam_right * input_dir.x)

	if move_dir.length_squared() > 0.001:
		move_dir = move_dir.normalized()
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		# Rotate mesh toward movement direction
		var target_angle := atan2(move_dir.x, move_dir.z)
		var current_angle := mesh_pivot.rotation.y
		mesh_pivot.rotation.y = lerp_angle(current_angle, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, speed * 8.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, speed * 8.0 * delta)

	move_and_slide()
