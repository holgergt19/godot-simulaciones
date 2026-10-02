extends DirectionalLight3D
## Sistema de dia/noche - Godot 4.7
## Cuelgalo directamente del nodo "Sun" (ya es un DirectionalLight3D,
## no hace falta crear ningun nodo nuevo: Sun -> clic derecho -> Adjuntar Script
## -> selecciona este archivo, o arrastralo al campo "Script" en el Inspector).
##
## Gira el sol a lo largo del dia (a las 6:00 amanece, a las 18:00 anochece)
## y ajusta su color/intensidad. Tambien puede oscurecer la luz ambiental
## del Environment si le arrastras el nodo en el campo "Environment" de abajo.

@export var running: bool = true
@export_range(0.0, 24.0, 0.01) var time_of_day: float = 12.0   ## hora inicial (0-24)
@export var day_length_seconds: float = 120.0                   ## cuanto dura un dia completo, en segundos reales
@export_range(10.0, 90.0, 1.0) var max_sun_elevation_deg: float = 60.0  ## que tan alto sube el sol al mediodia; 90 = justo encima (deja las paredes en sombra), 45-60 = luz mas rasante, ilumina mejor las caras verticales
@export var rotate_azimuth: bool = true             ## si esta activo, el sol tambien gira en horizontal a lo largo del dia (sale por un lado, se pone por el opuesto), asi ninguna pared se queda siempre en sombra
@export var azimuth_degrees: float = 0.0            ## direccion horizontal de partida, por si quieres que el amanecer salga por un lado concreto

@export_group("Avanzado (opcional)")
@export var sun_color: GradientTexture1D   ## si lo rellenas, manda sobre el color por defecto
@export var sun_energy_curve: Curve        ## si lo rellenas, manda sobre la intensidad por defecto
@export var environment: WorldEnvironment  ## arrastra aqui el nodo Environment para que tambien reaccione


func _process(delta: float) -> void:
	if not running:
		return
	time_of_day = fmod(time_of_day + (24.0 / day_length_seconds) * delta, 24.0)
	_apply_time()


func _apply_time() -> void:
	var day_t: float = time_of_day / 24.0              # 0.0 a 1.0 a lo largo del dia
	var raw_angle: float = day_t * 360.0 - 90.0          # curva de referencia: 6:00 amanece, 18:00 anochece
	var height: float = sin(deg_to_rad(raw_angle))       # -1 noche cerrada .. 1 mediodia solar

	# el sol nunca llega a los 90 grados (justo encima): se limita a max_sun_elevation_deg,
	# asi las paredes verticales siempre reciben algo de luz directa, no solo los techos
	rotation_degrees.x = height * max_sun_elevation_deg

	if rotate_azimuth:
		rotation_degrees.y = azimuth_degrees + day_t * 360.0

	var day_factor: float = clamp(height * 3.0, 0.0, 1.0)     # 0 de noche, 1 de pleno dia

	if sun_energy_curve:
		light_energy = sun_energy_curve.sample(day_t)
	else:
		light_energy = lerp(0.05, 2.6, day_factor)

	if sun_color:
		light_color = sun_color.gradient.sample(day_t)
	else:
		var warm := Color(1.0, 0.55, 0.3)
		var white := Color(1.0, 0.98, 0.92)
		var night := Color(0.25, 0.35, 0.55)
		light_color = night.lerp(warm.lerp(white, day_factor), clamp(height * 5.0 + 0.5, 0.0, 1.0))

	# de noche, sin luz directa, apaga las sombras del sol para no gastar rendimiento
	shadow_enabled = height > -0.05

	if environment and environment.environment:
		environment.environment.ambient_light_energy = lerp(0.15, 1.35, day_factor)
