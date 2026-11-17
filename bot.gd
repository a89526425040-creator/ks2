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
var body_mesh: MeshInstance3D

func _ready() -> void:
	rng.randomize()
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.38
	capsule.height = 1.8
	shape.shape = capsule
	add_child(shape)
	body_mesh = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.38
	mesh.height = 1.8
	body_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.16,0.38,0.72) if team == 0 else Color(0.68,0.19,0.13)
	body_mesh.material_override = mat
	add_child(body_mesh)
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.2
	hm.height = 0.4
	head.mesh = hm
	head.position.y = 0.88
	head.material_override = mat
	add_child(head)

func _physics_process(delta: float) -> void:
	if health <= 0 or game == null or game.round_over:
		velocity = Vector3.ZERO
		return
	shoot_clock -= delta
	think_clock -= delta
	if think_clock <= 0:
		think_clock = rng.randf_range(0.25,0.6)
		target = _find_target()
	if not is_instance_valid(target):
		velocity.x = move_toward(velocity.x,0, speed*delta)
		velocity.z = move_toward(velocity.z,0, speed*delta)
		move_and_slide()
		return
	var dist := global_position.distance_to(target.global_position)
	if dist > 10.0:
		var dir := (target.global_position-global_position)
		dir.y = 0
		dir = dir.normalized()
		velocity.x = dir.x*speed
		velocity.z = dir.z*speed
	else:
		velocity.x = move_toward(velocity.x,0,speed*delta)
		velocity.z = move_toward(velocity.z,0,speed*delta)
		_try_shoot(dist)
	if not is_on_floor():
		velocity.y -= 20.0*delta
	else:
		velocity.y = 0
	move_and_slide()
	if velocity.length() > 0.3:
		look_at(global_position + Vector3(velocity.x,0,velocity.z),Vector3.UP)

func _find_target() -> Node3D:
	if team == 1:
		if is_instance_valid(game.player) and game.player_health > 0:
			return game.player
		var ally := _nearest_bot(0)
		return ally
	return _nearest_bot(1)

func _nearest_bot(enemy_team: int) -> Node3D:
	var best: Node3D
	var best_d := INF
	for b in game.bots:
		if is_instance_valid(b) and b.health > 0 and b.team == enemy_team:
			var d := global_position.distance_squared_to(b.global_position)
			if d < best_d:
				best_d = d
				best = b
	if enemy_team == 1 and game.player_health > 0:
		var pd := global_position.distance_squared_to(game.player.global_position)
		if pd < best_d: best = game.player
	return best

func _try_shoot(dist: float) -> void:
	if shoot_clock > 0 or dist > 22.0:
		return
	shoot_clock = rng.randf_range(0.65,1.15)
	var origin := global_position + Vector3(0,0.65,0)
	var destination := target.global_position + Vector3(0,0.5,0)
	var direction := destination-origin
	if direction.length() > 22.0: return
	var query := PhysicsRayQueryParameters3D.create(origin,destination)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty(): return
	var victim: Object = hit.collider
	if victim == game.player and team == 1:
		game.damage_player(rng.randi_range(7,13))
	elif victim is CharacterBody3D and victim != self and victim.has_method("take_damage"):
		victim.take_damage(rng.randi_range(8,14),self)

func take_damage(amount: int, _source: Object = null) -> void:
	if health <= 0: return
	game.damage_bot(self,amount)
