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
@onready var _lm_path: Path2D = $LumbermillMinePath
# VillageRuinsPath оставлен в сцене как неиспользуемый узел (ручные точки
# сохранены), но отключён от логики: маршрут к Руинам теперь Dock->KnightRuins.

# ──────────────── Координаты ─────────────────────────────────────
const WAYPOINTS := {
	"Castle":          {"title": "Королевский замок",  "pos": Vector2(-1112, -704)},
	"Village":         {"title": "Деревня",             "pos": Vector2(-928,  -504)},
	"Dock":            {"title": "Пристань",            "pos": Vector2(-1160, -128)},
	"KnightRuins":     {"title": "Руины рыцарей",       "pos": Vector2(-792,  -288)},
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
# Центр между точкой прихода (waypoint) и зданием локации на карте, чтобы
# реветь раскрывал и место героя, и саму постройку с табличкой. Оценено по
# world_map.png (1672x941, узел -672,-552, centered).
const REVEAL_CENTERS := {
	"Dock":            Vector2(-1270, -165),  # чуть левее и выше (фидбек теста)
	"KnightRuins":     Vector2(-700, -330),
	"MageTower":       Vector2(-530, -265),
	"EarthMageCastle": Vector2(-600, -600),  # на замок; ~226px от DarkCastle (-376,-568) — прячет его
	"Lumbermill":      Vector2(-615, -795),
}

const ROUTES := {
	"Castle":          ["Village"],
	"Village":         ["Castle", "Dock", "Lumbermill"],
	"Dock":            ["Village", "KnightRuins"],
	"KnightRuins":     ["Dock", "MageTower"],
	"MageTower":       ["KnightRuins", "EarthMageCastle"],
	"EarthMageCastle": ["MageTower", "DarkCastle", "Mine"],
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

# Gate: локации, закрытые до будущей механики выхода из шахты (подземелья).
# Ребро/ROAD_PATHS к DarkCastle существует, но навигация туда запрещена,
# пока _mine_exit_done = false. Подземелье НЕ реализуется здесь — только gate.
const LOCKED_UNTIL_MINE_EXIT := ["DarkCastle"]
var _mine_exit_done: bool = false
func _is_locked(id: String) -> bool:
	return not _mine_exit_done and LOCKED_UNTIL_MINE_EXIT.has(id)

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
# Direction-click: герой шагает по дороге в сторону клика, целиться в линию точно
# не надо. ROAD_CLICK_STEP — максимум шага за клик (px по длине кривой),
# MIN_ROAD_STEP — минимум; реальный шаг = к проекции клика на дорогу (короткий шаг
# «по свету»). DIR_TOLERANCE_DEG — допуск угла: дорогу выбираем по направлению от
# героя к локации-соседу, ближайшему к направлению клика (разные локации — разные
# направления, поэтому развилка различается, даже если дороги идут рядом).
const ROAD_CLICK_STEP   := 220.0
const MIN_ROAD_STEP     := 40.0
const DIR_TOLERANCE_DEG := 75.0

# Состояние «герой остановился посреди дороги, не в локации».
# Обобщает прежний _cv_offset на любую Path2D-дорогу.
var _road_active: bool   = false   # true = герой стоит на дороге, не в локации
var _road_path:   Path2D = null    # активная Path2D
var _road_dest:   String = ""      # пункт назначения текущего шага (sosed или назад)
var _road_offset: float  = 0.0     # смещение героя вдоль кривой на последней остановке
var _road_target_off: float = 0.0  # целевая точка road-click на кривой

# Визуальная настройка карты: Marker2D в Main.tscn под MapTuningMarkers.
# Если маркер есть — берём его global_position; иначе fallback на константы
# WAYPOINTS / REVEAL_CENTERS. Кэшируются в _ready.
var _wp_markers: Dictionary = {}   # id -> Marker2D/Node2D
var _rc_markers: Dictionary = {}   # id -> Marker2D/Node2D

# ──────────────── Инициализация ──────────────────────────────────
func _ready() -> void:
	# Кривая Castle<->Village загружается из Main.tscn (Curve2D_castle_village).
	# Для редактирования: выдели CastleVillagePath в сцене и двигай точки мышью.

	_cache_markers()
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
## Waypoint движения: позиция Marker2D из редактора если есть, иначе константа.
func _pos(id: String) -> Vector2:
	if _wp_markers.has(id):
		return (_wp_markers[id] as Node2D).global_position
	return WAYPOINTS[id]["pos"]

func _title(id: String) -> String:  return WAYPOINTS[id]["title"]

## Центр раскрытия тумана локации: Marker2D из редактора если есть, иначе
## константа REVEAL_CENTERS, иначе сам waypoint.
func _reveal_pos(id: String) -> Vector2:
	if _rc_markers.has(id):
		return (_rc_markers[id] as Node2D).global_position
	return REVEAL_CENTERS.get(id, _pos(id))

## Кэширует Marker2D-узлы настройки карты (MapTuningMarkers/*). Вызывается в _ready.
func _cache_markers() -> void:
	var wnode := get_node_or_null("MapTuningMarkers/Waypoints")
	if wnode != null:
		for c in wnode.get_children():
			_wp_markers[c.name] = c
	var rnode := get_node_or_null("MapTuningMarkers/RevealCenters")
	if rnode != null:
		for c in rnode.get_children():
			_rc_markers[c.name] = c

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

		# 1) Клик прямо по иконке доступной локации — идём к ней целиком.
		#    Скрытую в тумане локацию по иконке не пускаем (её не видно).
		if not _road_active:
			var clicked := _find_accessible_waypoint(world_pos)
			if clicked != "" and ((discovered.get(clicked, false) as bool) \
					or _is_road_point_visible(_pos(clicked))):
				_try_move_to(clicked)
				return

		# 2) Direction-click: герой идёт по дороге, лучше всего совпадающей с
		#    направлением клика от героя (целиться в линию не нужно).
		if _try_road_click(world_pos):
			return

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
	# Закрыто до выхода из шахты — навигация туда запрещена
	if _is_locked(id):                       return false
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

	# Если для пары есть Path2D — ВСЕГДА идём по кривой (даже при icon-клике),
	# чтобы герой не срезал углы прямой линией.
	var p := _route_path_for(current_location, id)
	if p != null:
		# Ориентация: где старт кривой — у current_location или у id
		var baked := p.curve.get_baked_points()
		var s := p.to_global(baked[0])
		if s.distance_to(_pos(current_location)) <= s.distance_to(_pos(id)):
			hero.move_along_path(id, _sample_path(p, current_location, id, true))
		else:
			hero.move_along_path(id, _sample_path(p, id, current_location, false))
		return

	# Fallback (прямая/ROAD_PATHS) — ТОЛЬКО для маршрутов без Path2D
	print("[DEBUG] no Path2D for ", current_location, "->", id,
		" — fallback direct/ROAD_PATHS")
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
		"EarthMageCastle-MageTower":   _ke_path,
		"Lumbermill-Mine":             _lm_path,
	}
	return by_key.get(key, null)

# Все маршруты на Path2D (пара локаций). Используется для выбора дороги по
# фактической близости героя, а не по current_location.
const ROUTED_PAIRS := [
	["Castle", "Village"], ["Village", "Dock"], ["Dock", "KnightRuins"],
	["Village", "Lumbermill"], ["Lumbermill", "Mine"],
	["KnightRuins", "MageTower"], ["MageTower", "EarthMageCastle"],
]

## Клик-исследование: кликаешь В СТОРОНУ, куда хочешь идти (в темноту тоже можно),
## целиться в линию не нужно. Кандидаты — ВСЕ активные дороги, на кривой которых
## герой СЕЙЧАС стоит (в пределах HERO_VISIBLE_R). На развилке он близок сразу к
## нескольким дорогам — поэтому можно свернуть на любую из них по направлению
## клика, не заходя в локацию-узел (оба конца дороги — кандидаты на dest, берём
## тот, чьё направление от героя ближе к клику). disabled/фиолетовые и закрытые —
## мимо. Шаг — к проекции клика («по свету»).
func _try_road_click(world_pos: Vector2) -> bool:
	var click_vec := world_pos - hero.global_position
	if click_vec.length() < 1.0:
		return false
	var click_dir := click_vec.normalized()
	var best_path: Path2D = null
	var best_dest := ""
	var best_dot := cos(deg_to_rad(DIR_TOLERANCE_DEG))
	for pair: Array in ROUTED_PAIRS:
		var p := _route_path_for(pair[0], pair[1])
		if p == null:
			continue
		# герой должен СЕЙЧАС стоять на этой дороге (иначе «прыгнуть» нельзя)
		var hlp := p.to_local(hero.global_position)
		if hlp.distance_to(p.curve.get_closest_point(hlp)) >= HERO_VISIBLE_R:
			continue
		# оба конца — кандидаты; вперёд к соседу или назад к узлу решает клик
		for dest: String in [str(pair[0]), str(pair[1])]:
			if _is_locked(dest):
				continue
			if not (available.get(dest, false) as bool) and not (discovered.get(dest, false) as bool):
				continue
			var to_dest := _pos(dest) - hero.global_position
			if to_dest.length() < 1.0:
				continue   # герой уже у этого конца
			var dot := click_dir.dot(to_dest.normalized())
			if dot > best_dot:
				best_dot = dot
				best_path = p
				best_dest = dest
	if best_path == null:
		return false
	var curve := best_path.curve
	var hero_off := curve.get_closest_offset(best_path.to_local(hero.global_position))
	var dest_off := curve.get_closest_offset(best_path.to_local(_pos(best_dest)))
	return _commit_road_move(best_path, best_dest, hero_off,
		_step_target_click(best_path, hero_off, dest_off, world_pos))

## Целевой offset шага: ведём к проекции клика на дорогу (короткий шаг «по свету»),
## но не дальше ROAD_CLICK_STEP и не ближе MIN_ROAD_STEP. Snap к концу (→ прибытие)
## ТОЛЬКО если игрок целит В конец дороги: клик у локации или за ней. Если клик не
## доходит до конца — герой останавливается у клика, локация НЕ «захватывает»
## (можно пройти мимо/свернуть на развилке).
func _step_target_click(path: Path2D, hero_off: float, dest_off: float, world_pos: Vector2) -> float:
	var curve := path.curve
	var total := curve.get_baked_length()
	var dir := signf(dest_off - hero_off)
	var click_off := curve.get_closest_offset(path.to_local(world_pos))
	var raw := click_off - hero_off
	# дистанцию клика берём только если он в сторону dest, иначе минимальный шаг
	var mag := absf(raw) if signf(raw) == dir else MIN_ROAD_STEP
	mag = clampf(mag, MIN_ROAD_STEP, ROAD_CLICK_STEP)
	var target_off := clampf(hero_off + dir * mag, 0.0, total)
	# целит ли клик В конец: у конца (в пределах ARRIVAL_RADIUS) или ЗА ним
	var aims_end := (dest_off - click_off) * dir <= ARRIVAL_RADIUS
	if aims_end and absf(dest_off - target_off) < ARRIVAL_RADIUS:
		target_off = dest_off
	return target_off

## Запускает движение по дороге к dest до target_off. fog/discovered-гейт НЕ
## применяется: шаг ограничен ROAD_CLICK_STEP, к скрытой цели целиком не ведём.
func _commit_road_move(path: Path2D, dest: String, hero_off: float, target_off: float) -> bool:
	if absf(target_off - hero_off) < 5.0:
		return false   # уже на месте
	if _is_locked(dest):
		return false
	if not (available.get(dest, false) as bool) and not (discovered.get(dest, false) as bool):
		return false
	_road_path = path
	_road_dest = dest
	_road_target_off = target_off
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

## Фактическая точка движения героя — для debug overlay target-line.
## road-click: спроецированная точка на _road_path по _road_target_off
## (НЕ endpoint-локация _road_dest). icon-click: waypoint цели. Иначе — позиция.
## Только чтение, на игровую логику не влияет.
func get_debug_target_position() -> Vector2:
	if _road_path != null and (_road_active or hero.target_location == "_road_"):
		return _road_path.to_global(_road_path.curve.sample_baked(_road_target_off))
	if hero.is_moving and WAYPOINTS.has(hero.target_location):
		return _pos(hero.target_location)
	return hero.global_position

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
		# Прибытие только когда герой реально у КОНЦА дороги (dest), а не просто
		# прошёл рядом с waypoint: проверяем И по прямой, И по дуге кривой.
		var dest_off := _road_path.curve.get_closest_offset(
			_road_path.to_local(_pos(_road_dest)))
		var near_xy := hero.global_position.distance_to(_pos(_road_dest)) < ARRIVAL_RADIUS
		var near_arc := absf(_road_offset - dest_off) < ARRIVAL_RADIUS
		# dest — это всегда КОНЕЦ дороги (терминал кривой 0 или длина). Маркер
		# локации может лежать в стороне от кривой (curve не дотягивает до него),
		# тогда near_xy недостижим. Поэтому прибытие засчитываем и когда герой
		# реально дошёл до терминала со стороны dest (near_arc + dest у конца).
		var total := _road_path.curve.get_baked_length()
		var dest_at_terminal := dest_off < ARRIVAL_RADIUS or absf(dest_off - total) < ARRIVAL_RADIUS
		if near_arc and (near_xy or dest_at_terminal):
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
	_road_target_off = 0.0

	discovered[location_name] = true
	fog_overlay.reveal(_reveal_pos(location_name))
	# Trail НЕ очищаем при прибытии — последние точки FIFO держат недавно
	# пройденную дорогу частично открытой (баг: дорога зарастала туманом).
	_last_trail_pos = Vector2(-99999.0, -99999.0)

	for neighbor in ROUTES[location_name]:
		if _is_locked(neighbor):
			continue   # gated до выхода из шахты — не делаем кликабельным
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
