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
# ЭКСПЕРИМЕНТ: длинная проходная «главная дорога» EarthMageCastle→Mine, идёт мимо
# KnightRuins/Dock/Village/Lumbermill (они НЕ endpoint'ы — только точки кривой).
@onready var _em_main_path: Path2D = $EarthMageCastleMineMainPath
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

# ──────────────── RoadGraph V2 (junction ≠ location) ─────────────
# Phase 1: только данные + self-check. НЕ подключено к навигации.
# Модель: Junction — дорожный узел (проезд action не запускает), Location —
# иконка (вход только icon-click). Дорога = Path2D segment между junction-узлами.
# В будущем encounters будут висеть на segment + offset. Junction-маркеры —
# RoadGraph/Junctions/* в Main.tscn. Старая навигация пока работает как есть.
const ROAD_JUNCTIONS := {
	"CastleJunction":      "Castle",
	"VillageJunction":     "Village",
	"DockJunction":        "Dock",
	"KnightRuinsJunction": "KnightRuins",
	"MageTowerJunction":   "MageTower",
	"EarthMageJunction":   "EarthMageCastle",
	"LumbermillJunction":  "Lumbermill",
	"MineJunction":        "Mine",
	"DarkCastleJunction":  "DarkCastle",
}

# Тестовый маршрут V2: CastleJunction → VillageJunction → LumbermillJunction → MineJunction.
# Формат: [from_junction, to_junction, path2d_node_name]. Path2D берутся из уже
# существующих узлов сцены (НЕ создаём новые дороги в Phase 1).
const ROAD_SEGMENTS_V2 := [
	["CastleJunction",    "VillageJunction",    "CastleVillagePath"],
	["VillageJunction",   "LumbermillJunction", "VillageLumbermillPath"],
	["LumbermillJunction", "MineJunction",      "LumbermillMinePath"],
]

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
# Радиус явного клика по иконке локации = вход. Маленький: клик строго по табличке,
# а не рядом. ЕДИНСТВЕННЫЙ способ войти (road-click внутрь локации не заводит).
const ICON_CLICK_R     := 18.0
# DIRECTION-STEP: клик рядом с героем задаёт направление; шаг фиксированный по offset.
# ROAD_CLICK_STEP — длина шага за клик (px по длине кривой), move_toward к концу дороги.
# DIR_TOLERANCE_DEG — допуск угла: дорогу выбираем по направлению от героя к соседу,
# ближайшему к направлению клика (разные соседи — разные направления, поэтому развилка
# различается, даже если дороги идут рядом). Проекция клика на кривую НЕ используется.
const ROAD_CLICK_STEP   := 220.0
const ROAD_ADVANCE_STEP := 60.0
const DIR_TOLERANCE_DEG := 75.0
# Свернуть на ДРУГУЮ дорогу (не ту, на которой герой стоит) можно только вплотную
# к узлу — в пределах этого радиуса от её кривой. Иначе при переходе за 80px от
# узла, где кривые уже разошлись, герой прыгал бы диагональю на чужую кривую (срез
# угла). У узла кривые сходятся в общую точку → переход без среза. Безопасно только
# вместе с _road_arrive_intended: дойдя до узла, герой НЕ входит в локацию.
const JUNCTION_SWITCH_R := 50.0

# Guard A2: fast-path в _try_road_click должен ОТКЛЮЧАТЬСЯ, если:
#  • герой рядом с destination/развилкой (до 120 px) — клик «мимо» не должен
#    дотягивать героя к dest по тангенсу кривой → [ROAD_CONTINUE_SKIP] near_dest_junction;
#  • клик не явно вперёд по текущей дороге (dot < 0.35) → [ROAD_CONTINUE_SKIP] weak_forward_dot.
const ROAD_CONTINUE_MIN_DOT := 0.35
const JUNCTION_NEAR_DEST_R  := 120.0

# Состояние «герой остановился посреди дороги, не в локации».
# Обобщает прежний _cv_offset на любую Path2D-дорогу.
var _road_active: bool   = false   # true = герой стоит на дороге, не в локации
var _road_path:   Path2D = null    # активная Path2D
var _road_dest:   String = ""      # пункт назначения текущего шага (sosed или назад)
var _road_offset: float  = 0.0     # смещение героя вдоль кривой на последней остановке
var _road_target_off: float = 0.0  # целевая точка road-click на кривой
# Намерение войти в локацию: true только если клик был В саму локацию (рядом с
# маркером). Если герой просто дошёл до конца кривой = узла развилки, но клик был
# МИМО/ЗА локацию (хочет свернуть/пройти) — прибытие НЕ засчитываем, герой стоит
# на узле в _road_active и может уйти на другую дорогу. Решает «затягивание лучом».
var _road_arrive_intended: bool = false
# Форс-вход: road-движение, запущенное ЯВНЫМ кликом по иконке (_enter_location_click),
# завершается входом в локацию. Обычный road-click его НЕ ставит → проход без захвата.
var _road_force_enter: bool = false

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
	_verify_roadgraph_v2()
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

## Phase 1 self-check RoadGraph V2: все junction-маркеры и тестовые Path2D на
## месте. Ничего не меняет в навигации — только лог/предупреждения.
func _verify_roadgraph_v2() -> void:
	var jroot := get_node_or_null("RoadGraph/Junctions")
	var ok_j := 0
	var miss_j: Array[String] = []
	for jname in ROAD_JUNCTIONS.keys():
		if jroot != null and jroot.has_node(NodePath(jname)):
			ok_j += 1
		else:
			miss_j.append(jname)
	var ok_s := 0
	var miss_s: Array[String] = []
	for seg in ROAD_SEGMENTS_V2:
		var path_name: String = seg[2]
		var n := get_node_or_null(NodePath(path_name))
		if n != null and n is Path2D:
			ok_s += 1
		else:
			miss_s.append(path_name)
	print("[ROADGRAPH_V2] ready junctions=%d/%d segments=%d/%d" \
		% [ok_j, ROAD_JUNCTIONS.size(), ok_s, ROAD_SEGMENTS_V2.size()])
	if not miss_j.is_empty():
		push_warning("[ROADGRAPH_V2] missing junctions: %s" % ", ".join(miss_j))
	if not miss_s.is_empty():
		push_warning("[ROADGRAPH_V2] missing segment paths: %s" % ", ".join(miss_s))

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

		# 1) ВХОД В ЛОКАЦИЮ = явный клик ПО ИКОНКЕ (приоритет). Малый радиус
		#    ICON_CLICK_R: входим только при клике строго по табличке. Работает и
		#    когда герой стоит на дороге у узла (иконка уже в свету). Это
		#    ЕДИНСТВЕННЫЙ способ войти — клик по дороге внутрь локации не заводит.
		var clicked := _find_accessible_waypoint(world_pos, ICON_CLICK_R)
		if clicked != "" and ((discovered.get(clicked, false) as bool) \
				or _is_road_point_visible(_pos(clicked))):
			_enter_location_click(clicked)
			return

		# 2) Иначе — шаг по дороге в сторону клика. НИКОГДА не входит в локацию:
		#    проход мимо узла/развилки без засасывания сразу на ВСЕХ узлах.
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

## Явный ВХОД по клику ПО ИКОНКЕ = REACH NODE + ACTION (квест/действие). В отличие от
## road-click (который только доезжает = reach node без действия). Если герой на дороге,
## у которой id — конец: доходит по дуге и входит (если уже на конце — reach+action сразу).
## Иначе (герой в локации) — обычный маршрут _try_move_to → вход на прибытии.
func _enter_location_click(id: String) -> void:
	if not _is_accessible(id):
		return
	if _road_active and _road_path != null:
		var curve := _road_path.curve
		var total := curve.get_baked_length()
		var dest_off := curve.get_closest_offset(_road_path.to_local(_pos(id)))
		# id — терминал текущей дороги?
		if dest_off < ARRIVAL_RADIUS or absf(dest_off - total) < ARRIVAL_RADIUS:
			var hero_off := curve.get_closest_offset(_road_path.to_local(hero.global_position))
			_road_force_enter = true
			if _commit_road_move(_road_path, id, hero_off, dest_off, true):
				return
			# Не сдвинулись (уже на конце) → вход напрямую: reach node + action.
			_road_force_enter = false
			if absf(hero_off - dest_off) < ARRIVAL_RADIUS:
				_reach_location_node(id)
				_run_location_action(id)
			return
	_try_move_to(id)

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
		"EarthMageCastle-Mine":        _em_main_path,
	}
	return by_key.get(key, null)

# Все маршруты на Path2D (пара локаций). Используется для выбора дороги по
# фактической близости героя, а не по current_location.
const ROUTED_PAIRS := [
	["Castle", "Village"], ["Village", "Dock"], ["Dock", "KnightRuins"],
	["Village", "Lumbermill"], ["Lumbermill", "Mine"],
	["KnightRuins", "MageTower"], ["MageTower", "EarthMageCastle"],
	# ЭКСПЕРИМЕНТ: главная проходная дорога. Только эти 2 — endpoint'ы/destination;
	# KnightRuins/Dock/Village/Lumbermill вдоль трека НЕ становятся dest.
	["EarthMageCastle", "Mine"],
]

# Through-road'ы: длинные проходные дороги, на которые можно «сесть» из района
# промежуточной локации (не обязательно их endpoint) и ехать по тангенсу/offset.
# Phase 1: только EarthMageCastle↔Mine (EarthMageCastleMineMainPath). Dock пока
# НЕ проходной — кривая от него далеко.
const THROUGH_ROUTES := [["EarthMageCastle", "Mine"]]

## BIDIRECTIONAL track-lock: для Path2D-дороги возвращает opposite endpoint
## относительно dest. Если dest — один конец дороги, возвращает другой конец;
## иначе "" (дорога не найдена в ROUTED_PAIRS). Используется fast-path'ом
## _try_road_click для движения назад по тому же треку (клик против тангенса).
func _opposite_endpoint(path: Path2D, dest: String) -> String:
	for pair: Array in ROUTED_PAIRS:
		var a := str(pair[0])
		var b := str(pair[1])
		var p := _route_path_for(a, b)
		if p == path:
			if a == dest:
				return b
			if b == dest:
				return a
	return ""

## THROUGH-ROAD boarding (Phase 1). Позволяет «сесть» на длинную проходную дорогу
## (EarthMageCastleMineMainPath) из РАЙОНА промежуточной локации — даже если
## current_location НЕ является её endpoint'ом. Направление берём по ТАНГЕНСУ кривой
## в точке героя (как fast-path), а не по вектору к endpoint. Шаг — фикс ROAD_ADVANCE_STEP
## к концу в сторону клика. Боковой клик → false (обычный side-road выбор работает).
func _try_through_road(world_pos: Vector2, click_dir: Vector2) -> bool:
	for pair: Array in THROUGH_ROUTES:
		var a := str(pair[0])   # start endpoint (offset 0)
		var b := str(pair[1])   # end endpoint (offset total)
		var p := _route_path_for(a, b)
		if p == null:
			continue
		var curve := p.curve
		var hlp := p.to_local(hero.global_position)
		var hero_off := curve.get_closest_offset(hlp)
		# герой должен быть РЯДОМ с кривой, иначе на неё не садимся
		var d_curve := hlp.distance_to(curve.get_closest_point(hlp))
		if d_curve >= HERO_VISIBLE_R:
			continue
		var total := curve.get_baked_length()
		# тангенс кривой в точке героя: точка на ~40px впереди/позади по offset
		var fwd_off := minf(hero_off + minf(ROAD_ADVANCE_STEP, 40.0), total)
		var bwd_off := maxf(hero_off - minf(ROAD_ADVANCE_STEP, 40.0), 0.0)
		var fwd_vec := p.to_global(curve.sample_baked(fwd_off)) - hero.global_position
		var bwd_vec := p.to_global(curve.sample_baked(bwd_off)) - hero.global_position
		var dot_fwd := click_dir.dot(fwd_vec.normalized()) if fwd_vec.length() > 1.0 else -1.0
		var dot_bwd := click_dir.dot(bwd_vec.normalized()) if bwd_vec.length() > 1.0 else -1.0
		# вперёд к b (Mine)
		if dot_fwd >= ROAD_CONTINUE_MIN_DOT and dot_fwd >= dot_bwd \
				and not _is_locked(b) \
				and ((available.get(b, false) as bool) or (discovered.get(b, false) as bool)):
			var end_off := curve.get_closest_offset(p.to_local(_pos(b)))
			var target_off := move_toward(hero_off, end_off, ROAD_ADVANCE_STEP)
			print("[THROUGH_ROAD] board dest=%s path=%s dot=%.3f hero_off=%.1f end_off=%.1f target_off=%.1f d_curve=%.1f" \
				% [b, p.name, dot_fwd, hero_off, end_off, target_off, d_curve])
			return _commit_road_move(p, b, hero_off, target_off, false)
		# назад к a (EarthMageCastle)
		if dot_bwd >= ROAD_CONTINUE_MIN_DOT and dot_bwd > dot_fwd \
				and not _is_locked(a) \
				and ((available.get(a, false) as bool) or (discovered.get(a, false) as bool)):
			var end_off := curve.get_closest_offset(p.to_local(_pos(a)))
			var target_off := move_toward(hero_off, end_off, ROAD_ADVANCE_STEP)
			print("[THROUGH_ROAD] board dest=%s path=%s dot=%.3f hero_off=%.1f end_off=%.1f target_off=%.1f d_curve=%.1f" \
				% [a, p.name, dot_bwd, hero_off, end_off, target_off, d_curve])
			return _commit_road_move(p, a, hero_off, target_off, false)
	return false

## DIRECTION-STEP: клик РЯДОМ С ГЕРОЕМ задаёт НАПРАВЛЕНИЕ (click_dir), а не точку на
## карте. Выбираем активную дорогу/ветку, направление к концу которой лучше совпадает с
## click_dir (на развилке — любую из сходящихся, оба конца — кандидаты на dest). Затем
## шагаем ФИКСИРОВАННО по offset к концу этой дороги — проекция клика на Curve2D НЕ
## используется, поэтому изгибы/петли не стопорят, не надо целиться в линию и кликать в
## туман. disabled/закрытые — мимо. Вход в локацию НЕ здесь (road-click не входит).
func _try_road_click(world_pos: Vector2) -> bool:
	var click_vec := world_pos - hero.global_position
	if click_vec.length() < 1.0:
		return false
	var click_dir := click_vec.normalized()

	# Герой уже стоит В текущей дорожной локации (fast-path пропущен через
	# dest_is_current_location): общий выбор должен брать ТОЛЬКО дороги,
	# соединённые с current_location, а не любую геометрически близкую.
	var force_current_location_candidates := false

	# ── FAST-PATH: продолжить текущую дорогу по тангенсу кривой ──────
	# На изгибах прямой вектор к endpoint-локации расходится с реальным
	# направлением дороги → dot падает ниже порога → клик «съедается».
	# Решение: если герой уже на дороге, берём локальный тангенс кривой
	# (точка на 40px впереди по offset), а не вектор к финальному маркеру.
	# dot >= ROAD_CONTINUE_MIN_DOT (0.35) = клик явно вперёд по текущей дороге → продолжаем.
	# dot < 0.35 = клик вбок → [ROAD_CONTINUE_SKIP] weak_forward_dot → общий выбор кандидатов
	# (развилка у узла различается через JUNCTION_NEAR_DEST_R-гейтом ниже).
	if _road_active and _road_path != null and _road_dest != "":
		if _road_dest == current_location:
			force_current_location_candidates = true
			print("[ROAD_CONTINUE_SKIP] reason=dest_is_current_location dest=%s current=%s" \
				% [_road_dest, current_location])
		else:
			var curve_c := _road_path.curve
			var hero_off_c := curve_c.get_closest_offset(
				_road_path.to_local(hero.global_position))
			var dest_off_c := curve_c.get_closest_offset(
				_road_path.to_local(_pos(_road_dest)))
			# Противоположный конец того же трека — цель для движения НАЗАД (клик против
			# тангенса). opp_off_c = его offset на кривой (для move_toward в reverse-ветке).
			var opp_dest := _opposite_endpoint(_road_path, _road_dest)
			var opp_off_c := dest_off_c
			if opp_dest != "":
				opp_off_c = curve_c.get_closest_offset(_road_path.to_local(_pos(opp_dest)))
			# GUARD (A): у destination/развилки fast-path ОТКЛЮЧАЕТСЯ — иначе клик
			# «мимо Village» продолжает тянуть героя в Village по тангенсу кривой.
			# Падаем в обычный выбор кандидатов по направлению клика (dot product).
			var near_dest := absf(hero_off_c - dest_off_c) < JUNCTION_NEAR_DEST_R
			if near_dest:
				print("[ROAD_CONTINUE_SKIP] reason=near_dest_junction dest=%s hero_off=%.1f dest_off=%.1f" \
					% [_road_dest, hero_off_c, dest_off_c])
			else:
				var ahead_off := move_toward(hero_off_c, dest_off_c, minf(ROAD_ADVANCE_STEP, 40.0))
				var ahead_pos := _road_path.to_global(curve_c.sample_baked(ahead_off))
				var road_vec := ahead_pos - hero.global_position
				if road_vec.length() > 1.0:
					var road_dir := road_vec.normalized()
					var dot_c := click_dir.dot(road_dir)
					if dot_c >= ROAD_CONTINUE_MIN_DOT:
						var target_off_c := move_toward(hero_off_c, dest_off_c, ROAD_ADVANCE_STEP)
						print("[ROAD_CONTINUE] dest=%s path=%s dot=%.3f hero_off=%.1f dest_off=%.1f target_off=%.1f" \
							% [_road_dest, _road_path.name, dot_c, hero_off_c, dest_off_c, target_off_c])
						return _commit_road_move(_road_path, _road_dest, hero_off_c, target_off_c, false)
					elif dot_c <= -ROAD_CONTINUE_MIN_DOT and opp_dest != "" and not _is_locked(opp_dest) \
							and ((available.get(opp_dest, false) as bool) or (discovered.get(opp_dest, false) as bool)):
						var target_off_c := move_toward(hero_off_c, opp_off_c, ROAD_ADVANCE_STEP)
						print("[ROAD_CONTINUE_REVERSE] dest=%s path=%s dot=%.3f hero_off=%.1f opp_off=%.1f target_off=%.1f" \
							% [opp_dest, _road_path.name, dot_c, hero_off_c, opp_off_c, target_off_c])
						return _commit_road_move(_road_path, opp_dest, hero_off_c, target_off_c, false)
					else:
						print("[ROAD_CONTINUE_SKIP] reason=weak_forward_dot dest=%s dot=%.3f hero_off=%.1f dest_off=%.1f" \
							% [_road_dest, dot_c, hero_off_c, dest_off_c])

	# ── THROUGH-ROAD: посадка на главную проходную дорогу ──────────────
	# После fast-path: если он НЕ увёл героя (нет ROAD_CONTINUE/REVERSE, либо
	# dest_is_current_location) — пробуем посадить на сквозную дорогу по тангенсу.
	# Боковой клик → false → обычный side-road выбор ниже работает как прежде.
	if _try_through_road(world_pos, click_dir):
		return true

	var best_path: Path2D = null
	var best_dest := ""
	var best_dot := cos(deg_to_rad(DIR_TOLERANCE_DEG))
	for pair: Array in ROUTED_PAIRS:
		var p := _route_path_for(pair[0], pair[1])
		if p == null:
			continue
		# Герой стоит В локации-узле: разрешаем ТОЛЬКО дороги, у которых
		# current_location — один из концов. Геометрически близкая дорога
		# (хороший dot, но не соединённая с узлом) больше НЕ кандидат.
		if force_current_location_candidates and current_location != "":
			var a := str(pair[0])
			var b := str(pair[1])
			if a != current_location and b != current_location:
				continue
		# герой должен СЕЙЧАС стоять на этой дороге (иначе «прыгнуть» нельзя)
		var hlp := p.to_local(hero.global_position)
		var d_curve := hlp.distance_to(p.curve.get_closest_point(hlp))
		if d_curve >= HERO_VISIBLE_R:
			continue
		# на ДРУГУЮ дорогу — только у самого узла, где кривые сходятся (без среза)
		if p != _road_path and d_curve >= JUNCTION_SWITCH_R:
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
	# ОДИН клик = ОДНА дорога до конца. Длина клика больше не влияет на дистанцию
	# проезда — direction-click уже выбрал дорогу (dot product выше), герой идёт
	# ЦЕЛИКОМ до dest_off (следующего узла). Без шагов по 40..220px.
	var target_off := move_toward(hero_off, dest_off, ROAD_ADVANCE_STEP)
	# DEBUG NAV: убрать после диагностики
	print("[ROAD_CLICK] dest=%s path=%s dot=%.3f hero_off=%.1f dest_off=%.1f target_off=%.1f" \
		% [best_dest, best_path.name, best_dot, hero_off, dest_off, target_off])
	return _commit_road_move(best_path, best_dest, hero_off, target_off)

## Запускает движение по дороге к dest до target_off. fog/discovered-гейт НЕ
## применяется: шаг ограничен ROAD_CLICK_STEP, к скрытой цели целиком не ведём.
func _commit_road_move(path: Path2D, dest: String, hero_off: float, target_off: float,
		arrive_intent: bool = false) -> bool:
	if absf(target_off - hero_off) < 5.0:
		# Герой уже у целевого узла (target_off = dest_off после фикса A).
		# Движение не запустится — засчитать arrival немедленно, иначе клик
		# «съедается» и герой стоит у маркера без reach/discover.
		# SAFE: road-click → только reach node (discover/current_location),
		# БЕЗ _run_location_action. action — только при arrive_intent (icon-click)
		# или _road_force_enter.
		if _is_locked(dest):
			return false
		if not (available.get(dest, false) as bool) and not (discovered.get(dest, false) as bool):
			return false
		_road_path = path
		_road_dest = dest
		_road_offset = hero_off
		_road_target_off = target_off
		_road_arrive_intended = arrive_intent
		_road_active = true
		# DEBUG NAV: убрать после диагностики
		print("[ROAD_ARRIVAL] dest=%s branch=INSTANT_AT_NODE road_off=%.1f dest_off=%.1f force=%s arrive_intent=%s" \
			% [dest, hero_off, target_off, _road_force_enter, arrive_intent])
		if arrive_intent or _road_force_enter:
			_road_force_enter = false
			_reach_location_node(dest)
			_run_location_action(dest)   # icon-click: вход разрешён
		else:
			_reach_location_node(dest)   # road-click: ТОЛЬКО reach node, БЕЗ action
		return true
	if _is_locked(dest):
		return false
	if not (available.get(dest, false) as bool) and not (discovered.get(dest, false) as bool):
		return false
	_road_path = path
	_road_dest = dest
	_road_target_off = target_off
	_road_arrive_intended = arrive_intent
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
		# Остановка на дороге. Различаем НАВИГАЦИЮ и ДЕЙСТВИЕ:
		#  • дошёл до КОНЦА дороги (endpoint локации) → REACH NODE: навигация
		#    (current_location/discovered/открыть дороги дальше), БЕЗ запуска действия;
		#  • остановка ПОСРЕДИ дороги → road_stop (проход мимо узла без захвата);
		#  • явный icon-click ставит _road_force_enter → REACH + ACTION (вход внутрь).
		_road_active = true
		_road_offset = _road_path.curve.get_closest_offset(
			_road_path.to_local(hero.global_position))
		var dest_off := _road_path.curve.get_closest_offset(
			_road_path.to_local(_pos(_road_dest)))
		var total := _road_path.curve.get_baked_length()
		# Достаточно: герой дошёл до dest marker по кривой. Не требуем, чтобы
		# dest_off был точно 0 или total — baked-конец кривой может не совпадать
		# с точной позицией маркера локации, и строгое условие вызывает застревание.
		var at_endpoint := absf(_road_offset - dest_off) < ARRIVAL_RADIUS
		# DEBUG NAV: убрать после диагностики
		print("[ROAD_ARRIVAL] dest=%s road_off=%.1f dest_off=%.1f total=%.1f at_endpoint=%s force=%s" \
			% [_road_dest, _road_offset, dest_off, total, at_endpoint, _road_force_enter])
		if _road_force_enter:
			_road_force_enter = false
			var dest := _road_dest   # _reach_location_node обнулит _road_dest — сохраняем
			_reach_location_node(dest)
			_run_location_action(dest)
		elif at_endpoint:
			_reach_location_node(_road_dest)   # навигация, БЕЗ действия
		else:
			_debug_state("road_stop %s off=%s" % [_road_dest, str(snapped(_road_offset, 0.1))])
			queue_redraw()
		return
	# Не "_road_": приход через _try_move_to (icon-click к не-Path2D локации) = вход.
	_reach_location_node(location_name)
	_run_location_action(location_name)

## REACH/DISCOVER NODE — навигационная веха, НЕ вход внутрь локации.
## Ставит current_location, помечает discovered, открывает туман и исходящие дороги.
## Вызывается когда герой ДОШЁЛ до endpoint дороги (road-click) ИЛИ при явном входе.
## НЕ запускает квест/бой/экран — это отдельно делает _run_location_action.
func _reach_location_node(location_name: String) -> void:
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
	_debug_state("reached node: " + location_name)
	queue_redraw()

## ENTER ACTION — явный вход ВНУТРЬ локации (квест/бой/диалог/меню). Пока заглушка-хук.
## Вызывается ТОЛЬКО при icon/marker-click, НЕ при проезде road-click мимо/до узла.
func _run_location_action(location_name: String) -> void:
	# DEBUG NAV: убрать после диагностики
	print("[LOCATION_ENTER] === action: %s === (stub: quest/battle/menu)" % location_name)

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
