extends SceneTree

const TARGET_SCENE := "res://MountainPath.tscn"
const SETDRESS_SCENE := "res://TownSetdress.tscn"
const NODE_NAME := "TownSetdress"

func _init() -> void:
	var target_packed := load(TARGET_SCENE)
	if target_packed == null or not (target_packed is PackedScene):
		push_error("Failed to load target scene: %s" % TARGET_SCENE)
		quit(1)
		return

	var setdress_packed := load(SETDRESS_SCENE)
	if setdress_packed == null or not (setdress_packed is PackedScene):
		push_error("Failed to load setdress scene: %s" % SETDRESS_SCENE)
		quit(1)
		return

	var root := (target_packed as PackedScene).instantiate()
	if root == null:
		push_error("Failed to instantiate target scene")
		quit(1)
		return

	var existing := root.get_node_or_null(NODE_NAME)
	if existing != null:
		existing.free()

	var setdress := (setdress_packed as PackedScene).instantiate()
	if setdress == null:
		push_error("Failed to instantiate setdress scene")
		quit(1)
		return

	setdress.name = NODE_NAME
	setdress.position = Vector3.ZERO
	root.add_child(setdress)
	_set_owner_recursive(setdress, root)

	var out := PackedScene.new()
	var pack_err := out.pack(root)
	if pack_err != OK:
		push_error("Failed to pack merged scene, err=%s" % str(pack_err))
		quit(1)
		return

	var save_err := ResourceSaver.save(out, TARGET_SCENE)
	if save_err != OK:
		push_error("Failed to save merged scene, err=%s" % str(save_err))
		quit(1)
		return

	print("Merged TownSetdress into MountainPath")
	quit(0)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for ch in node.get_children():
		_set_owner_recursive(ch, owner)
