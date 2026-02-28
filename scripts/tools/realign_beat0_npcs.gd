extends SceneTree

const SCENE_PATH := "res://MountainPath.tscn"

const NPC_LAYOUT := {
	"VillageNpc01": {"pos": Vector3(1.8, 0.0, -8.8), "yaw": 145.0},
	"VillageNpc02": {"pos": Vector3(8.2, 0.0, -8.6), "yaw": -145.0},
	"VillageNpc03": {"pos": Vector3(2.2, 0.0, -14.4), "yaw": 35.0},
	"VillageNpc04": {"pos": Vector3(8.4, 0.0, -14.2), "yaw": -35.0},
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

	for npc_name in NPC_LAYOUT.keys():
		_realign_npc(root, npc_name, NPC_LAYOUT[npc_name])

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

	print("Realigned Beat0 NPC roots and child interaction nodes")
	quit(0)

func _realign_npc(root: Node, npc_name: String, spec: Dictionary) -> void:
	var npc := root.get_node_or_null(npc_name) as Node3D
	if npc == null:
		return

	npc.position = spec["pos"]
	npc.rotation.y = deg_to_rad(float(spec["yaw"]))

	var area := npc.get_node_or_null("InteractArea") as Area3D
	if area != null:
		area.position = Vector3(0.0, 0.9, 0.0)
		area.rotation = Vector3.ZERO
		area.scale = Vector3.ONE
		var area_shape := area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if area_shape != null:
			area_shape.position = Vector3.ZERO
			area_shape.rotation = Vector3.ZERO
			area_shape.scale = Vector3.ONE

	var prompt := npc.get_node_or_null("Prompt") as Label3D
	if prompt != null:
		prompt.position = Vector3(0.0, 2.2, 0.0)
		prompt.rotation = Vector3.ZERO
		prompt.scale = Vector3.ONE

	var model := npc.get_node_or_null("CharacterModel") as Node3D
	if model != null:
		model.position = Vector3(0.0, 0.02, 0.0)
		model.rotation = Vector3.ZERO

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for ch in node.get_children():
		_set_owner_recursive(ch, owner)
