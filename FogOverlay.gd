## FogOverlay.gd — управление туманом войны
##
## Прикрепляется к ColorRect "FogOverlay" внутри CanvasLayer "UI".
## ColorRect занимает весь экран и рисует шейдер тумана.
## Шейдер сам конвертирует экранные координаты в мировые через позицию камеры.

extends ColorRect

const MAX_LOCS := 9

var _mat:      ShaderMaterial
var _revealed: Array[Vector2] = []

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

## Обновить позицию камеры в шейдере (вызывать каждый кадр из Main._process)
func update_camera(cam_pos: Vector2, zoom: float, vp_size: Vector2) -> void:
	_mat.set_shader_parameter("cam_pos",  cam_pos)
	_mat.set_shader_parameter("cam_zoom", zoom)
	_mat.set_shader_parameter("vp_size",  vp_size)

## Обновить позицию героя для визуального reveal во время движения.
## Не добавляет в _revealed, не влияет на счётчик.
func update_hero_pos(pos: Vector2) -> void:
	_mat.set_shader_parameter("hero_pos", pos)

func _sync_revealed() -> void:
	_mat.set_shader_parameter("revealed_count", mini(_revealed.size(), MAX_LOCS))
	for i in MAX_LOCS:
		var p := _revealed[i] if i < _revealed.size() else Vector2(-99999, -99999)
		_mat.set_shader_parameter("rp%d" % i, p)
