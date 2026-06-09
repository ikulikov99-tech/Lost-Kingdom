## FogOverlay.gd — слой тумана войны
##
## Рисует тёмный туман поверх карты.
## Вызывайте reveal(pos) при открытии новой локации.

extends Node2D

# Границы карты в мировых координатах
const MAP_RECT := Rect2(-1523, -1017, 1672, 940)
const MAX_LOCS := 9

var _mat: ShaderMaterial
var _revealed: Array[Vector2] = []

func _ready() -> void:
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://fog.gdshader")
	material = _mat
	_sync_shader()

## Открыть область вокруг указанной мировой позиции
func reveal(pos: Vector2) -> void:
	# Избегаем дублей (сравниваем с небольшим допуском)
	for existing in _revealed:
		if existing.distance_to(pos) < 10.0:
			return
	_revealed.append(pos)
	_sync_shader()
	queue_redraw()

func _sync_shader() -> void:
	_mat.set_shader_parameter("revealed_count", mini(_revealed.size(), MAX_LOCS))

	# Передаём позиции как плоский массив float: [x0, y0, x1, y1, ...]
	var flat := PackedFloat32Array()
	for p in _revealed:
		flat.append(p.x)
		flat.append(p.y)
	# Заполняем до MAX_LOCS пар
	while flat.size() < MAX_LOCS * 2:
		flat.append(-9999.0)

	_mat.set_shader_parameter("revealed_xy", flat)

func _draw() -> void:
	# Белый прямоугольник — шейдер превращает его в туман с дырками
	draw_rect(MAP_RECT, Color.WHITE)
