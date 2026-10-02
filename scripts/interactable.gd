extends StaticBody3D
# Objeto interactuable - Godot 4.7
# Colgar en cualquier StaticBody3D (una caja, una consola, un panel...).
# El RayCast3D del jugador llama a interact() al pulsar E.

@export var title: String = "Inspeccionar la senal"
@export var description: String = "Alguien estuvo aqui antes que tu."

signal interacted(title: String, description: String)


func interact(_by: Node) -> void:
	print("[INTERACT] %s - %s" % [title, description])
	interacted.emit(title, description)
	# Aqui despues conectas la UI: mostrar el panel tipo "FIELD NOTE" del referente.
