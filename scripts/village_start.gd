extends Node3D

# Under the Same Moon - VillageStart scene controller
# Wires player, camera, and cat together on ready.

const EDITOR_TEST_SIZE := Vector2i(1280, 720)
const RESPAWN_STUCK_TIME := 3.5
const NPC_ALBEDO_TEX_PATH := "res://thirdparty/Free Medieval 3D People Low Poly Pack/texture/people_texture_map.png"
const NPC_NAMES := ["VillageNpc01", "VillageNpc02", "VillageNpc03", "VillageNpc04"]

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var cat: CharacterBody3D = $Cat
@onready var moon_far: Node3D = get_node_or_null("MoonRig/MoonFar")
@onready var spawn_anchor: Node3D = get_node_or_null("Beat0SpawnAnchor")

@export var respawn_fall_y: float = -4.0

var _spawn_player_position := Vector3.ZERO
var _spawn_cat_offset := Vector3(-1.2, 0.0, 1.7)
var _stuck_intent_time := 0.0

func _ready() -> void:
	if OS.has_feature("editor"):
		DisplayServer.window_set_size(EDITOR_TEST_SIZE)
	_spawn_player_position = player.global_position
	if spawn_anchor:
		_spawn_player_position = spawn_anchor.global_position
	_spawn_cat_offset = cat.global_position - player.global_position
	player.global_position = _spawn_player_position
	if moon_far:
		_orient_player_toward(moon_far.global_position)
	camera_rig.set_target(player)
	if camera_rig.has_method("set_opening_composition") and moon_far:
		camera_rig.set_opening_composition(moon_far.global_position)
	cat.set_target(player)
	_respawn_cat_with_player()
	_apply_npc_material_fallback()

func _physics_process(delta: float) -> void:
	if player.global_position.y < respawn_fall_y:
		_respawn_player_and_cat()
		return
	if _is_player_wedged(delta):
		_respawn_player_and_cat()

func _orient_player_toward(target_pos: Vector3) -> void:
	var look_target := target_pos
	look_target.y = player.global_position.y
	player.look_at(look_target, Vector3.UP)

func _respawn_player_and_cat() -> void:
	player.velocity = Vector3.ZERO
	player.global_position = _spawn_player_position
	if moon_far:
		_orient_player_toward(moon_far.global_position)
	_respawn_cat_with_player()
	_stuck_intent_time = 0.0

func _respawn_cat_with_player() -> void:
	cat.velocity = Vector3.ZERO
	cat.global_position = player.global_position + _spawn_cat_offset
	cat.set_target(player)

func _is_player_wedged(delta: float) -> bool:
	var intent := Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_RIGHT)
	if not intent or not player.is_on_floor():
		_stuck_intent_time = 0.0
		return false
	var horizontal_speed := Vector2(player.velocity.x, player.velocity.z).length()
	if horizontal_speed > 0.15:
		_stuck_intent_time = 0.0
		return false
	_stuck_intent_time += delta
	return _stuck_intent_time >= RESPAWN_STUCK_TIME

func _apply_npc_material_fallback() -> void:
	var tex := load(NPC_ALBEDO_TEX_PATH) as Texture2D
	if tex == null:
		return

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = tex
	mat.albedo_color = Color(1, 1, 1, 1)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC

	for npc_name in NPC_NAMES:
		var npc := get_node_or_null(npc_name)
		if npc == null:
			continue
		var model := npc.get_node_or_null("CharacterModel")
		if model == null:
			continue
		_apply_material_to_meshes(model, mat)

func _apply_material_to_meshes(root_node: Node, mat: Material) -> void:
	var stack: Array[Node] = [root_node]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		for ch in cur.get_children():
			stack.push_back(ch)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			mi.material_override = mat
