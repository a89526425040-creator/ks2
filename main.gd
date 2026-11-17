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
	var weapon_root := Node3D.new()
	weapon_root.name = "WeaponView"
	weapon_root.position = Vector3(0.34, -0.28, -0.58)
	camera.add_child(weapon_root)
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
	if reload_clock > 0:
		reload_clock -= delta
		if reload_clock <= 0:
			var need := magazine_sizes[weapon]-ammo
			var take := mini(need,reserve_ammo)
			ammo += take
			reserve_ammo -= take

func _fire() -> void:
	if ammo <= 0:
		_reload()
		return
	ammo -= 1
	fire_clock = fire_delays[weapon]
	var from := camera.global_position
	var to := from + (-camera.global_transform.basis.z * 100.0)
	var query := PhysicsRayQueryParameters3D.create(from,to)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var target: Object = hit.collider
		if target is CharacterBody3D and target.has_method("take_damage"):
			target.take_damage(damage_values[weapon], player)
		elif target == player:
			pass

func _reload() -> void:
	if reload_clock > 0 or ammo >= magazine_sizes[weapon] or reserve_ammo <= 0:
		return
	reload_clock = [1.8,1.3,2.5][weapon]
	_show_message("RELOADING...", 1.0)

func _select_weapon(index: int) -> void:
	weapon = clampi(index,0,2)
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
