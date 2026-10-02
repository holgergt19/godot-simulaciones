extends StaticBody3D
# Puerta interactuable con bisagra animada - Godot 4.7
# ------------------------------------------------------------------
# Jerarquia esperada (asi ya viene en scenes/props/door_panel.tscn):
#   Hinge (Node3D)            <- se coloca en el CANTO de la puerta (el eje)
#     DoorPanel (StaticBody3D)  <- este script, desplazado del Hinge
#       Mesh (MeshInstance3D)
#       Collision (CollisionShape3D)
#
# Al pulsar E, este script anima Hinge.rotation.y con un Tween.
# Como Collision cuelga de este mismo StaticBody3D, que a su vez cuelga
# del Hinge, al girar el Hinge se mueve el mesh Y la colision juntos:
# la puerta abre fisicamente el paso, no solo visualmente.

signal interacted(title: String, description: String)

@export var title: String = "Puerta"
@export var description: String = "Una puerta como cualquier otra."
@export var open_angle_degrees: float = 100.0
@export var open_seconds: float = 0.8
@export_enum("+Y", "-Y") var swing_direction: String = "+Y"

var _open: bool = false
var _tween: Tween
@onready var _hinge: Node3D = get_parent() as Node3D


func interact(_by: Node) -> void:
	_open = not _open
	_animate()
	interacted.emit(title, description)


func _animate() -> void:
	if _hinge == null:
		push_warning("door.gd: el nodo padre de la puerta debe ser un Node3D usado como bisagra.")
		return
	var sign := 1.0 if swing_direction == "+Y" else -1.0
	var target_y := deg_to_rad(open_angle_degrees) * sign if _open else 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_property(_hinge, "rotation:y", target_y, open_seconds)
