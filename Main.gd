## Main.gd — глобальная карта Lost Kingdom

extends Node2D

# ──────────────── Узлы ───────────────────────────────────────────
@onready var hero: CharacterBody2D  = $Hero
@onready var camera: Camera2D       = $Hero/Camera2D
@onready var current_label: Label   = $UI/StatusPanel/CurrentLabel
@onready var unlocked_label: Label  = $UI/StatusPanel/UnlockedLabel
@onready var tooltip_label: Label   = $UI/TooltipLabel
@onready var fog_overlay: Control = $UI/FogOverlay

# Path2D маршруты (HeroFollower не используется в runtime)
@onready var _cv_path: Path2D = $CastleVillagePath
@onready var _vd_path: Path2D = $VillageDockPath
@onready var _vl_path: Path2D = $VillageLumbermillPath
@onready var _km_path: Path2D = $KnightRuinsMageTowerPath
@onready var _ke_path: Path2D = $KnightRuinsEarthMagePath
@onready var _dk_path: Path2D = $DockKnightRuinsPath
# VillageRuinsPath оставлен в сцене как неиспользуемый узел (ручные точки
# сохранены), но отключён от логики: маршрут к Руинам теперь Dock->KnightRuins.

# ──────────────── Координаты ─────────────────────────────────────
const WAYPOINTS := {
	"Castle":          {"title": "Королевский замок",  "pos": Vector2(-1112, -704)},
	"Village":         {"title": "Деревня",             "pos": Vector2(-928,  -504)},
	"Dock":            {"title": "Пристань",            "pos": Vector2(-1160, -128)},
	"KnightRuins":     {"title": "Руины рыцарей",       "pos": Vector2(-816,  -296)},
	"MageTower":       {"title": "Башня мага",          "pos": Vector2(-560,  -320)},
	"EarthMageCastle": {"title": "Замок мага земли",    "pos": Vector2(-464,  -488)},
	"DarkCastle":      {"title": "Замок тьмы",          "pos": Vector2(-376,  -568)},
	"Lumbermill":      {"title": "Лесопилка",           "pos": Vector2(-640,  -752)},
	"Mine":            {"title": "Заброшенная шахта",   "pos": Vector2(-392,  -832)},
}

# Центр раскрытия тумана для локаций, у которых waypoint стоит на ВХОДЕ с
# дороги, а не в центре картинки. Герой приходит к waypoint (точка движения
# не двигается), но туман раскрывается вокруг reveal-центра — вся локация и
# табличка выходят из тумана. Для остальных локаций reveal = waypoint.
const REVEAL_CENTERS := {
	"KnightRuins": Vector2(-648, -288),   # тело руин правее входа (-816,-296)
	"Dock":        Vector2(-1112, -160),  # причал выше-правее угла (-1160,-128)
}

const ROUTES := {
	"Castle":          ["Village"],
	"Village":         ["Castle", "Dock", "Lumbermill"],
	"Dock":            ["Village", "KnightRuins"],
	"KnightRuins":     ["Dock", "MageTower", "EarthMageCastle"],
	"MageTower":       ["KnightRuins"],
	"EarthMageCastle": ["KnightRuins", "DarkCastle", "Mine"],
	"DarkCastle":      ["EarthMageCastle"],
	"Lumbermill":      ["Village", "Mine"],
	"Mine":            ["Lumbermill", "EarthMageCastle"],
}

# Промежуточные точки для маршрутов без Path2D
const ROAD_PATHS := {
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

# ── Исследование дорог через Path2D (Итерация 1) ─────────────────
# Расстояние от клика до кривой чтобы засчитать попадание.
# Дорога на карте шире линии Path2D — радиус щедрый
const ROAD_CLICK_DIST  := 50.0
# Радиусы видимости = радиус шейдера + амплитуда шума краёв (edge_amp).
# Логика принимает клик везде, где туман МОЖЕТ быть визуально открыт,
# иначе клики в открытые «языки» тумана мёртвые (рассинхрон с маской).
# Локации: reveal_r 135 + edge_amp 75
const ROAD_VISIBLE_R   := 210.0
# Герой: hero_reveal_r 80 + edge_amp_hero 30
const HERO_VISIBLE_R   := 110.0
# Расстояние до вейпоинта чтобы засчитать прибытие
const ARRIVAL_RADIUS   := 60.0

# Состояние «герой остановился посреди дороги, не в локации».
# Обобщает прежний _cv_offset на любую Path2D-дорогу.
var _road_active: bool   = false   # true = герой стоит на дороге, не в локации
var _road_path:   Path2D = null    # активная Path2D
var _road_dest:   String = ""      # пункт назначения текущего шага (sosed или назад)
var _road_offset: float  = 0.0     # смещение героя вдоль кривой на последней остановке

# ──────────────── Инициализация ──────────────────────────────────
func _ready() -> void:
	# Кривая Castle<->Village загружается из Main.tscn (Curve2D_castle_village).
	# Для редактирования: выдели CastleVillagePath в сцене и двигай точки мышью.

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
	fog_overlay.reveal(_reveal_pos("Castle"))

	_push_camera_to_fog()
	_update_ui()
	_debug_state("_ready")
	queue_redraw()

# ──────────────── Вспомогательные ────────────────────────────────
func _pos(id: String)   -> Vector2: return WAYPOINTS[id]["pos"]
func _title(id: String) -> String:  return WAYPOINTS[id]["title"]
## Центр раскрытия тумана локации: reveal-центр если задан, иначе waypoint.
func _reveal_pos(id: String) -> Vector2: return REVEAL_CENTERS.get(id, _pos(id))

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
		var world_pos := get_global_mouse_position()

		# Новая механика: клик по видимому участку любой Path2D-дороги
		if _try_road_click(world_pos):
			return

		# Посреди дороги работают только клики по самой дороге —
		# иначе _try_move_to построит путь от исходной локации (телепорт назад)
		if _road_active:
			return

		# Fallback: клик по иконке локации (ROAD_PATHS-маршруты, обратный путь)
		var clicked := _find_accessible_waypoint(world_pos)
		if clicked == "":
			return
		# Неоткрытая локация с Path2D-дорогой достижима только исследованием
		# дороги — слепой клик по иконке сквозь туман не пускаем
		if not (discovered.get(clicked, false) as bool) \
				and _route_path_for(current_location, clicked) != null \
				and not _is_road_point_visible(_pos(clicked)):
			return
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
	# Dock↔KnightRuins (новый маршрут к Руинам через Пристань)
	if (current_location == "Dock" and id == "KnightRuins") or \
	   (current_location == "KnightRuins" and id == "Dock"):
		hero.move_along_path(id, _sample_path(_dk_path, "Dock", "KnightRuins", current_location == "Dock"))
		return
	# Village↔Lumbermill
	if (current_location == "Village" and id == "Lumbermill") or \
	   (current_location == "Lumbermill" and id == "Village"):
		hero.move_along_path(id, _sample_path(_vl_path, "Village", "Lumbermill", current_location == "Village"))
		return
	# KnightRuins↔MageTower
	if (current_location == "KnightRuins" and id == "MageTower") or \
	   (current_location == "MageTower" and id == "KnightRuins"):
		hero.move_along_path(id, _sample_path(_km_path, "KnightRuins", "MageTower", current_location == "KnightRuins"))
		return
	# KnightRuins↔EarthMageCastle
	if (current_location == "KnightRuins" and id == "EarthMageCastle") or \
	   (current_location == "EarthMageCastle" and id == "KnightRuins"):
		hero.move_along_path(id, _sample_path(_ke_path, "KnightRuins", "EarthMageCastle", current_location == "KnightRuins"))
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
	# baked-точки в локальном пространстве узла → переводим в global
	var baked := path.curve.get_baked_points()  # PackedVector2Array
	if forward:
		pts.append(_pos(from_id))
		for i in range(1, baked.size() - 1):
			pts.append(path.to_global(baked[i]))
		pts.append(_pos(to_id))
	else:
		pts.append(_pos(to_id))
		var i := baked.size() - 2
		while i > 0:
			pts.append(path.to_global(baked[i]))
			i -= 1
		pts.append(_pos(from_id))
	return pts

# ──────────────── Механика исследования дорог ────────────────────
## Path2D для пары локаций (или null, если маршрут не на Path2D).
func _route_path_for(a: String, b: String) -> Path2D:
	var s: Array = [a, b]
	s.sort()
	var key: String = str(s[0]) + "-" + str(s[1])
	var by_key := {
		"Castle-Village":              _cv_path,
		"Dock-Village":                _vd_path,
		"Dock-KnightRuins":            _dk_path,
		"Lumbermill-Village":          _vl_path,
		"KnightRuins-MageTower":       _km_path,
		"EarthMageCastle-KnightRuins": _ke_path,
	}
	return by_key.get(key, null)

## Клик по видимому участку дороги. Возвращает true если движение запущено.
## Каждый клик оценивает ВСЕ дороги текущей локации от фактической позиции
## героя — игрок не заперт на текущем Path2D и может развернуться/сменить ветку
## через общий узел (развилку). current_location — это узел-развилка: пока
## герой на дороге, current_location остаётся последней посещённой локацией,
## а её ROUTES дают все ветки развилки.
func _try_road_click(world_pos: Vector2) -> bool:
	var candidates: Array = []   # [{d, path, nbr}]
	for n: String in ROUTES[current_location]:
		var p := _route_path_for(current_location, n)
		if p == null:
			continue
		# Сосед должен быть кликабелен (available/discovered), скрытые — нельзя
		if not (available.get(n, false) as bool) and not (discovered.get(n, false) as bool):
			continue
		# curve в локальном пространстве узла — клик переводим в local
		var lp := p.to_local(world_pos)
		var cp := p.curve.get_closest_point(lp)
		var d := lp.distance_to(cp)
		if d < ROAD_CLICK_DIST:
			candidates.append({"d": d, "path": p, "nbr": n})
	candidates.sort_custom(func(a, b): return (a["d"] as float) < (b["d"] as float))

	for c: Dictionary in candidates:
		if _start_road_move(c["path"], c["nbr"], world_pos):
			return true
	return false

## Движение по дороге к точке клика. Направление и пункт назначения берутся
## из фактической позиции героя: к соседу nbr или назад к current_location —
## смотря в какую сторону клик. Реверс и смена ветки больше не блокируются.
func _start_road_move(path: Path2D, nbr: String, world_pos: Vector2) -> bool:
	var curve := path.curve
	# Все запросы к curve — в локальном пространстве узла (path.position может
	# быть ≠ 0). Точки наружу (видимость, движение) возвращаем в global.
	var lp := path.to_local(world_pos)
	var closest := path.to_global(curve.get_closest_point(lp))
	if world_pos.distance_to(closest) > ROAD_CLICK_DIST:
		return false

	var hero_off   := curve.get_closest_offset(path.to_local(hero.global_position))
	var target_off := curve.get_closest_offset(lp)
	if absf(target_off - hero_off) < 5.0:
		return false   # клик там, где герой уже стоит

	# dest = конец дороги в сторону клика. nbr_off/loc_off задают ориентацию
	# кривой; если клик в сторону current_location — идём назад к ней.
	var loc_off := curve.get_closest_offset(path.to_local(_pos(current_location)))
	var nbr_off := curve.get_closest_offset(path.to_local(_pos(nbr)))
	var dest := nbr
	if (target_off - hero_off) * (nbr_off - loc_off) < 0.0:
		dest = current_location

	# Туман-гейт только для НЕоткрытых пунктов назначения. Дорога между двумя
	# discovered-локациями уже исследована (trail/reveal) — клик свободен на
	# всю длину. К неоткрытой локации сквозь глубокий туман кликать нельзя.
	if not (discovered.get(dest, false) as bool) and not _is_road_point_visible(closest):
		print("[DEBUG] road click rejected: in fog (", dest,
			" d_hero=", snapped(hero.global_position.distance_to(closest), 1.0), ")")
		return false

	_road_path = path
	_road_dest = dest
	_last_trail_pos = hero.global_position
	hero.move_along_path("_road_", _build_partial_path(path, hero_off, target_off))
	return true

## Проверяет, попадает ли точка в открытую зону тумана.
## Зеркалит логику шейдера: radial reveal вокруг героя и discovered-локаций.
func _is_road_point_visible(point: Vector2) -> bool:
	if hero.global_position.distance_to(point) < HERO_VISIBLE_R:
		return true
	for id in discovered.keys():
		if (discovered[id] as bool) and _reveal_pos(id).distance_to(point) < ROAD_VISIBLE_R:
			return true
	return false

## Частичный путь вдоль кривой от from_off до to_off (любое направление).
## Первая и последняя точки — точные результаты sample_baked.
func _build_partial_path(path: Path2D, from_off: float, to_off: float) -> Array[Vector2]:
	var curve := path.curve
	var total := curve.get_baked_length()
	var baked := curve.get_baked_points()
	var n     := baked.size()
	var lo    := minf(from_off, to_off)
	var hi    := maxf(from_off, to_off)
	var pts: Array[Vector2] = []

	# Точки кривой локальные → герою отдаём global через path.to_global
	pts.append(path.to_global(curve.sample_baked(from_off)))
	if to_off >= from_off:
		for i in range(1, n - 1):
			var po := float(i) / float(n - 1) * total
			if po > lo and po < hi:
				pts.append(path.to_global(baked[i]))
	else:
		for i in range(n - 2, 0, -1):
			var po := float(i) / float(n - 1) * total
			if po > lo and po < hi:
				pts.append(path.to_global(baked[i]))
	pts.append(path.to_global(curve.sample_baked(to_off)))
	return pts

func _exit_tree() -> void:
	if hero != null and hero.arrived.is_connected(_on_hero_arrived):
		hero.arrived.disconnect(_on_hero_arrived)

func on_route_event(_from: String, _to: String) -> void:
	pass   # stub

# ──────────────── Прибытие ───────────────────────────────────────
func _on_hero_arrived(location_name: String) -> void:
	if location_name == "_road_":
		# Остановка посреди дороги, не в локации
		_road_active = true
		_road_offset = _road_path.curve.get_closest_offset(
			_road_path.to_local(hero.global_position))
		# Если герой достаточно близко к dest — открываем локацию
		if hero.global_position.distance_to(_pos(_road_dest)) < ARRIVAL_RADIUS:
			_arrive_at_location(_road_dest)
		else:
			_debug_state("road_stop %s off=%s" % [_road_dest, str(snapped(_road_offset, 0.1))])
			queue_redraw()
		return
	_arrive_at_location(location_name)

## Открывает локацию: туман, счётчик, соседи. Вызывается при реальном прибытии.
func _arrive_at_location(location_name: String) -> void:
	current_location           = location_name
	GameState.current_location = location_name
	# Сброс состояния дороги — герой в локации
	_road_active = false
	_road_path   = null
	_road_dest   = ""
	_road_offset = 0.0

	discovered[location_name] = true
	fog_overlay.reveal(_reveal_pos(location_name))
	fog_overlay.clear_trail()
	_last_trail_pos = Vector2(-99999.0, -99999.0)

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
			elif (a == "KnightRuins" and b == "Dock") or (a == "Dock" and b == "KnightRuins"):
				route_path = _dk_path
			elif (a == "Lumbermill" and b == "Village") or (a == "Village" and b == "Lumbermill"):
				route_path = _vl_path
			elif (a == "KnightRuins" and b == "MageTower") or (a == "MageTower" and b == "KnightRuins"):
				route_path = _km_path
			elif (a == "EarthMageCastle" and b == "KnightRuins") or (a == "KnightRuins" and b == "EarthMageCastle"):
				route_path = _ke_path

			if route_path != null:
				if route_path.curve != null:
					var baked := route_path.curve.get_baked_points()
					for i in range(baked.size() - 1):
						draw_line(route_path.to_global(baked[i]),
							route_path.to_global(baked[i + 1]), col, 4.0)
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

		if is_disc:
			draw_string(ThemeDB.fallback_font,
				pos + Vector2(-40, 40), _title(id),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13,
				Color(1.0, 1.0, 0.75, 0.95))
