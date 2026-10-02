extends CharacterBody3D
# Controlador en primera persona - Godot 4.7
# Colgar en el nodo raiz Player (CharacterBody3D)
# Jerarquia esperada:
#   Player (CharacterBody3D)  <- este script
#     CollisionShape3D        (CapsuleShape3D: radio 0.4, altura 1.8)
#     Head (Node3D)           (Position Y = 1.6)
#       Camera3D
#         Aim (RayCast3D)     (Target Position = (0, 0, -2.5))

# --- Ajustes expuestos en el Inspector ---
@export_group("Movimiento")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 6.5
@export var crouch_speed: float = 2.0
@export var jump_velocity: float = 4.5
@export var ground_accel: float = 12.0
@export var air_accel: float = 2.5

@export_group("Camara")
@export var mouse_sensitivity: float = 0.0022
@export var head_bob_amount: float = 0.02
@export var head_bob_speed: float = 12.0

@export_group("Agacharse")
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var aim: RayCast3D = $Head/Camera3D/Aim
@onready var _shape: CollisionShape3D = $CollisionShape3D

const PITCH_LIMIT := deg_to_rad(89.0)

var _head_base_y: float = 1.6
var _bob_time: float = 0.0
var _is_crouching: bool = false


# Teclas por defecto. Se registran solas si no existen en el Input Map,
# asi el jugador funciona sin configurar nada en Project Settings.
const DEFAULT_ACTIONS := {
	"move_forward": KEY_W,
	"move_back": KEY_S,
	"move_left": KEY_A,
	"move_right": KEY_D,
	"jump": KEY_SPACE,
	"sprint": KEY_SHIFT,
	"crouch": KEY_CTRL,
	"interact": KEY_E,
}


func _ensure_actions() -> void:
	for action_name in DEFAULT_ACTIONS:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name)
		var ev := InputEventKey.new()
		ev.physical_keycode = DEFAULT_ACTIONS[action_name]
		InputMap.action_add_event(action_name, ev)


func _ready() -> void:
	_ensure_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_head_base_y = head.position.y


func _unhandled_input(event: InputEvent) -> void:
	# Mirar con el raton
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * mouse_sensitivity)
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, -PITCH_LIMIT, PITCH_LIMIT)

	# ESC libera / recaptura el cursor (comodo para trabajar en el editor)
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = (
			Input.MOUSE_MODE_VISIBLE
			if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
			else Input.MOUSE_MODE_CAPTURED
		)

	if event.is_action_pressed("interact"):
		_try_interact()


func _physics_process(delta: float) -> void:
	# Gravedad (usa el valor de Project Settings > Physics > 3D > Default Gravity)
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor() and not _is_crouching:
		velocity.y = jump_velocity

	_update_crouch(delta)

	# Direccion relativa a donde mira el personaje
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var speed := walk_speed
	if _is_crouching:
		speed = crouch_speed
	elif Input.is_action_pressed("sprint"):
		speed = sprint_speed

	# Aceleracion suave en suelo, casi nula en el aire (se siente con peso)
	var accel := ground_accel if is_on_floor() else air_accel
	var target := direction * speed
	velocity.x = lerpf(velocity.x, target.x, clampf(accel * delta, 0.0, 1.0))
	velocity.z = lerpf(velocity.z, target.z, clampf(accel * delta, 0.0, 1.0))

	move_and_slide()
	_apply_head_bob(delta)


func _update_crouch(delta: float) -> void:
	var want_crouch := Input.is_action_pressed("crouch")

	# No permitir levantarse si hay techo justo encima
	if _is_crouching and not want_crouch and test_move(global_transform, Vector3.UP * 0.7):
		want_crouch = true

	_is_crouching = want_crouch

	var capsule := _shape.shape as CapsuleShape3D
	if capsule == null:
		return
	var target_h := crouch_height if _is_crouching else stand_height
	capsule.height = lerpf(capsule.height, target_h, clampf(10.0 * delta, 0.0, 1.0))
	_shape.position.y = capsule.height * 0.5
	_head_base_y = lerpf(_head_base_y, capsule.height - 0.2, clampf(10.0 * delta, 0.0, 1.0))


func _apply_head_bob(delta: float) -> void:
	var planar_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and planar_speed > 0.4:
		_bob_time += delta * head_bob_speed * (planar_speed / walk_speed)
		head.position.y = _head_base_y + sin(_bob_time) * head_bob_amount
	else:
		head.position.y = lerpf(head.position.y, _head_base_y, clampf(8.0 * delta, 0.0, 1.0))


func _try_interact() -> void:
	if not aim.is_colliding():
		return
	var target := aim.get_collider()
	if target and target.has_method("interact"):
		target.interact(self)
