extends Node3D

# Under the Same Moon - VillageStart scene controller
# Wires player, camera, and cat together on ready.

@onready var player: CharacterBody3D = $Player
@onready var camera_rig: Node3D = $CameraRig
@onready var cat: CharacterBody3D = $Cat

func _ready() -> void:
	camera_rig.set_target(player)
	cat.set_target(player)
