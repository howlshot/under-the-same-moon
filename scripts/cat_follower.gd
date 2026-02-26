extends CharacterBody3D

# Under the Same Moon - Cat Follower
# Simple tether: stays within follow_distance behind player.
# Smooth position and rotation lerp. No complex AI.

@export var follow_distance: float = 1.8
@export var catch_up_speed: float = 5.0
@export var rotation_speed: float = 6.0
@export var gravity: float = 20.0

@onready var mesh_pivot: Node3D = $MeshPivot

var _target: Node3D = null

func set_target(node: Node3D) -> void:
	_target = node

func _physics_process(delta: float) -> void:
	if _target == null:
		return

	if not is_on_floor():
		velocity.y -= gravity * delta

	var to_target: Vector3 = _target.global_position - global_position
	to_target.y = 0.0
	var dist: float = to_target.length()

	if dist > follow_distance:
		var move_dir: Vector3 = to_target.normalized()
		var t: float = clamp((dist - follow_distance) / 3.0, 0.0, 1.0)
		var speed: float = catch_up_speed * t
		velocity.x = move_dir.x * speed
		velocity.z = move_dir.z * speed
		# Rotate toward player
		var target_angle: float = atan2(move_dir.x, move_dir.z)
		mesh_pivot.rotation.y = lerp_angle(mesh_pivot.rotation.y, target_angle, rotation_speed * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, catch_up_speed * 4.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, catch_up_speed * 4.0 * delta)

	move_and_slide()
