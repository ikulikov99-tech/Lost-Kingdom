## MapDebugOverlay.gd — ВРЕМЕННЫЙ debug overlay карты (toggle F3).
##
## НЕ игровая фича: ничего не меняет в логике движения/маршрутов/тумана/reveal.
## Только рисует поверх карты: Path2D, waypoints, REVEAL_CENTERS, радиусы тумана,
## live-круг героя, текущий target. Данные читает из Main (consts/узлы) — Main.gd
## не модифицируется. Лежит в CanvasLayer выше тумана, рисует в экранных
## координатах (мир -> экран через камеру, как FogOverlay). Выключен по умолчанию.

extends Control

const ACTIVE_PATHS := [
	"CastleVillagePath", "VillageDockPath", "VillageLumbermillPath",
	"LumbermillMinePath", "DockKnightRuinsPath", "KnightRuinsMageTowerPath",
	"KnightRuinsEarthMagePath",
]
const DISABLED_PATHS := ["VillageRuinsPath", "EarthMageDarkCastlePath"]

# Радиусы из fog_mask.gdshader — только для визуализации
const REVEAL_R    := 135.0
const TRAIL_R     := 70.0
const HERO_R      := 50.0
const HERO_OFFSET := Vector2(0.0, -35.0)

var _main: Node = null
var _cam: Camera2D = null
var _enabled: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	_main = get_tree().current_scene
	if _main != null:
		_cam = _main.get_node_or_null("Hero/Camera2D") as Camera2D

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_F3:
		_enabled = not _enabled
		visible = _enabled
		queue_redraw()

func _process(_delta: float) -> void:
	if _enabled:
		queue_redraw()

## Мир -> экран через камеру (учёт zoom/limits, как в FogOverlay).
func _w2s(world: Vector2) -> Vector2:
	var cam: Vector2 = _cam.get_screen_center_position()
	var zoom: float = _cam.zoom.x
	var vp: Vector2 = get_viewport_rect().size
	return (world - cam) * zoom + vp * 0.5

func _draw() -> void:
	if not _enabled or _main == null or _cam == null:
		return
	var zoom: float = _cam.zoom.x
	var font := ThemeDB.fallback_font

	# 1. Активные дороги (жёлтые)
	for n: String in ACTIVE_PATHS:
		_draw_path(n, Color(1.0, 0.85, 0.2, 0.95), 2.0)
	# 2. Отключённые/будущие (фиолетовые, тоньше)
	for n: String in DISABLED_PATHS:
		_draw_path(n, Color(0.7, 0.35, 1.0, 0.7), 1.5)

	var wp: Dictionary = _main.WAYPOINTS
	var rc: Dictionary = _main.REVEAL_CENTERS
	var locked: Array = _main.LOCKED_UNTIL_MINE_EXIT

	# 3. Waypoints + LOCKED + подписи + кольцо location reveal_r
	# Позиции берём через _main._pos(id) — показываем актуальные Marker2D.
	for id: String in wp.keys():
		var wpos: Vector2 = _main._pos(id)
		var sp := _w2s(wpos)
		var is_locked := locked.has(id)
		var col := Color(1.0, 0.3, 0.3, 1.0) if is_locked else Color(0.3, 0.8, 1.0, 1.0)
		draw_circle(sp, 6.0, col)
		draw_arc(sp, 8.0, 0.0, TAU, 24, Color(0, 0, 0, 0.85), 1.5)
		draw_arc(sp, REVEAL_R * zoom, 0.0, TAU, 48, Color(0.3, 0.8, 1.0, 0.22), 1.0)
		var label: String = str(wp[id]["title"])
		if is_locked:
			label += "  [LOCKED]"
		draw_string(font, sp + Vector2(9, -8), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

	# 4. REVEAL_CENTERS — оранжевые маркеры (через _main._reveal_pos) + связь
	for id: String in rc.keys():
		var cpos: Vector2 = _main._reveal_pos(id)
		var sc := _w2s(cpos)
		var oc := Color(1.0, 0.6, 0.0, 1.0)
		if wp.has(id):
			draw_line(_w2s(_main._pos(id)), sc, Color(1.0, 0.6, 0.0, 0.55), 1.0)
		draw_circle(sc, 4.0, oc)
		draw_arc(sc, REVEAL_R * zoom, 0.0, TAU, 48, Color(1.0, 0.6, 0.0, 0.4), 1.5)
		draw_string(font, sc + Vector2(6, 12), "rc " + id, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, oc)

	# 5+6. Герой: позиция, live-круг (со смещением) hero_r, кольцо trail_r
	var hero := _main.hero as Node2D
	var hpos: Vector2 = hero.global_position
	var hs := _w2s(hpos)
	var hc := _w2s(hpos + HERO_OFFSET)
	draw_arc(hs, TRAIL_R * zoom, 0.0, TAU, 40, Color(0.0, 1.0, 0.5, 0.5), 1.0)
	draw_arc(hc, HERO_R * zoom, 0.0, TAU, 40, Color(1.0, 1.0, 0.0, 0.8), 1.5)
	draw_line(hs, hc, Color(1.0, 1.0, 0.0, 0.6), 1.0)
	draw_circle(hs, 5.0, Color(1.0, 1.0, 1.0, 1.0))

	# 7. Target-line к ФАКТИЧЕСКОЙ точке движения (Main.get_debug_target_position):
	# road-click → спроецированная точка на дороге, icon-click → waypoint.
	# _road_dest здесь не используется (он только для arrival-проверки).
	if hero.is_moving or bool(_main._road_active):
		var tp: Vector2 = _main.get_debug_target_position()
		draw_line(hs, _w2s(tp), Color(1.0, 0.0, 1.0, 0.8), 2.0)
		draw_circle(_w2s(tp), 4.0, Color(1.0, 0.0, 1.0, 0.9))

	# Легенда
	var legend := "[F3] жёлт=road  фиол=disabled  оранж=reveal  зел=trail_r  жёлт.круг=hero"
	draw_string(font, Vector2(20, 120), legend,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.9))

func _draw_path(node_name: String, col: Color, width: float) -> void:
	var p := _main.get_node_or_null(node_name) as Path2D
	if p == null or p.curve == null:
		return
	var baked := p.curve.get_baked_points()
	for i in range(baked.size() - 1):
		draw_line(_w2s(p.to_global(baked[i])), _w2s(p.to_global(baked[i + 1])), col, width)
