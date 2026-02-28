extends SceneTree

const SCENE_PATH := "res://TownSetdress.tscn"

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

	# Remove overlapping ground collision from setdress to avoid double-floor physics.
	var setdress_ground_body := root.get_node_or_null("Props/TownGround/StaticBody3D")
	if setdress_ground_body != null:
		setdress_ground_body.free()

	# Remove gameplay/runtime actors; this scene is set dressing only.
	for node_name in ["Player", "CameraRig", "Cat"]:
		var runtime_node := root.get_node_or_null(node_name)
		if runtime_node != null:
			runtime_node.free()

	# Open the town toward the mountain path by removing south/southeast boundary block.
	var boundary := root.get_node_or_null("Boundary")
	if boundary != null:
		for child in boundary.get_children():
			var n := child.name
			if n == "BoundarySeg_01" or n == "BoundarySeg_02" or n.begins_with("BoundaryDress_01_") or n.begins_with("BoundaryDress_02_"):
				child.free()

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

	print("TownSetdress fixed: gate opened + floor collider removed")
	quit(0)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for ch in node.get_children():
		_set_owner_recursive(ch, owner)
