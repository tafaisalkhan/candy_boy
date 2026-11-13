class_name Granny
extends CharacterBody3D


const STOMP_BOUNCE: float = 10.0
const GRAVITY: float = -30.0
const FALL_GRAVITY: float = -55.0
const ROTATE_LERP: float = 10.0
const SPEED: float = 5.0
const DECELERATION: float = 20.0
const JUMP_VELOCITY: float = 16.0
const CAM_ROTATION_SPEED: float = PI 
const CAM_TILT_MAX: float = 10.0
const CAM_TILT_HEIGHT: float = 12.0
const CAM_TILT_LERP: float = 3.0 


@onready var hurt_sound: AudioStreamPlayer = $HurtSound
@onready var land_sound: AudioStreamPlayer = $LandSound
@onready var debug_label: Label3D = $DebugLabel
@onready var jump_sound: AudioStreamPlayer = $JumpSound
@onready var camera_controller: Node3D = $CameraController
@onready var granny: Node3D = $Granny
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var walk_sound: AudioStreamPlayer = $WalkSound
@onready var shooter: Shooter = $Granny/Shooter
@onready var health: Health = $Health
@onready var land_puff: GPUParticles3D = $LandPuff
@onready var stomp_box: HitBox = $StompBox

@export var runner_mode: bool = false
@export var runner_speed: float = 7.5
var runner_direction: Vector3 = Vector3.FORWARD
var runner_jump_queued: bool = false


var is_moving: bool:
	get: return not Vector2(velocity.x, velocity.z).is_zero_approx()


var is_falling: bool:
	get: return velocity.y < 0.0



var is_throwing: bool:
	get: 
		return animation_tree.get("parameters/Ground/InvokeThrow/active")


var _last_on_floor: bool = false
var _cam_base_tilt: float = 0.0
var _ground_y: float = 0.0
var _should_bounce: bool = false
var _bounce_speed: float = 0.0


func _enter_tree() -> void:
	add_to_group(GameDefs.GROUP_GRANNY)


func _ready() -> void:
	_cam_base_tilt = camera_controller.rotation.x
	_ground_y = global_position.y
	late_init.call_deferred()


func late_init() -> void:
	SignalHub.emit_player_health_changed(health.health)


func start_bounce(new_bounce_speed: float) -> void:
	_should_bounce = true
	_bounce_speed = new_bounce_speed


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	handle_jump()
	handle_movement(delta) 
	handle_camera(delta)
	handle_throw()
	consume_bounce()
	move_and_slide()
	update_stomp_box()
	update_walk_sound()
	check_landing()
	follow_camera()
	update_camera_tilt(delta)


func update_stomp_box() -> void:
	if is_falling != stomp_box.monitoring:
		set_area_active(stomp_box, is_falling)


func set_area_active(area: Area3D, active: bool) -> void:
	area.set_monitorable.call_deferred(active)
	area.set_monitoring.call_deferred(active)
	

func consume_bounce() -> void:
	if !_should_bounce: return
	_should_bounce = false
	velocity.y = _bounce_speed
	jump_sound.play()


func update_camera_tilt(delta: float) -> void:
	var height: float = maxf(0.0, global_position.y - _ground_y)
	var t: float = clampf(height / CAM_TILT_HEIGHT, 0.0, 1.0)
	var target: float = _cam_base_tilt - deg_to_rad(CAM_TILT_MAX) * t
	camera_controller.rotation.x = lerpf(camera_controller.rotation.x, target, delta * CAM_TILT_LERP)


func follow_camera() -> void:
	if runner_mode:
		var look_ahead: Vector3 = runner_direction.normalized() * 0.6
		var target: Vector3 = global_position + Vector3.UP * 1.6 + look_ahead
		camera_controller.global_position = camera_controller.global_position.lerp(target, 0.12)
		var desired_yaw: float = atan2(-runner_direction.x, -runner_direction.z)
		camera_controller.rotation.y = lerp_angle(camera_controller.rotation.y, desired_yaw, 0.08)
	else:
		camera_controller.global_position = camera_controller.global_position.lerp(global_position, 0.3)


func handle_camera(delta: float) -> void:
	if runner_mode:
		return
	var cam_turn: float = Input.get_axis("cam_right", "cam_left")
	debug_label.text += "\ncam: %.2f" % cam_turn
	camera_controller.rotate_y(cam_turn * delta * CAM_ROTATION_SPEED)


func handle_throw() -> void:
	if runner_mode:
		return
	if Input.is_action_just_pressed("shoot") and is_on_floor() and !is_throwing:
		animation_tree.set("parameters/Ground/InvokeThrow/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)


func fire_projectile() -> void:
	shooter.shoot()


func handle_movement(delta: float) -> void:
	if runner_mode:
		var run_dir: Vector3 = runner_direction.normalized()
		velocity.x = run_dir.x * runner_speed
		velocity.z = run_dir.z * runner_speed
		if run_dir.length_squared() > 0.01:
			granny.rotation.y = lerp_angle(granny.rotation.y,
				atan2(-run_dir.x, -run_dir.z), delta * ROTATE_LERP)
		return
	var input_dir: Vector2 = Input.get_vector("m_left", "m_right", "m_fwd", "m_back")
	#var direction: Vector3 = Vector3(input_dir.x, 0.0, input_dir.y)	
	var direction: Vector3 =  camera_controller.basis * Vector3(input_dir.x, 0.0, input_dir.y)
	debug_label.text = "input: (%.1v)\ndir: (%.1v)" % [ input_dir, direction ]
	
	if direction.length() > 0.01:
		granny.rotation.y =  lerp_angle(granny.rotation.y, 
								atan2(-direction.x, -direction.z), delta * ROTATE_LERP)
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECELERATION * delta)
		velocity.z = move_toward(velocity.z, 0.0, DECELERATION * delta)


func handle_jump() -> void:
	if (Input.is_action_just_pressed("jump") or runner_jump_queued) and is_on_floor():
		velocity.y = JUMP_VELOCITY
		jump_sound.play()
	runner_jump_queued = false


func request_runner_jump() -> void:
	runner_jump_queued = true


func apply_gravity(delta: float) -> void:
	velocity.y += (FALL_GRAVITY if velocity.y < 0.0 else GRAVITY) * delta


func update_walk_sound() -> void:
	var walking: bool = is_moving and is_on_floor()
	if walking and not walk_sound.playing:
		walk_sound.play()
	elif not walking and walk_sound.playing:
		walk_sound.stop()
		


func check_landing() -> void:
	if not _last_on_floor and is_on_floor():
		land_sound.play()
		land_puff.restart()
	if is_on_floor():
		_ground_y = global_position.y
	_last_on_floor = is_on_floor()



func _on_health_health_changed(current: int) -> void:
	SignalHub.emit_player_health_changed(current)


func _on_health_died() -> void:
	set_physics_process(false)


func _on_stomp_box_hit() -> void:
	velocity.y = STOMP_BOUNCE
	SignalHub.emit_player_hit()


func _on_fell_off_fell_off() -> void:
	health.take_damage(health.max_health)


func _on_hurt_box_hurt() -> void:
	hurt_sound.play()
	SignalHub.emit_player_hit()
