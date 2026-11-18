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
var weapon_names := ["AK-STYLE RIFLE", "PISTOL", "SNIPER"]
var magazine_sizes := [30, 12, 5]
var damage_values := [28, 35, 90]
var fire_delays := [0.105, 0.24, 0.85]
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
var bullet_holes: Array[Node3D] = []
var message_clock := 0.0
var bomb_position := Vector3(0, 0, -13)

func _ready() -> void:
	_setup_input()
	_build_world()
	_spawn_player()
	_spawn_teams()
	_build_hud()
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

func _load_ak_weapon() -> void:
	# The procedural weapon remains visible unless the imported FBX is verified.
	var weapon_resource: Resource = ResourceLoader.load("res://896cdfacb60948bd89918a152d25c658.fbx")
	if not (weapon_resource is PackedScene):
		push_warning("KS2: AK FBX did not import as a PackedScene; keeping fallback weapon.")
		return
	var instance: Node = (weapon_resource as PackedScene).instantiate()
	if not (instance is Node3D):
		instance.free()
		push_warning("KS2: AK FBX root is not Node3D; keeping fallback weapon.")
		return
	imported_weapon = instance as Node3D
	imported_weapon.name = "ImportedAKS74"
	weapon_view.add_child(imported_weapon)
	imported_magazine = _find_weapon_part(imported_weapon, ["mag", "magazine"])
	imported_bolt = _find_weapon_part(imported_weapon, ["bolt", "charging", "handle"])
	if is_instance_valid(imported_magazine):
		imported_magazine_home = imported_magazine.position
	if is_instance_valid(imported_bolt):
		imported_bolt_home = imported_bolt.position
	var bounds := _collect_weapon_bounds(imported_weapon, imported_weapon)
	if bounds.size.length() < 0.001:
		imported_weapon.queue_free()
		imported_weapon = null
		push_warning("KS2: AK FBX contains no visible mesh; keeping fallback weapon.")
		return
	# Align the longest model axis with the barrel direction (-Z).
	var dimensions := bounds.size
	var longest_axis := 2
	if dimensions.x >= dimensions.y and dimensions.x >= dimensions.z:
		longest_axis = 0
	elif dimensions.y >= dimensions.x and dimensions.y >= dimensions.z:
		longest_axis = 1
	imported_weapon.rotation = Vector3.ZERO
	if longest_axis == 0:
		imported_weapon.rotation.y = PI * 0.5
	elif longest_axis == 1:
		imported_weapon.rotation.x = PI * 0.5
	var scale_factor := 0.98 / maxf(dimensions.x, maxf(dimensions.y, dimensions.z))
	imported_weapon.scale = Vector3.ONE * scale_factor
	var rotated_bounds: AABB = bounds * Transform3D(imported_weapon.basis, Vector3.ZERO)
	imported_weapon.position = Vector3(0.0, 0.0, -0.52) - imported_weapon.basis * bounds.get_center() * scale_factor
	# Hide the primitive only after the FBX has passed the mesh check.
	for part in fallback_weapon_parts:
		if is_instance_valid(part):
			part.visible = false
	print("KS2: imported AKS-74 FBX with %d mesh bounds; scale %.4f" % [1, scale_factor])


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
	reload_magazine.visible = is_instance_valid(imported_weapon)

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
	_label("WASD MOVE   •   MOUSE AIM   •   LMB FIRE   •   R RELOAD   •   1/2/3 WEAPONS   •   E INTERACT   •   ESC MENU", Vector2(360,866), 17, Color(0.8,0.84,0.86))

func _label(t: String, pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = t
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	hud.add_child(l)
	return l

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and mouse_captured and not round_over:
		player.rotate_y(-event.relative.x * 0.0022)
		camera.rotate_x(-event.relative.y * 0.0022)
		camera.rotation.x = clamp(camera.rotation.x, -1.48, 1.48)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		mouse_captured = not mouse_captured
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mouse_captured else Input.MOUSE_MODE_VISIBLE
	if event.is_action_pressed("weapon_1"): _select_weapon(0)
	if event.is_action_pressed("weapon_2"): _select_weapon(1)
	if event.is_action_pressed("weapon_3"): _select_weapon(2)

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
				reload_magazine.visible = is_instance_valid(imported_weapon)
			if is_instance_valid(weapon_bolt):
				weapon_bolt.position.z = -0.23
			if is_instance_valid(imported_magazine):
				imported_magazine.position = imported_magazine_home
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
	if reload_clock > 0 or ammo >= magazine_sizes[weapon] or reserve_ammo <= 0:
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
	weapon = clampi(index,0,2)
	if is_instance_valid(imported_weapon):
		imported_weapon.visible = weapon == 0
	if is_instance_valid(reload_magazine):
		reload_magazine.visible = weapon == 0 and reload_clock <= 0.0
		for part in fallback_weapon_parts:
			if is_instance_valid(part):
				part.visible = weapon != 0
	ammo = mini(ammo,magazine_sizes[weapon])
	reserve_ammo = [90,48,20][weapon]
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
	reserve_ammo = [90,48,20][weapon]
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
