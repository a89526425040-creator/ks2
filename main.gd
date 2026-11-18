extends Node3D

const BotScript = preload("res://bot.gd")
const ROUND_TIME := 100.0
const MAX_ROUNDS := 13

var player: CharacterBody3D
var camera: Camera3D
var hud: CanvasLayer
var status_label: Label
var ammo_label: Label
var score_label: Label
var message_label: Label
var health_label: Label
var bots: Array[CharacterBody3D] = []
var player_health := 100
var ammo := 30
var reserve_ammo := 90
var weapon := 0
var weapon_names := ["AK-STYLE RIFLE", "PISTOL", "SNIPER", "BUTTERFLY KNIFE"]
var magazine_sizes := [30, 12, 5, 0]
var damage_values := [28, 35, 90, 65]
var fire_delays := [0.105, 0.24, 0.85, 0.48]
var fire_clock := 0.0
var reload_clock := 0.0
var round_clock := ROUND_TIME
var round_number := 1
var score_attack := 0
var score_defend := 0
var planted := false
var bomb_clock := 35.0
var round_over := false
var match_over := false
var mouse_captured := false
var player_speed := 7.2
var player_velocity := Vector3.ZERO
var weapon_view: Node3D
var weapon_magazine: MeshInstance3D
var weapon_bolt: MeshInstance3D
var imported_weapon: Node3D
var imported_magazine: Node3D
var imported_bolt: Node3D
var imported_magazine_home := Vector3.ZERO
var imported_bolt_home := Vector3.ZERO
var reload_magazine: MeshInstance3D
var reload_magazine_home := Vector3(0.0, -0.18, -0.16)
var dropped_magazines: Array[Node3D] = []
var reload_magazine_spawned := false
var fallback_weapon_parts: Array[MeshInstance3D] = []
var reload_elapsed := 0.0
var reload_duration := 1.8
var muzzle_flash: MeshInstance3D
var muzzle_clock := 0.0
var weapon_recoil := 0.0
var knife_view: Node3D
var knife_left_handle: Node3D
var knife_right_handle: Node3D
var knife_inspect_time := 0.0
var knife_inspecting := false
var knife_attack_time := 0.0
var knife_blade_material: StandardMaterial3D
var knife_grip_material: StandardMaterial3D
var knife_hardware_material: StandardMaterial3D
var bullet_holes: Array[Node3D] = []
var message_clock := 0.0
var bomb_position := Vector3(0, 0, -13)
var shop_panel: Panel
var shop_weapon := 0
var selected_skins := [0, 0, 0, 6]
var shop_status_label: Label
var skin_names := ["CLASSIC", "DESERT", "ARCTIC", "JUNGLE", "CRIMSON", "NEON", "EMERALD"]
var skin_base_colors: Array[Color] = [
	Color(0.105, 0.115, 0.11), Color(0.43, 0.31, 0.19),
	Color(0.62, 0.69, 0.73), Color(0.12, 0.25, 0.16),
	Color(0.34, 0.055, 0.045), Color(0.12, 0.08, 0.28),
	Color(0.025, 0.42, 0.16)
]
var skin_secondary_colors: Array[Color] = [
	Color(0.19, 0.205, 0.19), Color(0.24, 0.17, 0.10),
	Color(0.25, 0.31, 0.36), Color(0.055, 0.12, 0.075),
	Color(0.12, 0.025, 0.025), Color(0.035, 0.23, 0.30),
	Color(0.008, 0.095, 0.045)
]
var skin_accent_colors: Array[Color] = [
	Color(0.30, 0.19, 0.105), Color(0.72, 0.56, 0.31),
	Color(0.86, 0.91, 0.94), Color(0.35, 0.48, 0.25),
	Color(0.78, 0.12, 0.08), Color(0.10, 0.82, 0.95),
	Color(0.24, 0.95, 0.48)
]


func _ready() -> void:
	_setup_input()
	_build_world()
	_spawn_player()
	_spawn_teams()
	_build_hud()
	_build_skin_shop()
	_apply_weapon_skin(0)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	mouse_captured = true
	_show_message("KS2  |  COUNTER-TERRORISTS: PROTECT THE SITE", 4.0)

func _setup_input() -> void:
	if not InputMap.has_action("interact"):
		InputMap.add_action("interact")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_E
		InputMap.action_add_event("interact", key)

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = Sky.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.48, 0.52, 0.58)
	env.ambient_light_energy = 0.65
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_env.environment = env
	add_child(world_env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, -32, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	_box("Ground", Vector3(0, -0.35, 0), Vector3(42, 0.7, 42), Color(0.22, 0.25, 0.24))
	_box("Site A", bomb_position + Vector3(0, 0.02, 0), Vector3(8, 0.08, 7), Color(0.48, 0.34, 0.18), false)
	# Outer walls and lanes
	_box("North wall", Vector3(0, 2, -21), Vector3(42, 4, 1), Color(0.28, 0.31, 0.32))
	_box("South wall", Vector3(0, 2, 21), Vector3(42, 4, 1), Color(0.28, 0.31, 0.32))
	_box("West wall", Vector3(-21, 2, 0), Vector3(1, 4, 42), Color(0.28, 0.31, 0.32))
	_box("East wall", Vector3(21, 2, 0), Vector3(1, 4, 42), Color(0.28, 0.31, 0.32))
	# Central structures, crates and cover
	_box("Central container", Vector3(0, 1.25, 0), Vector3(7, 2.5, 3), Color(0.22, 0.32, 0.34))
	_box("Container stripe", Vector3(0, 2.53, 0), Vector3(7.1, 0.08, 0.12), Color(0.82, 0.55, 0.16), false)
	for p in [Vector3(-10,0.8,-8),Vector3(10,0.8,-8),Vector3(-10,0.8,8),Vector3(10,0.8,8),Vector3(-4,0.8,-14),Vector3(4,0.8,14),Vector3(-15,0.8,0),Vector3(15,0.8,0)]:
		_box("Crate", p, Vector3(2.4,1.6,2.4), Color(0.39,0.31,0.22))
	for x in [-14,-7,7,14]:
		_box("Low barrier", Vector3(x,0.55,-2), Vector3(2.2,1.1,0.7), Color(0.36,0.38,0.35))
		_box("Low barrier", Vector3(x,0.55,2), Vector3(2.2,1.1,0.7), Color(0.36,0.38,0.35))
	# Site marker
	var marker := MeshInstance3D.new()
	var ring := CylinderMesh.new()
	ring.top_radius = 3.8
	ring.bottom_radius = 3.8
	ring.height = 0.025
	marker.mesh = ring
	marker.position = bomb_position + Vector3(0,0.06,0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9,0.62,0.12,0.42)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marker.material_override = mat
	add_child(marker)

func _box(n: String, pos: Vector3, size: Vector3, color: Color, solid := true) -> void:
	var body: Node3D
	if solid:
		body = StaticBody3D.new()
	else:
		body = Node3D.new()
	body.name = n
	body.position = pos
	if solid:
		var collision := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = size
		collision.shape = shape
		body.add_child(collision)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	mesh.material_override = material
	body.add_child(mesh)
	add_child(body)

func _spawn_player() -> void:
	player = CharacterBody3D.new()
	player.name = "Player"
	player.position = Vector3(0, 1.1, 17)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	player.add_child(shape)
	camera = Camera3D.new()
	camera.position = Vector3(0, 0.62, 0)
	camera.current = true
	camera.fov = 82
	player.add_child(camera)
	_add_weapon_model()
	add_child(player)

func _add_weapon_model() -> void:
	weapon_view = Node3D.new()
	weapon_view.name = "WeaponView"
	weapon_view.position = Vector3(0.34, -0.28, -0.58)
	camera.add_child(weapon_view)
	var weapon_root := weapon_view
	var body := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16,0.18,0.62)
	body.mesh = mesh
	body.position = Vector3(0,0,-0.22)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12,0.14,0.13)
	body.material_override = mat
	weapon_root.add_child(body)
	var barrel := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.035
	cyl.bottom_radius = 0.035
	cyl.height = 0.45
	barrel.mesh = cyl
	barrel.rotation.x = PI/2
	barrel.position = Vector3(0,0,-0.67)
	barrel.material_override = mat
	weapon_root.add_child(barrel)
	var grip := MeshInstance3D.new()
	var grip_mesh := BoxMesh.new()
	grip_mesh.size = Vector3(0.1,0.22,0.13)
	grip.mesh = grip_mesh
	grip.position = Vector3(0,-0.17,-0.12)
	grip.material_override = mat
	weapon_root.add_child(grip)
	weapon_magazine = MeshInstance3D.new()
	var magazine_mesh := BoxMesh.new()
	magazine_mesh.size = Vector3(0.11, 0.24, 0.16)
	weapon_magazine.mesh = magazine_mesh
	weapon_magazine.position = Vector3(0, -0.18, -0.12)
	weapon_magazine.material_override = mat
	weapon_root.add_child(weapon_magazine)
	weapon_bolt = MeshInstance3D.new()
	var bolt_mesh := BoxMesh.new()
	bolt_mesh.size = Vector3(0.055, 0.045, 0.22)
	weapon_bolt.mesh = bolt_mesh
	weapon_bolt.position = Vector3(0, 0.105, -0.23)
	weapon_bolt.material_override = mat
	weapon_root.add_child(weapon_bolt)
	muzzle_flash = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.055
	flash_mesh.height = 0.11
	muzzle_flash.mesh = flash_mesh
	muzzle_flash.position = Vector3(0, 0, -0.96)
	var flash_mat := StandardMaterial3D.new()
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.albedo_color = Color(1.0, 0.62, 0.12)
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.38, 0.06)
	flash_mat.emission_energy_multiplier = 3.0
	muzzle_flash.material_override = flash_mat
	muzzle_flash.visible = false
	weapon_root.add_child(muzzle_flash)
	fallback_weapon_parts = [body, barrel, grip, weapon_magazine, weapon_bolt, muzzle_flash]
	_load_ak_weapon()
	_create_reload_magazine()
	_create_butterfly_knife()

func _load_ak_weapon() -> void:
	# Load the supplied textured FBX. Keep the fallback visible until fitting succeeds.
	imported_weapon = Node3D.new()
	imported_weapon.name = "ImportedAKS74"
	weapon_view.add_child(imported_weapon)
	var packed := load("res://896cdfacb60948bd89918a152d25c658.fbx") as PackedScene
	if packed == null:
		push_error("KS2: AKS-74 FBX could not be loaded; fallback remains visible")
		imported_weapon.queue_free()
		imported_weapon = null
		return
	var instance := packed.instantiate()
	if instance == null:
		push_error("KS2: AKS-74 FBX scene is empty; fallback remains visible")
		imported_weapon.queue_free()
		imported_weapon = null
		return
	var model: Node3D
	if instance is Node3D:
		model = instance as Node3D
	else:
		model = Node3D.new()
		model.add_child(instance)
	model.name = "AKS74_FBX"
	imported_weapon.add_child(model)
	call_deferred("_fit_imported_ak", model)


func _fit_imported_ak(model: Node3D) -> void:
	if not is_instance_valid(model) or not is_instance_valid(imported_weapon):
		return
	model.position = Vector3.ZERO
	model.rotation = Vector3.ZERO
	model.scale = Vector3.ONE
	await get_tree().process_frame
	if not is_instance_valid(model) or not is_instance_valid(imported_weapon):
		return
	var bounds := _collect_weapon_bounds(model, imported_weapon)
	if bounds.size.length() < 0.001:
		push_error("KS2: AKS-74 FBX has no mesh bounds; fallback remains visible")
		imported_weapon.queue_free()
		imported_weapon = null
		return
	var dimensions := [bounds.size.x, bounds.size.y, bounds.size.z]
	var long_axis := 0
	for i in range(1, 3):
		if dimensions[i] > dimensions[long_axis]:
			long_axis = i
	if long_axis == 0:
		model.rotation.y = PI * 0.5
	elif long_axis == 1:
		model.rotation.x = PI * 0.5
	await get_tree().process_frame
	if not is_instance_valid(model) or not is_instance_valid(imported_weapon):
		return
	bounds = _collect_weapon_bounds(model, imported_weapon)
	var longest := maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
	if longest < 0.001:
		push_error("KS2: invalid AKS-74 bounds after orientation; fallback remains visible")
		imported_weapon.queue_free()
		imported_weapon = null
		return
	var fit_scale := 1.42 / longest
	model.scale = Vector3.ONE * fit_scale
	model.position = -bounds.get_center() * fit_scale + Vector3(0.0, -0.035, 0.0)
	await get_tree().process_frame
	if not is_instance_valid(model):
		return
	imported_magazine = _find_weapon_part(model, ["magazine", "mag"])
	imported_bolt = _find_weapon_part(model, ["charging", "bolt", "handle"])
	if is_instance_valid(imported_magazine):
		imported_magazine_home = imported_magazine.position
	if is_instance_valid(imported_bolt):
		imported_bolt_home = imported_bolt.position
	for part in fallback_weapon_parts:
		if is_instance_valid(part):
			part.visible = false
	print("KS2: original textured AKS-74 FBX loaded; bounds=", bounds.size)


func _weapon_material(color: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _weapon_box(parent: Node3D, part_name: String, dimensions: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part


func _weapon_cylinder(parent: Node3D, part_name: String, top_radius: float, bottom_radius: float, length: float, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = length
	part.mesh = mesh
	part.rotation.x = PI * 0.5
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part



func _create_butterfly_knife() -> void:
	knife_view = Node3D.new()
	knife_view.name = "ButterflyKnife"
	knife_view.position = Vector3(0.39, -0.34, -0.62)
	knife_view.rotation_degrees = Vector3(-8, -10, 4)
	camera.add_child(knife_view)

	knife_blade_material = StandardMaterial3D.new()
	knife_blade_material.albedo_color = Color(0.025, 0.42, 0.16)
	knife_blade_material.metallic = 0.96
	knife_blade_material.roughness = 0.14
	knife_blade_material.clearcoat_enabled = true
	knife_blade_material.clearcoat = 0.85
	var steel := knife_blade_material
	var edge_mat := StandardMaterial3D.new()
	edge_mat.albedo_color = Color(0.91, 0.94, 0.97)
	edge_mat.metallic = 1.0
	edge_mat.roughness = 0.11
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.025, 0.033, 0.041)
	dark.metallic = 0.88
	dark.roughness = 0.24
	knife_grip_material = StandardMaterial3D.new()
	knife_grip_material.albedo_color = Color(0.008, 0.095, 0.045)
	knife_grip_material.metallic = 0.72
	knife_grip_material.roughness = 0.22
	var grip := knife_grip_material
	knife_hardware_material = StandardMaterial3D.new()
	knife_hardware_material.albedo_color = Color(0.24, 0.95, 0.48)
	knife_hardware_material.metallic = 0.98
	knife_hardware_material.roughness = 0.13
	var accent := knife_hardware_material

	# Blade: tapered point, wide cutting section, spine and a recessed fuller.
	var blade_root := Node3D.new()
	blade_root.name = "TaperedSteelBlade"
	knife_view.add_child(blade_root)
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.052, 0.019, 0.39)
	blade.mesh = blade_mesh
	blade.position = Vector3(0, 0, -0.235)
	blade.material_override = steel
	blade_root.add_child(blade)
	var point := MeshInstance3D.new()
	var point_mesh := PrismMesh.new()
	point_mesh.size = Vector3(0.052, 0.019, 0.15)
	point.mesh = point_mesh
	point.position = Vector3(0, 0, -0.505)
	point.rotation.x = PI * 0.5
	point.material_override = steel
	blade_root.add_child(point)
	var edge := MeshInstance3D.new()
	var edge_mesh := BoxMesh.new()
	edge_mesh.size = Vector3(0.006, 0.004, 0.34)
	edge.mesh = edge_mesh
	edge.position = Vector3(-0.027, -0.009, -0.245)
	edge.material_override = edge_mat
	blade_root.add_child(edge)
	var fuller := MeshInstance3D.new()
	var fuller_mesh := BoxMesh.new()
	fuller_mesh.size = Vector3(0.008, 0.003, 0.235)
	fuller.mesh = fuller_mesh
	fuller.position = Vector3(0.006, 0.010, -0.225)
	fuller.material_override = dark
	blade_root.add_child(fuller)
	var spine := MeshInstance3D.new()
	var spine_mesh := BoxMesh.new()
	spine_mesh.size = Vector3(0.012, 0.009, 0.31)
	spine.mesh = spine_mesh
	spine.position = Vector3(0, 0.012, -0.22)
	spine.material_override = accent
	blade_root.add_child(spine)
	var ricasso := MeshInstance3D.new()
	var ricasso_mesh := BoxMesh.new()
	ricasso_mesh.size = Vector3(0.062, 0.024, 0.075)
	ricasso.mesh = ricasso_mesh
	ricasso.position = Vector3(0, 0, -0.045)
	ricasso.material_override = accent
	blade_root.add_child(ricasso)

	# Two separate skeleton handles with textured scales, liners and pivot hardware.
	for side in [-1, 1]:
		var pivot := Node3D.new()
		pivot.name = "LeftHandlePivot" if side < 0 else "RightHandlePivot"
		pivot.position = Vector3(float(side) * 0.027, 0, 0.025)
		knife_view.add_child(pivot)
		var liner := MeshInstance3D.new()
		var liner_mesh := BoxMesh.new()
		liner_mesh.size = Vector3(0.064, 0.025, 0.365)
		liner.mesh = liner_mesh
		liner.position = Vector3(0, 0, 0.18)
		liner.material_override = accent
		pivot.add_child(liner)
		var handle := MeshInstance3D.new()
		var handle_mesh := CapsuleMesh.new()
		handle_mesh.radius = 0.026
		handle_mesh.height = 0.37
		handle.mesh = handle_mesh
		handle.rotation.x = PI * 0.5
		handle.position = Vector3(0, 0.016, 0.18)
		handle.material_override = grip
		pivot.add_child(handle)
		var scale_panel := MeshInstance3D.new()
		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(0.057, 0.012, 0.285)
		scale_panel.mesh = panel_mesh
		scale_panel.position = Vector3(0, 0.038, 0.18)
		scale_panel.material_override = dark
		pivot.add_child(scale_panel)
		for groove_index in range(5):
			var groove := MeshInstance3D.new()
			var groove_mesh := BoxMesh.new()
			groove_mesh.size = Vector3(0.058, 0.003, 0.009)
			groove.mesh = groove_mesh
			groove.position = Vector3(0, 0.045, 0.075 + float(groove_index) * 0.052)
			groove.material_override = accent
			pivot.add_child(groove)
		# Large pivot washer and smaller screw head.
		var washer := MeshInstance3D.new()
		var washer_mesh := CylinderMesh.new()
		washer_mesh.top_radius = 0.031
		washer_mesh.bottom_radius = 0.031
		washer_mesh.height = 0.012
		washer.mesh = washer_mesh
		washer.rotation.z = PI * 0.5
		washer.position = Vector3(0, 0, 0.015)
		washer.material_override = dark
		pivot.add_child(washer)
		var screw := MeshInstance3D.new()
		var screw_mesh := CylinderMesh.new()
		screw_mesh.top_radius = 0.014
		screw_mesh.bottom_radius = 0.014
		screw_mesh.height = 0.018
		screw.mesh = screw_mesh
		screw.rotation.z = PI * 0.5
		screw.position = Vector3(0, 0, 0.015)
		screw.material_override = edge_mat
		pivot.add_child(screw)
		for pin_z in [0.105, 0.255]:
			var pin := MeshInstance3D.new()
			var pin_mesh := CylinderMesh.new()
			pin_mesh.top_radius = 0.009
			pin_mesh.bottom_radius = 0.009
			pin_mesh.height = 0.012
			pin.mesh = pin_mesh
			pin.rotation.z = PI * 0.5
			pin.position = Vector3(0, 0.047, pin_z)
			pin.material_override = edge_mat
			pivot.add_child(pin)
		if side < 0:
			knife_left_handle = pivot
		else:
			knife_right_handle = pivot
	knife_view.visible = false

func _update_butterfly_knife(delta: float) -> void:
	if not is_instance_valid(knife_view): return
	knife_attack_time = maxf(0.0, knife_attack_time - delta)
	var t := Time.get_ticks_msec() * 0.001
	knife_view.position = Vector3(0.39, -0.34 + sin(t * 2.2) * 0.006, -0.62)
	var angle := 0.0
	if knife_inspecting:
		knife_inspect_time += delta
		var p := clampf(knife_inspect_time / 1.15, 0.0, 1.0)
		angle = PI + sin(p * PI * 5.0) * 0.5 * (1.0 - p)
		knife_view.rotation.y = sin(p * PI * 2.0) * 0.35
		if p >= 1.0:
			knife_inspecting = false
			knife_view.rotation.y = 0.0
	elif knife_attack_time > 0.0:
		var p := 1.0 - knife_attack_time / 0.32
		knife_view.rotation.x = -0.85 * sin(p * PI)
	else:
		knife_view.rotation.x = 0.0
	if is_instance_valid(knife_left_handle): knife_left_handle.rotation.x = angle
	if is_instance_valid(knife_right_handle): knife_right_handle.rotation.x = -angle

func _knife_attack() -> void:
	if knife_attack_time > 0.0 or knife_inspecting: return
	knife_attack_time = 0.32
	var start := camera.global_position
	var finish := start + (-camera.global_transform.basis.z * 2.2)
	var query := PhysicsRayQueryParameters3D.create(start, finish)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit.collider
		if target is CharacterBody3D and target.has_method("take_damage"):
			target.take_damage(65, player)
			_show_message("KNIFE HIT", 0.5)

func _create_reload_magazine() -> void:
	reload_magazine = MeshInstance3D.new()
	reload_magazine.name = "AnimatedReloadMagazine"
	var mag_mesh := BoxMesh.new()
	mag_mesh.size = Vector3(0.075, 0.22, 0.105)
	reload_magazine.mesh = mag_mesh
	var mag_mat := StandardMaterial3D.new()
	mag_mat.albedo_color = Color(0.075, 0.085, 0.078)
	mag_mat.roughness = 0.72
	reload_magazine.material_override = mag_mat
	reload_magazine.position = reload_magazine_home
	reload_magazine.rotation_degrees = Vector3(-8, 0, 0)
	weapon_view.add_child(reload_magazine)
	reload_magazine.visible = false

func _spawn_dropped_magazine() -> void:
	if not is_instance_valid(reload_magazine) or not is_instance_valid(camera):
		return
	var dropped := MeshInstance3D.new()
	dropped.name = "DroppedMagazine"
	dropped.mesh = reload_magazine.mesh
	dropped.material_override = reload_magazine.material_override
	camera.add_child(dropped)
	dropped.transform = weapon_view.transform * reload_magazine.transform
	dropped.position += Vector3(0.0, 0.0, -0.02)
	dropped.set_meta("fall_velocity", Vector3(0.12, -0.15, -0.05))
	dropped_magazines.append(dropped)

func _update_dropped_magazines(delta: float) -> void:
	for i in range(dropped_magazines.size() - 1, -1, -1):
		var mag := dropped_magazines[i]
		if not is_instance_valid(mag):
			dropped_magazines.remove_at(i)
			continue
		var velocity: Vector3 = mag.get_meta("fall_velocity", Vector3.ZERO)
		velocity.y -= 2.8 * delta
		mag.set_meta("fall_velocity", velocity)
		mag.position += velocity * delta
		mag.rotation.x += 1.8 * delta
		mag.rotation.z += 2.2 * delta
		if mag.position.y < -1.35:
			mag.queue_free()
			dropped_magazines.remove_at(i)

func _find_weapon_part(node: Node, name_hints: Array[String]) -> Node3D:
	for child in node.get_children():
		var child_name := child.name.to_lower()
		for hint in name_hints:
			if child_name.contains(hint) and child is Node3D and child != node:
				return child as Node3D
		var nested := _find_weapon_part(child, name_hints)
		if is_instance_valid(nested):
			return nested
	return null

func _collect_weapon_bounds(node: Node, root: Node3D) -> AABB:
	var combined := AABB()
	var found := false
	for child in node.get_children():
		if child is MeshInstance3D and child.mesh != null:
			var mesh_node := child as MeshInstance3D
			var relative_transform := root.global_transform.affine_inverse() * mesh_node.global_transform
			var mesh_bounds: AABB = mesh_node.get_aabb() * relative_transform
			if not found:
				combined = mesh_bounds
				found = true
			else:
				combined = combined.merge(mesh_bounds)
		var nested := _collect_weapon_bounds(child, root)
		if nested.size.length() > 0.001:
			if not found:
				combined = nested
				found = true
			else:
				combined = combined.merge(nested)
	return combined

func _spawn_teams() -> void:
	# Player is a defender; four allied bots and five attackers.
	for i in range(4):
		_spawn_bot(0, Vector3(-5 + i*3.3, 1, 13 - (i%2)*3), i)
	for i in range(5):
		_spawn_bot(1, Vector3(-12 + i*6, 1, -16 - (i%2)*1.5), i+4)

func _spawn_bot(team: int, pos: Vector3, idx: int) -> void:
	var bot := CharacterBody3D.new()
	bot.set_script(BotScript)
	bot.team = team
	bot.game = self
	bot.bot_id = idx
	bot.position = pos
	bots.append(bot)
	add_child(bot)

func _build_hud() -> void:
	hud = CanvasLayer.new()
	add_child(hud)
	var panel := ColorRect.new()
	panel.color = Color(0.025,0.035,0.045,0.82)
	panel.position = Vector2(0,0)
	panel.size = Vector2(1600,64)
	hud.add_child(panel)
	score_label = _label("ROUND 1  |  CT 0 : 0 T", Vector2(24,12), 25, Color(0.95,0.78,0.35))
	status_label = _label("BOMB SITE A  •  DEFEND", Vector2(560,14), 24, Color(0.9,0.92,0.94))
	health_label = _label("♥ 100", Vector2(24,820), 30, Color(0.3,0.9,0.55))
	ammo_label = _label("AK-STYLE RIFLE   30 / 90", Vector2(1280,820), 26, Color(0.95,0.95,0.95))
	message_label = _label("", Vector2(350,110), 30, Color(1,0.82,0.3))
	var cross := _label("+", Vector2(790,420), 32, Color(1,1,1))
	cross.add_theme_color_override("font_shadow_color", Color.BLACK)
	cross.add_theme_constant_override("shadow_offset_x", 1)
	cross.add_theme_constant_override("shadow_offset_y", 1)
	var shop_button := Button.new()
	shop_button.text = "FREE SKINS  [B]"
	shop_button.position = Vector2(1370, 12)
	shop_button.size = Vector2(205, 40)
	shop_button.pressed.connect(_toggle_skin_shop)
	hud.add_child(shop_button)
	_label("WASD MOVE   •   MOUSE AIM   •   LMB FIRE   •   R RELOAD   •   1/2/3/4 WEAPONS   •   E INTERACT   •   B SKINS", Vector2(360,866), 17, Color(0.8,0.84,0.86))

func _build_skin_shop() -> void:
	shop_panel = Panel.new()
	shop_panel.name = "FreeSkinShop"
	shop_panel.position = Vector2(430, 105)
	shop_panel.size = Vector2(740, 690)
	shop_panel.visible = false
	shop_panel.z_index = 20
	hud.add_child(shop_panel)
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 22
	layout.offset_top = 18
	layout.offset_right = -22
	layout.offset_bottom = -18
	layout.add_theme_constant_override("separation", 14)
	shop_panel.add_child(layout)

	var heading := Label.new()
	heading.text = "KS2  |  FREE WEAPON SKINS"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.95, 0.78, 0.35))
	layout.add_child(heading)
	var note := Label.new()
	note.text = "ALL FINISHES ARE FREE — SELECT ANY LOOK"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_font_size_override("font_size", 16)
	layout.add_child(note)

	var weapon_row := HBoxContainer.new()
	weapon_row.add_theme_constant_override("separation", 10)
	layout.add_child(weapon_row)
	for i in range(4):
		var weapon_button := Button.new()
		weapon_button.text = weapon_names[i]
		weapon_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		weapon_button.custom_minimum_size = Vector2(0, 46)
		weapon_button.pressed.connect(_set_shop_weapon.bind(i))
		weapon_row.add_child(weapon_button)

	var separator := HSeparator.new()
	layout.add_child(separator)
	var skin_grid := GridContainer.new()
	skin_grid.columns = 2
	skin_grid.add_theme_constant_override("h_separation", 12)
	skin_grid.add_theme_constant_override("v_separation", 12)
	layout.add_child(skin_grid)
	for i in range(skin_names.size()):
		var skin_button := Button.new()
		skin_button.text = skin_names[i] + "   •   FREE"
		skin_button.custom_minimum_size = Vector2(0, 88)
		skin_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var style := StyleBoxFlat.new()
		style.bg_color = skin_base_colors[i]
		style.border_color = skin_accent_colors[i]
		style.set_border_width_all(3)
		style.set_corner_radius_all(8)
		style.content_margin_left = 12
		style.content_margin_right = 12
		skin_button.add_theme_stylebox_override("normal", style)
		var hover_style := style.duplicate() as StyleBoxFlat
		hover_style.bg_color = skin_secondary_colors[i]
		skin_button.add_theme_stylebox_override("hover", hover_style)
		skin_button.add_theme_color_override("font_color", Color.WHITE)
		skin_button.add_theme_color_override("font_hover_color", Color.WHITE)
		skin_button.pressed.connect(_choose_skin.bind(i))
		skin_grid.add_child(skin_button)

	shop_status_label = Label.new()
	shop_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shop_status_label.add_theme_font_size_override("font_size", 17)
	shop_status_label.add_theme_color_override("font_color", Color(0.35, 0.9, 0.58))
	layout.add_child(shop_status_label)
	var close_button := Button.new()
	close_button.text = "CLOSE  [B]"
	close_button.custom_minimum_size = Vector2(0, 48)
	close_button.pressed.connect(_toggle_skin_shop)
	layout.add_child(close_button)
	_update_skin_shop_status()


func _toggle_skin_shop() -> void:
	if not is_instance_valid(shop_panel):
		return
	shop_panel.visible = not shop_panel.visible
	mouse_captured = not shop_panel.visible
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if shop_panel.visible else Input.MOUSE_MODE_CAPTURED
	if shop_panel.visible:
		_update_skin_shop_status()


func _set_shop_weapon(index: int) -> void:
	shop_weapon = clampi(index, 0, 3)
	_update_skin_shop_status()


func _choose_skin(index: int) -> void:
	selected_skins[shop_weapon] = clampi(index, 0, skin_names.size() - 1)
	if weapon == shop_weapon:
		_apply_weapon_skin(shop_weapon)
	_update_skin_shop_status()
	_show_message("%s SKIN: %s" % [weapon_names[shop_weapon], skin_names[index]], 1.8)


func _update_skin_shop_status() -> void:
	if not is_instance_valid(shop_status_label):
		return
	shop_status_label.text = "%s  |  EQUIPPED: %s  |  ALL SKINS FREE" % [
		weapon_names[shop_weapon], skin_names[selected_skins[shop_weapon]]
	]


func _apply_weapon_skin(weapon_index: int) -> void:
	var skin_index: int = selected_skins[weapon_index]
	var primary: Color = skin_base_colors[skin_index]
	var secondary: Color = skin_secondary_colors[skin_index]
	var accent: Color = skin_accent_colors[skin_index]
	if weapon_index == 0 and is_instance_valid(imported_weapon):
		# CLASSIC uses the FBX's original material and wood textures.
		if skin_index > 0:
			_apply_ak_skin_recursive(imported_weapon, primary, secondary, accent)
	elif weapon_index == 3:
		if is_instance_valid(knife_blade_material):
			knife_blade_material.albedo_color = primary
			knife_blade_material.metallic = 0.96
			knife_blade_material.roughness = 0.14
		if is_instance_valid(knife_grip_material):
			knife_grip_material.albedo_color = secondary
		if is_instance_valid(knife_hardware_material):
			knife_hardware_material.albedo_color = accent
	elif weapon_index > 0:
		for part in fallback_weapon_parts:
			if not is_instance_valid(part) or part == muzzle_flash:
				continue
			var part_name := part.name.to_lower()
			var color := primary
			if part_name.contains("magazine") or part_name.contains("bolt"):
				color = accent
			elif part_name.contains("grip") or part_name.contains("barrel"):
				color = secondary
			part.material_override = _weapon_material(color, 0.42)


func _apply_ak_skin_recursive(node: Node, primary: Color, secondary: Color, accent: Color) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var part := child as MeshInstance3D
			if part.mesh != null:
				var part_name := part.name.to_lower()
				var a := primary
				var b := secondary
				var c := accent
				if part_name.contains("wood") or part_name.contains("stock") or part_name.contains("handguard"):
					a = accent
					b = primary
					c = secondary
				elif part_name.contains("magazine") or part_name.contains("mag"):
					a = secondary
					b = primary
					c = accent
				elif part_name.contains("barrel") or part_name.contains("sight") or part_name.contains("bolt") or part_name.contains("selector"):
					a = secondary
					b = primary
					c = secondary
				for surface in range(part.mesh.get_surface_count()):
					var source := part.get_active_material(surface)
					var base_texture: Texture2D
					var base_color := Color.WHITE
					if source is StandardMaterial3D:
						base_texture = (source as StandardMaterial3D).albedo_texture
						base_color = (source as StandardMaterial3D).albedo_color
					var shader := Shader.new()
					shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
uniform sampler2D base_texture : source_color;
uniform bool has_base_texture = false;
uniform vec4 base_color : source_color = vec4(1.0);
uniform vec4 skin_a : source_color;
uniform vec4 skin_b : source_color;
uniform vec4 skin_c : source_color;
void fragment() {
	vec3 original = (has_base_texture ? texture(base_texture, UV).rgb : vec3(1.0)) * base_color.rgb;
	float p1 = sin(UV.x * 8.0 + sin(UV.y * 6.0) * 2.2) * 0.5 + 0.5;
	float p2 = sin(UV.y * 17.0 + sin(UV.x * 11.0) * 1.7) * 0.5 + 0.5;
	float mask = smoothstep(0.30, 0.72, p1 * 0.68 + p2 * 0.32);
	vec3 camo = mix(skin_a.rgb, skin_b.rgb, mask);
	camo = mix(camo, skin_c.rgb, smoothstep(0.76, 0.94, p2) * 0.42);
	ALBEDO = mix(original, camo, 0.56);
	ROUGHNESS = 0.72;
}
"""
					var skin_material := ShaderMaterial.new()
					skin_material.shader = shader
					skin_material.set_shader_parameter("base_texture", base_texture)
					skin_material.set_shader_parameter("has_base_texture", base_texture != null)
					skin_material.set_shader_parameter("base_color", base_color)
					skin_material.set_shader_parameter("skin_a", a)
					skin_material.set_shader_parameter("skin_b", b)
					skin_material.set_shader_parameter("skin_c", c)
					part.set_surface_override_material(surface, skin_material)
		_apply_ak_skin_recursive(child, primary, secondary, accent)


func _label(t: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	hud.add_child(l)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured and not round_over and not (is_instance_valid(shop_panel) and shop_panel.visible):
		player.rotate_y(-event.relative.x * 0.0022)
		camera.rotate_x(-event.relative.y * 0.0022)
		camera.rotation.x = clamp(camera.rotation.x, -1.48, 1.48)
	if event is InputEventKey and event.pressed and event.keycode == KEY_B:
		_toggle_skin_shop()
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if is_instance_valid(shop_panel) and shop_panel.visible:
			_toggle_skin_shop()
		else:
			mouse_captured = not mouse_captured
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("weapon_1"): _select_weapon(0)
	if event.is_action_pressed("weapon_2"): _select_weapon(1)
	if event.is_action_pressed("weapon_3"): _select_weapon(2)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_4: _select_weapon(3)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_V and weapon == 3:
		knife_inspecting = true
		knife_inspect_time = 0.0

func _physics_process(delta: float) -> void:
	if match_over:
		return
	_update_player(delta)
	_update_weapon(delta)
	_update_dropped_magazines(delta)
	_update_objective(delta)
	_update_hud()
	if message_clock > 0:
		message_clock -= delta
		if message_clock <= 0: message_label.text = ""

func _update_player(delta: float) -> void:
	if is_instance_valid(shop_panel) and shop_panel.visible:
		player.velocity = Vector3.ZERO
		return
	if round_over:
		player.velocity = Vector3.ZERO
		return
	var input := Input.get_vector("move_left","move_right","move_forward","move_back")
	var direction := (player.transform.basis * Vector3(input.x,0,input.y)).normalized()
	var speed := player_speed
	if Input.is_key_pressed(KEY_SHIFT): speed *= 1.28
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	if not player.is_on_floor(): player.velocity.y -= 22.0 * delta
	elif Input.is_action_just_pressed("jump"): player.velocity.y = 6.0
	player.move_and_slide()
	if ((weapon == 0 and Input.is_action_pressed("fire")) or Input.is_action_just_pressed("fire")) and fire_clock <= 0 and reload_clock <= 0:
		_fire()
	if Input.is_action_just_pressed("reload"):
		_reload()
	if Input.is_action_just_pressed("interact"):
		_interact()

func _update_weapon(delta: float) -> void:
	fire_clock = maxf(0, fire_clock-delta)
	weapon_recoil = move_toward(weapon_recoil, 0.0, delta * 1.8)
	muzzle_clock = maxf(0.0, muzzle_clock - delta)
	if weapon == 3:
		if is_instance_valid(weapon_view): weapon_view.visible = false
		_update_butterfly_knife(delta)
		return
	if is_instance_valid(weapon_view): weapon_view.visible = true
	if is_instance_valid(weapon_view):
		var bob := sin(Time.get_ticks_msec() * 0.012) * 0.006
		weapon_view.position = Vector3(0.34, -0.28 + bob, -0.58 + weapon_recoil)
		weapon_view.rotation = Vector3.ZERO
		if reload_clock > 0.0:
			reload_elapsed += delta
			var progress := clampf(reload_elapsed / maxf(reload_duration, 0.01), 0.0, 1.0)
			# Tactical reload sequence: lower and cant the rifle, remove the magazine,
			# seat a fresh one, rack the action, then bring the rifle back on target.
			var dip_in := clampf(progress / 0.18, 0.0, 1.0)
			var dip_out := 1.0 - clampf((progress - 0.78) / 0.22, 0.0, 1.0)
			var dip := minf(dip_in, dip_out)
			weapon_view.position.y -= 0.24 * dip
			weapon_view.position.x += 0.12 * dip
			weapon_view.rotation.z = -0.58 * dip
			weapon_view.rotation.x = 0.24 * dip
			var mag_drop := clampf((progress - 0.18) / 0.18, 0.0, 1.0)
			var mag_insert := clampf((progress - 0.43) / 0.18, 0.0, 1.0)
			var magazine_out := mag_drop * (1.0 - mag_insert)
			if progress >= 0.36 and not reload_magazine_spawned:
				_spawn_dropped_magazine()
				reload_magazine_spawned = true
			if is_instance_valid(reload_magazine):
				reload_magazine.visible = progress < 0.36 or progress >= 0.43
				if progress < 0.36:
					reload_magazine.position = reload_magazine_home + Vector3(0.0, -0.34 * clampf((progress - 0.18) / 0.18, 0.0, 1.0), 0.015)
				elif progress >= 0.43:
					var fresh_t := clampf((progress - 0.43) / 0.18, 0.0, 1.0)
					reload_magazine.position = reload_magazine_home + Vector3(0.0, -0.42 * (1.0 - fresh_t), 0.015 * (1.0 - fresh_t))
			if is_instance_valid(weapon_magazine):
				weapon_magazine.position.y = -0.18 - 0.28 * magazine_out
			if is_instance_valid(imported_magazine):
				# Use the animated reload proxy only during the reload; hide the FBX magazine to avoid a duplicate.
				imported_magazine.visible = false
				imported_magazine.position = imported_magazine_home + Vector3(0.0, -0.24 * magazine_out, 0.0)
			var rack := clampf((progress - 0.76) / 0.10, 0.0, 1.0) * (1.0 - clampf((progress - 0.90) / 0.06, 0.0, 1.0))
			if is_instance_valid(weapon_bolt):
				weapon_bolt.position.z = -0.23 + 0.13 * rack
			if is_instance_valid(imported_bolt):
				imported_bolt.position = imported_bolt_home + Vector3(0.0, 0.0, 0.10 * rack)
		else:
			if is_instance_valid(weapon_magazine):
				weapon_magazine.position = Vector3(0, -0.18, -0.12)
			if is_instance_valid(reload_magazine):
				reload_magazine.position = reload_magazine_home
				reload_magazine.visible = false
			if is_instance_valid(weapon_bolt):
				weapon_bolt.position.z = -0.23
			if is_instance_valid(imported_magazine):
				imported_magazine.position = imported_magazine_home
				imported_magazine.visible = true
			if is_instance_valid(imported_bolt):
				imported_bolt.position = imported_bolt_home
	if is_instance_valid(muzzle_flash):
		muzzle_flash.visible = muzzle_clock > 0.0
	if reload_clock > 0:
		reload_clock -= delta
		if reload_clock <= 0:
			reload_clock = 0.0
			var need: int = magazine_sizes[weapon] - ammo
			var take := mini(need,reserve_ammo)
			ammo += take
			reserve_ammo -= take
			if is_instance_valid(weapon_magazine):
				weapon_magazine.position = Vector3(0, -0.18, -0.12)
			if is_instance_valid(imported_magazine):
				imported_magazine.position = imported_magazine_home
			if is_instance_valid(imported_bolt):
				imported_bolt.position = imported_bolt_home
			if is_instance_valid(weapon_view):
				weapon_view.rotation = Vector3.ZERO

func _fire() -> void:
	if weapon == 3:
		_knife_attack()
		return
	if ammo <= 0:
		_reload()
		return
	ammo -= 1
	fire_clock = fire_delays[weapon]
	weapon_recoil = minf(weapon_recoil + [0.075, 0.045, 0.14][weapon], 0.22)
	muzzle_clock = 0.055
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 100.0)
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var tracer_end: Vector3 = hit.position if not hit.is_empty() else to
	_spawn_tracer(from + (-camera.global_transform.basis.z * 0.85), tracer_end)
	if not hit.is_empty():
		var target: Object = hit.collider
		if not (target is CharacterBody3D):
			_spawn_bullet_hole(hit.position, hit.normal)
		if target is CharacterBody3D and target.has_method("take_damage"):
			target.take_damage(damage_values[weapon], player)
		elif target == player:
			pass

func _spawn_tracer(start: Vector3, finish: Vector3) -> void:
	var distance := start.distance_to(finish)
	if distance < 0.1:
		return
	var tracer := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.014, 0.014, distance)
	tracer.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.78, 0.32, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.52, 0.12)
	material.emission_energy_multiplier = 2.0
	tracer.material_override = material
	add_child(tracer)
	tracer.global_position = (start + finish) * 0.5
	tracer.look_at(finish, Vector3.UP)
	_remove_tracer_later(tracer)

func _remove_tracer_later(tracer: Node3D) -> void:
	await get_tree().create_timer(0.055).timeout
	if is_instance_valid(tracer):
		tracer.queue_free()

func _spawn_bullet_hole(point: Vector3, normal: Vector3) -> void:
	if normal.length_squared() < 0.5:
		return
	var hole := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.052
	mesh.bottom_radius = 0.052
	mesh.height = 0.008
	hole.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.035, 0.028, 0.022)
	material.roughness = 1.0
	hole.material_override = material
	var n := normal.normalized()
	var tangent := n.cross(Vector3.UP)
	if tangent.length_squared() < 0.01:
		tangent = n.cross(Vector3.RIGHT)
	tangent = tangent.normalized()
	var bitangent := tangent.cross(n).normalized()
	add_child(hole)
	hole.global_transform = Transform3D(Basis(tangent, n, bitangent), point + n * 0.006)
	bullet_holes.append(hole)
	if bullet_holes.size() > 80:
		var oldest: Node3D = bullet_holes.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()

func _reload() -> void:
	if weapon == 3 or reload_clock > 0 or ammo >= magazine_sizes[weapon] or reserve_ammo <= 0:
		return
	reload_duration = [1.8,1.3,2.5][weapon]
	reload_clock = reload_duration
	reload_elapsed = 0.0
	reload_magazine_spawned = false
	if is_instance_valid(reload_magazine):
		reload_magazine.position = reload_magazine_home
		reload_magazine.visible = is_instance_valid(imported_weapon)
	_show_message("RELOADING...", reload_duration)

func _select_weapon(index: int) -> void:
	weapon = clampi(index,0,3)
	if is_instance_valid(weapon_view): weapon_view.visible = weapon != 3
	if is_instance_valid(knife_view): knife_view.visible = weapon == 3
	knife_inspecting = false
	knife_attack_time = 0.0
	if is_instance_valid(imported_weapon):
		imported_weapon.visible = weapon == 0
	if weapon < 4:
		_apply_weapon_skin(weapon)
	if is_instance_valid(reload_magazine):
		reload_magazine.visible = weapon == 0 and reload_clock <= 0.0
		for part in fallback_weapon_parts:
			if is_instance_valid(part):
				part.visible = weapon != 0
	ammo = mini(ammo,magazine_sizes[weapon])
	reserve_ammo = [90,48,20,0][weapon]
	_show_message(weapon_names[weapon],1.0)

func _interact() -> void:
	if player.global_position.distance_to(bomb_position) > 4.8:
		_show_message("MOVE CLOSER TO SITE A",1.2)
	elif planted:
		planted = false
		_show_message("BOMB DEFUSED! CT WIN",3.0)
		_end_round(0)
	else:
		_show_message("YOU ARE DEFENDING SITE A",1.2)

func _update_objective(delta: float) -> void:
	if round_over:
		return
	round_clock -= delta
	if planted:
		bomb_clock -= delta
		if bomb_clock <= 0:
			_show_message("BOMB EXPLODED! T WIN",3.0)
			_end_round(1)
	else:
		if round_clock <= 0:
			_show_message("TIME EXPIRED! CT WIN",3.0)
			_end_round(0)

func _update_hud() -> void:
	var alive_ct := 1
	var alive_t := 0
	for b in bots:
		if b.health > 0:
			if b.team == 0: alive_ct += 1
			else: alive_t += 1
	score_label.text = "ROUND %d  |  CT %d : %d T" % [round_number,score_attack,score_defend]
	health_label.text = "♥ %d" % player_health
	ammo_label.text = "%s   %d / %d" % [weapon_names[weapon],ammo,reserve_ammo]
	status_label.text = ("BOMB PLANTED  •  %.0f SEC" % bomb_clock) if planted else ("SITE A  •  %.0f SEC  •  CT %d ALIVE / T %d ALIVE" % [round_clock,alive_ct,alive_t])

func damage_player(amount: int) -> void:
	player_health = max(0,player_health-amount)
	if player_health <= 0:
		_show_message("YOU WERE ELIMINATED",2.0)
		_end_round(1)

func damage_bot(bot: CharacterBody3D, amount: int) -> void:
	bot.health = max(0,bot.health-amount)
	if bot.health <= 0:
		bot.queue_free()
		bots.erase(bot)
		var ct_alive := 0
		var t_alive := 0
		for b in bots:
			if b.health > 0:
				if b.team == 0: ct_alive += 1
				else: t_alive += 1
		if t_alive == 0: _end_round(0)
		elif ct_alive == 0 and player_health <= 0: _end_round(1)

func _end_round(winner: int) -> void:
	if round_over: return
	round_over = true
	if winner == 0: score_attack += 1
	else: score_defend += 1
	if score_attack >= 7 or score_defend >= 7:
		match_over = true
		_show_message("MATCH OVER  |  %s WIN" % ("CT" if winner == 0 else "T"),8.0)
		return
	await get_tree().create_timer(3.0).timeout
	_next_round()

func _next_round() -> void:
	round_number += 1
	round_over = false
	planted = false
	round_clock = ROUND_TIME
	bomb_clock = 35.0
	player_health = 100
	ammo = magazine_sizes[weapon]
	reserve_ammo = [90,48,20,0][weapon]
	player.position = Vector3(0,1.1,17)
	for b in bots:
		b.queue_free()
	bots.clear()
	_spawn_teams()
	_show_message("ROUND %d  |  DEFEND SITE A" % round_number,3.0)

func _show_message(t: String, duration: float) -> void:
	if message_label:
		message_label.text = t
		message_clock = duration
