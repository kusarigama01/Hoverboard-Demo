class_name PlayerController
extends CharacterBody3D

# ---------------------------------------------------------------
# CONSTANTES PHYSIQUES
# ---------------------------------------------------------------
const HOVER_HEIGHT   : float = 0.35   # hauteur de flottaison cible (m)
const HOVER_SPRING   : float = 80.0   # rigidité du ressort de lévitation
const HOVER_DAMPING  : float = 12.0   # amortissement du ressort
const GRAVITY        : float = 20.0   # gravité custom (m/s²)
const MAX_SPEED      : float = 20.0   # vitesse max horizontale (m/s ≈ 72 kph)
const ACCELERATION   : float = 10.0   # m/s²
const BRAKE_FORCE    : float = 18.0   # m/s²
const TURN_SPEED     : float = 2.2    # rad/s
const FRICTION       : float = 3.0    # décélération naturelle sans input

# Caméra
const CAM_LERP_SPEED    : float = 6.0
const CAM_OFFSET_Y      : float = 2.5
const CAM_OFFSET_Z      : float = 5.0
const CAM_FOV_MIN       : float = 75.0  # FOV à l'arrêt
const CAM_FOV_MAX       : float = 90.0  # FOV à vitesse max

# ---------------------------------------------------------------
# EXPORTS — à assigner dans l'Inspector
# ---------------------------------------------------------------
@export var hover_fl : RayCast3D
@export var hover_fr : RayCast3D
@export var hover_rl : RayCast3D
@export var hover_rr : RayCast3D
@export var camera   : Camera3D

# ---------------------------------------------------------------
# VARIABLES PRIVÉES
# ---------------------------------------------------------------
var _velocity      : Vector3 = Vector3.ZERO
var _is_grounded   : bool    = false
var _cam_target    : Vector3 = Vector3.ZERO

# ---------------------------------------------------------------
# READY
# ---------------------------------------------------------------
func _ready() -> void:
	# Vérification des références obligatoires
	if hover_fl == null: push_error("PlayerController : hover_fl non assigné")
	if hover_fr == null: push_error("PlayerController : hover_fr non assigné")
	if hover_rl == null: push_error("PlayerController : hover_rl non assigné")
	if hover_rr == null: push_error("PlayerController : hover_rr non assigné")
	if camera   == null: push_error("PlayerController : camera non assignée")

	# Initialise la caméra sans lerp au démarrage
	if camera != null:
		_cam_target = camera.global_position

# ---------------------------------------------------------------
# LOOP PHYSIQUE
# ---------------------------------------------------------------
func _physics_process(delta: float) -> void:
	_apply_hover(delta)
	_apply_movement(delta)

	velocity = _velocity
	move_and_slide()

	_update_camera(delta)

# ---------------------------------------------------------------
# LÉVITATION — ressort sur 4 raycasts
# ---------------------------------------------------------------
func _apply_hover(dt: float) -> void:
	var total    : float = 0.0
	var hit_count: int   = 0

	# Mesure la distance sol sur chaque raycast
	for ray in [hover_fl, hover_fr, hover_rl, hover_rr]:
		if ray != null and ray.is_colliding():
			total     += (global_position - ray.get_collision_point()).length()
			hit_count += 1

	if hit_count > 0:
		var avg   : float = total / hit_count
		var error : float = HOVER_HEIGHT - avg
		# Force = ressort - amortissement
		var force : float = (HOVER_SPRING * error) - (HOVER_DAMPING * _velocity.y)
		_velocity.y  += force * dt
		_is_grounded  = avg < HOVER_HEIGHT + 0.1
	else:
		# Aucun sol détecté → chute libre
		_velocity.y -= GRAVITY * dt
		_is_grounded  = false

# ---------------------------------------------------------------
# MOUVEMENT — direction, accélération, freinage, friction
# ---------------------------------------------------------------
func _apply_movement(dt: float) -> void:
	var steer : float = Input.get_axis("steer_left", "steer_right")
	var accel : bool  = Input.is_action_pressed("accelerate")
	var brake : bool  = Input.is_action_pressed("brake")

	# Rotation gauche/droite (seulement au sol)
	if _is_grounded and steer != 0.0:
		rotate_y(-steer * TURN_SPEED * dt)

	var forward : Vector3 = -global_transform.basis.z

	if accel:
		_velocity += forward * ACCELERATION * dt
		# Limite la vitesse horizontale sans toucher Y
		var horizontal : Vector3 = Vector3(_velocity.x, 0.0, _velocity.z)
		if horizontal.length() > MAX_SPEED:
			horizontal  = horizontal.normalized() * MAX_SPEED
			_velocity.x = horizontal.x
			_velocity.z = horizontal.z

	if brake:
		var horizontal : Vector3 = Vector3(_velocity.x, 0.0, _velocity.z)
		horizontal  = horizontal.move_toward(Vector3.ZERO, BRAKE_FORCE * dt)
		_velocity.x = horizontal.x
		_velocity.z = horizontal.z

	# Friction naturelle quand aucun input
	if not accel and not brake:
		var horizontal : Vector3 = Vector3(_velocity.x, 0.0, _velocity.z)
		horizontal  = horizontal.move_toward(Vector3.ZERO, FRICTION * dt)
		_velocity.x = horizontal.x
		_velocity.z = horizontal.z

# ---------------------------------------------------------------
# CAMÉRA — suivi smooth + FOV dynamique selon vitesse
# ---------------------------------------------------------------
func _update_camera(dt: float) -> void:
	if camera == null:
		return

	# Position cible : derrière et au-dessus du joueur
	var behind : Vector3 = global_transform.basis.z.normalized()
	var target : Vector3 = global_position \
						 + behind        * CAM_OFFSET_Z \
						 + Vector3.UP    * CAM_OFFSET_Y

	# Lerp smooth vers la cible
	_cam_target            = _cam_target.lerp(target, CAM_LERP_SPEED * dt)
	camera.global_position = _cam_target

	# La caméra regarde légèrement au-dessus du centre joueur
	camera.look_at(global_position + Vector3.UP * 0.8, Vector3.UP)

	# FOV dynamique selon vitesse horizontale
	var speed       : float = Vector3(_velocity.x, 0.0, _velocity.z).length()
	var speed_ratio : float = speed / MAX_SPEED
	camera.fov = lerpf(CAM_FOV_MIN, CAM_FOV_MAX, speed_ratio)
