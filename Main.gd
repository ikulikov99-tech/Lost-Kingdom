## Main.gd — глобальная карта Lost Kingdom
##
## Отвечает за:
##  - отображение и клик по точкам карты
##  - движение героя по дорогам через промежуточные точки
##  - подсветку доступных локаций
##  - туман войны через FogOverlay
##  - синхронизацию с GameState

extends Node2D

# ──────────────── Ссылки на узлы ─────────────────────────────────
@onready var hero: CharacterBody2D         = $Hero
@onready var current_label: Label          = $UI/StatusPanel/CurrentLabel
@onready var unlocked_label: Label         = $UI/StatusPanel/UnlockedLabel
@onready var tooltip_label: Label          = $UI/TooltipLabel

const FogOverlayClass = preload("res://FogOverlay.gd")
var fog_overlay: Node2D   # создаётся в _ready()

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

# ──────────────── Пути по дорогам ────────────────────────────────
# Промежуточные точки между локациями (без старта и финиша).
# Порядок: от первого ID ко второму. Обратный маршрут применяет reverse().
# TODO: уточнить промежуточные точки по фактическим дорогам на карте.
# Для уточнения: кликни на дорогу в игре, запиши координаты в MAP_COORDINATES.md
# и добавь их сюда.
const ROAD_PATHS := {
	"Castle->Village":              [],
	"Village->Dock":                [],
	"Village->KnightRuins":         [],
	"Village->Lumbermill":          [],
	"KnightRuins->MageTower":       [],
	"KnightRuins->EarthMageCastle": [],
	"EarthMageCastle->DarkCastle":  [],
	"EarthMageCastle->Mine":        [],
	"Lumbermill->Mine":             [],
}

# ──────────────── Состояние игры ─────────────────────────────────
var current_location: String = "Castle"
var unlocked: Dictionary = {}   # id -> bool

# ──────────────── Инициализация ──────────────────────────────────
func _ready() -> void:
	# Создаём туман войны программно (между WorldMap и Hero)
	fog_overlay = FogOverlayClass.new()
	add_child(fog_overlay)
	move_child(fog_overlay, 1)   # WorldMap=0, FogOverlay=1, Hero=2

	# Инициализируем состояние
	current_location = GameState.current_location
	for id in WAYPOINTS.keys():
		unlocked[id] = false
	unlocked["Castle"] = true
	unlocked["Village"] = true

	# Позиция героя
	hero.global_position = _pos(current_location)
	hero.arrived.connect(_on_hero_arrived)

	# Открываем туман у стартовых локаций
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
	# Обновляем подсказку при наведении мыши
	var mouse_pos := get_global_mouse_position()
	var hovered := _find_any_waypoint(mouse_pos, 60.0)
	if hovered != "":
		tooltip_label.text = _title(hovered)
		tooltip_label.visible = true
		# Позиционируем тултип у курсора
		var screen_pos := get_viewport().get_mouse_position()
		tooltip_label.position = screen_pos + Vector2(12, -28)
	else:
		tooltip_label.visible = false

	# Пульсация доступных точек — требует перерисовки каждый кадр
	if not hero.is_moving:
		queue_redraw()

# ──────────────── Поиск точки по клику ───────────────────────────
## Возвращает ID доступной для перехода точки в радиусе radius
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

## Возвращает ID любой открытой точки (для тултипа)
func _find_any_waypoint(mouse_pos: Vector2, radius: float) -> String:
	var best := ""
	var best_dist := radius
	for id in WAYPOINTS.keys():
		if not unlocked.get(id, false):
			continue
		var d := mouse_pos.distance_to(_pos(id))
		if d < best_dist:
			best_dist = d
			best = id
	return best

func _is_accessible(id: String) -> bool:
	if not unlocked.get(id, false):
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

	# Заглушка для событий на пути — реализовать в следующем PR
	on_route_event(current_location, id)

	var path := _build_path(current_location, id)
	hero.move_along_path(id, path)

## Строим полный путь: старт + промежуточные точки + финиш
func _build_path(from_id: String, to_id: String) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	pts.append(_pos(from_id))

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

# ──────────────── Событие на пути (заглушка) ─────────────────────
## TODO (следующий PR): случайное событие при переходе (бой, головоломка, предметы).
## Сейчас всегда пропускается (chance = 0).
func on_route_event(_from: String, _to: String) -> void:
	pass

# ──────────────── Прибытие ───────────────────────────────────────
func _on_hero_arrived(location_name: String) -> void:
	current_location = location_name
	GameState.current_location = location_name

	# Открываем соседние локации
	for neighbor in ROUTES[location_name]:
		if not unlocked.get(neighbor, false):
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
		var open := unlocked.get(id, false)
		var is_current    := id == current_location
		var is_accessible := _is_accessible(id)

		if not open:
			# Закрытая: маленький тусклый кружок (виден сквозь туман)
			draw_circle(pos, 8.0, Color(0.3, 0.3, 0.3, 0.3))
			continue

		# ── Основной кружок ──────────────────────────────────────
		var color: Color
		if is_current:
			color = Color(0.2, 0.55, 1.0, 1.0)       # синий — здесь
		elif is_accessible:
			color = Color(0.15, 0.9, 0.25, 1.0)       # зелёный — можно идти
		else:
			color = Color(0.7, 0.65, 0.3, 0.75)       # жёлтый — открыта, но не соединена

		draw_circle(pos, 20.0, color)
		draw_arc(pos, 26.0, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 2.5)

		# ── Пульсирующая подсветка доступных ────────────────────
		if is_accessible and not hero.is_moving:
			var pulse := 0.5 + 0.5 * sin(t + pos.x * 0.01)
			draw_arc(pos, 32.0 + pulse * 6.0, 0.0, TAU, 40,
					 Color(0.3, 1.0, 0.4, 0.55 * pulse), 2.0)

		# ── Название ─────────────────────────────────────────────
		draw_string(ThemeDB.fallback_font,
			pos + Vector2(-40, 40),
			_title(id),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(1.0, 1.0, 0.75, 0.95))
