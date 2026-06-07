extends Node2D

var current_waypoint := "Castle"
var is_moving := false

const WALK_SPEED := 160.0

func move_to(waypoint_name: String, target_pos: Vector2) -> void:
	is_moving = true
	var duration := position.distance_to(target_pos) / WALK_SPEED
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position", target_pos, duration)
	tween.tween_callback(_arrived.bind(waypoint_name))

func _arrived(waypoint_name: String) -> void:
	current_waypoint = waypoint_name
	is_moving = false
	get_parent().on_hero_arrived(waypoint_name)
