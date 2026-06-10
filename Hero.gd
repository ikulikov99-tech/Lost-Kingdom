## Hero.gd — герой на глобальной карте
##
## Два режима движения:
##  1. follow_path2d()  — движение вдоль PathFollow2D (Castle<->Village)
##  2. move_along_path() — движение через массив точек (остальные маршруты)

extends CharacterBody2D

signal arrived(location_name: String)

@export var walk_speed: float = 80.0

# ── Режим PathFollow2D ────────────────────────────────────────────
var _pf_node:   PathFollow2D = null
var _pf_length: float        = 0.0
var _pf_forward: bool        = true   # true = от start к end, false = обратно

# ── Режим массива точек ───────────────────────────────────────────
var path: Array[Vector2] = []
var path_index: int      = 0

# ── Общее ────────────────────────────────────────────────────────
var target_location: String = "Castle"
var is_moving: bool         = false

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	_setup_hero_animation()
	animated_sprite.play("idle")

# ──────────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not is_moving:
		return

	# ── Режим PathFollow2D ────────────────────────────────────────
	if _pf_node != null:
		var prev_pos := global_position
		if _pf_forward:
			_pf_node.progress += walk_speed * delta
		else:
			_pf_node.progress -= walk_speed * delta

		var new_pos := _pf_node.global_position
		_set_visual_direction(new_pos - prev_pos)
		global_position = new_pos

		var done := (_pf_forward  and _pf_node.progress_ratio >= 1.0) or \
					(not _pf_forward and _pf_node.progress <= 0.0)
		if done:
			_pf_node.progress_ratio = 1.0 if _pf_forward else 0.0
			global_position = _pf_node.global_position
			_finish_move()
		return

	# ── Режим массива точек ───────────────────────────────────────
	var target := path[path_index]
	var direction := target - global_position

	if direction.length() <= 3.0:
		global_position = target
		path_index += 1
		if path_index >= path.size():
			_finish_move()
		return

	velocity = direction.normalized() * walk_speed
	_set_visual_direction(direction)
	move_and_slide()

func _finish_move() -> void:
	velocity     = Vector2.ZERO
	is_moving    = false
	_pf_node     = null
	animated_sprite.play("idle")
	emit_signal("arrived", target_location)

# ──────────────────────────────────────────────────────────────────
## Движение по PathFollow2D.
## pf      — PathFollow2D (дочерний узел Path2D)
## length  — длина кривой (curve.get_baked_length())
## forward — true: от начала кривой к концу; false: в обратную сторону
func follow_path2d(loc_name: String, pf: PathFollow2D,
				   length: float, forward: bool) -> void:
	target_location = loc_name
	_pf_node        = pf
	_pf_length      = length
	_pf_forward     = forward
	# Ставим PathFollow2D в начало или конец в зависимости от направления
	pf.progress_ratio = 0.0 if forward else 1.0
	global_position   = pf.global_position
	is_moving         = true
	animated_sprite.play("walk")

## Движение по массиву мировых точек (legacy).
func move_along_path(loc_name: String, points: Array[Vector2]) -> void:
	if points.size() < 2:
		push_warning("Hero.move_along_path: менее 2 точек")
		emit_signal("arrived", loc_name)
		return
	target_location = loc_name
	path            = points
	path_index      = 1
	_pf_node        = null
	is_moving       = true
	animated_sprite.play("walk")

# ──────────────────────────────────────────────────────────────────
func _setup_hero_animation() -> void:
	var folder := "res://characters/female_map"
	if GameState.selected_hero == "male":
		folder = "res://characters/male_map"

	var frames := SpriteFrames.new()

	frames.add_animation("idle")
	frames.set_animation_loop("idle", true)
	frames.set_animation_speed("idle", 2.0)
	frames.add_frame("idle", load(folder + "/frame_1.png"))

	frames.add_animation("walk")
	frames.set_animation_loop("walk", true)
	frames.set_animation_speed("walk", 8.0)
	for i in range(1, 5):
		frames.add_frame("walk", load(folder + "/frame_%d.png" % i))

	animated_sprite.sprite_frames = frames

func _set_visual_direction(dir: Vector2) -> void:
	if dir.length() > 0.1:
		animated_sprite.flip_h = dir.x < 0.0
