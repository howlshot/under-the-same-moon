extends CharacterBody3D

# Under the Same Moon - Cat Follower
# Tether follow: trails behind player at a fixed distance.
# Smooth acceleration and deceleration, no jitter.

@export var follow_distance: float = 2.6     # preferred distance behind player
@export var stop_buffer: float = 0.85        # start moving once farther than this from follow anchor
@export var stop_deadzone: float = 0.45      # fully stop inside this radius (prevents jitter)
@export var personal_space: float = 1.5      # avoid overlapping player when idle
@export var max_speed: float = 6.0           # top catch-up speed
@export var acceleration: float = 8.0        # how quickly cat speeds up
@export var deceleration: float = 10.0       # how quickly cat slows when near player
@export var rotation_speed: float = 8.0
@export var gravity: float = 20.0
@export var jump_velocity: float = 8.0
@export var leash_distance: float = 8.0      # far-distance catch-up threshold (no teleport)
@export var obstacle_check_distance: float = 1.9
@export var obstacle_check_height: float = 0.45
@export var jump_cooldown: float = 0.35
@export var vertical_chase_threshold: float = 0.45
@export var ledge_jump_height_threshold: float = 0.9
@export var min_jump_chase_distance: float = 1.35
@export var min_ledge_jump_distance: float = 1.8
@export var arrive_slow_radius: float = 1.7
@export var idle_reacquire_margin: float = 0.5
@export var obstacle_surface_max_normal_y: float = 0.55
@export var floor_probe_distance: float = 1.1
@export var floor_probe_drop: float = 1.4
@export var floor_walkable_min_normal_y: float = 0.65
@export var idle_settle_speed: float = 1.9
@export var floor_snap_len: float = 0.28
@export var cat_collision_y_offset: float = 0.18
@export var idle_vertical_ignore_band: float = 0.35
@export var idle_anchor_lock_distance: float = 0.95
@export var sprint_detect_speed: float = 6.2
@export var sprint_speed_boost: float = 1.22
@export var sprint_follow_distance: float = 2.35
@export var unstuck_distance_threshold: float = 7.5
@export var unstuck_speed_threshold: float = 0.28
@export var unstuck_time_threshold: float = 0.75
@export var unstuck_teleport_distance: float = 2.8
@export var unstuck_ground_probe_up: float = 3.0
@export var unstuck_ground_probe_down: float = 6.0
@export var interact_radius: float = 2.2
@export var interact_cooldown: float = 1.5
@export var purr_enabled: bool = true
@export var purr_delay: float = 0.7

@onready var mesh_pivot: Node3D = $MeshPivot
@onready var cat_collision: CollisionShape3D = get_node_or_null("CollisionShape3D")
@onready var meow_sfx: AudioStreamPlayer3D = get_node_or_null("MeowSfx")
@onready var purr_sfx: AudioStreamPlayer3D = get_node_or_null("PurrSfx")

var _target: Node3D = null
var _jump_cooldown_left := 0.0
var _last_move_dir := Vector3.FORWARD
var _last_follow_dir := Vector3.FORWARD
var _is_chasing := true
var _stuck_time := 0.0
var _interact_was_pressed := false
var _interact_cooldown_left := 0.0
var _pending_purr_left := -1.0
var _meow_runtime: AudioStreamPlayer3D
var _purr_runtime: AudioStreamPlayer3D

func _ready() -> void:
	# Stick to gentle slopes/ramps to reduce seam snagging and false "stuck" states.
	floor_snap_length = floor_snap_len
	if cat_collision and abs(cat_collision.position.y) < 0.001:
		cat_collision.position.y = cat_collision_y_offset
	_init_runtime_audio()

func set_target(node: Node3D) -> void:
	_target = node
	if _target:
		var back := -_target.global_transform.basis.z
		back.y = 0.0
		if back.length_squared() < 0.0001:
			back = Vector3.BACK
		back = back.normalized()
		_last_follow_dir = back
		# One-time spawn correction so cat does not start inside the player.
		if global_position.distance_to(_target.global_position) < personal_space:
			var desired := _target.global_position - back * follow_distance
			global_position.x = desired.x
			global_position.z = desired.z

func _physics_process(delta: float) -> void:
	_jump_cooldown_left = max(0.0, _jump_cooldown_left - delta)
	_interact_cooldown_left = max(0.0, _interact_cooldown_left - delta)
	if _pending_purr_left >= 0.0:
		_pending_purr_left = max(-1.0, _pending_purr_left - delta)
		if _pending_purr_left == -1.0 and purr_enabled:
			if purr_sfx:
				purr_sfx.play()
			elif _purr_runtime:
				_play_runtime_tone(_purr_runtime, 180.0, 0.9, 0.12)

	if _target == null:
		return

	_process_cat_interaction()

	# Gravity
	if not is_on_floor():
		velocity.y -= gravity * delta

	var to_player := _target.global_position - global_position
	var vertical_gap := to_player.y
	var target_speed := 0.0
	var target_character := _target as CharacterBody3D
	if target_character:
		target_speed = Vector2(target_character.velocity.x, target_character.velocity.z).length()
	var target_is_idle := target_speed < 0.2
	var target_is_sprinting := target_speed > sprint_detect_speed

	# Follow an anchor behind the player to avoid clipping through the player on idle.
	var follow_dir := _get_target_follow_direction(target_speed)
	var dynamic_follow_distance := sprint_follow_distance if target_is_sprinting else follow_distance
	var desired_pos := _target.global_position - follow_dir * dynamic_follow_distance
	var to_desired := desired_pos - global_position
	to_desired.y = 0.0
	var dist := to_desired.length()
	var dynamic_stop_deadzone := stop_deadzone + (0.12 if target_is_idle else 0.0)
	var dynamic_stop_buffer := stop_buffer + (idle_reacquire_margin if target_is_idle else 0.0)
	var vertical_gap_for_chase := vertical_gap
	if target_is_idle and abs(vertical_gap) <= vertical_chase_threshold + idle_vertical_ignore_band:
		vertical_gap_for_chase = 0.0
	if _is_chasing:
		_is_chasing = dist > dynamic_stop_deadzone or vertical_gap_for_chase > vertical_chase_threshold * 0.5
	else:
		_is_chasing = dist > dynamic_stop_buffer or vertical_gap_for_chase > vertical_chase_threshold
	if target_is_idle and dist <= dynamic_stop_buffer and abs(vertical_gap_for_chase) < vertical_chase_threshold:
		_is_chasing = false
	if target_is_idle and dist <= idle_anchor_lock_distance:
		_is_chasing = false

	if _is_chasing:
		var move_dir := to_desired.normalized() if dist > 0.001 else Vector3.ZERO
		if move_dir.length_squared() > 0.0001:
			_last_move_dir = move_dir
		# Arrival-like speed scaling from follow anchor distance.
		# Use a softer curve near the anchor to prevent pace-back oscillation.
		var t: float = clamp((dist - dynamic_stop_deadzone) / max(dynamic_stop_buffer, 0.01), 0.0, 1.0)
		var wish_speed: float = max_speed * t
		var arrive_t: float = clamp((dist - dynamic_stop_deadzone) / max(arrive_slow_radius - dynamic_stop_deadzone, 0.01), 0.0, 1.0)
		var arrive_cap: float = max_speed * (arrive_t * arrive_t)
		wish_speed = min(wish_speed, arrive_cap)
		if target_is_idle:
			wish_speed = min(wish_speed, idle_settle_speed)
		if vertical_gap > vertical_chase_threshold:
			wish_speed = max(wish_speed, max_speed * 0.8)

		# Keep up during sprint by matching/edging target horizontal speed when needed.
		if target_speed > max_speed * 0.8:
			wish_speed = max(wish_speed, target_speed * 1.05)
		if target_is_sprinting:
			wish_speed = max(wish_speed, target_speed * sprint_speed_boost)
		if dist > leash_distance:
			wish_speed *= 1.15

		velocity.x = move_toward(velocity.x, move_dir.x * wish_speed, acceleration * 1.2 * delta)
		velocity.z = move_toward(velocity.z, move_dir.z * wish_speed, acceleration * 1.2 * delta)

		# Autonomous obstacle jump: when chasing and blocked by low obstacle.
		var to_player_flat := to_player
		to_player_flat.y = 0.0
		var player_flat_dist := to_player_flat.length()
		var can_consider_jump := dist > min_jump_chase_distance and player_flat_dist > personal_space * 0.9
		if can_consider_jump and (_should_jump_over_obstacle(move_dir) or _should_jump_to_higher_target(vertical_gap, player_flat_dist, move_dir)):
			velocity.y = jump_velocity
			# Ledge assist: carry some horizontal momentum toward target direction.
			var assist_dir := move_dir
			if assist_dir.length_squared() <= 0.0001:
				assist_dir = _last_move_dir
			if assist_dir.length_squared() <= 0.0001:
				assist_dir = -global_transform.basis.z
			velocity.x = move_toward(velocity.x, assist_dir.x * max_speed * 0.9, acceleration * 1.4 * delta)
			velocity.z = move_toward(velocity.z, assist_dir.z * max_speed * 0.9, acceleration * 1.4 * delta)
			_jump_cooldown_left = jump_cooldown

		# Rotate toward player smoothly
		if move_dir.length_squared() > 0.0001:
			var target_angle := atan2(move_dir.x, move_dir.z)
			mesh_pivot.rotation.y = lerp_angle(mesh_pivot.rotation.y, target_angle, rotation_speed * delta)
	else:
		# In deadzone - stop hard to prevent oscillation.
		velocity.x = move_toward(velocity.x, 0.0, deceleration * 1.8 * delta)
		velocity.z = move_toward(velocity.z, 0.0, deceleration * 1.8 * delta)
		# Keep breathing room from player center.
		var player_flat := to_player
		player_flat.y = 0.0
		var player_dist := player_flat.length()
		if player_dist < personal_space and player_dist > 0.05:
			var away := -player_flat.normalized()
			var repel: float = clamp((personal_space - player_dist) * 2.4, 0.0, 2.8)
			velocity.x = move_toward(velocity.x, away.x * repel, acceleration * 1.2 * delta)
			velocity.z = move_toward(velocity.z, away.z * repel, acceleration * 1.2 * delta)

	move_and_slide()
	_update_unstuck(delta, follow_dir)

func _should_jump_over_obstacle(move_dir: Vector3) -> bool:
	if _jump_cooldown_left > 0.0 or not is_on_floor():
		return false

	var origin := global_position + Vector3(0, obstacle_check_height, 0)
	var forward_end := origin + move_dir * obstacle_check_distance
	var up_clear_origin := global_position + Vector3(0, obstacle_check_height + 0.7, 0)
	var up_clear_end := up_clear_origin + move_dir * obstacle_check_distance

	var query_low := PhysicsRayQueryParameters3D.create(origin, forward_end)
	query_low.exclude = [self, _target]
	var hit_low := get_world_3d().direct_space_state.intersect_ray(query_low)
	if hit_low.is_empty():
		return false
	if hit_low.has("normal") and (hit_low.normal as Vector3).y > obstacle_surface_max_normal_y:
		return false

	# If upper ray is also blocked, obstacle is too tall to hop.
	var query_high := PhysicsRayQueryParameters3D.create(up_clear_origin, up_clear_end)
	query_high.exclude = [self, _target]
	var hit_high := get_world_3d().direct_space_state.intersect_ray(query_high)
	return hit_high.is_empty()

func _should_jump_to_higher_target(vertical_gap: float, dist: float, move_dir: Vector3) -> bool:
	if _jump_cooldown_left > 0.0 or not is_on_floor():
		return false
	# If player is above and cat is reasonably close, jump and carry forward.
	if vertical_gap > ledge_jump_height_threshold and dist < 5.5 and dist > min_ledge_jump_distance:
		if not _has_ledge_face_ahead(move_dir):
			return false
		# Require at least some forward intent so we don't bunny-hop in place.
		return move_dir.length_squared() > 0.0001
	return false

func _has_ledge_face_ahead(move_dir: Vector3) -> bool:
	if move_dir.length_squared() < 0.0001:
		return false
	var origin := global_position + Vector3(0, obstacle_check_height, 0)
	var end := origin + move_dir.normalized() * obstacle_check_distance
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self, _target]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.has("normal"):
		return false
	return (hit.normal as Vector3).y <= obstacle_surface_max_normal_y

func _has_walkable_floor_ahead(move_dir: Vector3) -> bool:
	if move_dir.length_squared() < 0.0001:
		return false
	var ahead := global_position + move_dir.normalized() * floor_probe_distance + Vector3(0, 0.35, 0)
	var down := ahead + Vector3(0, -floor_probe_drop, 0)
	var query := PhysicsRayQueryParameters3D.create(ahead, down)
	query.exclude = [self, _target]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	if not hit.has("normal"):
		return false
	return (hit.normal as Vector3).y >= floor_walkable_min_normal_y

func _update_unstuck(delta: float, follow_dir: Vector3) -> void:
	if _target == null:
		_stuck_time = 0.0
		return
	var to_target := _target.global_position - global_position
	var dist := Vector2(to_target.x, to_target.z).length()
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if dist < unstuck_distance_threshold or horizontal_speed > unstuck_speed_threshold:
		_stuck_time = 0.0
		return
	_stuck_time += delta
	if _stuck_time < unstuck_time_threshold:
		return
	_stuck_time = 0.0
	_unstuck_teleport_behind_target(follow_dir)

func _unstuck_teleport_behind_target(follow_dir: Vector3) -> void:
	var safe_dir := follow_dir
	if safe_dir.length_squared() < 0.0001:
		safe_dir = _last_follow_dir
	if safe_dir.length_squared() < 0.0001:
		safe_dir = Vector3.FORWARD
	safe_dir = safe_dir.normalized()
	var candidate := _target.global_position - safe_dir * unstuck_teleport_distance
	var probe_from := candidate + Vector3.UP * unstuck_ground_probe_up
	var probe_to := candidate + Vector3.DOWN * unstuck_ground_probe_down
	var query := PhysicsRayQueryParameters3D.create(probe_from, probe_to)
	query.exclude = [self, _target]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.has("position"):
		candidate = hit.position + Vector3.UP * 0.35
	global_position = candidate
	velocity = Vector3.ZERO
	_is_chasing = false

func _get_target_follow_direction(target_speed: float) -> Vector3:
	var dir := _last_follow_dir
	var target_character := _target as CharacterBody3D
	if target_character:
		var target_vel := Vector3(target_character.velocity.x, 0.0, target_character.velocity.z)
		if target_speed > 0.3 and target_vel.length_squared() > 0.09:
			dir = target_vel.normalized()
		elif target_speed > 0.08:
			var basis_back := -_target.global_transform.basis.z
			basis_back.y = 0.0
			if basis_back.length_squared() > 0.0001:
				dir = basis_back.normalized()
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = _last_follow_dir
	_last_follow_dir = dir.normalized()
	return _last_follow_dir

func _process_cat_interaction() -> void:
	var interact_pressed := Input.is_key_pressed(KEY_E)
	var interact_just_pressed := interact_pressed and not _interact_was_pressed
	_interact_was_pressed = interact_pressed
	if not interact_just_pressed or _interact_cooldown_left > 0.0:
		return
	if _target == null:
		return
	if global_position.distance_to(_target.global_position) > interact_radius:
		return
	if meow_sfx:
		meow_sfx.play()
	elif _meow_runtime:
		_play_runtime_tone(_meow_runtime, 650.0, 0.12, 0.25)
	if purr_enabled:
		_pending_purr_left = purr_delay
	_interact_cooldown_left = interact_cooldown

func _init_runtime_audio() -> void:
	_meow_runtime = AudioStreamPlayer3D.new()
	_meow_runtime.name = "MeowRuntime"
	_meow_runtime.max_distance = 18.0
	_meow_runtime.volume_db = -8.0
	add_child(_meow_runtime)
	var meow_stream := AudioStreamGenerator.new()
	meow_stream.mix_rate = 44100.0
	meow_stream.buffer_length = 0.2
	_meow_runtime.stream = meow_stream

	_purr_runtime = AudioStreamPlayer3D.new()
	_purr_runtime.name = "PurrRuntime"
	_purr_runtime.max_distance = 16.0
	_purr_runtime.volume_db = -12.0
	add_child(_purr_runtime)
	var purr_stream := AudioStreamGenerator.new()
	purr_stream.mix_rate = 44100.0
	purr_stream.buffer_length = 0.3
	_purr_runtime.stream = purr_stream

func _play_runtime_tone(player: AudioStreamPlayer3D, frequency: float, length_seconds: float, amplitude: float) -> void:
	if player.stream == null:
		return
	if not player.playing:
		player.play()
	var playback := player.get_stream_playback()
	if playback == null or not (playback is AudioStreamGeneratorPlayback):
		return
	var generator := player.stream as AudioStreamGenerator
	var frames := int(generator.mix_rate * length_seconds)
	var phase := 0.0
	var phase_inc := TAU * frequency / generator.mix_rate
	for i in range(frames):
		var t := float(i) / float(max(frames, 1))
		var env := 1.0 - t
		var sample := sin(phase) * amplitude * env
		(playback as AudioStreamGeneratorPlayback).push_frame(Vector2(sample, sample))
		phase += phase_inc
