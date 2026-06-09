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

	# 2. Для каждой открытой точки — большой белый круг с мягким краем
	for pos in _revealed:
		_draw_reveal(pos)

func _draw_reveal(center: Vector2) -> void:
	# Белая зона занимает 70% радиуса, мягкий переход только в крайних 30%.
	# Рисуем от большего (темнее) к меньшему (светлее), каждый круг перекрывает предыдущий.
	var r_full := REVEAL_R               # граница тумана
	var r_core := REVEAL_R * 0.70        # полностью белая зона

	# Градиент на переходной полосе (от тумана к белому)
	for i in range(STEPS + 1):
		var t    := float(i) / float(STEPS)         # 0 = внешний край, 1 = граница core
		var r    := lerpf(r_full, r_core, t)
		var bright := t * t                          # ease-in: быстро светлеет к core
		var col  := FOG_COLOR.lerp(Color.WHITE, bright)
		draw_circle(center, r, col)

	# Полностью белый core — видимая зона без тумана
	draw_circle(center, r_core, Color.WHITE)
