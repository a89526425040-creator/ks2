extends CharacterBody3D

var game: Node
var team := 1
var bot_id := 0
var health := 100
var speed := 4.0
var think_clock := 0.0
var shoot_clock := 0.5
var target: Node3D
var rng := RandomNumberGenerator.new()
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var rifle: Node3D
var muzzle: MeshInstance3D
var muzzle_clock := 0.0
var shot_kick := 0.0
var walk_phase := 0.0
var dark_material: StandardMaterial3D
var cloth_material: StandardMaterial3D

func _ready() -> void:
	rng.randomize()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)
	_build_soldier()

func _mat(color: Color, roughness := 0.72, metallic := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	return m

func _capsule(parent: Node3D, part_name: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = height
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part

func _box(parent: Node3D, part_name: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var part := MeshInstance3D.new()
	part.name = part_name
	var mesh := BoxMesh.new()
	mesh.size = size
	part.mesh = mesh
	part.position = at
	part.material_override = material
	parent.add_child(part)
	return part

func _build_soldier() -> void:
	var visual := Node3D.new()
	visual.name = "AnimatedSoldier"
	add_child(visual)
	var blue := team == 0
	var team_mat := _mat(Color(0.12, 0.31, 0.57) if blue else Color(0.42, 0.16, 0.10))
	dark_material = _mat(Color(0.055, 0.065, 0.07), 0.48, 0.28)
	cloth_material = _mat(Color(0.16, 0.19, 0.18) if blue else Color(0.24, 0.22, 0.17))
	_capsule(visual, "Torso", 0.29, 0.78, Vector3(0, 0.28, 0), cloth_material)
	_box(visual, "ArmoredVest", Vector3(0.49, 0.48, 0.22), Vector3(0, 0.31, -0.015), team_mat)
	_box(visual, "ChestPlate", Vector3(0.34, 0.22, 0.045), Vector3(0, 0.36, -0.14), dark_material)
	_capsule(visual, "Head", 0.17, 0.34, Vector3(0, 0.91, 0), _mat(Color(0.66, 0.52, 0.39)))
	_capsule(visual, "Helmet", 0.19, 0.22, Vector3(0, 1.08, 0.015), dark_material)
	_box(visual, "HelmetBand", Vector3(0.30, 0.035, 0.27), Vector3(0, 1.06, -0.01), team_mat)
	left_arm = Node3D.new()
	left_arm.position = Vector3(-0.34, 0.55, -0.015)
	visual.add_child(left_arm)
	_capsule(left_arm, "LeftSleeve", 0.105, 0.58, Vector3(0, -0.22, 0), cloth_material).rotation.z = -0.24
	_capsule(left_arm, "LeftGlove", 0.075, 0.18, Vector3(0, -0.48, -0.015), dark_material)
	right_arm = Node3D.new()
	right_arm.position = Vector3(0.34, 0.55, -0.015)
	visual.add_child(right_arm)
	_capsule(right_arm, "RightSleeve", 0.105, 0.58, Vector3(0, -0.22, 0), cloth_material).rotation.z = 0.24
	_capsule(right_arm, "RightGlove", 0.075, 0.18, Vector3(0, -0.48, -0.015), dark_material)
	left_leg = Node3D.new()
	left_leg.position = Vector3(-0.16, -0.10, 0)
	visual.add_child(left_leg)
	_capsule(left_leg, "LeftLeg", 0.12, 0.72, Vector3(0, -0.34, 0), dark_material)
	_capsule(left_leg, "LeftBoot", 0.12, 0.22, Vector3(0, -0.68, -0.055), dark_material)
	right_leg = Node3D.new()
	right_leg.position = Vector3(0.16, -0.10, 0)
	visual.add_child(right_leg)
	_capsule(right_leg, "RightLeg", 0.12, 0.72, Vector3(0, -0.34, 0), dark_material)
	_capsule(right_leg, "RightBoot", 0.12, 0.22, Vector3(0, -0.68, -0.055), dark_material)
	rifle = Node3D.new()
	rifle.name = "RifleInHands"
	rifle.position = Vector3(0, 0.38, -0.39)
	visual.add_child(rifle)
	_box(rifle, "Receiver", Vector3(0.12, 0.13, 0.48), Vector3(0, 0, -0.13), dark_material)
	_box(rifle, "Handguard", Vector3(0.105, 0.105, 0.28), Vector3(0, 0.015, -0.43), cloth_material)
	var barrel := MeshInstance3D.new()
	var barrel_mesh := CylinderMesh.new()
	barrel_mesh.top_radius = 0.025
	barrel_mesh.bottom_radius = 0.025
	barrel_mesh.height = 0.42
	barrel.mesh = barrel_mesh
	barrel.rotation.x = PI * 0.5
	barrel.position = Vector3(0, 0.015, -0.77)
	barrel.material_override = dark_material
	rifle.add_child(barrel)
	_box(rifle, "Magazine", Vector3(0.085, 0.22, 0.12), Vector3(0, -0.16, -0.10), dark_material)
	_box(rifle, "Stock", Vector3(0.10, 0.12, 0.22), Vector3(0, 0.015, 0.20), cloth_material)
	muzzle = MeshInstance3D.new()
	var flash_mesh := SphereMesh.new()
	flash_mesh.radius = 0.075
	flash_mesh.height = 0.15
	muzzle.mesh = flash_mesh
	muzzle.position = Vector3(0, 0.015, -1.0)
	var flash_mat := _mat(Color(1.0, 0.58, 0.12), 0.2)
	flash_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash_mat.emission_enabled = true
	flash_mat.emission = Color(1.0, 0.34, 0.05)
	flash_mat.emission_energy_multiplier = 3.0
	muzzle.material_override = flash_mat
	muzzle.visible = false
	rifle.add_child(muzzle)

func _physics_process(delta: float) -> void:
	if health <= 0 or game == null or game.round_over:
		velocity = Vector3.ZERO
		_animate_soldier(delta, false)
		return
	shoot_clock -= delta
	think_clock -= delta
	muzzle_clock = maxf(0.0, muzzle_clock - delta)
	shot_kick = move_toward(shot_kick, 0.0, delta * 5.0)
	if is_instance_valid(muzzle):
		muzzle.visible = muzzle_clock > 0.0
	if team == 1 and not game.planted:
		var site_delta: Vector3 = game.bomb_position - global_position
		site_delta.y = 0
		if site_delta.length() > 3.2:
			var site_dir := site_delta.normalized()
			velocity.x = site_dir.x * speed
			velocity.z = site_dir.z * speed
			_apply_gravity(delta)
			move_and_slide()
			if velocity.length() > 0.3:
				look_at(global_position + Vector3(velocity.x, 0, velocity.z), Vector3.UP)
			_animate_soldier(delta, true)
			return
		else:
			game.planted = true
			game.bomb_clock = 35.0
			game._show_message("BOMB PLANTED! DEFUSE IT!", 3.0)
	if think_clock <= 0:
		think_clock = rng.randf_range(0.25, 0.6)
		target = _find_target()
	if not is_instance_valid(target):
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)
		_apply_gravity(delta)
		move_and_slide()
		_animate_soldier(delta, false)
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > 10.0:
		var dir := target.global_position - global_position
		dir.y = 0
		dir = dir.normalized()
		velocity.x = dir.x * speed
		velocity.z = dir.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed * delta)
		velocity.z = move_toward(velocity.z, 0, speed * delta)
		_try_shoot(dist)
	_apply_gravity(delta)
	move_and_slide()
	if velocity.length() > 0.3:
		look_at(global_position + Vector3(velocity.x, 0, velocity.z), Vector3.UP)
	elif is_instance_valid(target):
		var aim := target.global_position
		aim.y = global_position.y
		look_at(aim, Vector3.UP)
	_animate_soldier(delta, Vector2(velocity.x, velocity.z).length() > 0.4)

func _animate_soldier(delta: float, moving: bool) -> void:
	walk_phase += delta * (9.0 if moving else 2.0)
	var stride := sin(walk_phase) * (0.62 if moving else 0.025)
	if is_instance_valid(left_leg):
		left_leg.rotation.x = stride
	if is_instance_valid(right_leg):
		right_leg.rotation.x = -stride
	if is_instance_valid(left_arm):
		left_arm.rotation.x = -0.30 - stride * 0.42 - shot_kick * 0.55
	if is_instance_valid(right_arm):
		right_arm.rotation.x = -0.36 + stride * 0.30 - shot_kick * 0.75
	if is_instance_valid(rifle):
		rifle.position.z = -0.39 + shot_kick * 0.10
		rifle.rotation.x = -shot_kick * 0.22

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 20.0 * delta
	else:
		velocity.y = 0

func _find_target() -> Node3D:
	if team == 1:
		if is_instance_valid(game.player) and game.player_health > 0:
			return game.player
		return _nearest_bot(0)
	return _nearest_bot(1)

func _nearest_bot(enemy_team: int) -> Node3D:
	var best: Node3D
	var best_d := INF
	for b in game.bots:
		if is_instance_valid(b) and b != self and b.health > 0 and b.team == enemy_team:
			var d := global_position.distance_squared_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
	if enemy_team == 1 and game.player_health > 0:
		var pd := global_position.distance_squared_to(game.player.global_position)
		if pd < best_d:
			best = game.player
	return best

func _try_shoot(dist: float) -> void:
	if shoot_clock > 0 or dist > 22.0:
		return
	shoot_clock = rng.randf_range(0.65, 1.15)
	shot_kick = 1.0
	muzzle_clock = 0.075
	var origin := global_position + Vector3(0, 0.65, 0)
	var destination := target.global_position + Vector3(0, 0.5, 0)
	var direction := destination - origin
	if direction.length() > 22.0:
		return
	var query := PhysicsRayQueryParameters3D.create(origin, destination)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var victim: Object = hit.collider
	if victim == game.player and team == 1:
		game.damage_player(rng.randi_range(7, 13))
	elif victim is CharacterBody3D and victim != self and victim.has_method("take_damage"):
		victim.take_damage(rng.randi_range(8, 14), self)

func take_damage(amount: int, _source: Object = null) -> void:
	if health <= 0:
		return
	game.damage_bot(self, amount)
