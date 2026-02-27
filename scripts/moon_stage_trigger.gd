extends Area3D

@export var target_moon: StringName = &"MoonFar"

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	var moon_rig := get_tree().current_scene.get_node_or_null("MoonRig")
	if moon_rig == null:
		return
	for child in moon_rig.get_children():
		if child is Node3D and (child.name == "MoonFar" or child.name == "MoonMid" or child.name == "MoonNear" or child.name == "MoonHuge"):
			child.visible = child.name == String(target_moon)
