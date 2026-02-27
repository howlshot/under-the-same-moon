extends Area3D

@export var message: String = "Press E to talk"
@export var npc_line: String = "The mountain watches over us."

@onready var prompt: Label3D = get_node_or_null("../Prompt")

var _player_in_range := false
var _interact_was_pressed := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false
		prompt.text = message

func _physics_process(_delta: float) -> void:
	var interact_pressed := Input.is_key_pressed(KEY_E)
	var interact_just_pressed := interact_pressed and not _interact_was_pressed
	_interact_was_pressed = interact_pressed
	if _player_in_range and interact_just_pressed:
		print("[NPC] %s" % npc_line)

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	_player_in_range = true
	if prompt:
		prompt.visible = true

func _on_body_exited(body: Node) -> void:
	if body.name != "Player":
		return
	_player_in_range = false
	if prompt:
		prompt.visible = false
