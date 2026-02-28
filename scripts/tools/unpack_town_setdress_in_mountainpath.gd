extends SceneTree

const SCENE_PATH := "res://MountainPath.tscn"
const NODE_NAME := "TownSetdress"

func _init() -> void:
	var packed := load(SCENE_PATH)
	if packed == null or not (packed is PackedScene):
		push_error("Failed to load %s" % SCENE_PATH)
		quit(1)
		return

	var root := (packed as PackedScene).instantiate()
	if root == null:
		push_error("Failed to instantiate %s" % SCENE_PATH)
		quit(1)
		return

	var inst := root.get_node_or_null(NODE_NAME)
	if inst == null:
		push_error("Missing node %s" % NODE_NAME)
		quit(1)
		return

	# Build a brand-new local container and copy children into it.
	var local_copy := Node3D.new()
	local_copy.name = NODE_NAME
	local_copy.position = inst.position
	local_copy.rotation = inst.rotation
	local_copy.scale = inst.scale

	for child in inst.get_children():
		var child_copy := child.duplicate(Node.DUPLICATE_SIGNALS | Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
		if child_copy != null:
			local_copy.add_child(child_copy)

	# Remove known mountain-pass blockers from the local boundary ring.
	var boundary := local_copy.get_node_or_null("Boundary")
	if boundary != null:
		for child in boundary.get_children():
			var n := String(child.name)
			if n == "BoundarySeg_01" or n == "BoundarySeg_02" or n.begins_with("BoundaryDress_01_") or n.begins_with("BoundaryDress_02_"):
				child.free()

	inst.free()
	root.add_child(local_copy)
	_set_owner_recursive(local_copy, root)

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

	print("Unpacked TownSetdress into editable local nodes and opened mountain pass")
	quit(0)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for ch in node.get_children():
		_set_owner_recursive(ch, owner)
