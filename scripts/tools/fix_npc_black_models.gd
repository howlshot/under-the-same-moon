extends SceneTree

const SCENE_PATH := "res://MountainPath.tscn"
const TEXTURE_PATH := "res://thirdparty/Free Medieval 3D People Low Poly Pack/texture/people_texture_map.png"
const MATERIAL_PATH := "res://thirdparty/Free Medieval 3D People Low Poly Pack/texture/npc_peasant_lit.tres"

const NPC_NAMES := [
	"VillageNpc01",
	"VillageNpc02",
	"VillageNpc03",
	"VillageNpc04",
]

func _init() -> void:
	var packed := load(SCENE_PATH) as PackedScene
	if packed == null:
		push_error("Failed to load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := packed.instantiate()
	if root == null:
		push_error("Failed to instantiate scene")
		quit(1)
		return

	var material := _build_npc_material()
	if material == null:
		push_error("Failed to create NPC material")
		quit(1)
		return

	for npc_name in NPC_NAMES:
		var npc := root.get_node_or_null(npc_name)
		if npc == null:
			continue
		var model := npc.get_node_or_null("CharacterModel")
		if model == null:
			continue
		_apply_material_override_recursive(model, material)

	_set_owner_recursive(root, root)

	var out := PackedScene.new()
	var pack_err := out.pack(root)
	if pack_err != OK:
		push_error("Failed to pack scene, err=%s" % str(pack_err))
		quit(1)
		return

	var save_err := ResourceSaver.save(out, SCENE_PATH)
	if save_err != OK:
		push_error("Failed to save scene, err=%s" % str(save_err))
		quit(1)
		return

	print("Applied lit NPC material overrides to Beat0 villagers")
	quit(0)

func _build_npc_material() -> StandardMaterial3D:
	var tex := load(TEXTURE_PATH) as Texture2D
	if tex == null:
		push_error("Missing texture: %s" % TEXTURE_PATH)
		return null

	var mat := StandardMaterial3D.new()
	mat.resource_name = "NPCPeasantLit"
	mat.albedo_texture = tex
	mat.vertex_color_use_as_albedo = false
	mat.roughness = 1.0
	mat.metallic = 0.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var mat_save_err := ResourceSaver.save(mat, MATERIAL_PATH)
	if mat_save_err != OK:
		push_error("Failed to save material, err=%s" % str(mat_save_err))
		return null

	return load(MATERIAL_PATH) as StandardMaterial3D

func _apply_material_override_recursive(node: Node, material: StandardMaterial3D) -> void:
	if node is MeshInstance3D:
		var mesh_instance := node as MeshInstance3D
		mesh_instance.material_override = material
	for child in node.get_children():
		_apply_material_override_recursive(child, material)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for child in node.get_children():
		_set_owner_recursive(child, owner)
