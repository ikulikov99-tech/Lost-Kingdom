extends CharacterBody2D

signal arrived(location_name: String)

@export var walk_speed: float = 160.0

var target_position: Vector2
var target_location: String = "Castle"
var is_moving: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	target_position = global_position
	_setup_hero_animation()
	animated_sprite.play("idle")

func _physics_process(delta: float) -> void:
	if not is_moving:
		return

	var direction := target_position - global_position

	if direction.length() <= 4.0:
		global_position = target_position
		velocity = Vector2.ZERO
		is_moving = false
		animated_sprite.play("idle")
		emit_signal("arrived", target_location)
		return

	velocity = direction.normalized() * walk_speed
	_set_visual_direction(direction)
	move_and_slide()

func move_to(location_name: String, point: Vector2) -> void:
	target_location = location_name
	target_position = point
	is_moving = true
	animated_sprite.play("walk")

func _setup_hero_animation() -> void:
	var hero_folder := "res://characters/female_map"
	if GameState.selected_hero == "male":
		hero_folder = "res://characters/male_map"

	var frames := SpriteFrames.new()
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 2.0)
	frames.add_frame("idle", load(hero_folder + "/frame_1.png"))

	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	for i in range(1, 5):
		frames.add_frame("walk", load(hero_folder + "/frame_%d.png" % i))

	animated_sprite.sprite_frames = frames

func _set_visual_direction(direction: Vector2) -> void:
	# Temporary MVP direction logic. Later replace with separate up/down/left/right animations.
	animated_sprite.flip_h = direction.x < -1.0
