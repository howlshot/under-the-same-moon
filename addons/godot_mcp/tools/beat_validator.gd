@tool
extends Node
class_name BeatValidator
## Beat validation tools for MCP workflows.
## Handles: validate_beat, validate (beat.validate route)

const BEATS_SETTINGS_KEY := "mcp/beats"

# Configurable thresholds
const MAX_LIGHT_ENERGY := 5.0
const MIN_FOG_DENSITY := 0.0001
const PURE_BLACK_EPSILON := 0.01
const FLOAT_HEIGHT_THRESHOLD := 1.5
const GROUND_RAYCAST_DISTANCE := 5.0
const SUPPORT_HORIZONTAL_RADIUS := 2.0
const FAR_DISTANCE_THRESHOLD := 40.0

const ENTRY_NAME_CANDIDATES: PackedStringArray = [
	"EntrySpawn", "entry_spawn", "Entry", "SpawnPoint", "PlayerSpawn"
]
const EXIT_NAME_CANDIDATES: PackedStringArray = [
	"ExitTrigger", "exit_trigger", "Exit", "BeatExit", "TransitionExit"
]
const EXIT_TARGET_PROPERTY_CANDIDATES: PackedStringArray = [
	"target_scene", "target_scene_path", "next_scene", "next_scene_path",
	"transition_scene", "destination_scene", "exit_scene"
]

var _editor_plugin: EditorPlugin = null
var _beat_registry: Node = null


func set_editor_plugin(plugin: EditorPlugin) -> void:
	_editor_plugin = plugin


func set_beat_registry(registry: Node) -> void:
	_beat_registry = registry


func validate_beat(args: Dictionary) -> Dictionary:
	# Backward-compatible entry point.
	return validate(args)


func validate(args: Dictionary) -> Dictionary:
	var scene_path: String = _ensure_res_scene_path(str(args.get("scene_path", "")))
	if scene_path.is_empty():
		return {"ok": false, "error": "Missing 'scene_path'", "summary": {}, "issues": []}

	var load_result := _load_scene(scene_path)
	if not load_result[1].is_empty():
		var err: Dictionary = load_result[1]
		return {"ok": false, "error": str(err.get("error", "Failed to load scene")), "summary": {}, "issues": []}

	var root: Node = load_result[0]
	var ctx := _build_context(root, scene_path)

	var summary := {
		"structure": "pass",
		"lighting": "pass",
		"fog": "pass",
		"geometry": "pass",
		"backdrop": "pass",
		"transition": "pass"
	}
	var issues: Array = []

	var structure_result := _validate_structure(ctx)
	summary["structure"] = structure_result["status"]
	_append_issues(issues, structure_result["issues"])

	var lighting_result := _validate_lighting(ctx)
	summary["lighting"] = lighting_result["status"]
	_append_issues(issues, lighting_result["issues"])

	var fog_result := _validate_fog(ctx)
	summary["fog"] = fog_result["status"]
	_append_issues(issues, fog_result["issues"])

	var geometry_result := _validate_geometry(ctx)
	summary["geometry"] = geometry_result["status"]
	_append_issues(issues, geometry_result["issues"])

	var backdrop_result := _validate_backdrop(ctx)
	summary["backdrop"] = backdrop_result["status"]
	_append_issues(issues, backdrop_result["issues"])

	var transition_result := _validate_transition(ctx)
	summary["transition"] = transition_result["status"]
	_append_issues(issues, transition_result["issues"])

	_free_scene_root(root)

	return {
		"ok": true,
		"summary": summary,
		"issues": issues
	}


func _validate_structure(ctx: Dictionary) -> Dictionary:
	var issues: Array = []

	var entry_node: Node = ctx.get("entry_node", null)
	if entry_node == null:
		issues.append(_issue("structure", "EntrySpawn", "EntrySpawn not found"))

	var exit_node: Node = ctx.get("exit_node", null)
	if exit_node == null:
		issues.append(_issue("structure", "ExitTrigger", "ExitTrigger not found"))

	var path_nodes: Array = ctx.get("path_nodes", [])
	if path_nodes.is_empty():
		issues.append(_issue("structure", "PathSpine", "Path spine not found (name contains 'Path' or group 'path_spine')"))

	return {"status": "fail" if not issues.is_empty() else "pass", "issues": issues}


func _validate_lighting(ctx: Dictionary) -> Dictionary:
	var issues: Array = []

	var directional_nodes: Array = ctx.get("directional_nodes", [])
	if directional_nodes.is_empty():
		issues.append(_issue("lighting", "DirectionalLight3D", "Missing DirectionalLight3D"))

	var world_env_nodes: Array = ctx.get("world_environment_nodes", [])
	if world_env_nodes.is_empty():
		issues.append(_issue("lighting", "WorldEnvironment", "Missing WorldEnvironment"))

	var ambient_non_zero := false
	for env_node_variant in world_env_nodes:
		var env_node: WorldEnvironment = env_node_variant
		var env := env_node.environment
		if env == null:
			continue
		if _has_property(env, "ambient_light_energy") and float(env.get("ambient_light_energy")) > 0.0001:
			ambient_non_zero = true
			break
	if not ambient_non_zero:
		issues.append(_issue("lighting", "WorldEnvironment", "Ambient light energy is zero"))

	var light_nodes: Array = ctx.get("light_nodes", [])
	for light_variant in light_nodes:
		var light: Light3D = light_variant
		var energy := float(light.light_energy)
		if energy > MAX_LIGHT_ENERGY:
			issues.append(_issue("lighting", _node_label(light, ctx), "Light energy too high (%.2f)" % energy))

	return {"status": "fail" if not issues.is_empty() else "pass", "issues": issues}


func _validate_fog(ctx: Dictionary) -> Dictionary:
	var issues: Array = []
	var world_env_nodes: Array = ctx.get("world_environment_nodes", [])

	if world_env_nodes.is_empty():
		issues.append(_issue("fog", "WorldEnvironment", "Missing WorldEnvironment for fog"))
		return {"status": "fail", "issues": issues}

	var has_fog_enabled := false
	var has_fog_density := false
	var has_non_black_fog_color := false

	for env_node_variant in world_env_nodes:
		var env_node: WorldEnvironment = env_node_variant
		var env := env_node.environment
		if env == null:
			continue

		var fog_enabled := bool(env.get("fog_enabled")) if _has_property(env, "fog_enabled") else false
		var volumetric_enabled := bool(env.get("volumetric_fog_enabled")) if _has_property(env, "volumetric_fog_enabled") else false

		if fog_enabled or volumetric_enabled:
			has_fog_enabled = true

		if fog_enabled and _has_property(env, "fog_density"):
			if float(env.get("fog_density")) > MIN_FOG_DENSITY:
				has_fog_density = true
		if volumetric_enabled and _has_property(env, "volumetric_fog_density"):
			if float(env.get("volumetric_fog_density")) > MIN_FOG_DENSITY:
				has_fog_density = true

		var fog_color: Variant = _extract_fog_color(env)
		if fog_color != null:
			var c: Color = fog_color
			if c.r > PURE_BLACK_EPSILON or c.g > PURE_BLACK_EPSILON or c.b > PURE_BLACK_EPSILON:
				has_non_black_fog_color = true

	if not has_fog_enabled:
		issues.append(_issue("fog", "WorldEnvironment", "Fog is not enabled"))
	if not has_fog_density:
		issues.append(_issue("fog", "WorldEnvironment", "Fog density is zero"))
	if not has_non_black_fog_color:
		issues.append(_issue("fog", "WorldEnvironment", "Fog color is pure black"))

	return {"status": "fail" if not issues.is_empty() else "pass", "issues": issues}


func _validate_geometry(ctx: Dictionary) -> Dictionary:
	var issues: Array = []
	var mesh_nodes: Array = ctx.get("mesh_nodes", [])
	var all_nodes: Array = ctx.get("all_nodes", [])

	for mesh_node_variant in mesh_nodes:
		var mesh_node: MeshInstance3D = mesh_node_variant
		var mesh := mesh_node.mesh
		var node_label := _node_label(mesh_node, ctx)

		if mesh == null:
			issues.append(_issue("geometry", node_label, "MeshInstance3D has no mesh resource"))
			continue

		var mesh_class := mesh.get_class()
		if mesh_class in ["CubeMesh", "BoxMesh", "PlaneMesh"]:
			issues.append(_issue("geometry", node_label, "Primitive %s detected" % mesh_class))

		if _is_floating_mesh(mesh_node, all_nodes):
			issues.append(_issue("geometry", node_label, "Mesh appears floating above ground support"))

	return {"status": "fail" if not issues.is_empty() else "pass", "issues": issues}


func _validate_backdrop(ctx: Dictionary) -> Dictionary:
	var issues: Array = []
	var mesh_nodes: Array = ctx.get("mesh_nodes", [])
	var path_center: Vector3 = ctx.get("path_center", Vector3.ZERO)

	var has_backdrop := false
	for mesh_variant in mesh_nodes:
		var mesh_node: MeshInstance3D = mesh_variant
		var name_lc := str(mesh_node.name).to_lower()
		if mesh_node.is_in_group("backdrop") or name_lc.contains("backdrop"):
			has_backdrop = true
			break

	if not has_backdrop:
		for mesh_variant in mesh_nodes:
			var mesh_node: MeshInstance3D = mesh_variant
			var dist := _node_position(mesh_node).distance_to(path_center)
			if dist >= FAR_DISTANCE_THRESHOLD:
				has_backdrop = true
				break

	if not has_backdrop:
		issues.append(_issue("backdrop", "Backdrop", "No backdrop mesh/group and no far-distance mesh detected"))

	return {"status": "fail" if not issues.is_empty() else "pass", "issues": issues}


func _validate_transition(ctx: Dictionary) -> Dictionary:
	var issues: Array = []
	var exit_node: Node = ctx.get("exit_node", null)

	if exit_node == null:
		issues.append(_issue("transition", "ExitTrigger", "ExitTrigger missing; cannot validate transition target"))
		return {"status": "fail", "issues": issues}

	var target_scene_path := _extract_exit_target_scene(exit_node)
	if target_scene_path.is_empty():
		target_scene_path = _target_scene_from_registry(ctx)

	if target_scene_path.is_empty():
		issues.append(_issue("transition", _node_label(exit_node, ctx), "ExitTrigger target scene is not configured"))
		return {"status": "fail", "issues": issues}

	if not FileAccess.file_exists(target_scene_path):
		issues.append(_issue("transition", _node_label(exit_node, ctx), "Target scene does not exist: %s" % target_scene_path))
		return {"status": "fail", "issues": issues}

	return {"status": "pass", "issues": issues}


func _build_context(root: Node, scene_path: String) -> Dictionary:
	var all_nodes: Array = []
	_collect_nodes(root, all_nodes)

	var mesh_nodes: Array = []
	var light_nodes: Array = []
	var directional_nodes: Array = []
	var world_env_nodes: Array = []
	var path_nodes: Array = []

	for node_variant in all_nodes:
		var node: Node = node_variant
		var name_lc := str(node.name).to_lower()

		if node is MeshInstance3D:
			mesh_nodes.append(node)
		if node is Light3D:
			light_nodes.append(node)
		if node is DirectionalLight3D:
			directional_nodes.append(node)
		if node is WorldEnvironment:
			world_env_nodes.append(node)
		if node.is_in_group("path_spine") or name_lc.contains("path"):
			path_nodes.append(node)

	var entry_node := _find_entry_node(all_nodes)
	var exit_node := _find_exit_node(all_nodes)
	var path_center := _compute_path_center(path_nodes)

	return {
		"scene_path": scene_path,
		"root": root,
		"all_nodes": all_nodes,
		"mesh_nodes": mesh_nodes,
		"light_nodes": light_nodes,
		"directional_nodes": directional_nodes,
		"world_environment_nodes": world_env_nodes,
		"path_nodes": path_nodes,
		"path_center": path_center,
		"entry_node": entry_node,
		"exit_node": exit_node,
		"beats": _load_beats()
	}


func _find_node_by_name_candidates(all_nodes: Array, candidates: PackedStringArray) -> Node:
	for candidate in candidates:
		for node_variant in all_nodes:
			var node: Node = node_variant
			if str(node.name) == candidate:
				return node
	for candidate in candidates:
		var candidate_lc := candidate.to_lower()
		for node_variant in all_nodes:
			var node: Node = node_variant
			if str(node.name).to_lower() == candidate_lc:
				return node
	return null


func _find_entry_node(all_nodes: Array) -> Node:
	var by_name := _find_node_by_name_candidates(all_nodes, ENTRY_NAME_CANDIDATES)
	if by_name != null:
		return by_name

	for node_variant in all_nodes:
		var node: Node = node_variant
		var name_lc := str(node.name).to_lower()
		if name_lc.contains("entryspawn") or (node is Marker3D and name_lc.contains("entry")):
			return node
	return null


func _find_exit_node(all_nodes: Array) -> Node:
	var by_name := _find_node_by_name_candidates(all_nodes, EXIT_NAME_CANDIDATES)
	if by_name != null:
		return by_name

	for node_variant in all_nodes:
		var node: Node = node_variant
		var name_lc := str(node.name).to_lower()
		if name_lc.contains("exittrigger"):
			return node
		if node is Area3D and (name_lc.contains("exit") or name_lc.contains("transition")):
			return node

	for node_variant in all_nodes:
		var node: Node = node_variant
		for prop_name in EXIT_TARGET_PROPERTY_CANDIDATES:
			if _has_property(node, prop_name):
				return node
	return null


func _extract_fog_color(env: Environment):
	for prop_name in ["fog_light_color", "volumetric_fog_albedo", "ambient_light_color"]:
		if _has_property(env, prop_name):
			var value = env.get(prop_name)
			if value is Color:
				return value
	return null


func _extract_exit_target_scene(exit_node: Node) -> String:
	for prop_name in EXIT_TARGET_PROPERTY_CANDIDATES:
		if not _has_property(exit_node, prop_name):
			continue
		var value = exit_node.get(prop_name)
		var path := _scene_path_from_value(value)
		if not path.is_empty():
			return path
	return ""


func _scene_path_from_value(value) -> String:
	if value == null:
		return ""
	if value is PackedScene:
		return _ensure_res_scene_path(str((value as PackedScene).resource_path))
	if value is Resource:
		return _ensure_res_scene_path(str((value as Resource).resource_path))
	if value is String:
		var s := str(value).strip_edges()
		if s.is_empty():
			return ""
		return _ensure_res_scene_path(s)
	return ""


func _target_scene_from_registry(ctx: Dictionary) -> String:
	var beats: Array = ctx.get("beats", [])
	var scene_path: String = _ensure_res_scene_path(str(ctx.get("scene_path", "")))
	if beats.is_empty() or scene_path.is_empty():
		return ""

	var ordered := _sort_beats(beats)
	var current_idx := -1
	for i in range(ordered.size()):
		var beat: Dictionary = ordered[i]
		if _ensure_res_scene_path(str(beat.get("scene_path", ""))) == scene_path:
			current_idx = i
			break
	if current_idx == -1:
		return ""

	var current: Dictionary = ordered[current_idx]
	var next_id := str(current.get("next_beat_id", "")).strip_edges()
	if not next_id.is_empty():
		for beat_variant in ordered:
			var beat: Dictionary = beat_variant
			if str(beat.get("beat_id", "")).strip_edges() == next_id:
				return _ensure_res_scene_path(str(beat.get("scene_path", "")))

	if current_idx + 1 < ordered.size():
		var fallback: Dictionary = ordered[current_idx + 1]
		return _ensure_res_scene_path(str(fallback.get("scene_path", "")))
	return ""


func _is_floating_mesh(mesh_node: MeshInstance3D, all_nodes: Array) -> bool:
	var mesh_pos := _node_position(mesh_node)
	if mesh_pos.y <= FLOAT_HEIGHT_THRESHOLD:
		return false

	for node_variant in all_nodes:
		var node: Node = node_variant
		if node == mesh_node or not (node is Node3D):
			continue

		var supports := node is CollisionShape3D or node is StaticBody3D or node is CSGShape3D or node is MeshInstance3D
		if not supports:
			continue

		var support_pos := _node_position(node as Node3D)
		if support_pos.y > mesh_pos.y:
			continue

		var dy := mesh_pos.y - support_pos.y
		if dy > GROUND_RAYCAST_DISTANCE:
			continue

		var dxz := Vector2(mesh_pos.x - support_pos.x, mesh_pos.z - support_pos.z).length()
		if dxz <= SUPPORT_HORIZONTAL_RADIUS:
			return false

	return true


func _compute_path_center(path_nodes: Array) -> Vector3:
	if path_nodes.is_empty():
		return Vector3.ZERO
	var acc := Vector3.ZERO
	var count := 0
	for node_variant in path_nodes:
		if not (node_variant is Node3D):
			continue
		acc += _node_position(node_variant as Node3D)
		count += 1
	if count == 0:
		return Vector3.ZERO
	return acc / float(count)


func _node_label(node: Node, ctx: Dictionary) -> String:
	if node == null:
		return ""
	var root: Node = ctx.get("root", null)
	if root == null:
		return str(node.name)
	return _node_path_from_root(root, node)


func _append_issues(dst: Array, src: Array) -> void:
	for issue_variant in src:
		dst.append(issue_variant)


func _node_position(node: Node3D) -> Vector3:
	if node == null:
		return Vector3.ZERO

	# Build a stable "global-like" transform from local transforms, even when
	# the scene is not attached to a live SceneTree.
	var chain: Array[Node3D] = []
	var current: Node = node
	while current != null:
		if current is Node3D:
			chain.push_front(current as Node3D)
		current = current.get_parent()

	var composed := Transform3D.IDENTITY
	for n in chain:
		composed = composed * n.transform
	return composed.origin


func _issue(issue_type: String, node: String, message: String) -> Dictionary:
	return {"type": issue_type, "node": node, "message": message}


func _has_property(obj: Object, prop_name: String) -> bool:
	for prop in obj.get_property_list():
		if str(prop.get("name", "")) == prop_name:
			return true
	return false


func _collect_nodes(node: Node, out: Array) -> void:
	out.append(node)
	for child in node.get_children():
		_collect_nodes(child, out)


func _node_path_from_root(root: Node, node: Node) -> String:
	if node == null:
		return ""
	if node == root:
		return "."

	var parts: Array[String] = []
	var current := node
	while current != null and current != root:
		parts.push_front(str(current.name))
		current = current.get_parent()
	if current == null:
		return str(node.name)
	return "/".join(parts)


func _load_beats() -> Array:
	if _beat_registry != null and _beat_registry.has_method("list_beats"):
		var result = _beat_registry.list_beats({"include_metadata": true})
		if bool(result.get("ok", false)) and typeof(result.get("beats", [])) == TYPE_ARRAY:
			return result.get("beats", [])

	var raw = ProjectSettings.get_setting(BEATS_SETTINGS_KEY, [])
	if typeof(raw) != TYPE_ARRAY:
		return []
	var beats: Array = []
	for item in raw:
		if typeof(item) == TYPE_DICTIONARY:
			beats.append((item as Dictionary).duplicate(true))
	return beats


func _sort_beats(beats: Array) -> Array:
	var sorted: Array = []
	for beat_variant in beats:
		if typeof(beat_variant) == TYPE_DICTIONARY:
			sorted.append((beat_variant as Dictionary).duplicate(true))
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ao := int(a.get("order", 0))
		var bo := int(b.get("order", 0))
		if ao == bo:
			return str(a.get("beat_id", "")) < str(b.get("beat_id", ""))
		return ao < bo
	)
	return sorted


func _ensure_res_scene_path(path: String) -> String:
	var normalized := path.strip_edges()
	if normalized.is_empty():
		return ""
	if not normalized.begins_with("res://"):
		normalized = "res://" + normalized
	if not normalized.ends_with(".tscn"):
		normalized += ".tscn"
	return normalized


func _load_scene(scene_path: String) -> Array:
	if not FileAccess.file_exists(scene_path):
		return [null, {"ok": false, "error": "Scene does not exist: " + scene_path}]

	var packed = load(scene_path) as PackedScene
	if packed == null:
		return [null, {"ok": false, "error": "Failed to load scene: " + scene_path}]

	var root = packed.instantiate()
	if root == null:
		return [null, {"ok": false, "error": "Failed to instantiate scene"}]

	return [root, {}]


func _free_scene_root(root: Node) -> void:
	if root == null or not is_instance_valid(root):
		return
	# Headless validation often runs without process frames; avoid deferred cleanup.
	if root.is_inside_tree():
		root.queue_free()
	else:
		root.free()
