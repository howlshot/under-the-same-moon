extends SceneTree

const SCENE_PATH := "res://MountainPath.tscn"
const DRESSING_PATH := "Beat0Dressing"

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

	var dressing := root.get_node_or_null(DRESSING_PATH)
	if dressing == null:
		push_error("Missing node: %s" % DRESSING_PATH)
		quit(1)
		return

	if not dressing.has_method("_bake_static"):
		push_error("Dressing node does not expose _bake_static()")
		quit(1)
		return

	dressing.call("_bake_static")
	_own_generated_children(dressing, root)
	dressing.set_script(null)

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

	print("Beat0 static bake complete")
	quit(0)

func _own_generated_children(dressing: Node, owner: Node) -> void:
	for child in dressing.get_children():
		if _is_generated_name(child.name):
			_set_owner_recursive(child, owner)

func _is_generated_name(node_name: String) -> bool:
	return node_name.begins_with("Beat0House_") or node_name.begins_with("Beat0Rock_") or node_name.begins_with("Beat0Foliage_") or node_name == "Beat0Well"

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for ch in node.get_children():
		_set_owner_recursive(ch, owner)
