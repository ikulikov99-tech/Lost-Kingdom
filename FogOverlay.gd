## FogOverlay.gd — управление туманом войны
##
## Прикрепляется к ColorRect "FogOverlay" внутри CanvasLayer "UI".
## ColorRect занимает весь экран и рисует шейдер тумана.
## Шейдер сам конвертирует экранные координаты в мировые через позицию камеры.

extends ColorRect

const MAX_LOCS  := 9
const MAX_TRAIL := 8

var _mat:      ShaderMaterial
var _revealed: Array[Vector2] = []
var _trail:    Array[Vector2] = []

func _ready() -> void:
	_mat        = ShaderMaterial.new()
	_mat.shader = load("res://fog.gdshader")
	material    = _mat
	# Не блокировать клики
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sync_revealed()

## Открыть область вокруг мировой позиции pos
func reveal(pos: Vector2) -> void:
	for p in _revealed:
		if p.distance_to(pos) < 20.0:
			return
	_revealed.append(pos)
	_sync_revealed()

## Обновить позицию камеры и time в шейдере (вызывать каждый кадр из Main._process)
func update_camera(cam_pos: Vector2, zoom: float, vp_size: Vector2) -> void:
	_mat.set_shader_parameter("cam_pos",  cam_pos)
	_mat.set_shader_parameter("cam_zoom", zoom)
	_mat.set_shader_parameter("vp_size",  vp_size)
	_mat.set_shader_parameter("time", Time.get_ticks_msec() * 0.001)

## Позиция героя — движется с ним, не пишет в _revealed, не меняет счётчик.
func update_hero_pos(pos: Vector2) -> void:
	_mat.set_shader_parameter("hero_pos", pos)

## Добавить точку пройденного пути. FIFO: при переполнении убираем самую старую.
## Не влияет на счётчик. Очищается при прибытии в локацию (clear_trail).
func add_trail_point(pos: Vector2) -> void:
	for p in _trail:
		if p.distance_to(pos) < 60.0:
			return
	if _trail.size() >= MAX_TRAIL:
		_trail.remove_at(0)
	_trail.append(pos)
	_sync_trail()

## Очистить trail при прибытии — постоянный reveal локации берёт на себя покрытие.
func clear_trail() -> void:
	_trail.clear()
	_sync_trail()

func _sync_revealed() -> void:
	_mat.set_shader_parameter("revealed_count", mini(_revealed.size(), MAX_LOCS))
	for i in MAX_LOCS:
		var p := _revealed[i] if i < _revealed.size() else Vector2(-99999, -99999)
		_mat.set_shader_parameter("rp%d" % i, p)

func _sync_trail() -> void:
	_mat.set_shader_parameter("trail_count", mini(_trail.size(), MAX_TRAIL))
	for i in MAX_TRAIL:
		var p := _trail[i] if i < _trail.size() else Vector2(-99999, -99999)
		_mat.set_shader_parameter("tp%d" % i, p)
