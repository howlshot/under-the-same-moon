extends CharacterBody3D

# Under the Same Moon - Player Controller
# Smooth acceleration/deceleration, camera-relative movement, natural rotation.

@export var walk_speed: float = 4.0
@export var run_speed: float = 8.0
@export var jump_velocity: float = 8.0
@export var acceleration: float = 12.0      # how quickly speed builds up
@export var friction: float = 14.0          # how quickly speed bleeds off when no input
@export var rotation_speed: float = 12.0    # mesh turn speed (higher = snappier)
@export var gravity: float = 20.0

@onready var mesh_pivot: Node3D = $MeshPivot
@onready var jump_sfx: AudioStreamPlayer3D = get_node_or_null("JumpSfx")
@onready var character_anim: AnimationPlayer = get_node_or_null("MeshPivot/CharacterModel/AnimationPlayer")

var _camera_basis: Basis = Basis.IDENTITY
var _jump_was_pressed := false
var _anim_idle := ""
var _anim_walk := ""
var _anim_jump := ""

func _ready() -> void:
	if character_anim:
		_anim_idle = _pick_animation(["idle", "Idle", "IDLE"])
		_anim_walk = _pick_animation(["walk", "Walk", "run", "Run", "WALK"])
		_anim_jump = _pick_animation(["jump", "Jump", "JUMP", "fall", "Fall"])

func _pick_animation(candidates: Array[String]) -> String:
	if not character_anim:
		return ""
	var names := character_anim.get_animation_list()
	for wanted in candidates:
		for existing in names:
			if existing == wanted:
				return existing
	for wanted in candidates:
		var wanted_l := wanted.to_lower()
		for existing in names:
			if existing.to_lower().find(wanted_l) != -1:
				return existing
	return names[0] if names.size() > 0 else ""

func set_camera_basis(basis: Basis) -> void:
	_camera_basis = basis

func _action_pressed(name: String) -> bool:
	return InputMap.has_action(name) and Input.is_action_pressed(name)

func _physics_process(delta: float) -> void:
	# --- Gravity ---
	if not is_on_floor():
		velocity.y -= gravity * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0

	# --- Jump (single jump only) ---
	var jump_held := _action_pressed("jump") or Input.is_key_pressed(KEY_SPACE)
	var jump_just_pressed := jump_held and not _jump_was_pressed
	_jump_was_pressed = jump_held
	if jump_just_pressed and is_on_floor():
		velocity.y = jump_velocity
		if jump_sfx:
			jump_sfx.play()

	# --- Input (direct key checks - no input map dependency) ---
	var raw := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		raw.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		raw.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		raw.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		raw.y += 1.0

	var is_running := Input.is_key_pressed(KEY_SHIFT) or _action_pressed("run") or _action_pressed("sprint")
	var target_speed := run_speed if is_running else walk_speed

	# --- Camera-relative direction ---
	var cam_fwd := -_camera_basis.z
	var cam_right := _camera_basis.x
	cam_fwd.y = 0.0
	cam_right.y = 0.0
	cam_fwd = cam_fwd.normalized()
	cam_right = cam_right.normalized()

	var wish_dir := (cam_fwd * -raw.y + cam_right * raw.x)

	if wish_dir.length_squared() > 0.001:
		wish_dir = wish_dir.normalized()

		# Accelerate toward target velocity
		var wish_vel := wish_dir * target_speed
		velocity.x = move_toward(velocity.x, wish_vel.x, acceleration * delta)
		velocity.z = move_toward(velocity.z, wish_vel.z, acceleration * delta)

		# Rotate mesh smoothly toward movement direction
		var target_angle := atan2(wish_dir.x, wish_dir.z)
		mesh_pivot.rotation.y = lerp_angle(mesh_pivot.rotation.y, target_angle, rotation_speed * delta)
	else:
		# Decelerate to stop
		velocity.x = move_toward(velocity.x, 0.0, friction * delta)
		velocity.z = move_toward(velocity.z, 0.0, friction * delta)

	_update_character_animation()
	move_and_slide()

func _update_character_animation() -> void:
	if not character_anim:
		return
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var wanted := _anim_idle
	if not is_on_floor() and _anim_jump != "":
		wanted = _anim_jump
	elif horizontal_speed > 0.15 and _anim_walk != "":
		wanted = _anim_walk
	if wanted != "" and character_anim.current_animation != wanted:
		character_anim.play(wanted, 0.15)
