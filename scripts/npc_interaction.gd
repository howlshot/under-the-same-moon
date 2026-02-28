extends Area3D

@export_multiline var lines: Array[String] = [
	"The mountain watches over us."
]
@export var line_duration: float = 2.5
@export var cooldown_seconds: float = 10.0

@onready var prompt: Label3D = get_node_or_null("../Prompt")

var _player_in_range := false
var _cooldown_left := 0.0
var _line_hide_left := 0.0

func _ready() -> void:
	randomize()
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	if prompt:
		prompt.visible = false

func _physics_process(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = max(0.0, _cooldown_left - delta)
	if _line_hide_left > 0.0:
		_line_hide_left = max(0.0, _line_hide_left - delta)
		if _line_hide_left == 0.0 and prompt:
			prompt.visible = false

func _on_body_entered(body: Node) -> void:
	if body.name != "Player":
		return
	_player_in_range = true
	_try_speak()

func _on_body_exited(body: Node) -> void:
	if body.name != "Player":
		return
	_player_in_range = false
	if prompt and _line_hide_left <= 0.0:
		prompt.visible = false

func _try_speak() -> void:
	if not _player_in_range:
		return
	if _cooldown_left > 0.0:
		return
	if lines.is_empty():
		return
	var line := lines[randi() % lines.size()]
	if prompt:
		prompt.text = line
		prompt.visible = true
	_line_hide_left = line_duration
	_cooldown_left = cooldown_seconds
