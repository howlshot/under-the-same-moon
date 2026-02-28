extends SceneTree

const SCENES := [
	"res://TownSetdress.tscn",
	"res://MountainPath.tscn",
]

func _init() -> void:
	for scene_path in SCENES:
		_organize_scene(scene_path)
	quit()

func _organize_scene(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	if packed == null:
		print("[organize] skip missing: %s" % scene_path)
		return
	var root := packed.instantiate()
	if root == null:
		print("[organize] skip instantiate failed: %s" % scene_path)
		return

	var town := _find_town_root(root)
	if town == null:
		print("[organize] skip no TownSetdress: %s" % scene_path)
		return

	var changed := false
	changed = _organize_buildings(root, town) or changed
	changed = _organize_boundary(root, town) or changed

	if not changed:
		print("[organize] unchanged: %s" % scene_path)
		return

	var out := PackedScene.new()
	var pack_err := out.pack(root)
	if pack_err != OK:
		push_error("[organize] pack failed for %s (%s)" % [scene_path, pack_err])
		return
	var save_err := ResourceSaver.save(out, scene_path)
	if save_err != OK:
		push_error("[organize] save failed for %s (%s)" % [scene_path, save_err])
		return

	print("[organize] updated: %s" % scene_path)

func _find_town_root(root: Node) -> Node3D:
	if root.name == "TownSetdress" and root is Node3D:
		return root as Node3D
	if root is Node3D and root.get_node_or_null("Buildings") != null and root.get_node_or_null("Boundary") != null:
		return root as Node3D
	return root.get_node_or_null("TownSetdress") as Node3D

func _ensure_group(parent: Node3D, name: String, owner: Node) -> Node3D:
	var existing := parent.get_node_or_null(name) as Node3D
	if existing != null:
		return existing
	var group := Node3D.new()
	group.name = name
	parent.add_child(group)
	group.owner = owner
	return group

func _organize_buildings(owner: Node, town: Node3D) -> bool:
	var buildings := town.get_node_or_null("Buildings") as Node3D
	if buildings == null:
		return false
	var houses := _ensure_group(buildings, "Houses", owner)
	var changed := false
	for child in buildings.get_children():
		if child == houses:
			continue
		if child.name.begins_with("House_"):
			child.reparent(houses)
			changed = true
	return changed

func _organize_boundary(owner: Node, town: Node3D) -> bool:
	var boundary := town.get_node_or_null("Boundary") as Node3D
	if boundary == null:
		return false
	var segments := _ensure_group(boundary, "Segments", owner)
	var dressing := _ensure_group(boundary, "Dressing", owner)
	var changed := false
	for child in boundary.get_children():
		if child == segments or child == dressing:
			continue
		if child.name.begins_with("BoundarySeg_"):
			child.reparent(segments)
			changed = true
		elif child.name.begins_with("BoundaryDress_"):
			child.reparent(dressing)
			changed = true
	return changed
