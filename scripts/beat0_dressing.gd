@tool
extends Node3D

const HOUSES_PACK_PATH := "res://thirdparty/stylized_houses__made_with_1_material_only.glb"
const STONES_PACK_PATH := "res://thirdparty/stylized_stones_minipack.glb"
const FOLIAGE_PACK_PATH := "res://thirdparty/stylized_foliage.glb"
const WELL_PACK_PATH := "res://thirdparty/stone-well-stylized/source/StoneWell.fbx"

const HOUSE_LARGE_PATH := "Sketchfab_model/Stylized_House_Scene_fbx/RootNode/Stylized_House_Large"
const HOUSE_SMALL_PATH := "Sketchfab_model/Stylized_House_Scene_fbx/RootNode/Stylized_House_Small"

const STONE_PATHS := [
	"Sketchfab_model/stones_v2_fbx/RootNode/Stone_1_Low",
	"Sketchfab_model/stones_v2_fbx/RootNode/Stone_2_Low",
	"Sketchfab_model/stones_v2_fbx/RootNode/Stone_3_Low",
	"Sketchfab_model/stones_v2_fbx/RootNode/Stone_4_Low",
	"Sketchfab_model/stones_v2_fbx/RootNode/Stone_5_Low",
]

const FOLIAGE_PATHS := [
	"Sketchfab_model/21249aef974d4d28a6c6e355846ab3e5_fbx/RootNode/grass_cluster_1",
	"Sketchfab_model/21249aef974d4d28a6c6e355846ab3e5_fbx/RootNode/ferns",
	"Sketchfab_model/21249aef974d4d28a6c6e355846ab3e5_fbx/RootNode/fern",
	"Sketchfab_model/21249aef974d4d28a6c6e355846ab3e5_fbx/RootNode/moss_cluster",
]

@export var bake_assets: bool = false:
	set(value):
		if value:
			_bake_static()
		bake_assets = false

var _spawn_center := Vector3(0.0, 0.0, 24.0)
var _spawn_radius := 10.0
var _aabb_valid := false
var _aabb := AABB()

func _ready() -> void:
	pass

func _bake_static() -> void:
	_clear_previous_bake()
	_spawn_houses()
	_spawn_well()
	_spawn_rocks()
	_spawn_foliage()
	_mark_children_owned()

func _clear_previous_bake() -> void:
	for child in get_children():
		if child.name.begins_with("Beat0House_") or child.name.begins_with("Beat0Rock_") or child.name.begins_with("Beat0Foliage_") or child.name == "Beat0Well":
			child.queue_free()

func _load_scene(path: String) -> PackedScene:
	var res := load(path)
	if res is PackedScene:
		return res as PackedScene
	return null

func _spawn_houses() -> void:
	var scene := _load_scene(HOUSES_PACK_PATH)
	if scene == null:
		return
	var pack := scene.instantiate()
	var large_template := pack.get_node_or_null(HOUSE_LARGE_PATH) as Node3D
	var small_template := pack.get_node_or_null(HOUSE_SMALL_PATH) as Node3D
	var placements := [
		{"k":"L", "p":Vector3(-21.0, 0.0, -3.0), "r":15.0},
		{"k":"S", "p":Vector3(-12.0, 0.0, -12.0), "r":32.0},
		{"k":"L", "p":Vector3(-2.0, 0.0, -16.0), "r":5.0},
		{"k":"S", "p":Vector3(9.0, 0.0, -11.0), "r":-18.0},
		{"k":"L", "p":Vector3(20.0, 0.0, -4.0), "r":-24.0},
		{"k":"S", "p":Vector3(-26.0, 0.0, -18.0), "r":8.0},
		{"k":"S", "p":Vector3(27.0, 0.0, -20.0), "r":-5.0},
		{"k":"L", "p":Vector3(-14.0, 0.0, -30.0), "r":22.0},
		{"k":"S", "p":Vector3(-1.0, 0.0, -33.0), "r":-10.0},
		{"k":"L", "p":Vector3(13.0, 0.0, -31.0), "r":-30.0},
		{"k":"S", "p":Vector3(-22.0, 0.0, -40.0), "r":45.0},
		{"k":"S", "p":Vector3(24.0, 0.0, -42.0), "r":-40.0},
	]
	var i := 0
	for item in placements:
		var template := large_template if item["k"] == "L" else small_template
		if template == null:
			continue
		var inst := template.duplicate() as Node3D
		inst.name = "Beat0House_%02d" % i
		_normalize_size(inst, 7.5 if item["k"] == "L" else 5.2)
		inst.position = item["p"]
		inst.rotation.y = deg_to_rad(item["r"])
		add_child(inst)
		i += 1
	pack.queue_free()

func _spawn_well() -> void:
	var scene := _load_scene(WELL_PACK_PATH)
	if scene == null:
		return
	var well := scene.instantiate() as Node3D
	if well == null:
		return
	well.name = "Beat0Well"
	_normalize_size(well, 3.4)
	well.position = Vector3(1.5, 0.0, -12.0)
	well.rotation.y = deg_to_rad(22.0)
	add_child(well)

func _spawn_rocks() -> void:
	var scene := _load_scene(STONES_PACK_PATH)
	if scene == null:
		return
	var pack := scene.instantiate()
	var templates: Array[Node3D] = []
	for p in STONE_PATHS:
		var n := pack.get_node_or_null(p) as Node3D
		if n:
			templates.append(n)
	var placements := [
		Vector3(-16.0, 0.0, -7.0), Vector3(16.0, 0.0, -9.0), Vector3(-18.0, 0.0, -35.0),
		Vector3(18.0, 0.0, -37.0), Vector3(0.0, 0.0, -45.0), Vector3(-27.0, 0.0, -23.0),
		Vector3(28.0, 0.0, -25.0), Vector3(-8.0, 0.0, 13.0), Vector3(8.0, 0.0, 13.5)
	]
	var i := 0
	for pos in placements:
		if pos.distance_to(_spawn_center) < _spawn_radius:
			continue
		if templates.is_empty():
			break
		var t := templates[i % templates.size()]
		var inst := t.duplicate() as Node3D
		inst.name = "Beat0Rock_%02d" % i
		_normalize_size(inst, 2.6 + float(i % 3) * 0.5)
		inst.position = pos
		inst.rotation.y = deg_to_rad(float((i * 37) % 360))
		add_child(inst)
		i += 1
	pack.queue_free()

func _spawn_foliage() -> void:
	var scene := _load_scene(FOLIAGE_PACK_PATH)
	if scene == null:
		return
	var pack := scene.instantiate()
	var templates: Array[Node3D] = []
	for p in FOLIAGE_PATHS:
		var n := pack.get_node_or_null(p) as Node3D
		if n:
			templates.append(n)
	var placements := [
		Vector3(-24.0, 0.0, -2.0), Vector3(24.0, 0.0, -3.0), Vector3(-8.0, 0.0, -9.0),
		Vector3(9.0, 0.0, -8.0), Vector3(-12.0, 0.0, -26.0), Vector3(12.0, 0.0, -27.0),
		Vector3(-4.0, 0.0, -39.0), Vector3(5.0, 0.0, -39.0), Vector3(-22.0, 0.0, -33.0),
		Vector3(23.0, 0.0, -34.0), Vector3(-12.0, 0.0, 11.5), Vector3(12.0, 0.0, 11.0)
	]
	var i := 0
	for pos in placements:
		if pos.distance_to(_spawn_center) < _spawn_radius:
			continue
		if templates.is_empty():
			break
		var t := templates[i % templates.size()]
		var inst := t.duplicate() as Node3D
		inst.name = "Beat0Foliage_%02d" % i
		_normalize_size(inst, 2.0 + float(i % 2) * 0.4)
		inst.position = pos
		inst.rotation.y = deg_to_rad(float((i * 23) % 360))
		add_child(inst)
		i += 1
	pack.queue_free()

func _normalize_size(node: Node3D, target_max_dim: float) -> void:
	var box: AABB = _combined_aabb(node)
	if box.size.length_squared() <= 0.00001:
		return
	var d: float = max(box.size.x, max(box.size.y, box.size.z))
	if d <= 0.0001:
		return
	var s: float = target_max_dim / d
	node.scale = node.scale * s

func _combined_aabb(root: Node3D) -> AABB:
	_aabb_valid = false
	_aabb = AABB()
	_collect_bounds(root, Transform3D.IDENTITY)
	return _aabb

func _collect_bounds(n: Node, xf: Transform3D) -> void:
	var next_xf: Transform3D = xf
	if n is Node3D:
		next_xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var a: AABB = mi.mesh.get_aabb()
			var corners: Array[Vector3] = [
				a.position,
				a.position + Vector3(a.size.x, 0, 0),
				a.position + Vector3(0, a.size.y, 0),
				a.position + Vector3(0, 0, a.size.z),
				a.position + Vector3(a.size.x, a.size.y, 0),
				a.position + Vector3(a.size.x, 0, a.size.z),
				a.position + Vector3(0, a.size.y, a.size.z),
				a.position + a.size,
			]
			for c in corners:
				var wp: Vector3 = next_xf * c
				if not _aabb_valid:
					_aabb.position = wp
					_aabb.size = Vector3.ZERO
					_aabb_valid = true
				else:
					_aabb = _aabb.expand(wp)
	for ch in n.get_children():
		_collect_bounds(ch, next_xf)

func _mark_children_owned() -> void:
	if not Engine.is_editor_hint():
		return
	var root := get_tree().edited_scene_root
	if root == null:
		return
	for child in get_children():
		if child.name.begins_with("Beat0House_") or child.name.begins_with("Beat0Rock_") or child.name.begins_with("Beat0Foliage_") or child.name == "Beat0Well":
			_set_owner_recursive(child, root)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	node.owner = owner
	for ch in node.get_children():
		_set_owner_recursive(ch, owner)
