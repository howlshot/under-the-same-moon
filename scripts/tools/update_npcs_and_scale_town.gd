extends SceneTree

const SCENE_PATH := "res://MountainPath.tscn"
const TARGET_NPC_HEIGHT := 2.35
const TOWN_SCALE_MULT := 1.0
const DRESSING_SCALE_MULT := 1.0
const NPC_ALBEDO_TEX_PATH := "res://thirdparty/Free Medieval 3D People Low Poly Pack/texture/people_texture_map.png"

const NPC_MODEL_PATHS := {
	"VillageNpc01": "res://thirdparty/Free Medieval 3D People Low Poly Pack/fbx/people_unity/peasant_1.fbx",
	"VillageNpc02": "res://thirdparty/Free Medieval 3D People Low Poly Pack/fbx/people_unity/peasant_2.fbx",
	"VillageNpc03": "res://thirdparty/Free Medieval 3D People Low Poly Pack/fbx/people_unity/peasant_3.fbx",
	"VillageNpc04": "res://thirdparty/Free Medieval 3D People Low Poly Pack/fbx/people_unity/peasant_4.fbx",
}

func _init() -> void:
	var packed := load(SCENE_PATH)
	if packed == null or not (packed is PackedScene):
		push_error("Failed to load scene: %s" % SCENE_PATH)
		quit(1)
		return

	var root := (packed as PackedScene).instantiate()
	if root == null:
		push_error("Failed to instantiate scene")
		quit(1)
		return

	_update_npcs(root)
	_scale_town(root)

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

	print("Updated NPC models and scaled town assets")
	quit(0)

func _update_npcs(root: Node) -> void:
	var npc_tex: Texture2D = load(NPC_ALBEDO_TEX_PATH)
	for npc_name in NPC_MODEL_PATHS.keys():
		var npc := root.get_node_or_null(String(npc_name))
		if npc == null:
			continue

		var old_model := npc.get_node_or_null("CharacterModel")
		var old_origin := Vector3.ZERO
		if old_model != null and old_model is Node3D:
			old_origin = (old_model as Node3D).position
			old_model.free()

		var old_body := npc.get_node_or_null("Body")
		if old_body != null:
			old_body.free()

		var model_packed := load(String(NPC_MODEL_PATHS[npc_name]))
		if model_packed == null or not (model_packed is PackedScene):
			push_warning("Could not load NPC model for %s: %s" % [npc_name, String(NPC_MODEL_PATHS[npc_name])])
			continue

		var model := (model_packed as PackedScene).instantiate()
		if model == null:
			continue

		model.name = "CharacterModel"
		npc.add_child(model)

		var target_mesh_name := String(NPC_MODEL_PATHS[npc_name]).get_file().get_basename()
		_prune_npc_model_meshes(model, target_mesh_name)

		if model is Node3D:
			var m := model as Node3D
			m.position = old_origin

			var local_bounds := _compute_mesh_bounds(model)
			if local_bounds.size.y > 0.001:
				var s := TARGET_NPC_HEIGHT / local_bounds.size.y
				m.scale = Vector3.ONE * s
				# Lift model so its feet are near local ground after scaling.
				m.position.y += -local_bounds.position.y * s

		if npc_tex != null:
			_apply_npc_material_override(model, npc_tex)

func _scale_town(root: Node) -> void:
	var town := root.get_node_or_null("TownSetdress")
	if town != null:
		for group_name in ["Buildings", "Boundary", "Props", "POIs", "Paths", "Lights"]:
			var n := town.get_node_or_null(group_name)
			if n != null and n is Node3D:
				(n as Node3D).scale *= TOWN_SCALE_MULT

	var beat0 := root.get_node_or_null("Beat0Dressing")
	if beat0 != null:
		for ch in beat0.get_children():
			if ch is Node3D:
				var n3 := ch as Node3D
				if n3.name.begins_with("Beat0House_") or n3.name.begins_with("Beat0Foliage_"):
					n3.scale *= DRESSING_SCALE_MULT

func _compute_mesh_bounds(node: Node) -> AABB:
	var has_bounds := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	var stack: Array = [node]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		for child in cur.get_children():
			stack.push_back(child)

		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh == null:
				continue
			var a := mi.mesh.get_aabb()
			var xf := _to_node_space_transform(node, mi)
			for corner in _aabb_corners(a):
				var p := xf * corner
				if not has_bounds:
					has_bounds = true
					min_v = p
					max_v = p
				else:
					min_v = min_v.min(p)
					max_v = max_v.max(p)

	if not has_bounds:
		return AABB(Vector3.ZERO, Vector3.ZERO)
	return AABB(min_v, max_v - min_v)

func _apply_npc_material_override(node: Node, tex: Texture2D) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	mat.roughness = 0.9
	mat.metallic = 0.0
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var stack: Array = [node]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		for child in cur.get_children():
			stack.push_back(child)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			var surface_count := 0
			if mi.mesh != null:
				surface_count = mi.mesh.get_surface_count()
			if surface_count <= 0:
				mi.material_override = mat
			else:
				for i in range(surface_count):
					mi.set_surface_override_material(i, mat)

func _prune_npc_model_meshes(node: Node, target_mesh_name: String) -> void:
	var keep_key := target_mesh_name.to_lower()
	var stack: Array = [node]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		for child in cur.get_children():
			stack.push_back(child)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.name.to_lower() != keep_key:
				mi.free()

func _to_node_space_transform(root: Node, target: Node3D) -> Transform3D:
	var chain: Array[Node3D] = []
	var cur: Node = target
	while cur != null and cur != root:
		if cur is Node3D:
			chain.push_back(cur as Node3D)
		cur = cur.get_parent()
	chain.reverse()
	var xf := Transform3D.IDENTITY
	for n in chain:
		xf = xf * n.transform
	return xf

func _aabb_corners(a: AABB) -> Array[Vector3]:
	var p := a.position
	var s := a.size
	return [
		Vector3(p.x, p.y, p.z),
		Vector3(p.x + s.x, p.y, p.z),
		Vector3(p.x, p.y + s.y, p.z),
		Vector3(p.x, p.y, p.z + s.z),
		Vector3(p.x + s.x, p.y + s.y, p.z),
		Vector3(p.x + s.x, p.y, p.z + s.z),
		Vector3(p.x, p.y + s.y, p.z + s.z),
		Vector3(p.x + s.x, p.y + s.y, p.z + s.z),
	]

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for ch in node.get_children():
		_set_owner_recursive(ch, owner)
