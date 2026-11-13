class_name Projectile
extends Node3D


@export var gravity: float = 0.0
@export var speed: float = 4.0
@export var explosion_scene: PackedScene


var _velocity: Vector3 = Vector3.ZERO


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_velocity = -global_transform.basis.z * speed


func _physics_process(delta: float) -> void:
	_velocity.y += gravity * delta
	global_position += _velocity * delta


func _on_hit_box_hit() -> void:
	if explosion_scene:
		SignalHub.emit_add_scene_at_transform(global_transform, explosion_scene)
	queue_free()
