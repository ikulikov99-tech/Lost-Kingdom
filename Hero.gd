## Hero.gd — герой на глобальной карте
##
## Поддерживает движение по пути через массив промежуточных точек.
## Сигнал arrived(location_name) отправляется при прибытии в конечную точку.

extends CharacterBody2D

signal arrived(location_name: String)

@export var walk_speed: float = 200.0

# Путь (массив мировых координат включая старт и финиш)
var path: Array[Vector2] = []
var path_index: int = 0
var target_location: String = "Castle"
var is_moving: bool = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_setup_hero_animation()
	animated_sprite.play("idle")

func _physics_process(_delta: float) -> void:
	if not is_moving:
		return

	var target := path[path_index]
	var direction := target - global_position

	if direction.length() <= 3.0:
		global_position = target
		path_index += 1

		if path_index >= path.size():
			# Конец пути — прибыли
			velocity = Vector2.ZERO
			is_moving = false
			animated_sprite.play("idle")
			emit_signal("arrived", target_location)
		# Иначе двигаемся к следующей точке (на следующем кадре)
		return

	velocity = direction.normalized() * walk_speed
	_set_visual_direction(direction)
	move_and_slide()

## Начать движение по массиву точек.
## points должен включать стартовую и конечную позицию.
func move_along_path(location_name: String, points: Array[Vector2]) -> void:
	if points.size() < 2:
		push_warning("Hero.move_along_path: path has fewer than 2 points")
		emit_signal("arrived", location_name)
		return

	target_location = location_name
	path = points
	path_index = 1          # 0 — текущая позиция, начинаем со следующей
	is_moving = true
	animated_sprite.play("walk")

## Устаревший метод — оставлен для совместимости.
## Предпочтительно использовать move_along_path.
func move_to(location_name: String, point: Vector2) -> void:
	var pts: Array[Vector2] = [global_position, point]
	move_along_path(location_name, pts)

# ──────────────────────────────────────────────
func _setup_hero_animation() -> void:
	var folder := "res://characters/female_map"
	if GameState.selected_hero == "male":
		folder = "res://characters/male_map"

	var frames := SpriteFrames.new()

	# idle: один кадр
	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 2.0)
	frames.add_frame("idle", load(folder + "/frame_1.png"))

	# walk: 4 кадра
	# TODO: заменить на 8-direction top-down спрайт-лист
	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	for i in range(1, 5):
		frames.add_frame("walk", load(folder + "/frame_%d.png" % i))

	animated_sprite.sprite_frames = frames

func _set_visual_direction(direction: Vector2) -> void:
	animated_sprite.flip_h = direction.x < 0.0
