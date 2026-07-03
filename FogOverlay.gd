## FogOverlay.gd — гибридный туман войны: текстурные облака + шейдер-маска
##
## Прикрепляется к SubViewportContainer "FogOverlay" внутри CanvasLayer "UI".
## Внутри FogViewport три слоя (порядок отрисовки важен):
##   1. FogBase (ColorRect)    — tileable noise, неоднородная плотность
##   2. Clouds (Node2D)        — рисованные puff-облака, 3 слоя масштабов, дрейф
##   3. RevealMask (ColorRect) — blend_mul, вырезает открытые зоны из всего выше
##
## Публичный API не изменился — Main.gd работает как раньше.

extends SubViewportContainer

const MAX_LOCS  := 9
const MAX_TRAIL := 8

# Puff-слои: масштаб, прозрачность, кол-во спрайтов, скорость дрейфа (px/сек, мир)
# Много мелких перекрывающихся облаков вместо нескольких больших пятен
const PUFF_LAYERS := [
	{"scale": 0.45, "alpha": 0.30, "count": 10, "speed": 8.0},
	{"scale": 0.70, "alpha": 0.38, "count": 8,  "speed": 5.0},
	{"scale": 1.05, "alpha": 0.46, "count": 5,  "speed": 3.0},
]
# Зона дрейфа puff-облаков — карта с запасом (limits Camera2D + margin)
const WORLD_MIN := Vector2(-1900.0, -1350.0)
const WORLD_MAX := Vector2(500.0, 250.0)

var _base_mat: ShaderMaterial
var _mask_mat: ShaderMaterial
var _revealed: Array[Vector2] = []
var _trail:    Array[Vector2] = []
var _puffs:    Array = []   # {spr: Sprite2D, anchor: Vector2(мир), dir: Vector2}

var _cam_pos:  Vector2 = Vector2(-1112.0, -704.0)
var _cam_zoom: float   = 1.3
var _vp_size:  Vector2 = Vector2(1280.0, 720.0)

@onready var _base:   ColorRect = $FogViewport/FogBase
@onready var _clouds: Node2D    = $FogViewport/Clouds
@onready var _mask:   ColorRect = $FogViewport/RevealMask

func _ready() -> void:
	stretch = true
	# Не блокировать клики
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_base_mat        = ShaderMaterial.new()
	_base_mat.shader = load("res://fog_base.gdshader")
	_base_mat.set_shader_parameter("noise_tex", load("res://fog/fog_density.png"))
	_base.material   = _base_mat

	_mask_mat        = ShaderMaterial.new()
	_mask_mat.shader = load("res://fog_mask.gdshader")
	_mask_mat.set_shader_parameter("edge_tex", load("res://fog/fog_edge_mask.png"))
	_mask.material   = _mask_mat

	_spawn_puffs()
	_sync_revealed()

## Создаёт puff-спрайты по слоям. Seed фиксирован — раскладка стабильна между запусками.
func _spawn_puffs() -> void:
	var textures: Array[Texture2D] = []
	for i in range(1, 7):
		var path := "res://fog/cloud_puff_%d.png" % i
		if ResourceLoader.exists(path):
			textures.append(load(path))
	if textures.is_empty():
		push_warning("FogOverlay: puff-текстуры не найдены в res://fog/")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260611
	var tex_i := 0
	for layer: Dictionary in PUFF_LAYERS:
		for c in range(layer["count"] as int):
			var spr := Sprite2D.new()
			spr.texture  = textures[tex_i % textures.size()]
			tex_i += 1
			spr.scale    = Vector2.ONE * (layer["scale"] as float)
			spr.rotation = rng.randf_range(-0.3, 0.3)
			# Тёмный холодный тон — туман войны, не белые облака
			spr.modulate = Color(0.29, 0.33, 0.49, layer["alpha"] as float)
			_clouds.add_child(spr)
			var anchor := Vector2(
				rng.randf_range(WORLD_MIN.x, WORLD_MAX.x),
				rng.randf_range(WORLD_MIN.y, WORLD_MAX.y))
			var dir := Vector2.from_angle(rng.randf_range(0.0, TAU)) * (layer["speed"] as float)
			_puffs.append({"spr": spr, "anchor": anchor, "dir": dir})

func _process(delta: float) -> void:
	# Дрейф в мировых координатах + wrap по зоне карты
	for p: Dictionary in _puffs:
		var anchor: Vector2 = p["anchor"] + (p["dir"] as Vector2) * delta
		if anchor.x < WORLD_MIN.x: anchor.x = WORLD_MAX.x
		elif anchor.x > WORLD_MAX.x: anchor.x = WORLD_MIN.x
		if anchor.y < WORLD_MIN.y: anchor.y = WORLD_MAX.y
		elif anchor.y > WORLD_MAX.y: anchor.y = WORLD_MIN.y
		p["anchor"] = anchor
		# Мир → экран SubViewport
		(p["spr"] as Sprite2D).position = (anchor - _cam_pos) * _cam_zoom + _vp_size * 0.5

## Открыть область вокруг мировой позиции pos
func reveal(pos: Vector2) -> void:
	for p in _revealed:
		if p.distance_to(pos) < 20.0:
			return
	_revealed.append(pos)
	_sync_revealed()

## Обновить камеру и time в шейдерах (вызывать каждый кадр из Main)
func update_camera(cam_pos: Vector2, zoom: float, vp_size: Vector2) -> void:
	_cam_pos  = cam_pos
	_cam_zoom = zoom
	_vp_size  = vp_size
	var t := Time.get_ticks_msec() * 0.001
	for m in [_base_mat, _mask_mat]:
		m.set_shader_parameter("cam_pos",  cam_pos)
		m.set_shader_parameter("cam_zoom", zoom)
		m.set_shader_parameter("vp_size",  vp_size)
		m.set_shader_parameter("time",     t)

## Позиция героя — движется с ним, не пишет в _revealed, не меняет счётчик.
func update_hero_pos(pos: Vector2) -> void:
	_mask_mat.set_shader_parameter("hero_pos", pos)

## Добавить точку пройденного пути. FIFO: при переполнении убираем самую старую.
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
	_mask_mat.set_shader_parameter("revealed_count", mini(_revealed.size(), MAX_LOCS))
	for i in MAX_LOCS:
		var p := _revealed[i] if i < _revealed.size() else Vector2(-99999, -99999)
		_mask_mat.set_shader_parameter("rp%d" % i, p)

func _sync_trail() -> void:
	_mask_mat.set_shader_parameter("trail_count", mini(_trail.size(), MAX_TRAIL))
	for i in MAX_TRAIL:
		var p := _trail[i] if i < _trail.size() else Vector2(-99999, -99999)
		_mask_mat.set_shader_parameter("tp%d" % i, p)
