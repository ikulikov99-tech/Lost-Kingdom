## FogOverlay.gd — туман войны (без шейдера, через BLEND_MODE_MUL)
##
## BLEND_MODE_MUL: пиксели FogOverlay умножаются на пиксели WorldMap.
##   FOG_COLOR × карта  → тёмная карта (туман)
##   WHITE     × карта  → видимая карта (открытая область)
##
## Вызывайте reveal(world_pos) при открытии новой локации.

extends Node2D

const MAP_RECT  := Rect2(-1523, -1017, 1672, 940)
const FOG_COLOR := Color(0.05, 0.05, 0.12, 1.0)   # тёмно-синий туман
const REVEAL_R  := 300.0                            # радиус видимости
const STEPS     := 20                               # шагов градиента

var _mat: CanvasItemMaterial
var _revealed: Array[Vector2] = []

func _ready() -> void:
	_mat = CanvasItemMaterial.new()
	_mat.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	material = _mat

## Открыть область видимости вокруг мировой позиции pos
func reveal(pos: Vector2) -> void:
	for p in _revealed:
		if p.distance_to(pos) < 20.0:
			return
	_revealed.append(pos)
	queue_redraw()

func _draw() -> void:
	# 1. Тёмный туман на весь прямоугольник карты
	draw_rect(MAP_RECT, FOG_COLOR)

	# 2. Для каждой открытой точки — градиентный круг (от тёмного края к белому центру)
	for pos in _revealed:
		_draw_reveal(pos)

func _draw_reveal(center: Vector2) -> void:
	# Рисуем от внешнего (тёмного) к внутреннему (белому).
	# Каждый следующий круг меньше и светлее — перекрывает предыдущий в центре.
	for i in range(STEPS + 1):
		var t    := float(i) / float(STEPS)  # 0 = край, 1 = центр
		var r    := REVEAL_R * (1.0 - t)
		var bright := t * t                  # плавный ease-in
		var col  := FOG_COLOR.lerp(Color.WHITE, bright)
		draw_circle(center, r, col)
