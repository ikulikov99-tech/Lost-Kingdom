## Main.gd — глобальная карта Lost Kingdom

extends Node2D

# ──────────────── Узлы ───────────────────────────────────────────
@onready var hero: CharacterBody2D  = $Hero
@onready var camera: Camera2D       = $Hero/Camera2D
@onready var current_label: Label   = $UI/StatusPanel/CurrentLabel
@onready var unlocked_label: Label  = $UI/StatusPanel/UnlockedLabel
@onready var tooltip_label: Label   = $UI/TooltipLabel
@onready var fog_overlay: ColorRect = $UI/FogOverlay

# Path2D маршруты (HeroFollower не используется в runtime)
@onready var _cv_path: Path2D = $CastleVillagePath
@onready var _vd_path: Path2D = $VillageDockPath
@onready var _vr_path: Path2D = $VillageRuinsPath

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
var current_location: String    = "Castle"
# discovered: туман открыт, считается в счётчике "Открыто"
var discovered: Dictionary      = {}   # id -> bool
# available: доступны для клика (соседи текущей), но туман не открыт
var available: Dictionary       = {}   # id -> bool

# Trail: расстояние между точками пути (px). При hero_reveal_r=160 и edge=40
# перекрытие между соседними точками начинается с dist < 240. Шаг 110 даёт
# надёжный overlap без лишних точек (8 точек × 110px = 880px покрытия).
const TRAIL_STEP := 110.0
var _last_trail_pos: Vector2 = Vector2(-99999.0, -99999.0)

# ──────────────── Инициализация ──────────────────────────────────
func _ready() -> void:
	current_location = "Castle"
	GameState.current_location = "Castle"

	for id in WAYPOINTS.keys():
		discovered[id] = false
		available[id]  = false

	# Только Castle открыта туманом и считается в счётчике
	discovered["Castle"] = true

	# Соседи Castle доступны для клика, но не открыты
	for neighbor in ROUTES["Castle"]:
		available[neighbor] = true

	hero.global_position = _pos("Castle")
	if not hero.arrived.is_connected(_on_hero_arrived):
		hero.arrived.connect(_on_hero_arrived)

	# Туман: только Castle
	fog_overlay.reveal(_pos("Castle"))

	_push_camera_to_fog()
	_update_ui()
	_debug_state("_ready")
	queue_redraw()

# ──────────────── Вспомогательные ────────────────────────────────
func _pos(id: String)   -> Vector2: return WAYPOINTS[id]["pos"]
func _title(id: String) -> String:  return WAYPOINTS[id]["title"]

## Точная позиция центра экрана в мировых координатах.
## camera.get_screen_center_position() учитывает zoom и limits Camera2D.
func _screen_center_world() -> Vector2:
	return camera.get_screen_center_position()

func _push_camera_to_fog() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	fog_overlay.update_camera(_screen_center_world(), camera.zoom.x, vp_size)
	fog_overlay.update_hero_pos(hero.global_position)

# ──────────────── Ввод ───────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and \
	   event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if hero.is_moving:
			return
		var clicked := _find_accessible_waypoint(get_global_mouse_position())
		if clicked != "":
			_try_move_to(clicked)

func _physics_process(_delta: float) -> void:
	_push_camera_to_fog()
	# Пишем trail-точки во время движения
	if hero.is_moving:
		var hpos := hero.global_position
		if _last_trail_pos.distance_to(hpos) >= TRAIL_STEP:
			fog_overlay.add_trail_point(hpos)
			_last_trail_pos = hpos

func _process(_delta: float) -> void:
	# Резервное обновление тумана на случай кадров без physics_process
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
		# Тултип показываем для discovered и available локаций
		if not (discovered.get(id, false) as bool) and not (available.get(id, false) as bool):
			continue
		var d := mpos.distance_to(_pos(id))
		if d < best_d: best_d = d; best = id
	return best

func _is_accessible(id: String) -> bool:
	# Можно кликнуть если локация available (или discovered) и является соседом текущей
	if not (available.get(id, false) as bool) and not (discovered.get(id, false) as bool):
		return false
	if id == current_location:               return false
	if not ROUTES[current_location].has(id): return false
	return true

# ──────────────── Движение ───────────────────────────────────────
func _try_move_to(id: String) -> void:
	if not _is_accessible(id): return
	# Сбрасываем trail-трекинг — первая точка добавится после TRAIL_STEP от старта
	_last_trail_pos = hero.global_position
	on_route_event(current_location, id)

	# Маршруты через Path2D — Castle↔Village
	if (current_location == "Castle" and id == "Village") or \
	   (current_location == "Village" and id == "Castle"):
		hero.move_along_path(id, _sample_path(_cv_path, "Castle", "Village", current_location == "Castle"))
		return
	# Village↔Dock
	if (current_location == "Village" and id == "Dock") or \
	   (current_location == "Dock" and id == "Village"):
		hero.move_along_path(id, _sample_path(_vd_path, "Village", "Dock", current_location == "Village"))
		return
	# Village↔KnightRuins
	if (current_location == "Village" and id == "KnightRuins") or \
	   (current_location == "KnightRuins" and id == "Village"):
		hero.move_along_path(id, _sample_path(_vr_path, "Village", "KnightRuins", current_location == "Village"))
		return

	# Остальные маршруты — промежуточные точки
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

## Сэмплирует Path2D: первая и последняя точки — точные координаты вейпоинтов.
## forward=true: from_id→to_id, false: to_id→from_id
func _sample_path(path: Path2D, from_id: String, to_id: String, forward: bool) -> Array[Vector2]:
	var pts: Array[Vector2] = []
	var baked := path.curve.get_baked_points()  # PackedVector2Array
	if forward:
		pts.append(_pos(from_id))
		for i in range(1, baked.size() - 1):
			pts.append(baked[i])
		pts.append(_pos(to_id))
	else:
		pts.append(_pos(to_id))
		var i := baked.size() - 2
		while i > 0:
			pts.append(baked[i])
			i -= 1
		pts.append(_pos(from_id))
	return pts

func _exit_tree() -> void:
	if hero != null and hero.arrived.is_connected(_on_hero_arrived):
		hero.arrived.disconnect(_on_hero_arrived)

func on_route_event(_from: String, _to: String) -> void:
	pass   # stub

# ──────────────── Прибытие ───────────────────────────────────────
func _on_hero_arrived(location_name: String) -> void:
	current_location           = location_name
	GameState.current_location = location_name

	# Постоянный reveal локации — trail больше не нужен, зона покрыта
	discovered[location_name] = true
	fog_overlay.reveal(_pos(location_name))
	fog_overlay.clear_trail()
	_last_trail_pos = Vector2(-99999.0, -99999.0)

	# Соседи становятся available для клика, но NOT discovered
	for neighbor in ROUTES[location_name]:
		available[neighbor] = true

	GameState.unlocked_locations = _get_discovered_list()
	_update_ui()
	_debug_state("arrived: " + location_name)
	queue_redraw()

# ──────────────── UI ─────────────────────────────────────────────
func _get_discovered_list() -> Array[String]:
	var r: Array[String] = []
	for id in discovered.keys():
		if discovered[id]: r.append(id)
	return r

func _update_ui() -> void:
	current_label.text  = "Текущее: " + _title(current_location)
	unlocked_label.text = "Открыто: " + str(_get_discovered_list().size()) + \
						  " / " + str(WAYPOINTS.size())

func _debug_state(context: String) -> void:
	print("[DEBUG] === ", context, " ===")
	print("[DEBUG] current_location: ", current_location)
	print("[DEBUG] discovered: ", _get_discovered_list())
	var av: Array[String] = []
	for id in available.keys():
		if available[id]: av.append(id)
	print("[DEBUG] available: ", av)

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

			var both: bool = (discovered.get(a, false) or available.get(a, false)) and \
							 (discovered.get(b, false) or available.get(b, false))
			var col := Color(1.0, 0.85, 0.35, 0.8) if both else Color(0.4, 0.4, 0.4, 0.2)

			# Маршруты по Path2D
			var route_path: Path2D = null
			if (a == "Castle" and b == "Village") or (a == "Village" and b == "Castle"):
				route_path = _cv_path
			elif (a == "Dock" and b == "Village") or (a == "Village" and b == "Dock"):
				route_path = _vd_path
			elif (a == "KnightRuins" and b == "Village") or (a == "Village" and b == "KnightRuins"):
				route_path = _vr_path

			if route_path != null:
				if route_path.curve != null:
					var baked := route_path.curve.get_baked_points()
					for i in range(baked.size() - 1):
						draw_line(baked[i], baked[i + 1], col, 4.0)
				continue

			var pts := _build_waypoint_path(a, b)
			for i in range(pts.size() - 1):
				draw_line(pts[i], pts[i + 1], col, 4.0)

func _draw_waypoints() -> void:
	var t := Time.get_ticks_msec() * 0.003
	for id in WAYPOINTS.keys():
		var pos          := _pos(id)
		var is_disc: bool = discovered.get(id, false)
		var is_avail: bool = available.get(id, false)
		var is_cur: bool  = (id == current_location)
		var is_acc: bool  = _is_accessible(id)

		if not is_disc and not is_avail:
			draw_circle(pos, 8.0, Color(0.3, 0.3, 0.3, 0.3))
			continue

		var color: Color
		if is_cur:         color = Color(0.2, 0.55, 1.0, 1.0)   # синий — текущая
		elif is_acc:       color = Color(0.15, 0.9, 0.25, 1.0)  # зелёный — кликабельная
		elif is_disc:      color = Color(0.7, 0.65, 0.3, 0.75)  # жёлтый — посещённая
		else:              color = Color(0.5, 0.5, 0.5, 0.5)    # серый — available но не соседняя

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
