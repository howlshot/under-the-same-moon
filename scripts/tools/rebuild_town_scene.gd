extends SceneTree

const SCENE_PATH := "res://Town.tscn"

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

	if not root.has_method("rebuild_all"):
		push_error("Town root does not expose rebuild_all()")
		quit(1)
		return

	root.call("rebuild_all")

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

	print("Town scene rebuild complete")
	quit(0)
