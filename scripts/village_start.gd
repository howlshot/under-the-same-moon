extends Node3D

# Under the Same Moon - VillageStart scene controller
# Wires player, camera, and cat together on ready.

const EDITOR_TEST_SIZE := Vector2i(1280, 720)

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var cat: CharacterBody3D = $Cat

func _ready() -> void:
	if OS.has_feature("editor"):
		DisplayServer.window_set_size(EDITOR_TEST_SIZE)
	camera_rig.set_target(player)
	cat.set_target(player)
