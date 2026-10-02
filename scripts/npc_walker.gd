extends CharacterBody3D
## NPC que camina solo - Godot 4.7
## Cuelgalo del CharacterBody3D raiz (ya viene puesto en npc_chocolate.tscn).
## Elige un punto al azar dentro de wander_radius, camina hacia el girando
## para mirar en esa direccion, espera un rato, y elige otro punto.
## Mientras camina reproduce la animacion del personaje en bucle; al llegar
## y esperar, la detiene (se queda en la pose actual).

@export var wander_radius: float = 6.0        ## que tan lejos del punto de partida puede alejarse
@export var move_speed: float = 1.6            ## metros por segundo
@export var turn_speed: float = 6.0            ## que tan rapido gira para encarar la direccion de movimiento
@export var wait_time_min: float = 1.0         ## segundos de espera minimos entre destinos
@export var wait_time_max: float = 3.0         ## segundos de espera maximos entre destinos
@export var animation_name: String = ""        ## nombre exacto de la animacion a reproducir; vacio = usa la primera que encuentre
@export var gravity: float = 9.8

var _home: Vector3
var _target: Vector3
var _waiting: bool = false
var _wait_timer: float = 0.0
var _anim_player: AnimationPlayer
var _anim_to_play: String = ""


func _ready() -> void:
	_home = global_position
	_anim_player = _find_animation_player(self)
	if _anim_player == null:
		push_warning("npc_walker.gd: no se encontro un AnimationPlayer dentro del modelo. La animacion no se reproducira.")
	else:
		_anim_to_play = animation_name if animation_name != "" else _anim_player.get_animation_list()[0]
	_pick_new_target()


func _find_animation_player(node: Node) -> AnimationPlayer:
	if node is AnimationPlayer:
		return node
	for child in node.get_children():
		var found := _find_animation_player(child)
		if found:
			return found
	return null


func _pick_new_target() -> void:
	var angle := randf() * TAU
	var dist := randf() * wander_radius
	_target = _home + Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0.0

	if _waiting:
		_wait_timer -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		if _anim_player and _anim_player.is_playing():
			_anim_player.stop()
		if _wait_timer <= 0.0:
			_waiting = false
			_pick_new_target()
		move_and_slide()
		return

	var to_target := _target - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	if dist < 0.15:
		_waiting = true
		_wait_timer = randf_range(wait_time_min, wait_time_max)
		move_and_slide()
		return

	var dir := to_target.normalized()
	velocity.x = dir.x * move_speed
	velocity.z = dir.z * move_speed

	# gira suavemente para mirar hacia donde camina
	var target_yaw := atan2(dir.x, dir.z)
	rotation.y = lerp_angle(rotation.y, target_yaw, turn_speed * delta)

	if _anim_player and _anim_to_play != "" and not _anim_player.is_playing():
		_anim_player.play(_anim_to_play)

	move_and_slide()
