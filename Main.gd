## Main.gd — глобальная карта Lost Kingdom
##
## Отвечает за:
##  - отображение и клик по точкам карты
##  - движение героя по дорогам (через Path2D или промежуточные точки)
##  - подсветку доступных локаций
##  - туман войны через FogOverlay (ColorRect в UI CanvasLayer)
##  - синхронизацию с GameState

extends Node2D

# ──────────────── Ссылки на узлы ─────────────────────────────────
@onready var hero: CharacterBody2D  = $Hero
@onready var camera: Camera2D       = $Hero/Camera2D
@onready var current_label: Label   = $UI/StatusPanel/CurrentLabel
@onready var unlocked_label: Label  = $UI/StatusPanel/UnlockedLabel
@onready var tooltip_label: Label   = $UI/TooltipLabel
@onready var fog_overlay: ColorRect = $UI/FogOverlay

# Path2D для конкретных дорог (заполняются в _ready через get_node)
var _path2d_castle_village: Path2D

# ──────────────── Координаты (только из MAP_COORDINATES.md) ──────
const WAYPOINTS := {
	"Castle":          {"title": "Королевский замок",  "pos": Vector2(-1112, -704)},
	"Village":         {"title": "Деревня",             "pos": Vector2(-928,  -504)},
	"Dock":            {"title": "Пристань",            "pos": Vector2(-1160, -128)},
	"KnightRuins":     {"title": "Руины рыцарей",       "pos": Vector2(-648,  -288)},
	"MageTower":       {"title": "Башня мага",          "pos": Vector2(-560,  -320)},
	"EarthMageCastle": {"title": "Замок мага земли",    "pos": Vector2(-464,  -488)},
	"DarkCastle":      {"title": "Замок тьмы",          "pos": Vector2(-376,  -568)},
	"Lumbermill":      {"title": "Лесопилка",           "pos": Vector2(-640,  -752)},
	"Mine":            {"title": "Заброшенная шахта",   "pos": Vector2(-392,  -832)},
}

# ──────────────── Связи между локациями ──────────────────────────
const ROUTES := {
	"Castle":          ["Village"],
	"Village":         ["Castle", "Dock", "KnightRuins", "Lumbermill"],
	"Dock":            ["Village"],
	"KnightRuins":     ["Village", "MageTower", "EarthMageCastle"],
	"MageTower":       ["KnightRuins"],
	"EarthMageCastle": ["KnightRuins", "DarkCastle", "Mine"],
	"DarkCastle":      ["EarthMageCastle"],
	"Lumbermill":      ["Village", "Mine"],
	"Mine":            ["Lumbermill", "EarthMageCastle"],
}

# ──────────────── Прямые промежуточные точки (для маршрутов без Path2D) ──
const ROAD_PATHS := {
	"Village->Dock": [
		Vector2(-1008, -400),
		Vector2(-1080, -280),
		Vector2(-1160, -192),
	],
	"Village->KnightRuins": [
		Vector2(-840,  -416),
		Vector2(-744,  -352),
	],
	"Village->Lumbermill": [
		Vector2(-832,  -608),
		Vector2(-736,  -688),
	],
	"KnightRuins->MageTower": [
		Vector2(-604,  -304),
	],
	"KnightRuins->EarthMageCastle": [
		Vector2(-576,  -376),
		Vector2(-512,  -440),
	],
	"EarthMageCastle->DarkCastle": [
		Vector2(-420,  -528),
	],
	"EarthMageCastle->Mine": [
		Vector2(-440,  -640),
		Vector2(-408,  -736),
	],
	"Lumbermill->Mine": [
		Vector2(-520,  -792),
	],
}

# Количество точек при сэмплировании Path2D (больше = плавнее кривая)
const PATH2D_SAMPLES := 20

# ──────────────── Состояние игры ─────────────────────────────────
var current_location: String = "Castle"
var unlocked: Dictionary = {}   # id -> bool

# ──────────────── Инициализация ──────────────────────────────────
func _ready() -> void:
	# Получаем Path2D-узлы и заполняем кривые программно
	_path2d_castle_village = get_node_or_null("CastleVillagePath")
	if _path2d_castle_village != null:
		var cv := Curve2D.new()
		cv.add_point(Vector2(-1112, -704))   # Castle
		cv.add_point(Vector2(-1060, -640))
		cv.add_point(Vector2(-984,  -576))
		cv.add_point(Vector2(-928,  -504))   # Village
		_path2d_castle_village.curve = cv

	# ── Жёсткий сброс состояния ──────────────────────────────────
	current_location = "Castle"
	GameState.current_location = "Castle"
	GameState.unlocked_locations = ["Castle", "Village"]

	for id in WAYPOINTS.keys():
		unlocked[id] = false
	unlocked["Castle"]  = true
	unlocked["Village"] = true

	# ── Позиция героя ─────────────────────────────────────────────
	hero.global_position = _pos("Castle")
	hero.arrived.connect(_on_hero_arrived)

	# ── Туман: открываем замок и деревню ─────────────────────────
	fog_overlay.reveal(_pos("Castle"))
	fog_overlay.reveal(_pos("Village"))

	_update_ui()
	queue_redraw()

func _pos(id: String) -> Vector2:
	return WAYPOINTS[id]["pos"]

func _title(id: String) -> String:
	return WAYPOINTS[id]["title"]

# ──────────────── Ввод: клик и наведение ─────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
	   event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if hero.is_moving:
			return
		var mouse_pos := get_global_mouse_position()
		var clicked := _find_accessible_waypoint(mouse_pos)
		if clicked != "":
			_try_move_to(clicked)

func _process(_delta: float) -> void:
	# ── Обновляем туман: передаём актуальную позицию камеры ──────
	var cam_pos := camera.get_screen_center_position()
	fog_overlay.update_camera(
		cam_pos,
		camera.zoom.x,
		get_viewport().get_visible_rect().size
	)

	# ── Тултип при наведении ──────────────────────────────────────
	var mouse_pos := get_global_mouse_position()
	var hovered := _find_any_waypoint(mouse_pos, 60.0)
	if hovered != "":
		tooltip_label.text = _title(hovered)
		tooltip_label.visible = true
		var screen_pos := get_viewport().get_mouse_position()
		tooltip_label.position = screen_pos + Vector2(12, -28)
	else:
		tooltip_label.visible = false

	# ── Пульсация требует перерисовки каждый кадр ────────────────
	if not hero.is_moving:
		queue_redraw()

# ──────────────── Поиск точки по клику ───────────────────────────
func _find_accessible_waypoint(mouse_pos: Vector2, radius: float = 70.0) -> String:
	var best := ""
	var best_dist := radius
	for id in WAYPOINTS.keys():
		if not _is_accessible(id):
			continue
		var d := mouse_pos.distance_to(_pos(id))
		if d < best_dist:
			best_dist = d
			best = id
	return best

func _find_any_waypoint(mouse_pos: Vector2, radius: float) -> String:
	var best := ""
	var best_dist := radius
	for id in WAYPOINTS.keys():
		if not (unlocked.get(id, false) as bool):
			continue
		var d := mouse_pos.distance_to(_pos(id))
		if d < best_dist:
			best_dist = d
			best = id
	return best

func _is_accessible(id: String) -> bool:
	if not (unlocked.get(id, false) as bool):
		return false
	if id == current_location:
		return false
	if not ROUTES[current_location].has(id):
		return false
	return true

# ──────────────── Движение к локации ─────────────────────────────
func _try_move_to(id: String) -> void:
	if not _is_accessible(id):
		return
	on_route_event(current_location, id)
	var path := _build_path(current_location, id)
	hero.move_along_path(id, path)

## Строим полный путь: старт + кривая (Path2D или точки) + финиш
func _build_path(from_id: String, to_id: String) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	pts.append(_pos(from_id))

	# ── Маршруты с Path2D ────────────────────────────────────────
	var path2d := _get_path2d(from_id, to_id)
	if path2d != null:
		var curve := path2d.curve
		var length := curve.get_baked_length()
		# Сэмплируем кривую равномерно
		for i in range(1, PATH2D_SAMPLES):
			var t := float(i) / float(PATH2D_SAMPLES)
			pts.append(curve.sample_baked(t * length))
	else:
		# ── Промежуточные точки из ROAD_PATHS ────────────────────
		var key_fwd := from_id + "->" + to_id
		var key_rev := to_id + "->" + from_id
		if ROAD_PATHS.has(key_fwd):
			for p: Vector2 in ROAD_PATHS[key_fwd]:
				pts.append(p)
		elif ROAD_PATHS.has(key_rev):
			var rev: Array = ROAD_PATHS[key_rev].duplicate()
			rev.reverse()
			for p: Vector2 in rev:
				pts.append(p)

	pts.append(_pos(to_id))
	return pts

## Возвращает Path2D для маршрута или null если не задан
func _get_path2d(from_id: String, to_id: String) -> Path2D:
	if (from_id == "Castle" and to_id == "Village") or \
	   (from_id == "Village" and to_id == "Castle"):
		return _path2d_castle_village
	return null

# ──────────────── Событие на пути (заглушка) ─────────────────────
func on_route_event(_from: String, _to: String) -> void:
	pass

# ──────────────── Прибытие ───────────────────────────────────────
func _on_hero_arrived(location_name: String) -> void:
	current_location = location_name
	GameState.current_location = location_name

	for neighbor in ROUTES[location_name]:
		if not (unlocked.get(neighbor, false) as bool):
			unlocked[neighbor] = true
			fog_overlay.reveal(_pos(neighbor))

	GameState.unlocked_locations = _get_unlocked_list()
	_update_ui()
	queue_redraw()

# ──────────────── UI ─────────────────────────────────────────────
func _get_unlocked_list() -> Array[String]:
	var result: Array[String] = []
	for id in unlocked.keys():
		if unlocked[id]:
			result.append(id)
	return result

func _update_ui() -> void:
	current_label.text  = "Текущее: " + _title(current_location)
	unlocked_label.text = "Открыто: " + str(_get_unlocked_list().size()) + \
						  " / " + str(WAYPOINTS.size())

# ──────────────── Отрисовка ──────────────────────────────────────
func _draw() -> void:
	_draw_roads()
	_draw_waypoints()

func _draw_roads() -> void:
	var drawn: Dictionary = {}
	for a in ROUTES.keys():
		for b: String in ROUTES[a]:
			var sorted_key: Array = [a, b]
			sorted_key.sort()
			var rk: String = str(sorted_key[0]) + "-" + str(sorted_key[1])
			if drawn.has(rk):
				continue
			drawn[rk] = true

			var path_pts := _build_path(a, b)
			var both_unlocked: bool = unlocked.get(a, false) and unlocked.get(b, false)
			var col := Color(1.0, 0.85, 0.35, 0.8) if both_unlocked \
					   else Color(0.4, 0.4, 0.4, 0.2)
			for i in range(path_pts.size() - 1):
				draw_line(path_pts[i], path_pts[i + 1], col, 4.0)

func _draw_waypoints() -> void:
	var t := Time.get_ticks_msec() * 0.003
	for id in WAYPOINTS.keys():
		var pos  := _pos(id)
		var open: bool = unlocked.get(id, false)
		var is_current: bool    = (id == current_location)
		var is_accessible: bool = _is_accessible(id)

		if not open:
			draw_circle(pos, 8.0, Color(0.3, 0.3, 0.3, 0.3))
			continue

		var color: Color
		if is_current:
			color = Color(0.2, 0.55, 1.0, 1.0)
		elif is_accessible:
			color = Color(0.15, 0.9, 0.25, 1.0)
		else:
			color = Color(0.7, 0.65, 0.3, 0.75)

		draw_circle(pos, 20.0, color)
		draw_arc(pos, 26.0, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 2.5)

		if is_accessible and not hero.is_moving:
			var pulse := 0.5 + 0.5 * sin(t + pos.x * 0.01)
			draw_arc(pos, 32.0 + pulse * 6.0, 0.0, TAU, 40,
					 Color(0.3, 1.0, 0.4, 0.55 * pulse), 2.0)

		draw_string(ThemeDB.fallback_font,
			pos + Vector2(-40, 40),
			_title(id),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(1.0, 1.0, 0.75, 0.95))
