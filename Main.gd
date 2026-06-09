## Main.gd — глобальная карта Lost Kingdom

extends Node2D

# ──────────────── Узлы ───────────────────────────────────────────
@onready var hero: CharacterBody2D  = $Hero
@onready var camera: Camera2D       = $Hero/Camera2D
@onready var current_label: Label   = $UI/StatusPanel/CurrentLabel
@onready var unlocked_label: Label  = $UI/StatusPanel/UnlockedLabel
@onready var tooltip_label: Label   = $UI/TooltipLabel
@onready var fog_overlay: ColorRect = $UI/FogOverlay

# Path2D для Castle<->Village
@onready var _cv_path: Path2D       = $CastleVillagePath
@onready var _cv_follow: PathFollow2D = $CastleVillagePath/HeroFollower

# ──────────────── Координаты ─────────────────────────────────────
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

# Промежуточные точки для маршрутов без Path2D
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

# ──────────────── Состояние ──────────────────────────────────────
var current_location: String = "Castle"
var unlocked: Dictionary     = {}   # id -> bool

# ──────────────── Инициализация ──────────────────────────────────
func _ready() -> void:
	# Строим кривую Castle<->Village программно с Безье-касательными.
	# Дорога идёт на юго-восток, огибая замок и реку.
	# Касательные задают плавный изгиб — не прямую линию.
	var cv := Curve2D.new()
	cv.add_point(
		Vector2(-1112, -704),                   # Castle
		Vector2(0, 0),                          # in (не используется у первой точки)
		Vector2(80, 40)                         # out → кривая уходит на восток-юг
	)
	cv.add_point(
		Vector2(-1020, -580),                   # промежуток: поворот у реки
		Vector2(-80, -40),
		Vector2(80, 40)
	)
	cv.add_point(
		Vector2(-928, -504),                    # Village
		Vector2(-80, -40),                      # in → приходим с запада-севера
		Vector2(0, 0)
	)
	_cv_path.curve = cv

	# Сброс состояния
	current_location = "Castle"
	GameState.current_location  = "Castle"
	GameState.unlocked_locations = ["Castle", "Village"]

	for id in WAYPOINTS.keys():
		unlocked[id] = false
	unlocked["Castle"]  = true
	unlocked["Village"] = true

	hero.global_position = _pos("Castle")
	hero.arrived.connect(_on_hero_arrived)

	# Туман: открыть только Castle и Village
	fog_overlay.reveal(_pos("Castle"))
	fog_overlay.reveal(_pos("Village"))

	# Первое обновление тумана с корректной позицией камеры
	_push_camera_to_fog()

	_update_ui()
	queue_redraw()

# ──────────────── Вспомогательные ────────────────────────────────
func _pos(id: String)   -> Vector2: return WAYPOINTS[id]["pos"]
func _title(id: String) -> String:  return WAYPOINTS[id]["title"]

## Точная позиция центра экрана в мировых координатах.
## Использует обратное преобразование холста — корректно учитывает лимиты камеры.
func _screen_center_world() -> Vector2:
	var vp_size := get_viewport().get_visible_rect().size
	var ct      := get_viewport().get_canvas_transform()
	return ct.affine_inverse().xform(vp_size * 0.5)

func _push_camera_to_fog() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	fog_overlay.update_camera(_screen_center_world(), camera.zoom.x, vp_size)

# ──────────────── Ввод ───────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
	   event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if hero.is_moving:
			return
		var clicked := _find_accessible_waypoint(get_global_mouse_position())
		if clicked != "":
			_try_move_to(clicked)

func _process(_delta: float) -> void:
	# Обновляем позицию камеры в шейдере каждый кадр
	_push_camera_to_fog()

	# Тултип
	var hovered := _find_any_waypoint(get_global_mouse_position(), 60.0)
	if hovered != "":
		tooltip_label.text    = _title(hovered)
		tooltip_label.visible = true
		tooltip_label.position = get_viewport().get_mouse_position() + Vector2(12, -28)
	else:
		tooltip_label.visible = false

	if not hero.is_moving:
		queue_redraw()

# ──────────────── Поиск точки ────────────────────────────────────
func _find_accessible_waypoint(mpos: Vector2, radius: float = 70.0) -> String:
	var best := ""; var best_d := radius
	for id in WAYPOINTS.keys():
		if not _is_accessible(id): continue
		var d := mpos.distance_to(_pos(id))
		if d < best_d: best_d = d; best = id
	return best

func _find_any_waypoint(mpos: Vector2, radius: float) -> String:
	var best := ""; var best_d := radius
	for id in WAYPOINTS.keys():
		if not (unlocked.get(id, false) as bool): continue
		var d := mpos.distance_to(_pos(id))
		if d < best_d: best_d = d; best = id
	return best

func _is_accessible(id: String) -> bool:
	if not (unlocked.get(id, false) as bool): return false
	if id == current_location:                return false
	if not ROUTES[current_location].has(id):  return false
	return true

# ──────────────── Движение ───────────────────────────────────────
func _try_move_to(id: String) -> void:
	if not _is_accessible(id): return
	on_route_event(current_location, id)

	# Castle <-> Village — движение по Path2D
	if (current_location == "Castle" and id == "Village") or \
	   (current_location == "Village" and id == "Castle"):
		var forward := (current_location == "Castle")
		hero.follow_path2d(id, _cv_follow,
						   _cv_path.curve.get_baked_length(), forward)
		return

	# Остальные маршруты — массив точек
	hero.move_along_path(id, _build_waypoint_path(current_location, id))

## Путь через промежуточные точки (не Path2D маршруты)
func _build_waypoint_path(from_id: String, to_id: String) -> Array[Vector2]:
	var pts: Array[Vector2] = [_pos(from_id)]
	var key_fwd := from_id + "->" + to_id
	var key_rev := to_id + "->" + from_id
	if ROAD_PATHS.has(key_fwd):
		for p: Vector2 in ROAD_PATHS[key_fwd]: pts.append(p)
	elif ROAD_PATHS.has(key_rev):
		var rev: Array = ROAD_PATHS[key_rev].duplicate()
		rev.reverse()
		for p: Vector2 in rev: pts.append(p)
	pts.append(_pos(to_id))
	return pts

func on_route_event(_from: String, _to: String) -> void:
	pass   # stub

# ──────────────── Прибытие ───────────────────────────────────────
func _on_hero_arrived(location_name: String) -> void:
	current_location            = location_name
	GameState.current_location  = location_name

	# Открываем соседей — reveal вызывается ТОЛЬКО здесь, не в _process
	for neighbor in ROUTES[location_name]:
		if not (unlocked.get(neighbor, false) as bool):
			unlocked[neighbor] = true
			fog_overlay.reveal(_pos(neighbor))

	GameState.unlocked_locations = _get_unlocked_list()
	_update_ui()
	queue_redraw()

# ──────────────── UI ─────────────────────────────────────────────
func _get_unlocked_list() -> Array[String]:
	var r: Array[String] = []
	for id in unlocked.keys():
		if unlocked[id]: r.append(id)
	return r

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
			var sk: Array = [a, b]; sk.sort()
			var rk: String = str(sk[0]) + "-" + str(sk[1])
			if drawn.has(rk): continue
			drawn[rk] = true

			var both: bool = unlocked.get(a, false) and unlocked.get(b, false)
			var col := Color(1.0, 0.85, 0.35, 0.8) if both else Color(0.4, 0.4, 0.4, 0.2)

			# Castle<->Village — рисуем по кривой Path2D
			if (a == "Castle" and b == "Village") or (a == "Village" and b == "Castle"):
				if _cv_path != null and _cv_path.curve != null:
					var baked := _cv_path.curve.get_baked_points()
					for i in range(baked.size() - 1):
						draw_line(baked[i], baked[i + 1], col, 4.0)
				continue

			var pts := _build_waypoint_path(a, b)
			for i in range(pts.size() - 1):
				draw_line(pts[i], pts[i + 1], col, 4.0)

func _draw_waypoints() -> void:
	var t := Time.get_ticks_msec() * 0.003
	for id in WAYPOINTS.keys():
		var pos         := _pos(id)
		var open: bool   = unlocked.get(id, false)
		var is_cur: bool = (id == current_location)
		var is_acc: bool = _is_accessible(id)

		if not open:
			draw_circle(pos, 8.0, Color(0.3, 0.3, 0.3, 0.3))
			continue

		var color: Color
		if is_cur:    color = Color(0.2, 0.55, 1.0, 1.0)
		elif is_acc:  color = Color(0.15, 0.9, 0.25, 1.0)
		else:         color = Color(0.7, 0.65, 0.3, 0.75)

		draw_circle(pos, 20.0, color)
		draw_arc(pos, 26.0, 0.0, TAU, 40, Color(1, 1, 1, 0.85), 2.5)

		if is_acc and not hero.is_moving:
			var pulse := 0.5 + 0.5 * sin(t + pos.x * 0.01)
			draw_arc(pos, 32.0 + pulse * 6.0, 0.0, TAU, 40,
					 Color(0.3, 1.0, 0.4, 0.55 * pulse), 2.0)

		draw_string(ThemeDB.fallback_font,
			pos + Vector2(-40, 40), _title(id),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
			Color(1.0, 1.0, 0.75, 0.95))
