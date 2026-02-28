extends SceneTree

const SCENE_PATH := "res://MountainPath.tscn"
const GROUND_NODE := "Beat0Ground"
const WINDMILL_SCENE := "res://thirdparty/windmill-stylized/source/toon_Skfb.fbx"

const HOUSE_LAYOUT := {
	"Beat0House_00": {"pos": Vector3(-22.0, 0.0, -6.0), "yaw": 20.0},
	"Beat0House_01": {"pos": Vector3(-17.5, 0.0, -15.0), "yaw": 30.0},
	"Beat0House_02": {"pos": Vector3(-21.5, 0.0, -24.0), "yaw": 15.0},
	"Beat0House_03": {"pos": Vector3(-14.0, 0.0, -31.5), "yaw": 22.0},
	"Beat0House_04": {"pos": Vector3(-19.5, 0.0, -40.0), "yaw": 8.0},
	"Beat0House_05": {"pos": Vector3(-9.0, 0.0, -45.0), "yaw": 14.0},
	"Beat0House_06": {"pos": Vector3(9.0, 0.0, -45.5), "yaw": -16.0},
	"Beat0House_07": {"pos": Vector3(19.0, 0.0, -39.5), "yaw": -10.0},
	"Beat0House_08": {"pos": Vector3(14.0, 0.0, -32.0), "yaw": -24.0},
	"Beat0House_09": {"pos": Vector3(20.0, 0.0, -23.0), "yaw": -16.0},
	"Beat0House_10": {"pos": Vector3(16.5, 0.0, -14.0), "yaw": -26.0},
	"Beat0House_11": {"pos": Vector3(22.0, 0.0, -6.5), "yaw": -20.0},
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

	_update_house_layout(root)
	_update_well(root)
	_update_shrine_and_lantern(root)
	_update_npc_placement(root)
	_add_windmill(root)
	_rebuild_ground(root)
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

	print("Updated Beat 0 town layout + ground")
	quit(0)

func _update_house_layout(root: Node) -> void:
	for house_name in HOUSE_LAYOUT.keys():
		var house := root.get_node_or_null("Beat0Dressing/%s" % house_name) as Node3D
		if house == null:
			continue
		var item: Dictionary = HOUSE_LAYOUT[house_name]
		house.position = item["pos"]
		house.rotation.y = deg_to_rad(float(item["yaw"]))

func _update_well(root: Node) -> void:
	var well := root.get_node_or_null("Beat0Dressing/Beat0Well") as Node3D
	if well == null:
		return
	well.position = Vector3(5.5, 0.0, -11.0)
	well.rotation.y = deg_to_rad(35.0)

func _update_shrine_and_lantern(root: Node) -> void:
	var shrine_base := root.get_node_or_null("Beat0ShrineBase") as CSGCylinder3D
	var shrine_lantern := root.get_node_or_null("Beat0ShrineLantern") as CSGBox3D
	var shrine_light := root.get_node_or_null("Beat0ShrineLight") as OmniLight3D
	if shrine_base != null:
		shrine_base.visible = true
		shrine_base.position = Vector3(0.0, 0.45, -12.0)
	if shrine_lantern != null:
		shrine_lantern.visible = true
		shrine_lantern.position = Vector3(0.0, 1.25, -12.0)
	if shrine_light != null:
		shrine_light.visible = true
		shrine_light.position = Vector3(0.0, 2.2, -12.0)
		shrine_light.light_energy = 1.45
		shrine_light.omni_range = 10.0

func _update_npc_placement(root: Node) -> void:
	var npc1 := root.get_node_or_null("VillageNpc01") as Node3D
	if npc1 != null:
		npc1.position = Vector3(-3.0, 0.0, 16.5)
		npc1.rotation.y = deg_to_rad(-12.0)

	var npc2 := root.get_node_or_null("VillageNpc02") as Node3D
	if npc2 != null:
		npc2.position = Vector3(2.0, 0.0, -9.0)
		npc2.rotation.y = deg_to_rad(165.0)

	var npc3 := root.get_node_or_null("VillageNpc03") as Node3D
	if npc3 != null:
		npc3.position = Vector3(16.5, 0.0, -32.0)
		npc3.rotation.y = deg_to_rad(168.0)

func _add_windmill(root: Node) -> void:
	var dressing := root.get_node_or_null("Beat0Dressing") as Node3D
	if dressing == null:
		return
	var existing := dressing.get_node_or_null("Beat0Windmill")
	if existing != null:
		existing.free()

	var packed := load(WINDMILL_SCENE)
	if packed == null or not (packed is PackedScene):
		push_warning("Failed to load windmill scene: %s" % WINDMILL_SCENE)
		return

	var inst := (packed as PackedScene).instantiate() as Node3D
	if inst == null:
		return
	inst.name = "Beat0Windmill"
	_normalize_size(inst, 15.0)
	inst.position = Vector3(-26.0, 0.0, -34.0)
	inst.rotation.y = deg_to_rad(14.0)
	dressing.add_child(inst)

func _rebuild_ground(root: Node) -> void:
	var existing := root.get_node_or_null(GROUND_NODE)
	if existing != null:
		existing.free()

	var ground_root := Node3D.new()
	ground_root.name = GROUND_NODE
	root.add_child(ground_root)

	var village_mat := StandardMaterial3D.new()
	village_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	village_mat.albedo_color = Color(0.19, 0.22, 0.26, 1.0)
	village_mat.roughness = 0.95

	var lane_mat := StandardMaterial3D.new()
	lane_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	lane_mat.albedo_color = Color(0.23, 0.28, 0.34, 1.0)
	lane_mat.roughness = 0.92

	_add_ground_patch(ground_root, "GroundMain", Vector3(0.0, -0.2, -16.0), Vector3(74.0, 0.4, 66.0), village_mat)
	_add_ground_patch(ground_root, "GroundOverlook", Vector3(0.0, -0.2, 21.0), Vector3(24.0, 0.4, 16.0), village_mat)
	_add_ground_patch(ground_root, "GroundLaneToGate", Vector3(9.0, -0.19, -34.0), Vector3(22.0, 0.35, 18.0), lane_mat)
	_add_ground_patch(ground_root, "GroundCenterLane", Vector3(0.5, -0.18, -10.0), Vector3(16.0, 0.32, 34.0), lane_mat)

func _add_ground_patch(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
	var patch := CSGBox3D.new()
	patch.name = name
	patch.position = pos
	patch.size = size
	patch.use_collision = true
	patch.material = mat
	parent.add_child(patch)

func _normalize_size(node: Node3D, target_max_dim: float) -> void:
	var box: AABB = _combined_aabb(node)
	if box.size.length_squared() <= 0.00001:
		return
	var d: float = max(box.size.x, max(box.size.y, box.size.z))
	if d <= 0.0001:
		return
	var s: float = target_max_dim / d
	node.scale *= s

func _combined_aabb(root: Node3D) -> AABB:
	var has_bounds := false
	var min_v := Vector3.ZERO
	var max_v := Vector3.ZERO
	var stack: Array[Node] = [root]
	while stack.size() > 0:
		var cur: Node = stack.pop_back()
		for child in cur.get_children():
			stack.push_back(child)
		if cur is MeshInstance3D:
			var mi := cur as MeshInstance3D
			if mi.mesh == null:
				continue
				var a: AABB = mi.mesh.get_aabb()
				var xf: Transform3D = _to_root_transform(root, mi)
				for c in _aabb_corners(a):
					var p: Vector3 = xf * c
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

func _to_root_transform(root: Node, target: Node3D) -> Transform3D:
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
