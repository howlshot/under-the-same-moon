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

@export var rebuild_town: bool = false:
	set(value):
		if value:
			rebuild_all()
		rebuild_town = false

@export var boundary_polygon := PackedVector3Array([
	Vector3(-30.0, 0.0, -29.0),
	Vector3(-21.0, 0.0, -33.0),
	Vector3(22.0, 0.0, -33.0),
	Vector3(31.0, 0.0, -23.0),
	Vector3(32.0, 0.0, 22.0),
	Vector3(22.0, 0.0, 32.0),
	Vector3(-23.0, 0.0, 31.0),
	Vector3(-31.0, 0.0, 21.0),
])

@export var boundary_collision_height := 2.2
@export var boundary_collision_thickness := 1.2

var _cached_house_large: Node3D
var _cached_house_small: Node3D
var _cached_rocks: Array[Node3D] = []
var _cached_foliage: Array[Node3D] = []

func _ready() -> void:
	if not Engine.is_editor_hint():
		_wire_runtime_scene()
		return
	if get_node_or_null("Buildings") == null:
		_create_root_groups()
	_ensure_subgroups()

func _wire_runtime_scene() -> void:
	var player := get_node_or_null("Player") as CharacterBody3D
	var camera_rig := get_node_or_null("CameraRig") as Node3D
	var cat := get_node_or_null("Cat") as CharacterBody3D
	var spawn := get_node_or_null("Props/PlayerSpawn") as Node3D
	var moon := get_node_or_null("Props/MoonBillboard") as Node3D

	if player != null and spawn != null:
		player.global_position = spawn.global_position + Vector3(0.0, 0.5, 0.0)
		player.rotation.y = spawn.rotation.y

	if camera_rig != null and player != null and camera_rig.has_method("set_target"):
		camera_rig.call("set_target", player)
		if moon != null and camera_rig.has_method("set_opening_composition"):
			camera_rig.call("set_opening_composition", moon.global_position)

	if cat != null and player != null and cat.has_method("set_target"):
		cat.global_position = player.global_position + Vector3(-1.3, 0.0, 1.8)
		cat.call("set_target", player)

func rebuild_all() -> void:
	_create_root_groups()
	_ensure_subgroups()
	_cache_templates()
	_clear_root_generated()
	_clear_group_children()
	_build_world()
	_build_houses()
	_build_pois()
	_build_paths()
	_rebuild_boundary_ring(boundary_polygon)
	_build_lighting()
	_build_backdrop()
	_build_spawn_view()
	_set_owners_for_save()

func _create_root_groups() -> void:
	for group_name in ["Buildings", "Paths", "Props", "Boundary", "Lights", "POIs"]:
		if get_node_or_null(group_name) == null:
			var n := Node3D.new()
			n.name = group_name
			add_child(n)

func _ensure_subgroups() -> void:
	var buildings := get_node_or_null("Buildings") as Node3D
	if buildings != null and buildings.get_node_or_null("Houses") == null:
		var houses := Node3D.new()
		houses.name = "Houses"
		buildings.add_child(houses)
	var boundary := get_node_or_null("Boundary") as Node3D
	if boundary != null and boundary.get_node_or_null("Segments") == null:
		var segments := Node3D.new()
		segments.name = "Segments"
		boundary.add_child(segments)
	if boundary != null and boundary.get_node_or_null("Dressing") == null:
		var dressing := Node3D.new()
		dressing.name = "Dressing"
		boundary.add_child(dressing)

func _clear_group_children() -> void:
	for group_name in ["Buildings", "Paths", "Props", "Boundary", "Lights", "POIs"]:
		var group_node := get_node_or_null(group_name)
		if group_node == null:
			continue
		if group_name == "Buildings":
			var houses := group_node.get_node_or_null("Houses")
			if houses != null:
				for child in houses.get_children():
					child.free()
			for child in group_node.get_children():
				if child.name != "Houses":
					child.free()
			continue
		if group_name == "Boundary":
			var segments := group_node.get_node_or_null("Segments")
			if segments != null:
				for child in segments.get_children():
					child.free()
			var dressing := group_node.get_node_or_null("Dressing")
			if dressing != null:
				for child in dressing.get_children():
					child.free()
			for child in group_node.get_children():
				if child.name != "Segments" and child.name != "Dressing":
					child.free()
			continue
		for child in group_node.get_children():
			child.free()

func _clear_root_generated() -> void:
	for root_node_name in ["TownEnvironment", "MoonLight", "MoonBillboard", "TownGround"]:
		var n := get_node_or_null(root_node_name)
		if n != null:
			n.free()

func _cache_templates() -> void:
	_cached_house_large = null
	_cached_house_small = null
	_cached_rocks.clear()
	_cached_foliage.clear()

	var house_scene := load(HOUSES_PACK_PATH) as PackedScene
	if house_scene != null:
		var house_pack := house_scene.instantiate()
		_cached_house_large = house_pack.get_node_or_null(HOUSE_LARGE_PATH) as Node3D
		_cached_house_small = house_pack.get_node_or_null(HOUSE_SMALL_PATH) as Node3D

	var rock_scene := load(STONES_PACK_PATH) as PackedScene
	if rock_scene != null:
		var rock_pack := rock_scene.instantiate()
		for p in STONE_PATHS:
			var n := rock_pack.get_node_or_null(p) as Node3D
			if n != null:
				_cached_rocks.append(n)

	var foliage_scene := load(FOLIAGE_PACK_PATH) as PackedScene
	if foliage_scene != null:
		var foliage_pack := foliage_scene.instantiate()
		for p in FOLIAGE_PATHS:
			var n := foliage_pack.get_node_or_null(p) as Node3D
			if n != null:
				_cached_foliage.append(n)

func _build_world() -> void:
	var props := get_node("Props")
	var lights := get_node("Lights")

	var env := WorldEnvironment.new()
	env.name = "TownEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.08, 0.1, 0.2, 1.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.2, 0.26, 0.42, 1.0)
	environment.ambient_light_energy = 0.55
	environment.fog_enabled = true
	environment.fog_density = 0.02
	environment.fog_light_color = Color(0.27, 0.3, 0.48, 1.0)
	environment.fog_aerial_perspective = 0.62
	env.environment = environment
	props.add_child(env)

	var moon_light := DirectionalLight3D.new()
	moon_light.name = "MoonLight"
	moon_light.light_color = Color(0.5, 0.62, 0.85, 1.0)
	moon_light.light_energy = 0.78
	moon_light.shadow_enabled = true
	moon_light.rotation_degrees = Vector3(-27.0, -40.0, 0.0)
	lights.add_child(moon_light)

	var moon := MeshInstance3D.new()
	moon.name = "MoonBillboard"
	var moon_mesh := QuadMesh.new()
	moon_mesh.size = Vector2(44.0, 44.0)
	moon.mesh = moon_mesh
	var moon_material := StandardMaterial3D.new()
	moon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	moon_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	moon_material.albedo_color = Color(0.95, 0.95, 0.9, 1.0)
	moon.material_override = moon_material
	moon.position = Vector3(-62.0, 52.0, -130.0)
	props.add_child(moon)

	var ground := MeshInstance3D.new()
	ground.name = "TownGround"
	var ground_mesh := PlaneMesh.new()
	ground_mesh.size = Vector2(80.0, 80.0)
	ground.mesh = ground_mesh
	var ground_mat := StandardMaterial3D.new()
	ground_mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	ground_mat.albedo_color = Color(0.15, 0.17, 0.2, 1.0)
	ground.material_override = ground_mat
	props.add_child(ground)

	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	ground.add_child(body)
	var shape := CollisionShape3D.new()
	shape.name = "CollisionShape3D"
	var box := BoxShape3D.new()
	box.size = Vector3(80.0, 0.4, 80.0)
	shape.shape = box
	body.add_child(shape)

func _build_houses() -> void:
	var houses := get_node("Buildings/Houses")
	var clusters := [
		{"center": Vector3(-13.0, 0.0, -13.0), "count": 4, "radius": 5.0},
		{"center": Vector3(11.0, 0.0, -14.0), "count": 4, "radius": 4.8},
		{"center": Vector3(-15.0, 0.0, 8.0), "count": 3, "radius": 4.2},
		{"center": Vector3(12.0, 0.0, 10.0), "count": 3, "radius": 4.0},
	]
	var i := 0
	for cluster in clusters:
		var cluster_count: int = int(cluster["count"])
		var cluster_center: Vector3 = cluster["center"] as Vector3
		var cluster_radius: float = float(cluster["radius"])
		for j in range(cluster_count):
			var angle: float = (TAU / float(cluster_count)) * float(j) + float(i) * 0.17
			var pos: Vector3 = cluster_center + Vector3(cos(angle), 0.0, sin(angle)) * cluster_radius
			var use_large := (i % 3) != 1
			var template := _cached_house_large if use_large else _cached_house_small
			var house := _duplicate_or_fallback_house(template, use_large)
			house.name = "House_%02d" % i
			house.position = pos
			house.rotation.y = angle + PI * 0.25
			var base_scale := 7.0 if use_large else 5.0
			_normalize_size(house, base_scale + float(i % 2) * 0.35)
			houses.add_child(house)
			_add_house_window_lights(house, i)
			i += 1

func _duplicate_or_fallback_house(template: Node3D, large: bool) -> Node3D:
	if template != null:
		return template.duplicate() as Node3D
	var fallback := Node3D.new()
	var m := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(2.0, 2.0 if large else 1.7, 2.0)
	m.mesh = b
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.28, 0.24, 0.2, 1.0)
	m.material_override = mat
	fallback.add_child(m)
	return fallback

func _add_house_window_lights(house: Node3D, house_idx: int) -> void:
	var lights := get_node("Lights")
	for w in range(2):
		var window := MeshInstance3D.new()
		window.name = "Window_%d" % w
		var qm := QuadMesh.new()
		qm.size = Vector2(0.38, 0.38)
		window.mesh = qm
		var wm := StandardMaterial3D.new()
		wm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		wm.albedo_color = Color(1.0, 0.8, 0.42, 1.0)
		window.material_override = wm
		window.position = Vector3(-0.35 + float(w) * 0.7, 1.2, 1.05)
		house.add_child(window)
	var lantern := OmniLight3D.new()
	lantern.name = "Lantern_%02d" % house_idx
	lantern.light_color = Color(1.0, 0.76, 0.43, 1.0)
	lantern.light_energy = 1.25
	lantern.omni_range = 4.4
	lantern.position = house.position + Vector3(0.2, 1.7, 1.6)
	lights.add_child(lantern)

func _build_pois() -> void:
	var pois := get_node("POIs")

	var well_scene := load(WELL_PACK_PATH) as PackedScene
	var well := Node3D.new()
	well.name = "WellPlaza"
	if well_scene != null:
		well = well_scene.instantiate() as Node3D
		well.name = "WellPlaza"
	_normalize_size(well, 4.2)
	well.position = Vector3(0.0, 0.0, -2.0)
	pois.add_child(well)

	var tower := Node3D.new()
	tower.name = "BellTowerSilhouette"
	tower.position = Vector3(24.0, 0.0, -24.0)
	var shaft := MeshInstance3D.new()
	shaft.mesh = BoxMesh.new()
	(shaft.mesh as BoxMesh).size = Vector3(3.4, 14.0, 3.4)
	shaft.position = Vector3(0.0, 7.0, 0.0)
	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.12, 0.13, 0.16, 1.0)
	shaft.material_override = tower_mat
	tower.add_child(shaft)
	var roof := MeshInstance3D.new()
	roof.mesh = BoxMesh.new()
	(roof.mesh as BoxMesh).size = Vector3(4.2, 1.8, 4.2)
	roof.position = Vector3(0.0, 14.8, 0.0)
	roof.material_override = tower_mat
	tower.add_child(roof)
	pois.add_child(tower)

	var lantern_cluster := Node3D.new()
	lantern_cluster.name = "LanternCluster"
	lantern_cluster.position = Vector3(-7.0, 0.0, 4.0)
	pois.add_child(lantern_cluster)
	for i in range(3):
		var post := MeshInstance3D.new()
		post.name = "LanternPost_%d" % i
		post.mesh = CylinderMesh.new()
		(post.mesh as CylinderMesh).top_radius = 0.08
		(post.mesh as CylinderMesh).bottom_radius = 0.12
		(post.mesh as CylinderMesh).height = 2.4
		post.position = Vector3(float(i) * 1.3, 1.2, 0.5 * sin(float(i)))
		lantern_cluster.add_child(post)

		var lamp := OmniLight3D.new()
		lamp.name = "LanternGlow_%d" % i
		lamp.light_color = Color(1.0, 0.74, 0.38, 1.0)
		lamp.light_energy = 1.55
		lamp.omni_range = 5.2
		lamp.position = lantern_cluster.position + post.position + Vector3(0.0, 1.0, 0.0)
		get_node("Lights").add_child(lamp)

	var notice := Node3D.new()
	notice.name = "NoticeboardSpot"
	notice.position = Vector3(8.5, 0.0, 5.0)
	var board := MeshInstance3D.new()
	board.mesh = BoxMesh.new()
	(board.mesh as BoxMesh).size = Vector3(2.0, 1.2, 0.2)
	board.position = Vector3(0.0, 1.6, 0.0)
	notice.add_child(board)
	var board_post_l := MeshInstance3D.new()
	board_post_l.mesh = BoxMesh.new()
	(board_post_l.mesh as BoxMesh).size = Vector3(0.14, 2.3, 0.14)
	board_post_l.position = Vector3(-0.75, 1.15, 0.0)
	notice.add_child(board_post_l)
	var board_post_r := MeshInstance3D.new()
	board_post_r.mesh = BoxMesh.new()
	(board_post_r.mesh as BoxMesh).size = Vector3(0.14, 2.3, 0.14)
	board_post_r.position = Vector3(0.75, 1.15, 0.0)
	notice.add_child(board_post_r)
	pois.add_child(notice)

func _build_paths() -> void:
	var paths := get_node("Paths")
	var path_mat := StandardMaterial3D.new()
	path_mat.albedo_color = Color(0.24, 0.26, 0.3, 1.0)
	var path_a := [
		Vector3(-24.0, 0.02, 24.0),
		Vector3(-15.0, 0.02, 15.0),
		Vector3(-8.0, 0.02, 8.0),
		Vector3(0.0, 0.02, -2.0),
	]
	var path_b := [
		Vector3(22.0, 0.02, 22.0),
		Vector3(14.0, 0.02, 12.0),
		Vector3(7.0, 0.02, 4.0),
		Vector3(0.0, 0.02, -2.0),
	]
	var path_c := [
		Vector3(24.0, 0.02, -23.0),
		Vector3(16.0, 0.02, -17.0),
		Vector3(8.0, 0.02, -10.0),
		Vector3(0.0, 0.02, -2.0),
	]
	_build_path_polyline(paths, path_a, 2.8, path_mat, "PathA")
	_build_path_polyline(paths, path_b, 2.5, path_mat, "PathB")
	_build_path_polyline(paths, path_c, 2.4, path_mat, "PathC")

func _build_path_polyline(parent: Node3D, points: Array, width: float, material: Material, name_prefix: String) -> void:
	for i in range(points.size() - 1):
		var a: Vector3 = points[i]
		var b: Vector3 = points[i + 1]
		var delta: Vector3 = b - a
		var len: float = maxf(delta.length(), 0.1)
		var segment := MeshInstance3D.new()
		segment.name = "%s_%02d" % [name_prefix, i]
		var box := BoxMesh.new()
		box.size = Vector3(width, 0.12, len)
		segment.mesh = box
		segment.material_override = material
		segment.position = (a + b) * 0.5
		segment.rotation.y = atan2(delta.x, delta.z)
		parent.add_child(segment)

func _rebuild_boundary_ring(points: PackedVector3Array) -> void:
	var boundary_segments := get_node_or_null("Boundary/Segments") as Node3D
	var boundary_dressing := get_node_or_null("Boundary/Dressing") as Node3D
	if boundary_segments == null or boundary_dressing == null:
		return
	if points.size() < 3:
		return
	for i in range(points.size()):
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		_build_boundary_segment(boundary_segments, boundary_dressing, a, b, i)

func _build_boundary_segment(segment_parent: Node3D, dressing_parent: Node3D, a: Vector3, b: Vector3, idx: int) -> void:
	var delta: Vector3 = b - a
	var len: float = maxf(delta.length(), 0.1)
	var mid: Vector3 = (a + b) * 0.5
	var yaw: float = atan2(delta.x, delta.z)
	var dir: Vector3 = delta.normalized()
	var outward: Vector3 = Vector3(-dir.z, 0.0, dir.x)

	var segment := Node3D.new()
	segment.name = "BoundarySeg_%02d" % idx
	segment.position = mid
	segment.rotation.y = yaw
	segment_parent.add_child(segment)

	var berm := MeshInstance3D.new()
	berm.name = "Berm"
	berm.mesh = BoxMesh.new()
	(berm.mesh as BoxMesh).size = Vector3(len, 0.7, 2.8)
	berm.position = Vector3(0.0, 0.05, 1.0)
	var berm_mat := StandardMaterial3D.new()
	berm_mat.albedo_color = Color(0.13, 0.16, 0.14, 1.0)
	berm.material_override = berm_mat
	segment.add_child(berm)

	var body := StaticBody3D.new()
	body.name = "BoundaryCollider"
	body.position = Vector3(0.0, boundary_collision_height * 0.5, 0.85)
	segment.add_child(body)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(len, boundary_collision_height, boundary_collision_thickness)
	shape.shape = box
	body.add_child(shape)

	var steps := int(ceil(len / 1.2))
	for s in range(steps + 1):
		var t := 0.0 if steps == 0 else float(s) / float(steps)
		var p := a.lerp(b, t) + outward * 0.9
		_add_boundary_dressing(dressing_parent, p, idx, s)

func _add_boundary_dressing(parent: Node3D, pos: Vector3, seg_idx: int, local_idx: int) -> void:
	var marker := Node3D.new()
	marker.name = "BoundaryDress_%02d_%02d" % [seg_idx, local_idx]
	marker.position = pos
	parent.add_child(marker)

	var fence_post := MeshInstance3D.new()
	fence_post.mesh = BoxMesh.new()
	(fence_post.mesh as BoxMesh).size = Vector3(0.12, 1.2, 0.12)
	fence_post.position = Vector3(0.0, 0.6, 0.0)
	marker.add_child(fence_post)

	var hedge := MeshInstance3D.new()
	hedge.mesh = BoxMesh.new()
	(hedge.mesh as BoxMesh).size = Vector3(0.8, 0.8, 0.8)
	hedge.position = Vector3(0.0, 0.35, 0.55)
	var hedge_mat := StandardMaterial3D.new()
	hedge_mat.albedo_color = Color(0.1, 0.2, 0.12, 1.0)
	hedge.material_override = hedge_mat
	marker.add_child(hedge)

	if not _cached_rocks.is_empty() and (local_idx % 2 == 0):
		var rock := _cached_rocks[(seg_idx + local_idx) % _cached_rocks.size()].duplicate() as Node3D
		rock.position = Vector3(0.0, 0.0, 1.1)
		_normalize_size(rock, 1.3)
		marker.add_child(rock)

	if not _cached_foliage.is_empty():
		var foliage := _cached_foliage[(seg_idx + local_idx) % _cached_foliage.size()].duplicate() as Node3D
		foliage.position = Vector3(0.0, 0.0, 1.4)
		_normalize_size(foliage, 1.2)
		marker.add_child(foliage)

func _build_lighting() -> void:
	var lights := get_node("Lights")
	var center_glow := OmniLight3D.new()
	center_glow.name = "PlazaGlow"
	center_glow.light_color = Color(1.0, 0.7, 0.4, 1.0)
	center_glow.light_energy = 1.6
	center_glow.omni_range = 8.0
	center_glow.position = Vector3(0.0, 2.4, -2.0)
	lights.add_child(center_glow)

func _build_backdrop() -> void:
	var props := get_node("Props")
	var mountain := MeshInstance3D.new()
	mountain.name = "MountainSilhouette"
	mountain.mesh = BoxMesh.new()
	(mountain.mesh as BoxMesh).size = Vector3(90.0, 36.0, 24.0)
	mountain.position = Vector3(-2.0, 16.0, -56.0)
	var mountain_mat := StandardMaterial3D.new()
	mountain_mat.albedo_color = Color(0.06, 0.08, 0.12, 1.0)
	mountain.material_override = mountain_mat
	props.add_child(mountain)

func _build_spawn_view() -> void:
	var props := get_node("Props")
	var spawn := Marker3D.new()
	spawn.name = "PlayerSpawn"
	spawn.position = Vector3(-20.0, 0.0, 24.0)
	spawn.rotation_degrees = Vector3(0.0, -35.0, 0.0)
	props.add_child(spawn)

func _normalize_size(node: Node3D, target_max_dim: float) -> void:
	var box: AABB = _combined_aabb(node)
	if box.size.length_squared() <= 0.00001:
		return
	var dim: float = maxf(box.size.x, maxf(box.size.y, box.size.z))
	if dim <= 0.0001:
		return
	var scale_factor: float = target_max_dim / dim
	node.scale *= scale_factor

func _combined_aabb(root: Node3D) -> AABB:
	var data := {"valid": false, "aabb": AABB()}
	_collect_bounds(root, Transform3D.IDENTITY, data)
	return data["aabb"] as AABB

func _collect_bounds(n: Node, xf: Transform3D, data: Dictionary) -> void:
	var next_xf := xf
	if n is Node3D:
		next_xf = xf * (n as Node3D).transform
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			var a := mi.mesh.get_aabb()
			var corners := [
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
				if not data["valid"]:
					data["aabb"] = AABB(wp, Vector3.ZERO)
					data["valid"] = true
				else:
					data["aabb"] = (data["aabb"] as AABB).expand(wp)
	for ch in n.get_children():
		_collect_bounds(ch, next_xf, data)

func _set_owners_for_save() -> void:
	_set_owner_recursive(self, self)

func _set_owner_recursive(node: Node, owner: Node) -> void:
	if node != owner:
		node.owner = owner
	for ch in node.get_children():
		_set_owner_recursive(ch, owner)
